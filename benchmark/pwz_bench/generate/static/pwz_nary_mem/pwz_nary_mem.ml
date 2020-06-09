open Pytokens

(* Define types. *)
type tok = token_pair
type pos = int ref
type exp = Tok of tok
         | Seq of sym * (exp list)
         | Alt of (exp list) ref
type cxt = TopC
         | SeqC of mem * sym * (exp list) * (exp list)
         | AltC of mem
and mem  = { mutable parents : cxt list; result : (pos, exp) Hashtbl.t }

type zipper = exp * mem

(* Define bottom values. *)
let l_bottom = "<l_bottom>"
let t_eof = (-1, l_bottom)

(* Define global hashmap. *)
let mems : ((pos * exp), mem) Hashtbl.t = Hashtbl.create 0

let derive (p : pos) ((t, l) : tok) ((e, m) : zipper) : zipper list =
  let rec d_d (c : cxt) (e : exp) : zipper list =
    match Hashtbl.find_opt mems (p, e) with
    | Some m -> m.parents <- c :: m.parents;
                (match Hashtbl.find_opt m.result p with
                 | Some e -> d_u' e c
                 | None   -> [])
    | None   -> let m = { parents = [c]; result = Hashtbl.create 0 } in
                Hashtbl.add mems (p, e) m;
                d_d' m e

  and d_d' (m : mem) (e : exp) : zipper list =
    match e with
    | Tok (t', _)       -> if t == t' then [(Seq (l, []), m)] else []
    | Seq (l', [])      -> d_u (Seq (l', [])) m
    | Seq (l', e :: es) -> let m' = { parents = [AltC m]; result = Hashtbl.create 0 } in
                           d_d (SeqC (m', l', [], es)) e
    | Alt (es)          -> List.concat (List.map (d_d (AltC m)) !es)

  and d_u (e : exp) (m : mem) : zipper list =
    Hashtbl.add m.result p e;
    List.concat (List.map (d_u' e) m.parents)

  and d_u' (e : exp) (c : cxt) : zipper list =
    match c with
    | TopC                            -> []
    | SeqC (m, l', es, [])            -> d_u (Seq (l', List.rev (e :: es))) m
    | SeqC (m, l', left, e' :: right) -> d_d (SeqC (m, l', e :: left, right)) e'
    | AltC m                          -> (match (Hashtbl.find_opt m.result p) with
                                          | Some (Alt es) -> es := e :: !es; []
                                          | None          -> d_u (Alt (ref [e])) m)

  in d_u e m

let init_zipper (e : exp) : zipper =
  let e' = Seq (l_bottom, []) in
  let m_top : mem = { parents = [TopC]; result  = Hashtbl.create 0; } in
  let c = SeqC (m_top, l_bottom, [], [e; Tok t_eof]) in
  let m_seq : mem = { parents = [c]; result  = Hashtbl.create 0; } in
  (e', m_seq)

let unwrap_top_zipper ((e', m) : zipper) : exp =
  match m.parents with
  | [SeqC ({ parents = [TopC] }, l_bottom, [e; _], [])] -> e

let parse (ts : tok list) (e : exp) : exp list =
  Hashtbl.clear mems;
  let rec parse (p : pos) (ts : tok list) (z : zipper) : zipper list =
    match ts with
    | []       -> derive p t_eof z
    | t :: ts' -> List.concat (List.map (fun z' -> parse (ref (!p + 1)) ts' z') (derive p t z))
  in
  List.map unwrap_top_zipper (parse (ref 0) ts (init_zipper e))

let list_product (l1 : 'a list) (l2 : ('a list) list) : ('a list) list =
  List.concat (List.map (fun l -> List.map (List.cons l) l2) l1)

let rec ast_list_of_exp (e : exp) : Pyast.ast list =
  match e with
  | Tok _       -> []
  | Seq (l, es) -> List.map (fun es' -> Pyast.Ast (l, es')) (List.fold_right list_product (List.map ast_list_of_exp es) [[]])
  | Alt es      -> List.concat (List.map ast_list_of_exp !es)

let ast_list_of_exp_list (es : exp list) : Pyast.ast list =
  List.concat (List.map ast_list_of_exp es)
