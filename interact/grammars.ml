open Types
open Cst

(*
TEST GRAMMARS FOR PARSING WITH ZIPPERS

   This file provides grammars and (simple) test examples to convince readers of
   the properties we claim about PwZ in our paper.

   Each grammar conforms to the Grammar module signature. This allows them to be
   kept separate and use similar naming conventions. We chose the first
   production of each grammar to be used as the `start` production.

   The grammars each have a comment above that explain the purpose of the
   grammar and show it written in a BNF format.

   Note that the BNF specifications use the unusual convention that lowercase
   letters represent non-terminals while capital letters represent terminals.

A NOTE ON LIMITATIONS IMPOSED BY OCAML

   The OCaml language features a number of limitations that prevent us from
   expressing grammars as succinctly and clearly as we would like. Namely, these
   are:

   1. Recursive record definitions must be completely static, i.e., we cannot use
      "smart constructors" to reduce syntactic overhead.
   2. Names of functions, values, and variables cannot begin with a capital
      letter. (We address this by prepending these names with an underscore.)
   3. Identifiers cannot contain non-ASCII characters. (This means we cannot use
      the ε character as an identifier.)

   2 and 3 are easy enough to deal with. However, 1 is more of a nuisance. One
   potential solution would be to write a syntax macro (e.g., using ppx) to
   allow for easier specification of recursive forms for defining grammars.
   Unfortunately, none of the authors is sufficiently skilled in the OCaml
   syntax system to implement this completely within the time limit afforded us
   by the author response. However, it is something we would like to provide.

A NOTE ON CST EXTRACTION

   For test cases that are expected to return a finite number of results, we use
   the function `cst_list_of_exp_list` from the Cst module (cst.ml) to extract
   an CST from the resulting parse forest. This allows us to enumerate the
   number of results arising from ambiguous grammars.

   However, the process of extraction can be exponential. In our paper, and also
   here, we do not factor this extraction into the cost of parsing. The parse
   itself completes prior to any extraction taking place. The extraction is
   merely a (lossy) method of better quantifying what the parse produced.
*)

(*
tok_list_of_string

   This function allows for easy conversion from a string to a list of tokens,
   useful for parsing the simple grammars encoded here.

   Each grammar contains an association list mapping single characters to token
   expressions. A string consisting solely of these characters can then be
   converted to a list of the token expressions.

   Note that the string cannot have any extraneous whitespace or other
   characters that are not defined in the association list.
*)
let tok_list_of_string (str : string) (assocs : (char * tok) list) : tok list =
  let limit = String.length str in

  let rec tok_list_of_string (idx : int) (acc : tok list) : tok list =
    if idx < limit
    then tok_list_of_string (idx + 1) ((List.assoc (String.get str idx) assocs) :: acc)
    else acc

  in List.rev (tok_list_of_string 0 [])

(*
Testing lists

   This record is used within each grammar definition to supply example strings
   that should either produce successful parses or should result in no parses.

   tests.success is a list of pairs. The first element of these pairs is a
   string, which is the test input. The second element is an optional integer.
   When this integer is present in a Some, its value corresponds to the number
   of trees the algorithm is expected to produce upon successful parsing. If the
   value is a None, then it is merely expected that the parse produces a
   positive result (i.e., there are more than 0 elements returned).

   tests.failure is a list of strings, which are simply test inputs. A failed
   parse is represented as an empty list in all cases, so no extra integer is
   needed for these.
*)
type tests = {
  success : (string * (int option)) list;
  failure : string list;
}

(*
Grammar module signature

   This module signature shows the interface through which all of the below
   grammars can be used.
*)
module type Grammar = sig
  val start : exp
  val tests : tests
end

(*
Token definitions

   These are simple definitions of type Types.tok. They are used by some of the
   grammars defined below.

   The association list maps characters to tokens. This list can be used by the
   tok_list_of_string function defined above in the conversion of strings to
   tokens.
*)
let t_A = (1, "A")
let t_B = (2, "B")

let tok_assoc = [('A', t_A); ('B', t_B)]

(*
parse
instrumented_parse

   These are wrappers for the Pwz module's `parse` and `instrumented_parse`
   functions.

   They each take two arguments: a Grammar module G (examples of which are
   defined below in this file) and a string. The string will be converted to a
   list of tokens according to the association list G.tokens. Then, the parse
   will proceed by starting at the G.start grammar expression.
*)

