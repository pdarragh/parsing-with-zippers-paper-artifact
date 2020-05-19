from pwz_bench.utility import *

from itertools import chain
from typing import List


__all__ = ['gen_pwz_nary_mem_pygram_ml']


PWZ_NARY_MEM_PYGRAM_ML = """\
open Pytokens
open Pwz_nary_mem

let rec {grammar_rules}
"""


def gen_pwz_nary_mem_pygram_ml(desc: GrammarDescription) -> List[str]:
    prefix = 'pwz_nary_mem_rule_'
    lines = PWZ_NARY_MEM_PYGRAM_ML.format(
        grammar_rules='\n    and '.join(chain(
            (f"{prefix}{token} = Tok {token_pair_of_token(token)}"
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
        production_strings = map(lambda p: str_of_production(p[1], desc, prefix, rule.name, p[0]),
                                 enumerate(group.productions, start=1))
        return f"{prefix}{rule.name} = Alt (ref [ {'; '.join(production_strings)} ])"



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
    return f"Seq (\"{production_name}\", [ {'; '.join(parts)} ])"
