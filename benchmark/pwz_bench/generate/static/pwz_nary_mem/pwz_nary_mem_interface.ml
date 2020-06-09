module PwzNaryMemParserInterface = struct
  type tok = Pytokens.token_pair
  type res = Pwz_nary_mem.exp list

  let process_tokens (tokens : Pytokens.token list) : tok list =
    List.map Pytokens.token_pair_of_token tokens

  let parse (tokens : tok list) : res =
    Pwz_nary_mem.parse tokens Pwz_nary_mem_pygram.pwz_nary_mem_rule_file_input

  let process_result (result : res) : Pyast.ast =
    match (Pwz_nary_mem.ast_list_of_exp_list result) with
    | [t] -> t
    | _ -> failwith (Printf.sprintf "Invalid number of resulting AST trees in PwZ-nary parse: %d." (List.length result))
end
