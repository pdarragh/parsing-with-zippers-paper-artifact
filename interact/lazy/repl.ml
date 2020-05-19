#mod_use "types.ml";;
#mod_use "cst.ml";;
#mod_use "pwz.ml";;
#mod_use "grammars.ml";;

open Grammars;;

let introduction = {|
################################################################################

Parsing with Zippers REPL

  This is a REPL that has been prepared for you to experiment with our
  implementation of the Parsing with Zippers (PwZ) algorithm.

  There are a number of grammars in the `grammars.ml` file. These have been
  imported for you into this REPL as modules named "Grammar1", "Grammar2", etc.

  We have also provided a simplified parsing function to use with these
  grammars, and it can be used like so:

    parse (module <Grammar module name>) <input string>;;

  where <Grammar module name> is the name of a Grammar module defined in the
  `grammars.ml` file, e.g., `Grammar1`, and <input string> is a string literal
  comprised solely of the capital letters A and B (or an empty string). For
  example, you could do:

    parse (module Grammar3) "ABBA";;

  The `parse` function returns an empty list if the parse fails. Otherwise, it
  will return a list with at least one `exp` in it. The `exp` objects can be
  difficult to read at a glance, so we have also provided the `parse_to_cst`
  function that will eagerly extract a concrete syntax tree from the parse
  result. Note that the `parse_to_cst` function is exponential, and it will
  cause a stack overflow on expressions that produce infinite parse forests.

  The grammars include a few test cases. To run all the tests, simply do:

    print_test_results ();;

  This function will run the tests and inform you of any failures. You could
  add additional tests in the `grammars.ml` to automate further testing at your
  discretion.

  If you wish to write your own grammars, we suggest looking at how the
  expressions are declared in the `grammars.ml` file. A manually-implemented
  grammar (which is not contained inside of a Grammar module) can be parsed by
  doing:

    Pwz.parse <list of tokens> <grammar root expression>

  where <list of tokens> is a list of tokens (of type `tok` --- see `types.ml`)
  and <grammar root expression> is the root `exp` element of your grammar.

################################################################################
|};;

Printf.printf "%s\n" introduction;;
