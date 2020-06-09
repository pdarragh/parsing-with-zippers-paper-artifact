open Types

(* These values are for tracking progress during parsing. *)
let worklist : (zipper list) ref = ref []

let tops : (exp list) ref = ref []

(* This is used for instrumentation. *)
let count : int ref = ref 0

let derive (p : pos) ((t, s) : tok) ((e', m) : zipper) : unit =
  let rec d_d (c : cxt) (e : exp) : unit =
    count := !count + 1;
    let e = Lazy.force e in
    if p == e.m.start_pos
    then (e.m.parents <- c :: e.m.parents;
          if p == e.m.end_pos then d_u' e.m.result c)
    else (let m = { start_pos = p; parents = [c]; end_pos = p_bottom; result = e_bottom } in
          e.m <- m;
          d_d' m e.e')

  and d_d' (m : mem) (e' : exp') : unit =
    count := !count + 1;
    match e' with
    | Tok (t', _)      -> if t = t' then worklist := (Seq (s, []), m) :: !worklist
    | Seq (s, [])      -> d_u (Seq (s, [])) m
    | Seq (s, e :: es) -> let m' = { start_pos = m.start_pos; parents = [AltC m];
                                     end_pos = p_bottom; result = e_bottom } in
                          d_d (SeqC (m', s, [], es)) e
    | Alt (es)         -> List.iter (d_d (AltC m)) !es

  and d_u (e' : exp') (m : mem) : unit =
    count := !count + 1;
    let e = lazy { m = m_bottom; e' = e' } in
    m.end_pos <- p;
    m.result <- e;
    List.iter (d_u' e) m.parents

  and d_u' (e : exp) (c : cxt) : unit =
    count := !count + 1;
    match c with
    | TopC                           -> tops := e :: !tops
    | SeqC (m, s, es, [])            -> d_u (Seq (s, List.rev (e :: es))) m
    | SeqC (m, s, es_L, e_R :: es_R) -> d_d (SeqC (m, s, e :: es_L, es_R)) e_R
    | AltC (m)                       -> if p == m.end_pos
                                        then match (Lazy.force m.result).e' with
                                             | Alt (es) -> es := e :: !es
                                        else d_u (Alt (ref [e])) m

  in d_u e' m

let init_zipper (e : exp) : zipper =
  let e'    = Seq (s_bottom, []) in
  let m_top = { start_pos = p_bottom; parents = [TopC]; end_pos = p_bottom; result = e_bottom } in
  let c     = SeqC (m_top, s_bottom, [], [e]) in
  let m_seq = { start_pos = p_bottom; parents = [c]; end_pos = p_bottom; result = e_bottom } in
  (e', m_seq)

let unwrap_top_exp (e : exp) : exp =
  match (Lazy.force e).e' with
  | Seq (_, [_; e]) -> e

let parse (ts : tok list) (e : exp) : exp list =
  let rec parse' (p : pos) (ts : tok list) : exp list =
    let w = !worklist in
    worklist := [];
    tops := [];
    match ts with
    | []            -> List.iter (derive p t_eof) w;
                       List.map unwrap_top_exp !tops
    | (t, s) :: ts' -> List.iter (derive p (t, s)) w;
                       parse' (ref (!p + 1)) ts' in
  worklist := [init_zipper e];
  parse' (ref 0) ts

let instrumented_parse (ts : tok list) (e : exp) : (exp list) * int =
  count := 0;
  let es = parse ts e in
  (es, !count)

let plug (p : pos) (zs : zipper list) : exp list =
  let rec pl (e' : exp') (m : mem) : exp list =
    let e = lazy { m = m_bottom; e' = e' } in
    m.end_pos <- p;
    m.result <- e;
    List.concat (List.map (pl' e) m.parents)

  and pl' (e : exp) (c : cxt) : exp list =
    match c with
    | TopC                    -> [e]
    | SeqC (m, s, es_L, es_R) -> pl (Seq (s, (List.rev es_L) @ (e :: es_R))) m
    | AltC (m)                -> if p == m.end_pos
                                 then match (Lazy.force m.result).e' with
                                      | Alt (es) -> es := e :: !es; []
                                 else pl (Alt (ref [e])) m

  in List.concat (List.map (fun (e', m) -> pl e' m) zs)
