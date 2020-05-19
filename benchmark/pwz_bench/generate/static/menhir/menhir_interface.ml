module MenhirParserInterface = struct
    type tok = Pytokens.token
    type res = Pyast.ast list

    let process_tokens (tokens : Pytokens.token list) : tok list = tokens

    let make_lexer (tokens : tok list) : ((tok list) ref -> tok) * ((tok list) ref) =
        let lex (lexbuf : (tok list) ref) : tok =
            match !lexbuf with
            | []    -> failwith "menhir lexbuf is empty but lexer called for new token!"
            | t::ts -> lexbuf := ts; t
        in
        (lex, ref tokens)

    let parse (tokens : tok list) : res =
        let (lexer, lexbuf) = make_lexer tokens in
        let start' =
            MenhirLib.Convert.traditional2revised
                (fun x -> x)
                (fun _ -> Lexing.dummy_pos)
                (fun _ -> Lexing.dummy_pos)
                Pymen.file_input
        in
        try  [start' (fun _ -> lexer lexbuf)]
        with Pymen.Error -> failwith "Invalid parse!"

    let process_result (result : res) : Pyast.ast =
        match result with
        | [t] -> t
        | _ -> failwith (Printf.sprintf "Invalid number of resulting AST trees in Menhir parse: %d." (List.length result))
end
