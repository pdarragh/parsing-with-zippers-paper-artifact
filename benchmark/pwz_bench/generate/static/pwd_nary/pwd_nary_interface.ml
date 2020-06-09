module PwdNaryParserInterface = struct
  type tok = Pwd_nary.tok
  type res = Pyast.ast list

  let process_tokens (tokens : Pytokens.token list) : tok list =
    List.map Pytokens.token_pair_of_token tokens

  let parse (tokens : tok list) : res = Pwd_nary.parse tokens Pwd_nary_pygram.pwd_nary_rule_file_input

  let process_result (result : res) : Pyast.ast =
    match result with
    | [t] -> t
    | _ -> let header = Printf.sprintf "Invalid number of resulting AST trees in PwD-nary parse: %d." (List.length result) in
           let asts = List.map Pyast.string_of_ast result in
           Printf.printf "%s" (header ^ "\n" ^ (String.concat "\n\n********\n\n  " asts));
           failwith header
end
