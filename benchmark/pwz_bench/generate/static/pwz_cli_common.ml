module Assoc = Core.List.Assoc
module In_channel = Core.In_channel

open Interface
open Pytokens

open Menhir_interface
open Dypgen_interface
open Pwz_nary_interface
open Pwz_nary_list_interface
open Pwz_nary_look_interface
open Pwz_nary_mem_interface
open Pwz_binary_interface
open Pwd_binary_interface
open Pwd_binary_opt_interface
open Pwd_nary_interface
open Pwd_nary_opt_interface

type parser_desc = (string * (module ParserInterface))

(* Pairs of parser names with their associated ParserInterface module. *)
let parsers_to_interfaces : parser_desc list =
    [ ("menhir", (module MenhirParserInterface))
    ; ("dypgen", (module DypgenParserInterface))
    ; ("pwz_nary", (module PwzNaryParserInterface))
    ; ("pwz_nary_list", (module PwzNaryListParserInterface))
    ; ("pwz_nary_look", (module PwzNaryLookParserInterface))
    ; ("pwz_nary_mem", (module PwzNaryMemParserInterface))
    ; ("pwz_binary", (module PwzBinaryParserInterface))
    ; ("pwd_binary", (module PwdBinaryParserInterface))
    ; ("pwd_binary_opt", (module PwdBinaryOptParserInterface))
    ; ("pwd_nary", (module PwdNaryParserInterface))
    ; ("pwd_nary_opt", (module PwdNaryOptParserInterface))
    ]

(* Look up a parser interface by name in the list. *)
let parser_of_string (s : string) : (module ParserInterface) =
    try  Assoc.find_exn ~equal:String.equal parsers_to_interfaces s
    with Not_found -> failwith ("Could not find parser with name '" ^ s ^ "'.")

(* Extract the tokens from a .lex file generated with the pwz_bench.py utility. *)
let token_list_from_file (filename : string) : token list =
    let lines = In_channel.read_lines filename in
    List.map token_of_string lines
