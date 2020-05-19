module Command = Core.Command

open Benchmarking
open Core_bench
open Interface
open Pwz_cli_common
open Pytokens

(* A small module for properly timing parses. This needed to be parameterized for the PI.tok, hence the module. *)
module MakeTimer (PI : ParserInterface) = struct
    let time_parse (tokens : PI.tok list) () =
        ignore (PI.parse tokens)
end

let strip_filename (filename : string) : string =
    match String.rindex_opt filename '/' with
    | Some i -> String.sub filename (i + 1) ((String.length filename) - i - 1)
    | None   -> filename

(* Create a Core_bench benchmarking test for a given file and parser. *)
let make_test_from_file (filename : string) (parser_name : string) ((module Parser) : (module ParserInterface)) : Bench.Test.t =
    let module Timer = MakeTimer(Parser) in
    let tokens = Parser.process_tokens (token_list_from_file filename) in
    Bench.Test.create ~name:(Printf.sprintf "%s:%s:%d" parser_name (strip_filename filename) (List.length tokens)) (Timer.time_parse tokens)

(* Create Core_bench benchmarking tests for all file for the given parser. *)
let make_tests_for_parser (parser : parser_desc) (filenames : string list) : Bench.Test.t list =
    let make_test_from_file (filename : string) = make_test_from_file filename (fst parser) (snd parser) in
    List.map make_test_from_file filenames

(* Construct all Core_bench benchmarking tests. *)
let make_tests (filenames : string list) (parsers : string list) : Bench.Test.t list =
    let pds = List.map (fun parser -> (parser, List.assoc parser parsers_to_interfaces)) parsers in
    List.concat (List.map (fun pd -> make_tests_for_parser pd filenames) pds)

(* The base parsing command. *)
let command : Command.t =
    Bench.make_command_ext ~summary:"benchmark stuff" (
        let open Command.Param in
        both
            (flag "input" (listed string) ~doc:"FILENAME Specify a .lex file to parse and benchmark. This flag may be specified multiple times to benchmark multiple files.")
            (flag "parser" (listed string) ~doc:"PARSER Specify a parser to parse with. This flag may be specified multiple times.")
        |> map ~f:(fun (filenames, parsers) -> make_bench_command (make_tests filenames parsers))
    )

let () = Command.run command
