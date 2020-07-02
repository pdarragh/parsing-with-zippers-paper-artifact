open Pwz_abstract_types
open Pwz_types

let derive (p : pos) (t : tok) ((e', m) : zipper) : zipper list =
  let rec d_d (c : cxt) (e : exp) : zipper list =
    if p == e.m.start_pos
    then (e.m.parents <- c :: e.m.parents;
          if p == e.m.end_pos then d_u' e.m.result c else [])
    else (let m = { start_pos = p; parents = [c]; end_pos = p_bottom; result = e_bottom } in
          e.m <- m;
          d_d' m e.e')

  and d_d' (m : mem) (e' : exp') : zipper list =
    match e' with
    | Tok (t')         -> if t = t' then [(Seq (t, []), m)] else []
    | Seq (s, [])      -> d_u (Seq (s, [])) m
    | Seq (s, e :: es) -> let m' = { start_pos = m.start_pos; parents = [AltC m];
                                     end_pos = p_bottom; result = e_bottom } in
                          d_d (SeqC (m', s, [], es)) e
    | Alt (es)         -> List.concat (List.map (d_d (AltC m)) !es)

  and d_u (e' : exp') (m : mem) : zipper list =
    let e = { m = m_bottom; e' = e' } in
    m.end_pos <- p;
    m.result <- e;
    List.concat (List.map (d_u' e) m.parents)

  and d_u' (e : exp) (c : cxt) : zipper list =
    match c with
    | TopC                           -> []
    | SeqC (m, s, es, [])            -> d_u (Seq (s, List.rev (e :: es))) m
    | SeqC (m, s, es_L, e_R :: es_R) -> d_d (SeqC (m, s, e :: es_L, es_R)) e_R
    | AltC (m)                       -> if p == m.end_pos
                                        then match m.result.e' with
                                             | Alt (es) -> es := e :: !es; []
                                             | _        -> failwith "Not an Alt."
                                        else d_u (Alt (ref [e])) m

  in d_u e' m
