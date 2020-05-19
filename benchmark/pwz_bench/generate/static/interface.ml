module type ParserInterface = sig
    type tok
    type res
    val process_tokens : (Pytokens.token list) -> (tok list)
    val parse : (tok list) -> res
    val process_result : res -> Pyast.ast
end
