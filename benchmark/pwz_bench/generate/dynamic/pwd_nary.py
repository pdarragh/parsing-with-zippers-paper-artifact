from pwz_bench.utility import *

from itertools import chain
from typing import List


__all__ = ['gen_pwd_nary_pygram_ml']


PWD_NARY_PYGRAM_ML = """\
open Pytokens
open Pwd_nary

let rec {grammar_rules}
"""


def gen_pwd_nary_pygram_ml(desc: GrammarDescription) -> List[str]:
    prefix = 'pwd_nary_rule_'
    lines = PWD_NARY_PYGRAM_ML.format(
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
        production_strings = map(lambda p: str_of_production(p[1], desc, prefix, rule.name, p[0]),
                                 enumerate(group.productions, start=1))
        return f"{prefix}{rule.name} = lazy (Alt [ {'; '.join(production_strings)} ])"


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
    return f"lazy (Seq (\"{production_name}\", [ {'; '.join(parts)} ]))"

"""

#require "core";;
module In_channel = Core.In_channel;;
let read_lines = In_channel.read_lines;;
#require "str";;
#mod_use "../pyast.ml";;
#mod_use "../pytokens.ml";;
#mod_use "pwd_nary.ml";;
#mod_use "pwd_nary_pygram.ml";;
#mod_use "pwd_nary_interface.ml";;
open Pytokens;;
let token_list_from_file (filename : string) : token list =
    let lines = In_channel.read_lines filename in
    List.map token_of_string lines;;
open Pwd_nary;;
open Pwd_nary_pygram;;
module P = Pwd_nary_interface.PwdNaryParserInterface;;

let parse_file (f : string) = let tokens = List.map token_pair_of_token (token_list_from_file ("/Users/pdarragh/Development/Research/pwz-bench/lexes/" ^ f)) in P.parse tokens;;
let res = parse_file "distutils___init__.py.lex";;
let [t] = res;;
open Pyast;;
print_endline (string_of_ast t);;

"""


"""

Seq ("simple_stmt",
    [Alt
    [Seq ("small_stmt-1",
    [Seq ("expr_stmt",
    [Seq ("testlist_star_expr", [Alt ...]); Alt [Seq (...); Seq (...)]])]);
    Seq ("small_stmt-2",
    [Seq ("del_stmt", [Tok (53, "DEL"); Seq ("exprlist", [Alt ...])])]);
    Seq ("small_stmt-3", [Tok (71, "PASS")]);
    Seq ("small_stmt-4",
    [Alt
    [Seq ("flow_stmt-1", [Tok ...]);
    Seq ("flow_stmt-2", [Tok ...]); Seq ("flow_stmt-3", [Seq (...)]);
    Seq ("flow_stmt-4", [Seq (...)]); Seq ("flow_stmt-5", [Seq (...)])]]);
    Seq ("small_stmt-5",
    [Alt
    [Seq ("import_stmt-1", [Seq (...)]);
    Seq ("import_stmt-2", [Seq (...)])]]);
    Seq ("small_stmt-6",
    [Seq ("global_stmt",
    [Tok (61, "GLOBAL"); Tok (83, "<NAME>"); Alt [Seq (...); Seq (...)]])]);
    Seq ("small_stmt-7",
    [Seq ("nonlocal_stmt",
    [Tok (68, "NONLOCAL"); Tok (83, "<NAME>");
    Alt [Seq (...); Seq (...)]])]);
    Seq ("small_stmt-8",
    [Seq ("assert_stmt",
    [Tok (48, "ASSERT"); Alt [Seq (...); Seq (...)];
    Alt [Seq (...); Seq (...)]])])];
    Alt
    [Seq ("_small_stmt_semi_lst-1",
    [Alt
    [Seq ("_small_stmt_semi_lst__opt_grp_1__21-1", []);
    Seq ("_small_stmt_semi_lst__opt_grp_1__21-2", [Tok ...])]]);
    Seq ("_small_stmt_semi_lst-2",
    [Tok (2, "SEMICOLON");
    Alt
    [Seq ("small_stmt-1", [Seq (...)]);
    Seq ("small_stmt-2", [Seq (...)]);
    Seq ("small_stmt-3", [Tok ...]);
    Seq ("small_stmt-4", [Alt ...]);
    Seq ("small_stmt-5", [Alt ...]);
    Seq ("small_stmt-6", [Seq (...)]);
    Seq ("small_stmt-7", [Seq (...)]);
    Seq ("small_stmt-8", [Seq (...)])];
    <cycle>])];
    Tok (79, "NEWLINE")])

"""
