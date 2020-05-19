from dataclasses import dataclass, field
from enum import Enum, auto
from typing import List


__all__ = ['Repeat', 'Component', 'Terminal', 'Literal', 'NonTerminal', 'Production', 'ProductionGroup', 'Rule',
           'pretty_print_rules']


class Repeat(Enum):
    none = auto()
    list = auto()
    ne_list = auto()


@dataclass
class Component:
    repeat: Repeat = field(init=False)  # repeat cannot have a default value because of inheritance MRO conflicts.

    def __post_init__(self):
        # self.repeat must be set manually after initialization to change this default value.
        self.repeat = Repeat.none

    def _rep_str(self) -> str:
        if self.repeat == Repeat.list:
            return '*'
        elif self.repeat == Repeat.ne_list:
            return '+'
        else:
            return ''


@dataclass(unsafe_hash=True)
class Terminal(Component):
    val: str

    def __str__(self) -> str:
        return self.val + self._rep_str()


@dataclass(unsafe_hash=True)
class Literal(Terminal):
    def __str__(self) -> str:
        return f"'{self.val}'{self._rep_str()}"


@dataclass(unsafe_hash=True)
class NonTerminal(Component):
    name: str

    def __str__(self) -> str:
        return self.name + self._rep_str()


@dataclass
class Production:
    components: List[Component] = field(default_factory=list)

    def add_component(self, component: Component):
        self.components.append(component)

    def __str__(self) -> str:
        return ' '.join(map(str, self.components))


@dataclass
class ProductionGroup(Component):
    optional: bool = False  # True = [ ], False = ( )
    implicit: bool = False  # Top-level groups are implicit.
    productions: List[Production] = field(default_factory=list)

    def add_production(self, production: Production):
        self.productions.append(production)

    def __str__(self) -> str:
        interior = ' | '.join(map(str, self.productions))
        if self.implicit:
            return interior
        else:
            if self.optional:
                return f"[{interior}]{self._rep_str()}"
            else:
                return f"({interior}){self._rep_str()}"


@dataclass
class Rule:
    name: str
    groups: List[ProductionGroup] = field(default_factory=list)

    def add_group(self, group: ProductionGroup):
        self.groups.append(group)

    def __str__(self) -> str:
        return f"{self.name}: {' | '.join(map(str, self.groups))}"


def pretty_print_rules(rules: List[Rule]):
    for rule in rules:
        if len(rule.groups) == 1:
            print(f"{rule.name}:")
            for production in rule.groups[0].productions:
                print(f"  | {production}")
        else:
            print(rule)
