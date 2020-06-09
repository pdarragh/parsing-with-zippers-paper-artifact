open Pytokens

type tok = token_pair

type grammar' = Nil
              | Eps of (Pyast.ast list) Lazy.t
              | Tok of tok
              | Seq of sym * grammar * grammar
              | Alt of grammar * grammar
              | Red of (Pyast.ast -> Pyast.ast) * grammar
and grammar   = grammar' Lazy.t

module GrammarHash = Hashtbl.Make(struct type t = grammar;; let equal = (==);; let hash = Hashtbl.hash end)
module TokenHash   = Hashtbl.Make(struct type t = tok;;     let equal = (=);;  let hash = Hashtbl.hash end)

type parameters = {
  mutable visited : bool GrammarHash.t;
  mutable changed : bool;
  mutable running : bool;
}

let mk_parameters () : parameters = {
  visited = GrammarHash.create 1;
  changed = false;
  running = false;
}

let fix (type a) (cache : a GrammarHash.t) (params : parameters) (inner_f : (grammar -> a)) (bottom : a) (g : grammar) =
  let is_cached = fun g -> GrammarHash.mem cache g in
  let is_visited = fun g -> GrammarHash.mem params.visited g in
  let cached_val g = match GrammarHash.find_opt cache g with
                   | Some v    -> v
                   | None      -> bottom in
  let rec wrapper (g : grammar) : a =
    if is_visited g
    then if is_cached g then cached_val g else bottom
    else (GrammarHash.replace params.visited g true;
          let new_val = inner_f g in
          if new_val <> cached_val g
          then (params.changed <- true;
                GrammarHash.replace cache g new_val);
          new_val) in
  if params.running
  then wrapper g
  else if is_cached g
  then cached_val g
  else (let v = ref bottom in
        params.visited <- GrammarHash.create 1;
        params.changed <- true;
        params.running <- true;
        while params.changed do
          params.changed <- false;
          GrammarHash.clear params.visited;
          v := wrapper g
        done;
        params.running <- false;
        !v)

let memoize1 (cache : 'a GrammarHash.t) (inner_f : (grammar -> 'a)) (g : grammar) : 'a =
  match GrammarHash.find_opt cache g with
  | Some v -> v
  | None   -> (let v = inner_f g in
               GrammarHash.add cache g v;
               v)

let memoize2 (cache : ('a TokenHash.t) GrammarHash.t) (inner_f : (grammar -> tok -> 'a)) (g : grammar) (tok : tok) : 'a =
  match GrammarHash.find_opt cache g with
  | Some th -> (match TokenHash.find_opt th tok with
                | Some v -> v
                | None   -> (let v = inner_f g tok in
                             TokenHash.add th tok v;
                             v))
  | None    -> (let th = TokenHash.create 1 in
                let v = inner_f g tok in
                TokenHash.add th tok v;
                GrammarHash.add cache g th;
                v)

let force_grammar_visited_cache = GrammarHash.create 1
let clear_force_grammar_visited_cache () = GrammarHash.clear force_grammar_visited_cache
let rec force_grammar (g : grammar) : unit =
  match GrammarHash.find_opt force_grammar_visited_cache g with
  | Some _ -> ()
  | None   -> (GrammarHash.add force_grammar_visited_cache g true;
               match Lazy.force g with
               | Nil             -> ()
               | Eps _           -> ()
               | Tok _           -> ()
               | Seq (_, g1, g2) -> force_grammar g1; force_grammar g2
               | Alt (g1, g2)    -> force_grammar g1; force_grammar g2
               | Red (_, g)      -> force_grammar g)

let is_empty_cache = GrammarHash.create 1
let clear_is_empty_cache () = GrammarHash.clear is_empty_cache
let is_empty_params = mk_parameters ()
let rec is_empty (g : grammar) : bool =
  let rec is_empty' (g : grammar) : bool =
    match Lazy.force g with
    | Nil             -> true
    | Eps _           -> false
    | Tok _           -> false
    | Seq (_, g1, g2) -> is_empty g1 || is_empty g2
    | Alt (g1, g2)    -> is_empty g1 && is_empty g2
    | Red (_, g)      -> is_empty g in
  fix is_empty_cache is_empty_params is_empty' true g

let is_nullable_cache = GrammarHash.create 1
let clear_is_nullable_cache () = GrammarHash.clear is_nullable_cache
let is_nullable_params = mk_parameters ()
let rec is_nullable (g : grammar) : bool =
  let rec is_nullable' (g : grammar) : bool =
    match Lazy.force g with
    | Nil             -> false
    | Eps _           -> true
    | Tok _           -> false
    | Seq (_, g1, g2) -> is_nullable g1 && is_nullable g2
    | Alt (g1, g2)    -> is_nullable g1 || is_nullable g2
    | Red (_, g)      -> is_nullable g in
  fix is_nullable_cache is_nullable_params is_nullable' true g

let is_null_cache = GrammarHash.create 1
let clear_is_null_cache () = GrammarHash.clear is_null_cache
let is_null_params = mk_parameters ()
let rec is_null (g : grammar) : bool =
  let rec is_null' (g : grammar) : bool =
    match Lazy.force g with
    | Nil             -> false
    | Eps _           -> true
    | Tok _           -> false
    | Seq (_, g1, g2) -> is_null g1 && is_null g2
    | Alt (g1, g2)    -> is_null g1 && is_null g2
    | Red (_, g)      -> is_null g in
  fix is_null_cache is_null_params is_null' true g

