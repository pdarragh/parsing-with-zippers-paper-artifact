open Pytokens

type tok = token_pair

type grammar' =
    | Nil
    | Eps of (Pyast.ast list) Lazy.t
    | Tok of tok
    | Seq of sym * (grammar list)
    | Alt of grammar list
    | Red of (Pyast.ast -> Pyast.ast) * grammar
and grammar = grammar' Lazy.t

let map_all = List.for_all
let map_any = List.exists

module GrammarHash = Hashtbl.Make(struct type t = grammar let equal = (==) let hash = Hashtbl.hash end)
module TokenHash = Hashtbl.Make(struct type t = tok let equal = (=) let hash = Hashtbl.hash end)

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
    let cached_val g =
        match GrammarHash.find_opt cache g with
        | Some v    -> v
        | None      -> bottom
    in
    let rec wrapper (g : grammar) : a =
        if is_visited g then
            if is_cached g then
                cached_val g
            else
                bottom
        else begin
            GrammarHash.replace params.visited g true;
            let new_val = inner_f g in
            if new_val <> cached_val g then begin
                params.changed <- true;
                GrammarHash.replace cache g new_val
            end;
            new_val
        end
    in
    if params.running then
        wrapper g
    else if is_cached g then
        cached_val g
    else begin
        let v = ref bottom in
        params.visited <- GrammarHash.create 1;
        params.changed <- true;
        params.running <- true;
        while params.changed do
            params.changed <- false;
            GrammarHash.clear params.visited;
            v := wrapper g
        done;
        params.running <- false;
        !v
    end

let memoize1 (cache : 'a GrammarHash.t) (inner_f : (grammar -> 'a)) (g : grammar) : 'a =
    match GrammarHash.find_opt cache g with
    | Some v -> v
    | None ->
        begin
            let v = inner_f g in
            GrammarHash.add cache g v;
            v
        end

let memoize2 (cache : ('a TokenHash.t) GrammarHash.t) (inner_f : (grammar -> tok -> 'a)) (g : grammar) (tok : tok) : 'a =
    match GrammarHash.find_opt cache g with
    | Some th ->
        begin
            match TokenHash.find_opt th tok with
            | Some v -> v
            | None ->
                begin
                    let v = inner_f g tok in
                    TokenHash.add th tok v;
                    v
                end
        end
    | None ->
        begin
            let th = TokenHash.create 1 in
            let v = inner_f g tok in
            TokenHash.add th tok v;
            GrammarHash.add cache g th;
            v
        end

let force_grammar_visited_cache = GrammarHash.create 1
let clear_force_grammar_visited_cache () = GrammarHash.clear force_grammar_visited_cache
let rec force_grammar (g : grammar) : unit =
    match GrammarHash.find_opt force_grammar_visited_cache g with
    | Some _    -> ()
    | None      -> begin
        GrammarHash.add force_grammar_visited_cache g true;
        match Lazy.force g with
        | Nil           -> ()
        | Eps _         -> ()
        | Tok _         -> ()
        | Seq (_, gs)   -> List.iter force_grammar gs
        | Alt gs        -> List.iter force_grammar gs
        | Red (_, g)    -> force_grammar g
    end

let is_empty_cache = GrammarHash.create 1
let clear_is_empty_cache () = GrammarHash.clear is_empty_cache
let is_empty_params = mk_parameters ()
let rec is_empty (g : grammar) : bool =
    let rec is_empty' (g : grammar) : bool =
        match Lazy.force g with
        | Nil           -> true
        | Eps _         -> false
        | Tok _         -> false
        | Seq (_, gs)   -> map_any is_empty gs
        | Alt gs        -> map_all is_empty gs
        | Red (_, g)    -> is_empty g
    in
    fix is_empty_cache is_empty_params is_empty' true g

let is_nullable_cache = GrammarHash.create 1
let clear_is_nullable_cache () = GrammarHash.clear is_nullable_cache
let is_nullable_params = mk_parameters ()
let rec is_nullable (g : grammar) : bool =
    let rec is_nullable' (g : grammar) : bool =
        match Lazy.force g with
        | Nil           -> false
        | Eps _         -> true
        | Tok _         -> false
        | Seq (_, gs)   -> map_all is_nullable gs
        | Alt gs        -> map_any is_nullable gs
        | Red (_, g)    -> is_nullable g
    in
    fix is_nullable_cache is_nullable_params is_nullable' true g

let is_null_cache = GrammarHash.create 1
let clear_is_null_cache () = GrammarHash.clear is_null_cache
let is_null_params = mk_parameters ()
let rec is_null (g : grammar) : bool =
    let rec is_null' (g : grammar) : bool =
        match Lazy.force g with
        | Nil           -> false
        | Eps _         -> true
        | Tok _         -> false
        | Seq (_, gs)   -> map_all is_null gs
        | Alt gs        -> map_all is_null gs
        | Red (_, g)    -> is_null g
    in
    fix is_null_cache is_null_params is_null' true g

let rec binary_cartesian_product (xs : 'a list) (ys : 'b list) (f : 'a -> 'b -> 'c) : 'c list =
    match xs with
    | []                -> []
    | x :: xs'          -> (List.map (f x) ys) @ (binary_cartesian_product xs' ys f)

