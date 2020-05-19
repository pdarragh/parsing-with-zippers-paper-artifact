open Types

type cst = Cst of lab * cst list

let list_product (l1 : 'a list) (l2 : ('a list) list) : ('a list) list =
  List.concat (List.map (fun l -> List.map (List.cons l) l2) l1)

let rec cst_list_of_exp (e : exp) : cst list =
  match e.e' with
  | Tok _       -> []
  | Seq (l, es) -> List.map (fun csts -> Cst (l, csts)) (List.fold_right list_product (List.map cst_list_of_exp es) [[]])
  | Alt es      -> List.concat (List.map cst_list_of_exp !es)

let cst_list_of_exp_list (es : exp list) : cst list =
  List.concat (List.map cst_list_of_exp es)
