open Pyast
open Pytokens

(* Define abstract types *)
type pos = int ref (* Using ref makes it easy to create values that are not pointer equal *)

let s_bottom = "<s_bottom>"

type tok = token_pair
let t_eof = (-1, "<t_eof>")

(* Define types. *)
type exp = Tok of tok
         | Seq of sym * exp list
         | Alt of (exp list) ref
type cxt = TopC
         | SeqC of mem * sym * exp list * exp list
         | AltC of mem
and mem  = { mutable parents : cxt list; result : (pos, exp) Hashtbl.t }

type zipper = exp * mem

(* Define global hashmap. *)
let mems : ((pos * exp), mem) Hashtbl.t = Hashtbl.create 0

let derive (p : pos) ((t, s) : tok) ((e, m) : zipper) : zipper list =
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
    | Tok (t', _)      -> if t = t' then [(Seq (s, []), m)] else []
    | Seq (s, [])      -> d_u (Seq (s, [])) m
    | Seq (s, e :: es) -> let m' = { parents = [AltC m]; result = Hashtbl.create 0 } in
                          d_d (SeqC (m', s, [], es)) e
    | Alt (es)         -> List.concat (List.map (d_d (AltC m)) !es)

  and d_u (e : exp) (m : mem) : zipper list =
    Hashtbl.add m.result p e;
    List.concat (List.map (d_u' e) m.parents)

  and d_u' (e : exp) (c : cxt) : zipper list =
    match c with
    | TopC                           -> []
    | SeqC (m, s, es, [])            -> d_u (Seq (s, List.rev (e :: es))) m
    | SeqC (m, s, es_L, e_R :: es_R) -> d_d (SeqC (m, s, e :: es_L, es_R)) e_R
    | AltC (m)                       -> (match Hashtbl.find_opt m.result p with
                                         | Some (Alt es) -> es := e :: !es; []
                                         | None          -> d_u (Alt (ref [e])) m)

  in d_u e m

let init_zipper (e : exp) : zipper =
  let e'    = Seq (s_bottom, []) in
  let m_top = { parents = [TopC]; result = Hashtbl.create 0; } in
  let c     = SeqC (m_top, s_bottom, [], [e; Tok t_eof]) in
  let m_seq = { parents = [c]; result  = Hashtbl.create 0; } in
  (e', m_seq)

let unwrap_top_zipper ((e', m) : zipper) : exp =
  match m.parents with
  | [SeqC ({ parents = [TopC] }, s_bottom, [e; _], [])] -> e

let parse (ts : tok list) (e : exp) : exp list =
  let rec parse' (p : pos) (ts : tok list) (z : zipper) : zipper list =
    match ts with
    | []       -> derive p t_eof z
    | t :: ts' -> List.concat (List.map (parse' (ref (!p + 1)) ts') (derive p t z)) in
  Hashtbl.clear mems;
  List.map unwrap_top_zipper (parse' (ref 0) ts (init_zipper e))

let list_product (l1 : 'a list) (l2 : ('a list) list) : ('a list) list =
  List.concat (List.map (fun l -> List.map (List.cons l) l2) l1)

let rec ast_list_of_exp (e : exp) : ast list =
  match e with
  | Tok _       -> []
  | Seq (s, es) -> List.map (fun es' -> Ast (s, es'))
                     (List.fold_right list_product (List.map ast_list_of_exp es) [[]])
  | Alt (es)    -> List.concat (List.map ast_list_of_exp !es)

let ast_list_of_exp_list (es : exp list) : ast list =
  List.concat (List.map ast_list_of_exp es)
