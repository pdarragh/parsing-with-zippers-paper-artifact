open Pwz_abstract_types
open Pwz_types

let plug (p : pos) (zs : zipper list) : exp list =
  let rec pl (e' : exp') (m : mem) : exp list =
    let e = { m = m_bottom; e' = e' } in
    m.end_pos <- p;
    m.result <- e;
    List.concat (List.map (pl' e) m.parents)

  and pl' (e : exp) (c : cxt) : exp list =
    match c with
    | TopC                    -> [e]
    | SeqC (m, s, es_L, es_R) -> pl (Seq (s, (List.rev es_L) @ (e :: es_R))) m
    | AltC (m)                -> if p == m.end_pos
                                 then match m.result.e' with
                                      | Alt (es) -> es := e :: !es; []
                                      | _        -> failwith "Not an Alt."
                                 else pl (Alt (ref [e])) m

  in List.concat (List.map (fun (e', m) -> pl e' m) zs)
