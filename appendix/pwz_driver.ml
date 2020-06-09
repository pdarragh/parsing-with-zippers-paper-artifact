open Pwz_abstract_types
open Pwz_types
open Pwz_derive

let init_zipper (e : exp) : zipper =
  let e'    = Seq (s_bottom, []) in
  let m_top = { start_pos = p_bottom; parents = [TopC]; end_pos = p_bottom; result = e_bottom } in
  let c     = SeqC (m_top, s_bottom, [], [e; { m = m_bottom; e' = Tok t_eof }]) in
  let m_seq = { start_pos = p_bottom; parents = [c]; end_pos = p_bottom; result = e_bottom } in
  (e', m_seq)

let unwrap_top_zipper ((e', m) : zipper) : exp =
  match m.parents with
  | [SeqC ({ parents = [TopC] }, s_bottom, [e; _], [])] -> e

let parse (ts : tok list) (e : exp) : exp list =
  let rec parse' (p : pos) (ts : tok list) (z : zipper) : zipper list =
    match ts with
    | []       -> derive p t_eof z
    | t :: ts' -> List.concat (List.map (fun z' -> parse' (ref (!p + 1)) ts' z') (derive p t z)) in
  List.map unwrap_top_zipper (parse' (ref 0) ts (init_zipper e))

type ast = Ast of sym * ast list

let list_product (l1 : 'a list) (l2 : ('a list) list) : ('a list) list =
  List.concat (List.map (fun l -> List.map (List.cons l) l2) l1)

let rec ast_list_of_exp (e : exp) : ast list =
  match e.e' with
  | Tok _       -> []
  | Seq (l, es) -> List.map (fun es' -> Ast (l, es'))
                     (List.fold_right list_product (List.map ast_list_of_exp es) [[]])
  | Alt (es)    -> List.concat (List.map ast_list_of_exp !es)

let ast_list_of_exp_list (es : exp list) : ast list =
  List.concat (List.map ast_list_of_exp es)
