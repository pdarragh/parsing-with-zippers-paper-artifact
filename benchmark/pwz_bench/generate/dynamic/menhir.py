from pwz_bench.utility import *

from itertools import chain
from typing import List


__all__ = ['gen_pymen_mly']


PYMEN_MLY_PRELUDE = """\
/* Prelude */
%{
let seq (p : (string * Pyast.ast list)) : Pyast.ast = Pyast.Ast (fst p, snd p)
let tok (s : string) : Pyast.ast = seq (s, [])
%}
"""

PYMEN_MLY_REST = """\
/* Token Definitions */
{token_definitions}

/* Start Symbols */
{start_symbols}

%%

/* Token Parsers */
{token_parsers}

/* Main Grammar Parsers */
{grammar_parsers}
"""


def gen_pymen_mly(desc: GrammarDescription) -> List[str]:
    lines = PYMEN_MLY_PRELUDE.split('\n')
    lines.extend(PYMEN_MLY_REST.format(
        token_definitions='\n'.join(chain((f"%token {tok}_" for tok in chain(desc.tokens.named,
                                                                             desc.tokens.nameless)),
                                          (f"%token <{ty}> {tok}_" for tok, ty in desc.tokens.typed))),
        start_symbols='\n'.join(f"%start <Pyast.ast> {ss}" for ss in desc.start_symbols),
        token_parsers='\n'.join(chain((f"{token}: {token}_ {{ tok \"{token}\" }}"
                                       for token in chain(desc.tokens.named,
                                                          desc.tokens.nameless)),
                                      (f"{token}: {token}_ {{ tok $1 }}" for token, _ in desc.tokens.typed))),
        grammar_parsers='\n'.join(generate_rules(desc)),
    ).split('\n'))
    return lines


def generate_rules(desc: GrammarDescription) -> List[str]:
    lines = []
    for rule in desc.base_grammar.rules:
        if len(rule.groups) != 1:
            raise RuntimeError(f"Rule {rule.name} has {len(rule.groups)} top-level groups; expected 1.")
        group = rule.groups[0]
        if len(group.productions) == 1:
            lines.append(f"{rule.name}: {str_of_production(group.productions[0], desc, rule.name)}")
        else:
            lines.append(f"{rule.name}:")
            for i, production in enumerate(group.productions, start=1):
                lines.append(f"    | {str_of_production(production, desc, rule.name, i)}")
    return lines


def str_of_production(production: Production, desc: GrammarDescription, rule_name: str, production_no: int = 0) -> str:
    parts: List[str] = []
    for component in production.components:
        if isinstance(component, Terminal):
            parts.append(desc.terminal_names[component])
        elif isinstance(component, NonTerminal):
            parts.append(component.name)
        else:
            raise RuntimeError(f"Invalid component instance in production of class {component.__class__.__name__}.")
    if len(parts) > 9:
        raise RuntimeError(f"Cannot create production with {len(parts)} parts; Menhir allows at most 9.")
    production_name = rule_name
    if production_no > 0:
        production_name += f"-{production_no}"
    arguments = '; '.join('$' + str(idx + 1) for idx in range(len(parts)))
    semantic_action = f"{{ seq (\"{production_name}\", [ {arguments} ]) }}"
    return ' '.join(parts) + ' ' + semantic_action