let parse ((module G) : (module Grammar)) (str : string) : exp list =
  Pwz.parse (tok_list_of_string str tok_assoc) G.start

let instrumented_parse ((module G) : (module Grammar)) (str : string) : (exp list) * int =
  Pwz.instrumented_parse (tok_list_of_string str tok_assoc) G.start

(*
parse_to_cst_list

   This function wraps the above `parse` function.

   It converts the list of expressions produced by parsing into a list of CST
   elements. This is useful for separating ambiguous parse results into separate
   parse trees, instead of the `parse` function's result (which is often an Alt
   containing multiple children).

   NOTE: This function eagerly extracts expressions into CST nodes. Some of the
   below grammars are designed to produce an infinite number of resulting
   expressions, which means that this function would be tasked with producing an
   eager infinite list. We recommend against its use in these cases.
*)
let parse_to_cst_list ((module G) : (module Grammar)) (str : string) : cst list =
  cst_list_of_exp_list (parse (module G) str)

(*
Grammar1: The empty grammar through self-reference.

   e ::= e
*)
module Grammar1 : Grammar = struct
  let rec e = { m = m_bottom; e' = Seq ("e", [e]) }

  let start = e

  let tests = {
    success = [];
    failure = [""; "A"; "AB"; "BB"; "ABA"];
  }
end

(*
Grammar2: The empty grammar, but seems productive.

   e ::= A e
*)
module Grammar2 : Grammar = struct
  let rec _A = { m = m_bottom; e' = Tok t_A }
      and e  = { m = m_bottom; e' = Seq ("e", [_A; e]) }

  let start = e

  let tests = {
    success = [];
    failure = [""; "A"; "AA"; "AAAAAAAAAAAAAAAAAAAAAAA"];
  }
end

(*
Grammar3: Ambiguously empty grammar.

   e ::= A e
       | e A
*)
module Grammar3 : Grammar = struct
  let rec _A  = { m = m_bottom; e' = Tok t_A }
      and _Ae = { m = m_bottom; e' = Seq ("Ae", [_A; e]) }
      and _eA = { m = m_bottom; e' = Seq ("eA", [e; _A]) }
      and e   = { m = m_bottom; e' = Alt (ref [ _Ae; _eA ]) }

  let start = e

  let tests = {
    success = [];
    failure = [""; "A"; "AA"; "AAA"; "AAAA"];
  }
end

(*
Grammar4: Another tricky empty grammar.

   e ::= A e A
*)
module Grammar4 : Grammar = struct
  let rec _A = { m = m_bottom; e' = Tok t_A }
      and e  = { m = m_bottom; e' = Seq ("AeA", [_A; e; _A]) }

  let start = e

  let tests = {
    success = [];
    failure = [""; "A"; "AA"; "AAA"; "AAAA"];
  }
end

(*
Grammar5: Right-recursive with infinite parse forests.

   e ::= e
       | A e
       | ε
*)
module Grammar5 : Grammar = struct
  let rec _A   = { m = m_bottom; e' = Tok t_A }
      and _Ae  = { m = m_bottom; e' = Seq ("Ae", [_A; e]) }
      and _eps = { m = m_bottom; e' = Seq ("ε", []) }
      and e    = { m = m_bottom; e' = Alt (ref [e; _Ae; _eps]) }

  let start = e

  let tests = {
    success = [ ("", None)
              ; ("A", None)
              ; ("AA", None)
              ; ("AAA", None) ];
    failure = [];
  }
end

(*
Grammar6: Left-recursive with infinite parse forests.

   e ::= e
       | e A
       | ε
*)
module Grammar6 : Grammar = struct
  let rec _A   = { m = m_bottom; e' = Tok t_A }
      and _eA  = { m = m_bottom; e' = Seq ("eA", [e; _A]) }
      and _eps = { m = m_bottom; e' = Seq ("ε", []) }
      and e    = { m = m_bottom; e' = Alt (ref [e; _eA; _eps]) }

  let start = e

  let tests = {
    success = [ ("", None)
              ; ("A", None)
              ; ("AA", None)
              ; ("AAA", None) ];
    failure = [];
  }
end

(*
Grammar7: Palindromes. Not ambiguous, and not LL(k) or LR(k) for any k.

   e ::= A e A
       | B e B
       | ε
*)
module Grammar7 : Grammar = struct
  let rec _A   = { m = m_bottom; e' = Tok t_A }
      and _B   = { m = m_bottom; e' = Tok t_B }
      and _AeA = { m = m_bottom; e' = Seq ("AeA", [_A; e; _A]) }
      and _BeB = { m = m_bottom; e' = Seq ("BeB", [_B; e; _B]) }
      and _eps = { m = m_bottom; e' = Seq ("ε", []) }
      and e    = { m = m_bottom; e' = Alt (ref [_AeA; _BeB; _eps]) }

  let start = e

  let tests = {
    success = [ ("", Some 1)
              ; ("AA", Some 1)
              ; ("BB", Some 1)
              ; ("ABBA", Some 1)
              ; ("ABBBBA", Some 1)
              ; ("ABBAABBA", Some 1) ];
    failure = ["A"; "B"; "AAB"; "ABA"];
  }
end

(*
Grammar8: Hidden production with left-recursion.

   e1 ::= e2 A
        | ε
   e2 ::= e1
*)
module Grammar8 : Grammar = struct
  let rec _A   = { m = m_bottom; e' = Tok t_A }
      and _eps = { m = m_bottom; e' = Seq ("ε", []) }
      and _e2A = { m = m_bottom; e' = Seq ("e2A", [e2; _A]) }
      and e1   = { m = m_bottom; e' = Alt (ref [_e2A; _eps]) }
      and e2   = { m = m_bottom; e' = Seq ("e2", [e1]) }

  let start = e1

  let tests = {
    success = [ ("", Some 1)
              ; ("A", Some 1)
              ; ("AA", Some 1)
              ; ("AAA", Some 1) ];
    failure = [];
  }
end

(*
Grammar9: Hidden production with right-recursion.

   e1 ::= A e2
        | ε
   e2 ::= e1
*)
module Grammar9 : Grammar = struct
  let rec _A   = { m = m_bottom; e' = Tok t_A }
      and _eps = { m = m_bottom; e' = Seq ("ε", []) }
      and _Ae2 = { m = m_bottom; e' = Seq ("Ae2", [_A; e2]) }
      and e1   = { m = m_bottom; e' = Alt (ref [_Ae2; _eps]) }
      and e2   = { m = m_bottom; e' = Seq ("e2", [e1]) }

  let start = e1

  let tests = {
    success = [ ("", Some 1)
              ; ("A", Some 1)
              ; ("AA", Some 1)
              ; ("AAA", Some 1) ];
    failure = [];
  }
end

(*
Grammar10: Empty grammar through mutual reference.

   e1 ::= e2
   e2 ::= e1
*)
module Grammar10 : Grammar = struct
  let rec e1 = { m = m_bottom; e' = Seq ("e1", [e2]) }
      and e2 = { m = m_bottom; e' = Seq ("e2", [e1]) }

  let start = e1

  let tests = {
    success = [];
    failure = [""; "A"; "AA"];
  }
end

(*
Grammar11: Tricky single-token grammar.

   e1 ::= e2
        | A
   e2 ::= e1
*)
module Grammar11 : Grammar = struct
  let rec _A = { m = m_bottom; e' = Tok t_A }
      and e1 = { m = m_bottom; e' = Alt (ref [e2; _A]) }
      and e2 = { m = m_bottom; e' = Seq ("e2", [e1]) }

  let start = e1

  let tests = {
    success = [("A", None)];
    failure = [""; "AA"; "AAA"];
  }
end

(*
Grammar12: Highly ambiguous for parsing ABABABABABABABA.

   e ::= A
       | e B e
*)
module Grammar12 : Grammar = struct
  let rec _A   = { m = m_bottom; e' = Tok t_A }
      and _B   = { m = m_bottom; e' = Tok t_B }
      and _eBe = { m = m_bottom; e' = Seq ("eBe", [e; _B; e]) }
      and e    = { m = m_bottom; e' = Alt (ref [_A; _eBe]) }

  let start = e

  let tests = {
    success = [ ("A", Some 1)
              ; ("ABA", Some 1)
              ; ("ABABA", Some 2)
              ; ("ABABABABABABABA", Some 429) ];
    failure = [""];
  }
end

(*
Grammar13: An ambiguous double-production grammar.

   e ::= A
       | ee
*)
module Grammar13 : Grammar = struct
  let rec _A  = { m = m_bottom; e' = Tok t_A }
      and _ee = { m = m_bottom; e' = Seq ("ee", [e; e]) }
      and e   = { m = m_bottom; e' = Alt (ref [_A; _ee]) }

  let start = e

  let tests = {
    success = [ ("A", Some 1)
              ; ("AA", Some 1)
              ; ("AAA", Some 2)
              ; ("AAAA", Some 5) ];
    failure = [""];
  }
end

(* A list of all the grammars put together. *)
let grammars : ((module Grammar) list) =
  [ (module Grammar1)
  ; (module Grammar2)
  ; (module Grammar3)
  ; (module Grammar4)
  ; (module Grammar5)
  ; (module Grammar6)
  ; (module Grammar7)
  ; (module Grammar8)
  ; (module Grammar9)
  ; (module Grammar10)
  ; (module Grammar11)
  ; (module Grammar12)
  ; (module Grammar13)
  ]

(*
filter_opt

   Filter out the None elements from a list of 'a option.
*)
let filter_opt (elems : ('a option) list) : 'a list =
  let rec filter_opt (elems : ('a option) list) (acc : 'a list) : 'a list =
    match elems with
    |                   [] -> acc
    |     (None :: elems') -> filter_opt elems' acc
    | ((Some a) :: elems') -> filter_opt elems' (a :: acc)
  in List.rev (filter_opt elems [])

(*
grammar_test_results

   If all tests pass successfully, this list should be empty.

   If this list is not empty, then each entry is a pair whose first element is
   the index of a grammar that had failing test cases, and whose second element
   is a pair whose elements are lists containing the indices of failed expected-
   to-succeed tests and failed expected-to-fail tests, respectively.
*)
let grammar_test_results () : (int * ((int list) * (int list))) list =
  let test_grammar (idx : int) ((module G) : (module Grammar)) : (int * ((int list) * (int list))) option =
    Printf.printf "Testing Grammar%d...\n" (idx + 1);
    (*
    test_case

       Attempt to parse the given test. If the resulting parse forest contains the
       expected number of results, return None (indicating nothing unusual
       happened). Otherwise, return a Some wrapped around the index of this test
       case, which can later be used to see which test failed.
    *)
    let test_case (idx : int) ((str, maybe_expected_num_of_parses) : (string * (int option))) : int option =
      Printf.printf "    case %d: \"%s\"..." (idx + 1) str;
      let success = match maybe_expected_num_of_parses with
        | Some expected_num_of_parses -> List.length (parse_to_cst_list (module G) str) == expected_num_of_parses
        | None                        -> List.length (parse (module G) str) > 0
      in
      if success
      then (Printf.printf "✅\n"; None)
      else (Printf.printf "❌\n"; Some (idx))
    in
    (*
    results

       A pair containing two lists: one containing indexes of failed test cases
       for inputs that should have succeeded, and one for those that should have
       failed.
    *)
    let results = ((Printf.printf "  Testing success cases...\n";
                    filter_opt (List.mapi test_case G.tests.success)),
                   (Printf.printf "  Testing failure cases...\n";
                    filter_opt (List.mapi (fun i s -> test_case i (s, Some 0)) G.tests.failure)))
    in match results with
    | ([], []) -> None
    | _        -> Some (idx, results)
  in filter_opt (List.mapi test_grammar grammars)

(*
print_test_results

   Prints out the results of tests in a relatively easy-to-read way.
*)
let print_test_results () : unit =
  let print_result ((g_idx, (s_idxs, f_idxs)) : (int * ((int list) * (int list)))) : unit =
    let (module G) : (module Grammar) = List.nth grammars g_idx in
    let string_of_success_case (idx : int) : string =
      Printf.sprintf "%d. \"%s\""
        (idx + 1)
        (fst (List.nth G.tests.success idx))
    in
    let string_of_failure_case (idx : int) : string =
      Printf.sprintf "%d. \"%s\""
        (idx + 1)
        (List.nth G.tests.failure idx)
    in Printf.printf
      "Grammar%d had failing test cases:\n  success cases: %s\n  failure cases: %s\n"
      (g_idx + 1)
      (String.concat "\n    " (List.map string_of_success_case s_idxs))
      (String.concat "\n    " (List.map string_of_failure_case f_idxs))
  in match grammar_test_results () with
  | [] -> Printf.printf "All tests passed successfully."
  | _  -> List.iter print_result (grammar_test_results ())
