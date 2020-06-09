open Pyast
open Pytokens

type token = token_pair
let false_token = (-1, "<empty-token>")

type node_tag =
  | Empty_tag
  | Eps_tag of (ast list Lazy.t)
  | Token_tag of ((token -> bool) * string)
  | Alt_tag
  | Seq_tag
  | Red_tag of (ast list -> ast list)
  | Unknown_tag

type node_nullable =
  | Nullable_true
  | Nullable_false of unit
  | Nullable_unvisited

type node = {
  mutable tag : node_tag;
  mutable child1 : node;
  mutable child2 : node;
  mutable nullable : node_nullable;
  mutable listeners : node list;
  mutable key : token;
  mutable value : node;
  mutable ast : ast list }

let rec false_node = {tag = Unknown_tag; child1 = false_node; child2 = false_node; nullable = Nullable_unvisited; listeners = []; key = false_token; value = false_node; ast = []}

let make_node tag child1 child2 nullable = {tag = tag; child1 = child1; child2 = child2; nullable = nullable; listeners = []; key = false_token; value = false_node; ast = []}

let node_partial_set node tag child1 child2 =
  node.tag <- tag;
  node.child1 <- child1;
  node.child2 <- child2;
  ()

let node_partial_copy dst src =
  dst.tag <- src.tag;
  dst.child1 <- src.child1;
  dst.child2 <- src.child2;
  dst.nullable <- src.nullable;
  ()

let node_add_listener n listener =
  n.listeners <- listener :: n.listeners;
  ()

let node_clear_listeners n =
  n.listeners <- [];
  ()

let an_empty_node = make_node Empty_tag false_node false_node (Nullable_false ())
let make_empty_node () = an_empty_node
let make_eps_node content = make_node (Eps_tag content) false_node false_node Nullable_true
let make_token_node pred clas = make_node (Token_tag (pred, clas)) false_node false_node (Nullable_false ())
let make_alt_node left right = make_node Alt_tag left right Nullable_unvisited
let make_seq_node left right = make_node Seq_tag left right Nullable_unvisited
let make_red_node child func = make_node (Red_tag func) child false_node Nullable_unvisited
let make_unknown_node () = make_node Unknown_tag false_node false_node Nullable_unvisited

let empty_node_set node =
  node_partial_set node Empty_tag false_node false_node;
  node.nullable <- Nullable_false ();
  ()

let eps_node_set node content =
  node_partial_set node (Eps_tag content) false_node false_node;
  node.nullable <- Nullable_true;
  ()

let token_node_set node pred clas = node_partial_set node (Token_tag (pred, clas)) false_node false_node
let alt_node_set node left right = node_partial_set node Alt_tag left right
let seq_node_set node left right = node_partial_set node Seq_tag left right
let red_node_set node child func = node_partial_set node (Red_tag func) child false_node

let make_opt_seq_node left right = match left.tag with
  | Empty_tag -> make_empty_node ()
  | Seq_tag -> make_red_node (make_seq_node left.child1 (make_seq_node left.child2 right))
     (fun ts -> List.map (fun t -> match t with
       Pyast.Ast (l1, [t1; Pyast.Ast (l2, [t2; t3])]) -> Pyast.Ast (l2, [Pyast.Ast (l1, [t1; t2]); t3])) ts)
  | Eps_tag t -> make_red_node right (fun ts2 -> List.concat (List.map (fun t1 ->
    List.map (fun t2 -> Pyast.Ast ("<seq>", [t1; t2])) ts2) (Lazy.force t)))
  | Red_tag f -> make_red_node (make_seq_node left.child1 right)
     (fun ts -> List.concat (List.map (function
     | Pyast.Ast (l, [t1; t2]) -> List.map (fun t' -> Pyast.Ast (l, [t'; t2])) (f [t1])) ts))
  | _ -> make_seq_node left right

let make_opt_red_node child func =
  match child.tag with
  | Empty_tag -> make_empty_node ()
  | Eps_tag t -> make_eps_node (lazy (func (Lazy.force t)))
  | Red_tag f -> make_red_node child.child1 (fun x -> func (f x))
  | _ -> make_red_node child func

let red_node_set_opt node child func =
  match child.tag with
  | Empty_tag -> empty_node_set node; true
  | Eps_tag content -> eps_node_set node (lazy (func (Lazy.force content))); true
  | Red_tag f -> red_node_set node child.child1 (fun x -> func (f x)); true
  | _ -> red_node_set node child func; false

let alt_node_set_opt node left right = match left.tag with
  | Eps_tag content -> (match right.tag with
    | Eps_tag content2 ->
       eps_node_set node (lazy (List.append (Lazy.force content) (Lazy.force content2)));
      true
    | _ -> alt_node_set node left right; false)
  | Empty_tag -> node_partial_copy node right; true
  | _ -> (match right.tag with
    | Empty_tag -> node_partial_copy node left; true
    | _ -> alt_node_set node left right; false)

let seq_node_set_opt_left node left right =
  match left.tag with
  | Empty_tag -> empty_node_set node; true
  | Seq_tag -> red_node_set node (make_opt_seq_node left.child1 (make_opt_seq_node left.child2 right))
     (fun ts -> List.map (function
     | Pyast.Ast (l1, [t1; Pyast.Ast (l2, [t2; t3])]) -> Pyast.Ast (l2, [Pyast.Ast (l1, [t1; t2]); t3])) ts);
    true
  | Eps_tag t -> red_node_set node right
     (fun ts2 -> List.concat (List.map (fun t1 ->
       List.map (fun t2 -> Pyast.Ast ("<seq>", [t1; t2])) ts2) (Lazy.force t)));
    true
  | Red_tag f -> red_node_set node (make_opt_seq_node left.child1 right)
     (fun ts -> List.concat (List.map (function
     | Pyast.Ast (l, [t1; t2]) -> List.map (fun t' -> Pyast.Ast (l, [t'; t2])) (f [t1])) ts));
    true
  | _ -> seq_node_set node left right; false