let rec cartesian_product (lists : 'a list list) : 'a list list =
    match lists with
    | []                -> [[]]
    | list :: lists'    -> let products = cartesian_product lists' in
                           binary_cartesian_product list products List.cons

let list_product (l1 : 'a list) (l2 : ('a list) list) : ('a list) list =
    List.concat (List.map (fun l -> List.map (List.cons l) l2) l1)

let parse_null_cache = GrammarHash.create 1
let clear_parse_null_cache () = GrammarHash.clear parse_null_cache
let parse_null_params = mk_parameters ()
let rec parse_null (g : grammar) : Pyast.ast list =
    let rec parse_null' (g : grammar) : Pyast.ast list =
        match Lazy.force g with
        | Nil           -> []
        | Eps ts        -> Lazy.force ts
        | Tok _         -> []
        | Seq (l, gs)   -> List.map (fun gs' -> Pyast.Ast (l, gs')) (List.fold_right list_product (List.map parse_null gs) [[]])
        | Alt gs        -> List.concat (List.map parse_null gs)
        | Red (f, g)    -> List.map f (parse_null g)
    in
    fix parse_null_cache parse_null_params parse_null' [] g

let mk_eps_star (l : sym) (gs : grammar list) : grammar =
    lazy (Eps (lazy (List.map (fun ts -> Pyast.Ast ("EPS-*-" ^ l, ts)) (cartesian_product (List.map parse_null gs)))))

let mk_seq_star (l : sym) (prev_gs : grammar list) (next_gs : grammar list) : grammar =
    let f = fun (Pyast.Ast (l', Pyast.Ast (l'', prev_gs') :: next_gs')) -> Pyast.Ast (l', prev_gs' @ next_gs') in
    lazy (Red (f, (lazy (Seq (l, mk_eps_star l prev_gs :: next_gs)))))

let derive_cache = GrammarHash.create 1
let clear_derive_cache () = GrammarHash.clear derive_cache
let rec derive (g : grammar) (tok : tok) : grammar =
    let derive_seq (l : sym) (gs : grammar list) =
        let rec derive_seq' (prev_gs : grammar list) (next_gs : grammar list) (accum_gs : grammar list) : grammar list =
            match next_gs with
            | []            -> accum_gs
            | g :: next_gs' -> let accum_gs' = (mk_seq_star l prev_gs ((derive g tok) :: next_gs')) :: accum_gs in
                               if is_nullable g then derive_seq' (prev_gs @ [g]) next_gs' accum_gs' else accum_gs'
        in
        derive_seq' [] gs []
    in
    let rec derive' (g : grammar) ((t, l) as tok : tok) : grammar =
        lazy begin
            match Lazy.force g with
            | Nil           -> Nil
            | Eps _         -> Nil
            | Tok (t', _)   -> if t == t' then Eps (lazy [Pyast.Ast (l, [])]) else Nil
            | Seq (l', [])  -> Nil
            | Seq (l', gs)  -> Alt (derive_seq l' gs)
            | Alt gs        -> Alt (List.map (fun g -> derive g tok) gs)
            | Red (f, g)    -> Red (f, derive g tok)
        end
    in
    memoize2 derive_cache derive' g tok

let make_compact_cache = GrammarHash.create 1
let clear_make_compact_cache () = GrammarHash.clear make_compact_cache
let rec make_compact (g : grammar) : grammar =
    let rec make_compact' (g : grammar) : grammar =
        let nullp_t : Pyast.ast ref = ref (Obj.magic 0) in
        let nullp (g : grammar) =
            is_null g && (let ts = parse_null g in
                          match ts with
                          | [x]   -> nullp_t := x; true
                          | _     -> false)
        in
        lazy begin
            match Lazy.force g with
            (* Trivial compaction. *)
            | Nil                               -> Nil
            | Eps ts                            -> Eps ts
            | Tok _ as tok                      -> tok
            (* Empty/null compaction. *)
            | _ when (is_empty g)               -> Nil
            | _ when (nullp g)                  -> let t = !nullp_t in Eps (lazy [t])
            (* Sequence compaction. *)
            | Seq (l, [g])                      -> Red ((fun t -> Pyast.Ast (l, [t])), make_compact g)
            | Seq (l, [g1; g2]) when (nullp g1) -> let t1 = !nullp_t in Red ((fun t -> Pyast.Ast (l, [t1; t])), make_compact g2)
            | Seq (l, g :: gs) when (nullp g)   -> let t1 = !nullp_t in Red ((fun t -> match t with Pyast.Ast (l', ts) -> Pyast.Ast (l', t1 :: ts)), lazy (Seq (l, List.map make_compact gs)))
            | Seq (l, gs)                       -> Seq (l, List.map make_compact gs)
            (* Alternate compaction. *)
            | Alt gs                            -> Alt (List.map make_compact (List.filter (fun g -> not (is_empty g)) gs))
            (* Reduction compaction. *)
            | Red (_, g) when (is_empty g)      -> Nil
            | Red (f, lazy (Red (f', g)))       -> Red ((fun t -> f (f' t)), make_compact g)
            | Red (f, g)                        -> Red (f, make_compact g)
        end
    in
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
                              ; clear_make_compact_cache
                              ];
    parse_compact ts g

