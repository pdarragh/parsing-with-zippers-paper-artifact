module PwdNaryOptParserInterface = struct
  type tok = Pwd_nary_opt.token
  type res = Pyast.ast list

  let process_tokens (tokens : Pytokens.token list) : tok list =
    List.map Pytokens.token_pair_of_token tokens

  let parse (tokens : tok list) : res = Pwd_nary_opt.parse Pwd_nary_opt_pygram.pwd_nary_opt_rule_file_input tokens

  let process_result (result : res) : Pyast.ast =
    match result with
    | [t] -> t
    | _ -> let header = Printf.sprintf "Invalid number of resulting AST trees in PwD-nary-opt parse: %d." (List.length result) in
           let asts = List.map Pyast.string_of_ast result in
           Printf.printf "%s" (header ^ "\n" ^ (String.concat "\n\n********\n\n  " asts));
           failwith header
end
