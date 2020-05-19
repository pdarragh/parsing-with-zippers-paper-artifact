from pwz_bench.utility import *

from itertools import chain
from typing import List


__all__ = ['gen_pwd_binary_opt_pygram_ml']


PWD_BINARY_OPT_PYGRAM_ML = """\
open Pytokens
open Pwd_binary_opt

let rec {grammar_rules}
"""


NODE_FILLER = "nullable = Nullable_unvisited; listeners = []; key = false_token; value = false_node; ast = []"


def gen_pwd_binary_opt_pygram_ml(desc: GrammarDescription) -> List[str]:
    prefix = 'pwd_binary_opt_rule_'
    lines = PWD_BINARY_OPT_PYGRAM_ML.format(
        grammar_rules='\n    and '.join(chain(
            (f"{prefix}{token} = make_token_node (fun c -> fst c == {TokenEnum[token].tag}) \"{token}\""
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
        return f"{prefix}{rule.name} = {build_binary_alt(production_strings)}"


def build_binary_alt(elements: List[str]) -> str:
    result = elements[-1]
    for element in reversed(elements[:-1]):
        result = f"{{ tag = Alt_tag; child1 = {element}; child2 = {result}; {NODE_FILLER} }}"
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
        return f"make_eps_node (lazy [Pyast.Seq (\"{production_name}\", [])])"
    elif len(parts) == 1:
        return f"{{ tag = Red_tag (List.map (fun t -> Pyast.Seq (\"{production_name}\", [t]))); child1 = {parts[0]}; " \
            f"child2 = false_node; {NODE_FILLER} }}"
    elif len(parts) == 2:
        return f"{{ tag = Red_tag (List.map (fun (Pyast.Seq (_, [t1; t2])) -> Pyast.Seq (\"{production_name}\", [t1; t2]))); " \
            f"child1 = {{ tag = Seq_tag; child1 = {parts[0]}; child2 = {parts[1]}; {NODE_FILLER} }};" \
            f"child2 = false_node; {NODE_FILLER} }}"
    else:
        return build_binary_seq(production_name, parts)


def build_binary_seq(label: str, elements: List[str]) -> str:
    result = elements[-1]
    for element in reversed(elements[:-1]):
        result = f"{{ tag = Seq_tag; child1 = {element}; child2 = {result}; {NODE_FILLER} }}"
    result = f"{{ tag = Red_tag (List.map (Pyast.flatten_binary_seqs {len(elements) - 1} \"{label}\")); " \
        f"child1 = {result}; child2 = false_node; {NODE_FILLER} }}"
    return result
