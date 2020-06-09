from pwz_bench.utility import *

from itertools import chain
from typing import List


__all__ = ['gen_pwz_binary_pygram_ml']


PWZ_BINARY_PYGRAM_ML = """\
open Pytokens
open Pwz_binary

let rec {grammar_rules}
"""


M_BOT = 'm_bottom'


def gen_pwz_binary_pygram_ml(desc: GrammarDescription) -> List[str]:
    prefix = 'pwz_binary_rule_'
    lines = PWZ_BINARY_PYGRAM_ML.format(
        grammar_rules='\n    and '.join(chain(
            (f"{prefix}{token} = {{ m = {M_BOT}; e' = Tok {token_pair_of_token(token)} }}"
             for token in chain(desc.tokens.named,
                                desc.tokens.nameless,
                                map(lambda p: p[0], desc.tokens.typed))),
            map(lambda r: generate_pygram_rule(r, desc, prefix), desc.base_grammar.rules)
        ))
    ).split('\n')
    return lines


def generate_pygram_rule(rule: Rule, desc: GrammarDescription, prefix: str) -> str:
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
    result = f"{{ m = {M_BOT}; e' = Alt (ref (Some {elements[-2]}), ref (Some {elements[-1]})) }}"
    for element in reversed(elements[:-2]):
        result = f"{{ m = {M_BOT}; e' = Alt (ref (Some {element}), ref (Some {result})) }}"
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
        return f"{{ m = {M_BOT}; e' = Eps \"{production_name}\" }}"
    elif len(parts) == 1:
        return f"{{ m = {M_BOT}; e' = Red ((fun t -> Pyast.Ast (\"{production_name}\", [t])), {parts[0]}) }}"
    elif len(parts) == 2:
        return f"{{ m = {M_BOT}; e' = Seq (\"{production_name}\", {parts[0]}, {parts[1]}) }}"
    else:
        return build_binary_seq(production_name, parts)


def build_binary_seq(label: str, elements: List[str]) -> str:
    result = elements[-1]
    for i, element in reversed(list(enumerate(elements[:-1], start=1))):
        result = f"{{ m = {M_BOT}; e' = Seq (\"BINRED-{i}-{label}\", {element}, {result}) }}"
    result = f"{{ m = {M_BOT}; e' = Red (Pyast.flatten_binary_seqs {len(elements) - 1} \"{label}\", {result}) }}"
    return result
