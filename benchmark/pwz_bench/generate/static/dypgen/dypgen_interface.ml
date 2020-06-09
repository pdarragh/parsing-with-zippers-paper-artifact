module DypgenParserInterface = struct
  type tok = Pytokens.token
  type res = Pyast.ast list

  let process_tokens (tokens : Pytokens.token list) : tok list = tokens

  let make_lexer (tokens : tok list) : ((tok list) ref -> tok) * ((tok list) ref) =
    let lex (lexbuf : (tok list) ref) : tok =
      match !lexbuf with
      | []    -> failwith "dypgen lexbuf is empty but lexer called for new token!"
      | t::ts -> lexbuf := ts; t in
    (lex, ref tokens)

  let parse (tokens : tok list) : res =
    let (lexer, lexbuf) = make_lexer tokens in
    let start' =
      MenhirLib.Convert.traditional2revised (* Although this is the Dypgen parser interface, the Menhir *)
        (fun x -> x)                        (* library provides easy conversion capability that works.  *)
        (fun _ -> Lexing.dummy_pos)
        (fun _ -> Lexing.dummy_pos)
        Pymen.file_input in
    try  [start' (fun _ -> lexer lexbuf)]
    with Dyp.Syntax_error -> failwith "Invalid parse!"

  let process_result (result : res) : Pyast.ast =
    match result with
    | [t] -> t
    | _ -> failwith (Printf.sprintf "Invalid number of resulting AST trees in Dypgen parse: %d." (List.length result))
end