let list_product (l1 : 'a list) (l2 : ('a list) list) : ('a list) list =
  List.concat (List.map (fun l -> List.map (List.cons l) l2) l1)

let rec binary_cartesian_product (xs : 'a list) (ys : 'b list) (f : 'a -> 'b -> 'c) : 'c list =
  match xs with
  | []       -> []
  | x :: xs' -> (List.map (f x) ys) @ (binary_cartesian_product xs' ys f)

let parse_null_cache = GrammarHash.create 1
let clear_parse_null_cache () = GrammarHash.clear parse_null_cache
let parse_null_params = mk_parameters ()
let rec parse_null (g : grammar) : Pyast.ast list =
  let rec parse_null' (g : grammar) : Pyast.ast list =
    match Lazy.force g with
    | Nil             -> []
    | Eps ts          -> Lazy.force ts
    | Tok _           -> []
    | Seq (l, g1, g2) -> let t1s = parse_null g1 in
                         let t2s = parse_null g2 in
                         binary_cartesian_product t1s t2s (fun t1 t2 -> Pyast.Ast (l, [t1; t2]))
    | Alt (g1, g2)    -> parse_null g1 @ parse_null g2
    | Red (f, g)      -> List.map f (parse_null g) in
  fix parse_null_cache parse_null_params parse_null' [] g

let mk_eps_star (g : grammar) : grammar = lazy (Eps (lazy (parse_null g)))

let derive_cache = GrammarHash.create 1
let clear_derive_cache () = GrammarHash.clear derive_cache
let rec derive (g : grammar) (tok : tok) : grammar =
  let rec derive' (g : grammar) ((t, l) as tok : tok) : grammar =
    lazy (match Lazy.force g with
          | Nil              -> Nil
          | Eps _            -> Nil
          | Tok (t', _)      -> if t == t' then Eps (lazy [Pyast.Ast (l, [])]) else Nil
          | Seq (l', g1, g2) -> if is_nullable g1
                                then Alt (lazy (Seq (l', derive g1 tok, g2)),
                                          lazy (Seq (l', mk_eps_star g1, derive g2 tok)))
                                else Seq (l', derive g1 tok, g2)
          | Alt (g1, g2)     -> Alt (derive g1 tok, derive g2 tok)
          | Red (f, g)       -> Red (f, derive g tok)) in
  memoize2 derive_cache derive' g tok

let make_compact_cache = GrammarHash.create 1
let clear_make_compact_cache () = GrammarHash.clear make_compact_cache
let rec make_compact (g : grammar) : grammar =
  let rec make_compact' (g : grammar) : grammar =
    let nullp_t : Pyast.ast ref = ref (Obj.magic 0) in
    let nullp (g : grammar) =
      is_null g && (match parse_null g with
                    | [x]   -> nullp_t := x; true
                    | _     -> false) in
    lazy (match Lazy.force g with
          (* Trivial compaction. *)
          | Nil                           -> Nil
          | Eps ts                        -> Eps ts
          | Tok _ as tok                  -> tok
          (* Empty/null compaction. *)
          | _ when is_empty g             -> Nil
          | _ when nullp g                -> let t = !nullp_t in Eps (lazy [t])
          (* Sequence compaction. *)
          | Seq (l, g1, g2) when nullp g1 -> let t1 = !nullp_t in Red ((fun t2 -> Pyast.Ast (l, [t1; t2])), make_compact g2)
          | Seq (l, g1, g2) when nullp g2 -> let t2 = !nullp_t in Red ((fun t1 -> Pyast.Ast (l, [t1; t2])), make_compact g1)
          | Seq (l, g1, g2)               -> Seq (l, make_compact g1, make_compact g2)
          (* Alternate compaction. *)
          | Alt (g1, g2) when is_empty g1 -> Lazy.force (make_compact g2)
          | Alt (g1, g2) when is_empty g2 -> Lazy.force (make_compact g1)
          | Alt (g1, g2)                  -> Alt (make_compact g1, make_compact g2)
          (* Reduction compaction. *)
          | Red (_, g) when is_empty g    -> Nil
          | Red (f, lazy (Red (f', g)))   -> Red ((fun t -> f (f' t)), make_compact g)
          | Red (f, g)                    -> Red (f, make_compact g)) in
  memoize1 make_compact_cache make_compact' g

let rec parse_compact (ts : tok list) (g : grammar) : Pyast.ast list =
  force_grammar g;
  match ts with
  | []        -> parse_null g
  | t :: ts'  -> parse_compact ts' (make_compact (derive g t))

let parse (ts : tok list) (g : grammar) : Pyast.ast list =
  List.iter (fun f -> f ()) [ clear_force_grammar_visited_cache
                            ; clear_is_empty_cache
                            ; clear_is_nullable_cache
                            ; clear_is_null_cache
                            ; clear_parse_null_cache
                            ; clear_derive_cache
                            ; clear_make_compact_cache ];
  parse_compact ts g
