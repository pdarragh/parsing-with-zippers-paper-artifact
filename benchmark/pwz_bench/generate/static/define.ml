type 'a eq_type =
    | Eq
    | Equal
    | Custom of ('a -> 'a -> bool)

let eq_lookup (eq : 'a eq_type) : ('a -> 'a -> bool) =
    match eq with
    | Eq        -> (==)
    | Equal     -> (=)
    | Custom f  -> f

module type MakeHashedType = sig
    type key
    val eq : key eq_type
end

(*
    The MakeHash module wraps the Hashtbl.S module type to provide
    functionality that is otherwise not raedily accessible to derivative
    modules produced via Hashtbl.Make. This structure allows for the
    implementation of additional functions that operate over these
    derived Hashtbl modules.
*)
module MakeHash(H : MakeHashedType) = struct
    module Hash = Hashtbl.Make(struct type t = H.key let equal = (eq_lookup H.eq) let hash = Hashtbl.hash end)

    type key = H.key
    type 'a hash_t = 'a Hash.t
    type 'a t = 'a hash_t

    let add = Hash.add
    let clear = Hash.clear
    let create = Hash.create
    let find = Hash.find
    let find_opt = Hash.find_opt
    let mem = Hash.mem
    let replace = Hash.replace

    (* `hash_ref` is a translation of `hash-ref` from Racket. *)
    let hash_ref (type value) (h : value hash_t) (k : key) (e : value) : value =
        match find_opt h k with
        | Some v    -> v
        | None      -> e

    (* `ymem` is the memoizing y-combinator. *)
    let rec ymem (type value) (h : ((value option) ref) hash_t) (f : (key -> (value option) ref) -> key -> (value option)) : (key -> (value option) ref) =
        let rec f' (k : key) : ((value option) ref) =
            match find_opt h k with
            | Some v -> v
            | None -> let v : ((value option) ref) = ref None in
                        add h k v;
                        v := f f' k;
                        v
        in
        f'
end

(*
    `fix` is a function which computes a fixed point of another function. This
    implementation is based on the `define/fix` syntax extension defined in
    `fixed-points.rkt` in the original implementation. The predicates in the
    `func` function have been rearranged to produce code that is easier to
    reason about. A full explanation of changes is detailed at the bottom of
    this file.
*)
let fix (type a) (type b) (f : (a -> b) -> a -> b) (bottom : b) (a_eq : a eq_type) : (a -> b) =
    let module HashA = MakeHash(struct type key = a let eq = a_eq end) in
    let module T = struct
        type parameters = {
            mutable visited : bool HashA.t;
            mutable changed : bool;
            mutable running : bool;
        }
    end in
    let open T in
    let params : parameters = {
        visited = HashA.create 1;
        changed = false;
        running = false;
    } in
    let cache = HashA.create 1 in
    let is_cached = fun x -> HashA.mem cache x in               (* is_cached and is_visited are implemented as thunks   *)
    let is_visited = fun x -> HashA.mem params.visited x in     (* to prevent unnecessary lookup at runtime.            *)
    let cached_val = fun x -> HashA.hash_ref cache x bottom in
    let rec f' (x : a) : b =
        if is_visited x then
            if is_cached x then
                cached_val x
            else
                bottom
        else begin
            HashA.replace params.visited x true;
            let new_val = f f' x in
            if new_val <> cached_val x then begin
                params.changed <- true;
                HashA.replace cache x new_val;
            end;
            new_val
        end
    in
    let first_f' (x : a) : b =
        if params.running then
            f' x
        else if is_cached x then
            cached_val x
        else begin
            let v = ref bottom in
            params.visited <- HashA.create 1;
            params.changed <- true;
            params.running <- true;
            while params.changed do
                params.changed <- false;
                HashA.clear params.visited;
                v := f' x
            done;
            params.running <- false;
            !v
        end
    in
    first_f'

(*
    The Memoize module provides the capability to memoize functions of one or
    two arguments.
*)
module Memoize : sig
    val args1 : (('a -> ('b option) ref) -> 'a -> 'b) -> 'a eq_type -> ('a -> ('b option) ref)
    val args2 : (('a -> 'b -> ('c option) ref) -> 'a -> 'b -> 'c) -> 'a eq_type -> 'b eq_type -> ('a -> 'b -> ('c option) ref)
end = struct
    (* Memoize a function of one argument. *)
    let args1 (type a) (type b) (f : (a -> (b option) ref) -> a -> b) (eq : a eq_type) : (a -> (b option) ref) =
        let module HashA = MakeHash(struct type key = a let eq = eq end) in
        let cacheA = HashA.create 1 in
        let f' (f'' : a -> (b option) ref) (x : a) : (b option) =
            Some (f f'' x)
        in
        HashA.ymem cacheA f'

    (* Memoize a function of two arguments. *)
    let args2 (type a) (type b) (type c) (f : (a -> b -> (c option) ref) -> a -> b -> c) (a_eq : a eq_type) (b_eq : b eq_type) : (a -> b -> (c option) ref) =
        let equal (k1 : (a * b)) (k2 : (a * b)) : bool =
            let a_equal = eq_lookup a_eq in
            let b_equal = eq_lookup b_eq in
            (a_equal (fst k1) (fst k2)) && (b_equal (snd k1) (snd k2))
        in
        let module HashAB = MakeHash(struct type key = (a * b) let eq = Custom equal end) in
        let cache = HashAB.create 1 in
        let f' (f'' : ((a * b) -> (c option) ref)) (x, y : a * b) : (c option) =
            Some (f (fun x' y' -> f'' (x', y')) x y)
        in
        (fun x y -> (HashAB.ymem cache f') (x, y))
end

(*
    Changes to Predicate Arrangement from `fixed-points.rkt` in Define.Fix.

    I found the original code to be a bit confusing, since certain conditions
    were re-evaluated multiple times in an unpredictable order. I rewrote the
    code to be a bit more straightforward. I accomplished this by simplifying
    the original implementation symbolically, deriving a truth table, and then
    laying out a few semantically equivalent alternatives and choosing the one
    that would only perform hashtable lookups once.

    Below, you will find the simplified symbolic form of the original code.
    The original (non-symbolic) code appears at the bottom of this section,
    as both the original Racket (Fig. 4) and the first-attempt OCaml (Fig. 5).

    ;;
    ;;  if (is_cached && not should_run) then
    ;;      a [cached_val]
    ;;  else
    ;;      if (should_run && mem visited x) then
    ;;          if (is_cached) then
    ;;              b [cached_val]
    ;;          else
    ;;              c [bottom]
    ;;      else
    ;;          if (should_run) then
    ;;              new_val = ...
    ;;              d [new_val]
    ;;          else
    ;;              if (not is_cached && not should_run) then
    ;;                  v = ...
    ;;                  e [v]
    ;;              else
    ;;                  f [error]
    ;;
    ;;  Fig. 1: Simplified, symbolic form of original code.
    ;;      The lowercase letters a-f indicate possible paths, and the
    ;;      bracketed forms to the right of these letters correspond (more or
    ;;      less) to values in the non-symbolic form.
    ;;

    The final predicate (`if (not is_cached && not should_run)`) actually need
    not be evaluated, because it will always be true. This can be shown by
    observing the following truth table (where `x` indicates true):

    ;;
    ;;                  | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
    ;;   --- --- --- ---|---|---|---|---|---|---|---|---|
    ;;  is_cached       | x | x | x | x |   |   |   |   |
    ;;  should_run      | x | x |   |   | x | x |   |   |
    ;;  mem visited x   | x |   | x |   | x |   | x |   |
    ;;   --- --- --- ---|---|---|---|---|---|---|---|---|
    ;;  execute         | b | d | a | a | c | d | e | e |
    ;;
    ;;  Fig. 2: Truth table of possible execution paths.
    ;;

    We can see from the table that the result `f` is never produced, so the
    corresponding branch could be eliminated.

    The rewritten symbolic form that I arrived at is:

    ;;
    ;;  if (should_run) then
    ;;      if (mem visited x) then
    ;;          if (is_cached) then
    ;;              b [cached_val]
    ;;          else
    ;;              c [bottom]
    ;;      else
    ;;          new_val = ...
    ;;          d [new_val]
    ;;  else
    ;;      if (is_cached) then
    ;;          a [cached_val]
    ;;      else
    ;;          v = ...
    ;;          e [v]
    ;;
    ;;  Fig. 3: Simplified, symbolic form of rearranged code.
    ;;      The final predicate has been eliminated, and the code has been
    ;;      restructured so each predicate consists of only one condition.
    ;;

    This symbolic form transforms into the concrete form given above in the
    actual (current) implementation.

    For reference, below is the original form of the code in Racket, followed
    by the original OCaml implementation of that code in full.

    ;;
    ;;  (cond
    ;;    [(and cached? (not run?))
    ;;     ; =>
    ;;     cached]
    ;;
    ;;    [(and run? (hash-has-key? (unbox (visited)) x))
    ;;     ; =>
    ;;     (if cached? cached bottom)]
    ;;
    ;;    [run?
    ;;     ; =>
    ;;     (hash-set! (unbox (visited)) x #t)
    ;;     (let ((new-val (begin body ...)))
    ;;       (when (not (equal? new-val cached))
    ;;         (set-box! (changed?) #t)
    ;;         (hash-set! cache x new-val))
    ;;       new-val)]
    ;;
    ;;    [(and (not cached?) (not run?))
    ;;     ; =>
    ;;     (parameterize ([changed? (box #t)]
    ;;                    [running? #t]
    ;;                    [visited (box (make-weak-hasheq))])
    ;;       (let ([v bottom])
    ;;         (while (unbox (changed?))
    ;;                (set-box! (changed?) #f)
    ;;                (set-box! (visited) (make-weak-hasheq))
    ;;                (set! v (f x)))
    ;;         v))])
    ;;
    ;;  Fig. 4: Original Racket form of code.
    ;;

    ;;
    ;;  if is_cached && not should_run then
    ;;      cached_val
    ;;  else
    ;;      if should_run && Hashtbl.mem params.visited x then
    ;;          if is_cached then
    ;;              cached_val
    ;;          else
    ;;              bottom
    ;;      else
    ;;          if should_run then
    ;;              let new_val = f x in begin
    ;;              Hashtbl.replace params.visited x true;
    ;;              if new_val != cached_val then begin
    ;;                  params.changed <- true;
    ;;                  Hashtbl.replace params.cache x new_val;
    ;;              end;
    ;;              new_val
    ;;          end
    ;;          else
    ;;              if not is_cached && not should_run then
    ;;                  let params' = {params with changed = true; running = true; visited = Hashtbl.create 1}
    ;;                  and v = ref bottom in begin
    ;;                  while params'.changed do
    ;;                      params'.changed <- false;
    ;;                      Hashtbl.clear params'.visited;
    ;;                      v := func x params';
    ;;                  done;
    ;;                  !v
    ;;              end
    ;;              else
    ;;                  raise Unmatched
    ;;
    ;;  Fig. 5: Original transformation of code from Racket to OCaml.
    ;;
*)