let rec cached_nullable visited parent node =
  match node.nullable with
  | Nullable_true -> true
  | Nullable_false _ ->
     (if not (parent == false_node) && node.nullable == visited
      then node_add_listener parent node
      else ()); false
  | Nullable_unvisited ->
     node.nullable <- visited;
    (if compute_notify_nullable visited node
     then true
     else ((if not (parent == false_node)
     then node_add_listener parent node else ()); false))

and compute_notify_nullable visited node =
  if compute_nullable visited node
  then (node.nullable <- Nullable_true;
        List.map (compute_notify_nullable visited) node.listeners;
        node_clear_listeners node;
        true)
  else false

and compute_nullable visited node =
    match node.tag with
    | Eps_tag _ -> true
    | Empty_tag -> false
    | Token_tag _ -> false
    | Seq_tag -> cached_nullable visited node node.child1 && cached_nullable visited node node.child2
    | Alt_tag -> cached_nullable visited node node.child1 || cached_nullable visited node node.child2
    | Red_tag _ -> cached_nullable visited node node.child1

let nullable node = cached_nullable (Nullable_false ()) false_node node

let optimize_gensym = (-1, "optimize_gensym")
let rec optimize l =
  if not (l.key == optimize_gensym)
  then (
    l.key <- optimize_gensym;
    let reoptimize = match l.tag with
      | Red_tag f -> (optimize l.child1;
                      red_node_set_opt l l.child1 f)
      | Alt_tag -> (optimize l.child1;
                    optimize l.child2;
                    alt_node_set_opt l l.child1 l.child2)
      | Seq_tag ->
         (optimize l.child1;
          optimize l.child2;
          (seq_node_set_opt_left l l.child1 l.child2) ||
            (match l.child2.tag with
            | Empty_tag -> empty_node_set l; true
            | Eps_tag t ->
               red_node_set l l.child1
                  (fun ts1 -> List.concat (List.map (fun t1 -> List.map (fun t2 ->
                    Pyast.Ast ("<seq>", [t1; t2])) (Lazy.force t)) ts1));
              true
            | Red_tag f ->
               red_node_set l (make_seq_node l.child1 l.child2.child1)
                 (fun ts -> List.concat (List.map (function
                 | Pyast.Ast (l, [t1; t2]) -> List.map (fun t' -> Pyast.Ast (l, [t1; t'])) [t2]) ts));
              true
            | _ -> false))
      | _ -> false in
    if reoptimize
    then (l.key <- false_token; optimize l)
    else (nullable l; ()))

let parse_tree_gensym = (-1, "parse_tree_gensym")
let rec parse_tree l =
  if l.key == parse_tree_gensym
  then l.ast
  else if not (nullable l) then []
  else (l.key <- parse_tree_gensym;
        l.ast <- [];
        let result = match l.tag with
          | Empty_tag -> []
          | Token_tag _ -> []
          | Eps_tag t -> Lazy.force t
          | Red_tag f -> f (parse_tree l.child1)
          | Alt_tag -> List.append (parse_tree l.child1) (parse_tree l.child2)
          | Seq_tag -> List.concat (List.map (fun t1 -> List.map (fun t2 -> Pyast.Ast ("<seq>", [t1; t2])) (parse_tree l.child2)) (parse_tree l.child1)) in
        l.ast <- result;
        result)

let derive_count = ref 0

let rec derive l c =
  derive_count := 1 + !derive_count;
  let my_let_result v f =
    l.key <- c;
    l.value <- v;
    f v;
    v in
  if c == l.key
  then l.value
  else match l.tag with
  | Empty_tag -> my_let_result (make_empty_node ()) (fun _ -> ())
  | Eps_tag t -> my_let_result (make_empty_node ()) (fun _ -> ())
  | Token_tag (pred, clas) -> my_let_result
     (if pred c
      then make_eps_node (lazy [Pyast.Ast (snd c, [])])
      else make_empty_node ())
     (fun _ -> ())
  | Red_tag f -> my_let_result
     (make_unknown_node ())
     (fun result -> red_node_set_opt result (derive l.child1 c) f)
  | Alt_tag -> my_let_result
     (make_unknown_node ())
     (fun result -> alt_node_set_opt result (derive l.child1 c) (derive l.child2 c))
  | Seq_tag -> my_let_result
     (make_unknown_node ())
     (fun result ->
         if nullable l.child1
         then alt_node_set_opt result
           (make_opt_red_node (derive l.child2 c)
              (let child = l.child1 in
               fun ts2 ->
                 List.concat (List.map (fun t1 ->
                   List.map (fun t2 -> Pyast.Ast ("<seq>", [t1; t2])) ts2) (parse_tree child))))
           (make_opt_seq_node (derive l.child1 c) l.child2)
         else seq_node_set_opt_left result (derive l.child1 c) l.child2)

let rec parse' l s =
  match s with
  | [] -> parse_tree l
  | c :: s' -> parse' (derive l c) s'

let parse l s =
  parse' l (List.map (fun (t, l) -> (t, l)) s)
