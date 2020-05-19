open Types

(* These values are for tracking progress during parsing. *)
let worklist : (zipper list) ref = ref []
let tops     :    (exp list) ref = ref []

(* This is used for instrumentation. *)
let count : int ref = ref 0

let derive (p : pos) ((t, l) : tok) ((e', m) : zipper) : unit =

  let rec d_d (c : cxt) (e : exp) : unit =
    count := !count + 1;
    let e = Lazy.force e in
    if p == e.m.start_pos
    then begin
      e.m.parents <- c :: e.m.parents;
      if p == e.m.end_pos then d_u' e.m.result c
    end
    else begin
      let m = {
        start_pos = p;
        parents   = [c];
        end_pos   = p_bottom;
        result    = e_bottom;
      } in
      e.m <- m;
      d_d' m e.e'
    end

  and d_d' (m : mem) (e' : exp') : unit =
    count := !count + 1;
    match e' with
    | Tok (t', _)       -> if t == t' then worklist := (Seq (l, []), m) :: !worklist
    | Seq (l', [])      -> d_u (Seq (l', [])) m
    | Seq (l', e :: es) -> let m' = {
                             start_pos = m.start_pos;
                             parents = [AltC m];
                             end_pos = p_bottom;
                             result = e_bottom;
                           } in
                           d_d (SeqC (m', l', [], es)) e
    | Alt es            -> List.iter (fun e -> d_d (AltC m) e) !es

  and d_u (e' : exp') (m : mem) : unit =
    count := !count + 1;
    let e = lazy { m = m_bottom; e' = e' } in
    m.end_pos <- p;
    m.result <- e;
    List.iter (fun c -> d_u' e c) m.parents

  and d_u' (e : exp) (c : cxt) : unit =
    count := !count + 1;
    match c with
    | TopC                            -> tops := e :: !tops
    | SeqC (m, l', es, [])            -> d_u (Seq (l', List.rev (e :: es))) m
    | SeqC (m, l', left, e' :: right) -> d_d (SeqC (m, l', e :: left, right)) e'
    | AltC m                          -> if p == m.end_pos
                                         then match (Lazy.force m.result).e' with
                                           | Alt es -> es := e :: !es
                                           | _ -> failwith "Failed match in the AltC clause of d_u'!"
                                         else d_u (Alt (ref [e])) m

  in d_u e' m

let init_zipper (e : exp) : zipper =
  let e' = Seq (l_bottom, []) in
  let m_top : mem = {
    start_pos = p_bottom;
    parents   = [TopC];
    end_pos   = p_bottom;
    result    = e_bottom;
  } in
  let c = SeqC (m_top, l_bottom, [], [e]) in
  let m_seq : mem = {
    start_pos = p_bottom;
    parents   = [c];
    end_pos   = p_bottom;
    result    = e_bottom;
  } in
  (e', m_seq)

let unwrap_top_exp (e1 : exp) : exp =
  match (Lazy.force e1).e' with
  | Seq (_, [_; e2]) -> e2
  | _                -> failwith "Failed to unwrap top exp!"

let parse (ts : tok list) (e : exp) : exp list =
  let rec parse' (p : pos) (ts : tok list) : exp list =
    let w = !worklist in
    worklist := [];
    tops := [];
    match ts with
    | []              -> List.iter (fun z -> derive p t_eof z) w;
                         List.map unwrap_top_exp !tops
    | ((t, s) :: ts') -> List.iter (fun z -> derive p (t, s) z) w;
                         parse' (ref (!p + 1)) ts'
  in
  worklist := [init_zipper e];
  parse' (ref 0) ts

let instrumented_parse (ts : tok list) (e : exp) : ((exp list) * int) =
  count := 0;
  let es = parse ts e in
  (es, !count)
