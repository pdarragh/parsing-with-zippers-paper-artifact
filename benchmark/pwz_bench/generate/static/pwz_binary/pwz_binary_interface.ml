module PwzBinaryParserInterface = struct
    type tok = Pytokens.token_pair
    type res = Pwz_binary.exp list

    let process_tokens (tokens : Pytokens.token list) : tok list =
        List.map Pytokens.token_pair_of_token tokens

    let parse (tokens : tok list) : res =
        Pwz_binary.parse tokens Pwz_binary_pygram.pwz_binary_rule_file_input

    let process_result (result : res) : Pyast.ast =
        match (Pwz_binary.ast_list_of_exp_list result) with
        | [t] -> t
        | _ -> failwith (Printf.sprintf "Invalid number of resulting AST trees in PwZ-binary parse: %d." (List.length result))
end
