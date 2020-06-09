open Pyast
open Pytokens

type token = token_pair
let false_token = (-1, "<empty-token>")

type node_tag = Token_tag of ((token -> bool) * string)
              | Seq_tag
              | Eps_tag of (ast list Lazy.t)
              | Alt_tag
              | Red_tag of (ast list -> ast list)
              | Unknown_tag

type node_nullable = Nullable_true
                   | Nullable_false of unit
                   | Nullable_unvisited

type node = { mutable tag : node_tag;
              mutable children : node list;
              mutable nullable : node_nullable;
              mutable listeners : node list;
              mutable key : token;
              mutable value : node;
              mutable ast : ast list }

let rec false_node = {tag = Unknown_tag; children = []; nullable = Nullable_unvisited; listeners = []; key = false_token; value = false_node; ast = []}

let make_node tag children nullable = {tag = tag; children = children; nullable = nullable; listeners = []; key = false_token; value = false_node; ast = []}

let node_partial_set node tag children =
  node.tag <- tag;
  node.children <- children;
  ()

let node_partial_copy dst src =
  dst.tag <- src.tag;
  dst.children <- src.children;
  dst.nullable <- src.nullable;
  ()

let node_add_listener n listener =
  n.listeners <- listener :: n.listeners;
  ()

let node_clear_listeners n =
  n.listeners <- [];
  ()

let an_empty_node = make_node Alt_tag [] (Nullable_false ())
let make_empty_node () = an_empty_node
let make_token_node pred clas = make_node (Token_tag (pred, clas)) [] (Nullable_false ())
let make_alt_node children = make_node Alt_tag children Nullable_unvisited
let make_seq_node children = make_node Seq_tag children Nullable_unvisited
let make_red_node child func = make_node (Red_tag func) [child] Nullable_unvisited
let make_eps_node content = make_node (Eps_tag content) [] Nullable_true
let make_unknown_node () = make_node Unknown_tag [] Nullable_unvisited

let empty_node_set node =
  node_partial_set node Alt_tag [];
  node.nullable <- Nullable_false ();
  ()

let eps_node_set node content =
  node_partial_set node (Eps_tag content) [];
  node.nullable <- Nullable_true;
  ()

let token_node_set node pred clas = node_partial_set node (Token_tag (pred, clas)) []
let alt_node_set node children = node_partial_set node Alt_tag children
let seq_node_set node children = node_partial_set node Seq_tag children
let red_node_set node child func = node_partial_set node (Red_tag func) [child]

