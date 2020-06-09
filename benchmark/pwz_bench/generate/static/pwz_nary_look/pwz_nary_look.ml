open Pytokens

(* Define types. *)
type tok = token_pair
type pos = int ref
type exp = { mutable m : mem;
             e : exp';
             lookahead : bool array;
             follow : bool array;
             mutable parents : exp list; }
and exp' = Tok of tok
         | Seq of sym * exp list
         | Alt of (exp list) ref
and cxt = TopC
        | SeqC of mem * sym * (exp list) * (exp list)
        | AltC of mem
and mem = { start_pos : pos;
            mutable parents : cxt list;
            mutable end_pos : pos;
            mutable result : exp; }

type zipper = exp' * mem

(* Define bottom values. *)
let l_bottom = "<l_bottom>"
let t_eof = (-1, l_bottom)
let p_bottom = ref (-1)
let e'_bottom = Alt (ref [])
let rec e_bottom : exp = {
    m           = m_bottom;
    e           = e'_bottom;
    lookahead   = [| |];
    follow      = [| |];
    parents     = []; }
and m_bottom : mem = {
    start_pos   = p_bottom;
    parents     = [];
    end_pos     = p_bottom;
    result      = e_bottom; }

let worklist : (zipper list) ref = ref []

let tops : exp list ref = ref []

let derive (p : pos) ((t, l) : tok) ((e, m) : zipper) : unit =
  let rec d_d (c : cxt) (e : exp) : unit =
    if p == e.m.start_pos
    then (e.m.parents <- c :: e.m.parents;
          if p == e.m.end_pos then d_u' e.m.result c)
    else (let m = { start_pos = p; parents = [c]; end_pos = p_bottom; result = e_bottom } in
          e.m <- m;
          d_d' m e.e)

  and d_d' (m : mem) (e : exp') : unit =
    match e with
    | Tok (t', _)       -> if t == t' then worklist := (Seq (l, []), m) :: !worklist
    | Seq (l', [])      -> d_u (Seq (l', [])) m
    | Seq (l', e :: es) -> let m' = { start_pos = m.start_pos; parents = [AltC m];
                                      end_pos = p_bottom; result = e_bottom; } in
                           d_d (SeqC (m', l', [], es)) e
    | Alt es            -> List.iter (fun e -> if e.lookahead.(t) then d_d (AltC m) e) !es

  and d_u (e : exp') (m : mem) : unit =
    let e' = { m = m_bottom; e = e; lookahead = [| |]; follow = [| |]; parents = [] } in
    m.end_pos <- p;
    m.result <- e';
    List.iter (fun c -> d_u' e' c) m.parents

  and d_u' (e : exp) (c : cxt) : unit =
    match c with
    | TopC                          -> tops := e :: !tops
    | SeqC (m, l', es, [])          -> d_u (Seq (l', List.rev (e :: es))) m
    | SeqC (m, l', left, e'::right) -> d_d (SeqC (m, l', e :: left, right)) e'
    | AltC m                        -> if p == m.end_pos
                                       then match m.result.e with
                                            | Alt es    -> es := e :: !es
                                       else d_u (Alt (ref [e])) m

  in d_u e m

let init_zipper (e : exp) : zipper =
  let e' = Seq (l_bottom, []) in
  let m_top : mem = { start_pos = p_bottom; parents = [TopC]; end_pos = p_bottom; result = e_bottom } in
  let c = SeqC (m_top, l_bottom, [], [e]) in
  let m_seq : mem = { start_pos = p_bottom; parents = [c]; end_pos = p_bottom; result = e_bottom } in
  (e', m_seq)

let unwrap_top_exp (e : exp) : exp =
  match e.e with
  | Seq (_, [_; e'])  -> e'

let parse (ts : tok list) (e : exp) : exp list =
  let rec parse (p : pos) (ts : tok list) : exp list =
    let w = !worklist in
    worklist := [];
    tops := [];
    match ts with
    | []            -> List.iter (fun z -> derive p t_eof z) w;
                       List.map unwrap_top_exp !tops
    | ((t, s)::ts') -> List.iter (fun z -> derive p (t, s) z) w;
                       parse (ref (!p + 1)) ts' in
  worklist := [init_zipper e];
  parse (ref 0) ts

let list_product (l1 : 'a list) (l2 : ('a list) list) : ('a list) list =
  List.concat (List.map (fun l -> List.map (List.cons l) l2) l1)

let rec ast_list_of_exp (e : exp) : Pyast.ast list =
  match e.e with
  | Tok _         -> []
  | Seq (l, es)   -> List.map (fun es' -> Pyast.Ast (l, es')) (List.fold_right list_product (List.map ast_list_of_exp es) [[]])
  | Alt es        -> List.concat (List.map ast_list_of_exp !es)

let ast_list_of_exp_list (es : exp list) : Pyast.ast list =
  List.concat (List.map ast_list_of_exp es)

let array_or (xs : bool array) (ys : bool array) : bool =
  let changed = ref false in
  Array.iteri (fun i y -> if not xs.(i) && y then (xs.(i) <- true; changed := true)) ys;
  !changed

let array_set_true (xs : bool array) (i : int) : bool =
  if xs.(i) != true
  then begin xs.(i) <- true; true end
  else false

let lookahead_worklist : (exp list) ref = ref []

let add_to_lookahead_worklist (e : exp) : unit = lookahead_worklist := (e :: !lookahead_worklist)

let add_parents_to_lookahead_worklist (e : exp) : unit = List.iter add_to_lookahead_worklist e.parents

let compute_lookahead_step (e : exp) : unit =
  match e.e with
  | Tok (t, _)  -> if array_set_true e.lookahead t then add_parents_to_lookahead_worklist e
  | Seq (_, es) -> let fold_or (e' : exp) (new_follow : bool array) : bool array =
                       if array_or e'.follow new_follow then add_to_lookahead_worklist e';
                       e'.lookahead in
                   if array_or e.lookahead (List.fold_right fold_or es e.follow) then add_parents_to_lookahead_worklist e
  | Alt es      -> let changed = ref false in
                   let child_or (e' : exp) : unit =
                       if array_or e'.follow e.follow then add_to_lookahead_worklist e';
                       if array_or e.lookahead e'.lookahead then changed := true in
                   List.iter child_or !es;
                   if !changed then add_parents_to_lookahead_worklist e

let rec compute_parents (e : exp) : unit =
  let check_child (e' : exp) : unit =
    let had_parents = e'.parents != [] in
    e'.parents <- (e :: e'.parents);
    if not had_parents then compute_parents e' in
  match e.e with
  | Tok _       -> ()
  | Seq (_, es) -> List.iter check_child es
  | Alt es      -> List.iter check_child !es

let compute_parents_from_root (root : exp) : unit =
  if root.parents == []
  then compute_parents root

let compute_parents_from_roots (roots : exp list) : unit =
  List.iter compute_parents_from_root roots


let compute_lookahead (initial : exp list) : unit =
  lookahead_worklist := initial;
  let rec loop () =
    match !lookahead_worklist with
    | []      -> ()
    | e :: es -> (lookahead_worklist := es;
                  compute_lookahead_step e;
                  loop ()) in
  loop ()
