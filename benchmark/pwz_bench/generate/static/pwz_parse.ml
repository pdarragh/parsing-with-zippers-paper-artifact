module Command = Core.Command

open Interface
open Pwz_cli_common
open Pyast

(*
 *  This command-line program is used for running the various parsers over a given input lex file and comparing the ASTs
 *  produced by them. We use Menhir's results as the ground truths on the basis that we hand-built the other parsers,
 *  whereas Menhir has been around a while and is thus more community-tested.
 *)

let make_ast_from_file (filename : string) ((module Parser) : (module ParserInterface)) : ast =
    let tokens = Parser.process_tokens (token_list_from_file filename) in
    let result = Parser.parse tokens in
    Parser.process_result result

let print_ast (ast : ast) : unit =
    print_endline (unindented_string_of_ast ast)

let parse_file_with_parser (filename : string) (parser_name : string) : unit =
    print_ast (make_ast_from_file filename (parser_of_string parser_name))

let command : Command.t =
    Command.basic ~summary:"Parse a given Python .lex file with the specified parser." (
        let open Command.Param in
        both
            (anon ("PARSER" %: string))
            (anon ("FILENAME" %: string))
        |> map ~f:(fun (parser, filename) ->
            fun () -> parse_file_with_parser filename parser)
    )

let () = Command.run command