let rec cats' = function
  | [] -> [[]]
  | x::xs ->
     let xs' = cats' xs in
     List.concat (List.map (fun t1 -> List.map (fun t2 -> t1 :: t2) xs') x)

let rec split i xs = match (i, xs) with
  | (0, xs) -> ([], xs)
  | (n, (x :: xs)) ->
      let (is, js) = split (n-1) xs in
      (x :: is, js)

let rec split3 = function
  | [] -> ([], [], [])
  | (x, y, z) :: rest ->
      let (xs, ys, zs) = split3 rest in
      (x :: xs, y :: ys, z :: zs)

let make_opt_red_node child func =
  match (child.tag, child.children) with
  | (Alt_tag, []) -> make_empty_node ()
  | (Eps_tag content, _) -> make_eps_node (lazy (func (Lazy.force content)))
  | (Red_tag f, [x]) -> make_red_node x (fun x -> func (f x))
  | _ -> make_red_node child func

let red_node_set_opt node child func =
  match (child.tag, child.children) with
  | (Alt_tag, []) -> empty_node_set node; true
  | (Eps_tag content, _) -> eps_node_set node (lazy (func (Lazy.force content))); true
  | (Red_tag f, [x]) -> red_node_set node x (fun x -> func (f x)); true
  | _ -> red_node_set node child func; false

let rec make_opt_seq_node_left child children =
  match child.tag with
  | Alt_tag when child.children == [] -> make_empty_node ()
  | Eps_tag t -> (match children with
                  | [] -> make_eps_node (lazy (List.map (fun t -> Pyast.Ast ("<eps>", [t])) (Lazy.force t)))
                  | [child2] -> make_opt_red_node child2
                                  (fun xs -> let t' = Lazy.force t in
                                             let f z = function y -> Pyast.Ast ("<seq>", [z; y]) in
                                             List.concat (List.map (fun z -> List.map (f z) xs) t'))
                  | _ -> make_red_node (make_seq_node children)
                           (fun xs -> let t' = Lazy.force t in
                                      let f z = function Pyast.Ast (l, ys) -> Pyast.Ast (l, z :: ys) in
                                      List.concat (List.map (fun z -> List.map (f z) xs) t')))
  | Seq_tag -> make_red_node (make_seq_node (List.append child.children children))
                 (fun ts -> let g = function Pyast.Ast (l, ys) -> let (bs, cs) = split (List.length child.children) ys in
                            Pyast.Ast (l, (Pyast.Ast ("<seq>", bs) :: cs)) in  (* TODO: Are these labels correct? *)
                            List.map g ts)
  | Red_tag f -> (match children with
                  | [] -> make_red_node (List.hd child.children)
                            (fun ts -> List.map (fun t -> Pyast.Ast ("<seq>", [t])) (f ts))
                  | _ -> make_red_node (make_opt_seq_node_left (List.hd child.children) children)
                           (fun ts -> let g = function Pyast.Ast (l, y :: ys) -> List.map (fun y' -> Pyast.Ast (l, y' :: ys)) (f [y]) in
                                      List.concat (List.map g ts)))
  | _ -> make_seq_node (child :: children)

let rec alt_node_partition eps non_eps nodes = match nodes with
  | [] -> (List.rev eps, List.rev non_eps)
  | node :: nodes ->
      match node.tag with
      | Alt_tag -> alt_node_partition eps non_eps (List.append node.children nodes)
      | Eps_tag t -> alt_node_partition (t :: eps) non_eps nodes
      | _ -> alt_node_partition eps (node :: non_eps) nodes

let alt_node_set_opt node children =
  match alt_node_partition [] [] children with
  | ([], []) -> empty_node_set node; false
  | ([], [non_eps]) -> node_partial_copy node non_eps; true
  | ([], non_eps) -> alt_node_set node non_eps; false
  | ([eps], []) -> eps_node_set node eps; true
  | ([eps], non_eps) -> alt_node_set node (make_eps_node eps :: non_eps); false
  | (eps, non_eps) ->
      let eps' = lazy (List.concat (List.map Lazy.force eps)) in
      match non_eps with
      | [] -> eps_node_set node eps'; true
      | _ -> alt_node_set node (make_eps_node eps' :: non_eps); false

let seq_node_set_opt_left (node : node) (child : node) (children : node list) : bool =
  match child.tag with
  | Alt_tag when child.children == [] -> empty_node_set node; true
  | Eps_tag t -> (match children with
                  | [] -> eps_node_set node (lazy (List.map (fun t -> Pyast.Ast ("<eps>", [t])) (Lazy.force t))); true
                  | [child2] -> red_node_set_opt node child2
                                  (fun xs -> let t' = Lazy.force t in
                                             let f z = function y -> Pyast.Ast ("<seq>", [z; y]) in
                                             List.concat (List.map (fun z -> List.map (f z) xs) t'));
                                true
                  | _ -> red_node_set node (make_seq_node children)
                           (fun xs -> let t' = Lazy.force t in
                                      let f z = function Pyast.Ast (l, ys) -> Pyast.Ast (l, z :: ys) in
                                      List.concat (List.map (fun z -> List.map (f z) xs) t'));
                         true)
  | Seq_tag -> red_node_set node (make_seq_node (List.append child.children children))
                 (fun ts -> let g = function
                                    | Pyast.Ast (l, ys) -> let (bs, cs) = split (List.length child.children) ys in
                                                           Pyast.Ast (l, (Pyast.Ast ("<seq>", bs) :: cs)) in  (* TODO: Are these labels correct? *)
                            List.map g ts);
                 true
  | Red_tag f -> (match children with
                  | [] -> red_node_set_opt node (List.hd child.children)
                            (fun ts -> List.map (fun t -> Pyast.Ast ("<seq>", [t])) (f ts))
                  | _ -> red_node_set_opt node (make_opt_seq_node_left (List.hd child.children) children)
                           (fun ts -> let g = function Pyast.Ast (l, y :: ys) -> List.map (fun y' -> Pyast.Ast (l, y' :: ys)) (f [y]) in
                                      List.concat (List.map g ts)))
  | _ -> seq_node_set node (child :: children); false

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
              then node_add_listener parent node else ());
             false))

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
  | Token_tag _ -> false
  | Seq_tag -> List.for_all (cached_nullable visited node) node.children
  | Alt_tag -> List.exists (cached_nullable visited node) node.children
  | Red_tag _ -> cached_nullable visited node (List.hd node.children)

let nullable node = cached_nullable (Nullable_false ()) false_node node

let optimize_gensym = (-1, "optimize_gensym")
let rec optimize l =
  if not (l.key == optimize_gensym)
  then (l.key <- optimize_gensym;
        let reoptimize =
          match l.tag with
          | Red_tag f -> (optimize (List.hd l.children);
                          red_node_set_opt l (List.hd l.children) f)
          | Alt_tag -> (List.map optimize l.children;
                        alt_node_set_opt l l.children)
          | Seq_tag -> (List.map optimize l.children;
                        let f x = match x.tag with
                          | Seq_tag -> raise (Failure "Seq in Seq")
                          | Eps_tag _ -> raise (Failure "Eps in Seq")
                          | Alt_tag when x.children == [] -> raise (Failure "Empty in Seq")
                          | Red_tag _ -> raise (Failure "Red in Seq")
                          | _ -> () in
                        List.map f l.children;
                        (match l.children with
                        | [] -> raise (Failure "no children in Seq")
                        | _ -> ());
                        false)
            | _ -> false in
        if reoptimize
        then (l.key <- false_token; optimize l)
        else (nullable l; ()))

let parse_tree_indent = ref ""

let parse_tree_gensym = (-1, "parse_tree_gensym")
let rec parse_tree (l : node) : ast list =
  let old_parse_tree_indent = !parse_tree_indent in
  parse_tree_indent := !parse_tree_indent ^ " ";
  let result =
    (if l.key == parse_tree_gensym
     then l.ast
     else if not (nullable l) then []
     else (l.key <- parse_tree_gensym;
           l.ast <- [];
           let result = match l.tag with
             | Token_tag _ -> []
             | Eps_tag t -> Lazy.force t
             | Red_tag f -> f (parse_tree (List.hd l.children))
             | Alt_tag -> List.concat (List.map parse_tree l.children)
             | Seq_tag ->
                match l.children with
                | [] -> [Pyast.Ast ("<seq>", [])]
                | _ -> List.map (fun x -> Pyast.Ast ("<seq>", x)) (cats' (List.map parse_tree l.children)) in
           l.ast <- result;
           result)) in
  parse_tree_indent := old_parse_tree_indent;
  result

let derive_count = ref 0

let rec derive (l : node) (c : token) : node =
  derive_count := 1 + !derive_count;
  let let_result v f =
    l.key <- c;
    l.value <- v;
    f v;
    v in
  if c == l.key
  then l.value
  else match (l.tag, l.children) with
       | (Alt_tag, []) -> let_result (make_empty_node ()) (fun _ -> ())
       | (Eps_tag t, _) -> let_result (make_empty_node ()) (fun _ -> ())
       | (Seq_tag, []) -> let_result (make_empty_node ()) (fun _ -> ())
       | (Token_tag (pred, clas), _) ->
           let_result
             (if pred c
              then make_eps_node (lazy [Pyast.Ast (snd c, [])])
              else make_empty_node ())
             (fun _ -> ())
       | (Red_tag f, _) ->
           let_result
             (make_unknown_node ())
             (fun result -> red_node_set_opt result (derive (List.hd l.children) c) f)
       | (Alt_tag, _) ->
           let_result
             (make_unknown_node ())
             (fun result -> alt_node_set_opt result (List.map (fun x -> derive x c) l.children))
       | (Seq_tag, _) ->
           let_result
             (make_unknown_node ())
             (fun result ->
               match l.children with
               | [] -> eps_node_set result (lazy [])
               | [x] -> red_node_set_opt result (derive x c) (fun ts -> List.map (fun t -> Pyast.Ast ("<seq>", [t])) ts); ()
               | x :: xs ->
                   if not (nullable x)
                   then (seq_node_set_opt_left result (derive x c) xs; ())
                   else let rec r (vs : node list) (xs : node list) : (node list * node * node list) list =
                          match xs with
                          | [] -> []
                          | x :: xs -> if not (nullable x)
                                       then [(List.rev vs, derive x c, xs)]
                                       else ((List.rev vs, derive x c, xs) :: r (x :: vs) xs) in
                        let xs' = r [] xs in
                        let rr : node list * node * node list -> node = function
                          | (skipped, node, remaining) ->
                              make_opt_red_node
                                (make_opt_seq_node_left node remaining)
                                (fun remaining' ->
                                  List.map (fun x -> Pyast.Ast ("<seq>", x))
                                    (List.map List.concat
                                      (cats' [cats' (parse_tree x :: List.map parse_tree skipped);
                                              List.map (function Pyast.Ast (_, asts) -> asts) (remaining')]))) in
                        alt_node_set_opt result (make_opt_seq_node_left (derive x c) xs :: List.map rr xs'); ())
       | (Unknown_tag, _) -> failwith "Encountered Unknown_tag in derivation."

let rec parse' l s =
  match s with
  | [] -> parse_tree l
  | c :: s' -> parse' (derive l c) s'

let parse l s =
  parse' l (List.map (fun (t, l) -> (t, l)) s)
