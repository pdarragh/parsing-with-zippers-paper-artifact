open Types

type ast = Ast of lab * ast list

let list_product (l1 : 'a list) (l2 : ('a list) list) : ('a list) list =
  List.concat (List.map (fun l -> List.map (List.cons l) l2) l1)

let rec ast_list_of_exp (e : exp) : ast list =
  match (Lazy.force e).e' with
  | Tok _       -> []
  | Seq (l, es) -> List.map (fun asts -> Ast (l, asts)) (List.fold_right list_product (List.map ast_list_of_exp es) [[]])
  | Alt es      -> List.concat (List.map ast_list_of_exp !es)

let ast_list_of_exp_list (es : exp list) : ast list =
  List.concat (List.map ast_list_of_exp es)
