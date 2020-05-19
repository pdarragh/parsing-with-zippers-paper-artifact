from .parse import *
from .rule_components import *
from .transform import parse_and_transform_grammar_file

from typing import Dict, List, Optional, Set, Union


__all__ = ['Grammar']


GrammarDict = Dict[str, Rule]


class Grammar:
    @staticmethod
    def build_from_file(filename: str) -> 'Grammar':
        gd = parse_and_transform_grammar_file(filename)
        return Grammar(gd)

    @staticmethod
    def build_untransformed_from_file(filename: str) -> 'Grammar':
        gd = parse_grammar_file(filename)
        return Grammar(gd)

    def __init__(self, grammar_dict: GrammarDict):
        self._grammar = grammar_dict
        self.non_terminals: Set[NonTerminal] = set()
        self.terminals: Set[Terminal] = set()
        self.rules: List[Rule] = []
        self._tally()
        self.valid = self.validate()

    def _tally(self, current: Optional[Union[Component, Production]] = None):
        if current is None:
            for rule in self._grammar.values():
                self.rules.append(rule)
                for group in rule.groups:
                    self._tally(group)
        elif isinstance(current, Production):
            for component in current.components:
                self._tally(component)
        elif isinstance(current, ProductionGroup):
            for production in current.productions:
                self._tally(production)
        elif isinstance(current, Terminal):
            self.terminals.add(current)
        elif isinstance(current, NonTerminal):
            self.non_terminals.add(current)
        else:
            raise ValueError(f"Cannot tally instance of class {current.__class__.__name__}.")

    def validate(self, raise_exception: bool = False) -> bool:
        missing = []
        for nt in self.non_terminals:
            if nt.name not in self._grammar.keys():
                missing.append(nt.name)
        if raise_exception and missing:
            raise RuntimeError(f"Invalid grammar: missing definitions for the following non-terminals:\n"
                               f"  {', '.join(missing)}")
        return not missing

    def __str__(self) -> str:
        return '\n'.join(map(str, self._grammar.values()))
