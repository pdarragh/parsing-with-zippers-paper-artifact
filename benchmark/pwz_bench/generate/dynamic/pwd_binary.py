from pwz_bench.utility import *

from itertools import chain
from typing import List


__all__ = ['gen_pwd_binary_pygram_ml']


PWD_BINARY_PYGRAM_ML = """\
open Pytokens
open Pwd_binary

let rec {grammar_rules}
"""


def gen_pwd_binary_pygram_ml(desc: GrammarDescription) -> List[str]:
    prefix = 'pwd_binary_rule_'
    lines = PWD_BINARY_PYGRAM_ML.format(
        grammar_rules='\n    and '.join(chain(
            (f"{prefix}{token} = lazy (Tok {token_pair_of_token(token)})"
             for token in chain(desc.tokens.named,
                                desc.tokens.nameless,
                                map(lambda p: p[0], desc.tokens.typed))),
            map(lambda r: str_of_rule(r, desc, prefix), desc.base_grammar.rules)
        ))
    ).split('\n')
    return lines


def str_of_rule(rule: Rule, desc: GrammarDescription, prefix: str) -> str:
    if len(rule.groups) != 1:
        raise RuntimeError(f"Rule {rule.name} has {len(rule.groups)} groups; expected 1.")
    group = rule.groups[0]
    if len(group.productions) == 1:
        return f"{prefix}{rule.name} = {str_of_production(group.productions[0], desc, prefix, rule.name)}"
    else:
        production_strings = list(map(lambda p: str_of_production(p[1], desc, prefix, rule.name, p[0]),
                                      enumerate(group.productions, start=1)))
        return f"{prefix}{rule.name} = " + build_binary_alt(production_strings)


def build_binary_alt(elements: List[str]) -> str:
    result = f"lazy (Alt ({elements[-2]}, {elements[-1]}))"
    for element in reversed(elements[:-2]):
        result = f"lazy (Alt ({element}, {result}))"
    return result


def str_of_production(production: Production, desc: GrammarDescription, prefix: str, rule_name: str,
                      production_no: int = 0) -> str:
    parts: List[str] = []
    for component in production.components:
        if isinstance(component, Terminal):
            parts.append(prefix + desc.terminal_names[component])
        elif isinstance(component, NonTerminal):
            parts.append(prefix + component.name)
        else:
            raise RuntimeError(f"Invalid component instance in production of class {component.__class__.__name__}.")
    production_name = rule_name
    if production_no > 0:
        production_name += f"-{production_no}"
    if len(parts) == 0:
        return f"lazy (Eps (lazy [Pyast.Seq (\"{production_name}\", [])]))"
    elif len(parts) == 1:
        return f"lazy (Red ((fun t -> Pyast.Seq (\"{production_name}\", [t])), {parts[0]}))"
    elif len(parts) == 2:
        return f"lazy (Seq (\"{production_name}\", {parts[0]}, {parts[1]}))"
    else:
        return build_binary_seq(production_name, parts)


def build_binary_seq(label: str, elements: List[str]) -> str:
    result = elements[-1]
    for i, element in reversed(list(enumerate(elements[:-1], start=1))):
        result = f"lazy (Seq (\"BINRED-{i}-{label}\", {element}, {result}))"
    result = f"lazy (Red (Pyast.flatten_binary_seqs {len(elements) - 1} \"{label}\", {result}))"
    return result


"""

File                                # tok   sec     tok/sec

__phello__.foo.py.lex               1       0.017   58
_sysconfigdata.py.lex               30      0.547   55
antigravity.py.lex                  101     2.154   47
collections___main__.py.lex         284     14.54   20
_compat_pickle.py.lex               517     33.98   15
code.py.lex                         1000    134.8   7


"""



"""

#require "core";;
module In_channel = Core.In_channel;;
let read_lines = In_channel.read_lines;;
#require "str";;
#mod_use "../pyast.ml";;
#mod_use "../pytokens.ml";;
#mod_use "pwd_binary.ml";;
#mod_use "pwd_binary_pygram.ml";;
#mod_use "pwd_binary_interface.ml";;
open Pytokens;;
let token_list_from_file (filename : string) : token list =
    let lines = In_channel.read_lines filename in
    List.map token_of_string lines;;
open Pwd_binary;;
open Pwd_binary_pygram;;
module P = Pwd_binary_interface.PwdBinaryParserInterface;;
let tpot = token_pair_of_token;;
let d = lazy (Seq ("seq-1", lazy (Tok (tpot TRUE_)), lazy (Tok (tpot FALSE_))));;



let parse_file (f : string) = let tokens = List.map token_pair_of_token (token_list_from_file ("/Users/pdarragh/Development/Research/pwz-bench/lexes/" ^ f)) in P.parse tokens;;
let res = parse_file "distutils___init__.py.lex";;
let [t] = res;;
open Pyast;;
print_endline (string_of_ast t);;


"""


"""


lazy (Alt 
      (lazy (Red 
             (Pyast.Seq (l, 
                         [t; Pyast.Seq (l'', ts)]) 
              -> Pyast.Seq (l, t::ts)), 
             lazy (Seq ("atom-1", 
                        pwd_binary_rule_L_PAR, 
                        lazy (Seq ("atom-1", 
                                   pwd_binary_rule_atom__opt_grp_1__3, 
                                   pwd_binary_rule_R_PAR))))), lazy (Red ((fun t -> Pyast.Seq ("atom-2", [t])), pwd_binary_rule_TRUE))))

"""

