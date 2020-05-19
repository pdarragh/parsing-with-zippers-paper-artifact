open Pytokens

(* Define types. *)
type tok = token_pair
type pos = int ref
type exp = {
    mutable m : mem;
    e : exp';
}
and exp' =
    | Tok of tok
    | Seq of lab * exp list
    | Alt of (exp list) ref
and cxt =
    | TopC
    | SeqC of mem * lab * (exp list) * (exp list)
    | AltC of mem
and mem = {
    start_pos       : pos;
    mutable parents : cxt list;
    mutable end_pos : pos;
    mutable result  : exp;
}
type zipper = exp' * mem

(* Define bottom values. *)
let l_bottom = "<l_bottom>"
let t_eof = (-1, l_bottom)
let p_bottom = ref (-1)
let e'_bottom = Alt (ref [])
let rec e_bottom : exp = {
    m = m_bottom;
    e = e'_bottom;
}
and m_bottom : mem = {
    start_pos   = p_bottom;
    parents     = [];
    end_pos     = p_bottom;
    result      = e_bottom;
}

let derive (p : pos) ((t, l) : tok) ((e', m) : zipper) : zipper list =

    let rec d_d (c : cxt) (e : exp) : zipper list =
        if p == e.m.start_pos
        then (e.m.parents <- c :: e.m.parents;
              if p == e.m.end_pos
              then d_u' e.m.result c
              else [])
        else let m = { start_pos = p; parents = [c]; end_pos = p_bottom; result = e_bottom } in
             e.m <- m;
             d_d' m e.e

    and d_d' (m : mem) (e' : exp') : zipper list =
        match e' with
        | Tok (t', _)       -> if t = t'
                               then [(Seq (l, []), m)]
                               else []
        | Seq (l', [])      -> d_u (Seq (l', [])) m
        | Seq (l', e :: es) -> let m' = { start_pos = m.start_pos;
                                          parents   = [AltC m];
                                          end_pos   = p_bottom;
                                          result    = e_bottom } in
                               d_d (SeqC (m', l', [], es)) e
        | Alt (es)          -> List.concat (List.map (d_d (AltC m)) !es)

    and d_u (e' : exp') (m : mem) : zipper list =
        let e = { m = m_bottom; e = e' } in
        m.end_pos <- p;
        m.result <- e;
        List.concat (List.map (d_u' e) m.parents)

    and d_u' (e : exp) (c : cxt) : zipper list =
        match c with
        | TopC                            -> []
        | SeqC (m, l', es, [])            -> d_u (Seq (l', List.rev (e :: es))) m
        | SeqC (m, l', es_L, e_R :: es_R) -> d_d (SeqC (m, l', e :: es_L, es_R)) e_R
        | AltC (m)                        -> if p == m.end_pos
                                             then match m.result.e with
                                                  | Alt (es) -> es := e :: !es; []
                                             else d_u (Alt (ref [e])) m

    in d_u e' m

let init_zipper (e : exp) : zipper =
    let e' = Seq (l_bottom, []) in
    let m_top : mem = {
        start_pos   = p_bottom;
        parents     = [TopC];
        end_pos     = p_bottom;
        result      = e_bottom
    } in
    let c = SeqC (m_top, l_bottom, [], [e; { m = m_bottom; e = Tok t_eof }]) in
    let m_seq : mem = {
        start_pos   = p_bottom;
        parents     = [c];
        end_pos     = p_bottom;
        result      = e_bottom
    } in
    (e', m_seq)

let unwrap_top_zipper ((e', m) : zipper) : exp =
    match m.parents with
    | [SeqC ({ parents = [TopC] }, l_bottom, [e; _], [])] -> e
    | _ -> failwith "Could not unwrap top zipper!"

let parse (ts : tok list) (e : exp) : exp list =
    let rec parse (p : pos) (ts : tok list) (z : zipper) : zipper list =
        match ts with
        | []        -> derive p t_eof z
        | t :: ts'  -> List.concat (List.map (fun z' -> parse (ref (!p + 1)) ts' z') (derive p t z))
    in
    List.map unwrap_top_zipper (parse (ref 0) ts (init_zipper e))

let list_product (l1 : 'a list) (l2 : ('a list) list) : ('a list) list =
    List.concat (List.map (fun l -> List.map (List.cons l) l2) l1)

let rec ast_list_of_exp (e : exp) : Pyast.ast list =
    match e.e with
    | Tok _         -> []
    | Seq (l, es)   -> List.map (fun es' -> Pyast.Seq (l, es')) (List.fold_right list_product (List.map ast_list_of_exp es) [[]])
    | Alt es        -> List.concat (List.map ast_list_of_exp !es)

let ast_list_of_exp_list (es : exp list) : Pyast.ast list =
    List.concat (List.map ast_list_of_exp es)

let plug (p : pos) (zs : zipper list) : exp list =

    let rec pl (e' : exp') (m : mem) : exp list =
        let e = { m = m_bottom; e = e' } in
        m.end_pos <- p;
        m.result <- e;
        List.concat (List.map (pl' e) m.parents)

    and pl' (e : exp) (c : cxt) : exp list =
        match c with
        | TopC                      -> [e]
        | SeqC (m, l, es_L, es_R)   -> pl (Seq (l, (List.rev es_L) @ (e :: es_R))) m
        | AltC (m)                  -> if p == m.end_pos
                                       then match m.result.e with
                                           | Alt (es) -> es := e :: !es; []
                                       else pl (Alt (ref [e])) m

    in
    List.concat (List.map (fun (e', m) -> pl e' m) zs)

