from .parse import *
from .rule_components import *

from collections import deque
from dataclasses import replace
from typing import Dict, Generic, List, Optional, Tuple, TypeVar, Union


__all__ = ['parse_and_transform_grammar_file', 'transform_grammar']


Grammar = Dict[str, Rule]


_KT = TypeVar('_KT')
_VT = TypeVar('_VT')


class QueueDict(Generic[_KT, _VT]):
    def __init__(self):
        self._deque = deque()
        self._dict: Dict[_KT, _VT] = {}

    def insert(self, key: _KT, val: _VT):
        if key in self:
            return
        self._dict[key] = val
        self._deque.append(key)

    def pop(self) -> Tuple[_KT, _VT]:
        key = self._deque.popleft()
        val = self._dict[key]
        del(self._dict[key])
        return key, val

    def __contains__(self, key: _KT) -> bool:
        return key in self._dict

    def __bool__(self) -> bool:
        return bool(self._deque)


def parse_and_transform_grammar_file(filename: str, return_original: bool = False) -> Union[Grammar,
                                                                                            Tuple[Grammar, Grammar]]:
    original_grammar = parse_grammar_file(filename)
    new_grammar = transform_grammar(original_grammar)
    if return_original:
        return original_grammar, new_grammar
    else:
        return new_grammar


def transform_grammar(old_grammar: Dict[str, Rule]) -> Dict[str, Rule]:
    new_grammar: Dict[str, Rule] = {}
    for name, rule in old_grammar.items():
        new_rules = transform_rule(rule)
        for new_rule in new_rules:
            new_grammar[new_rule.name] = new_rule
    _reduce_grammar(new_grammar)
    return new_grammar


def _reduce_grammar(grammar: Dict[str, Rule]):
    """
    In the declaration of a grammar, we may end up with simple alias definitions of the form:

        rule_1: rule_2
        rule_3: 'terminal'

    This is undesirable for some parser generators which rely on OCaml's recursive let bindings, which cannot have this
    form. This function reduces these rules, leaving no simple aliases.

    Note that this is an in-place operation over the existing grammar definition.

    :param grammar: the grammar within which to reduce rules
    """
    worklist = QueueDict[str, Union[Terminal, NonTerminal]]()
    for name, rule in grammar.items():
        target = _find_reduction_target(rule)
        if target is not None:
            worklist.insert(name, target)
    while worklist:
        name, target = worklist.pop()
        if name not in grammar:
            continue
        if isinstance(target, NonTerminal):
            # We have an aliasing situation going on: `rule` is merely another name for another rule, and does nothing
            # noteworthy on its own. We will replace all references to `rule` with references to the other rule.
            aliased_name = target.name
            # Check for illegal circumstances.
            if aliased_name == name:
                raise RuntimeError(f"Cannot have self-reference in rule {name}.")
            if aliased_name in worklist:
                raise RuntimeError(f"Cannot have circular references in rules {name} and {aliased_name}.")
            # Reduce the rules.
            reference = NonTerminal(aliased_name)
            _replace_references(name, reference, grammar)
        elif isinstance(target, Terminal):
            # This is an overly simple rule: it consists only of a terminal. For some parser generators, this may cause
            # a problem, so we lift the terminal to replace all references to this rule.
            _replace_references(name, target, grammar)
        else:
            raise RuntimeError(f"Unexpected reduction target found: {target}.")


def _find_reduction_target(rule: Rule) -> Optional[Union[Terminal, NonTerminal]]:
    """
    Determines whether a rule should be reduced, and if so, determines the reduction target for this rule. The reduction
    target is the terminal or non-terminal which should determine what to replace this rule with in the rest of the
    grammar.

    :param rule: the rule to probe for a reduction target
    :return: either the reduction target (a Terminal or NonTerminal) or None (if the rule should not be reduced)
    """
    if len(rule.groups) != 1:
        return None
    group = rule.groups[0]
    if group.optional or not group.implicit:
        return None
    if len(group.productions) == 1:
        production = group.productions[0]
        if len(production.components) == 1:
            component = production.components[0]
            if isinstance(component, Terminal) or isinstance(component, NonTerminal):
                return component
    return None


def _replace_references(rule_name: str, replacement: Union[Terminal, NonTerminal], grammar: Dict[str, Rule]):
    """
    Replaces all references to the rule in the grammar with the given replacement.

    Note that this is an in-place operation.

    :param rule_name: the name of the rule to replace references of
    :param replacement: the terminal or non-terminal to replace those references with
    :param grammar: the grammar in which to perform replacements
    """
    for name, rule in grammar.items():
        if name == rule_name:
            continue
        for group in rule.groups:
            for production in group.productions:
                for i, component in enumerate(production.components):
                    if isinstance(component, NonTerminal) and component.name == rule_name:
                        production.components[i] = replacement
    del(grammar[rule_name])


def transform_rule(old_rule: Rule) -> List[Rule]:
    new_rule = Rule(old_rule.name)
    # All rules should have a single top-level group.
    if len(old_rule.groups) != 1:
        raise RuntimeError(f"Rule {old_rule.name} has {len(old_rule.groups)} top-level groups instead of exactly 1.")
    new_group, new_rules = transform_group(old_rule.groups[0], old_rule.name)
    new_rule.add_group(new_group)
    # Include the base new rule in the list of rules.
    new_rules.insert(0, new_rule)
    return new_rules


def transform_group(old_group: ProductionGroup, rule_name: str) -> Tuple[ProductionGroup, List[Rule]]:
    new_group = ProductionGroup(optional=old_group.optional, implicit=old_group.implicit)
    new_rules: List[Rule] = []
    for snt_cnt, old_production in enumerate(old_group.productions, start=1):
        new_production, rules = transform_production(old_production, rule_name, snt_cnt)
        new_group.add_production(new_production)
        new_rules.extend(rules)
    return new_group, new_rules


def transform_production(old_production: Production, rule_name: str, snt_cnt: int = 1) -> Tuple[Production, List[Rule]]:
    new_production = Production()
    new_rules: List[Rule] = []
    for old_component in old_production.components:
        if old_component.repeat is Repeat.none:
            if isinstance(old_component, Terminal) or isinstance(old_component, NonTerminal):
                new_component = replace(old_component)
                new_production.add_component(new_component)
            elif isinstance(old_component, ProductionGroup):
                rules = create_rule_from_group(old_component, rule_name, snt_cnt)
                snt_cnt += 1
                snt = NonTerminal(rules[0].name)
                new_production.add_component(snt)
                new_rules.extend(rules)
            else:
                raise RuntimeError(f"Cannot transform component of type {old_component.__class__.__name__}.")
        else:
            rules = create_rule_from_list(old_component, rule_name, snt_cnt)
            snt_cnt += 1
            snt = NonTerminal(rules[0].name)
            new_production.add_component(snt)
            new_rules.extend(rules)
    return new_production, new_rules


_nt_cnt = 1
def _create_snt_rule_name(rule_name: str, modifier: str, snt_cnt: int) -> str:
    global _nt_cnt
    name = f"{rule_name}__{modifier}_{snt_cnt}__{_nt_cnt}"
    _nt_cnt += 1
    return name


def create_rule_from_list(old_component: Component, rule_name: str, snt_cnt: int) -> List[Rule]:
    nonempty = old_component.repeat is Repeat.ne_list
    rule = Rule(_create_snt_rule_name(rule_name, 'lst', snt_cnt))
    new_rules: List[Rule] = [rule]
    if isinstance(old_component, Terminal) or isinstance(old_component, NonTerminal):
        """
        rule: x*    ==> rule: snt
                        snt: e | x snt      (where 'e' represents the empty production)
        """
        new_component = replace(old_component)
        if nonempty:
            lhs = Production([new_component])
        else:
            lhs = Production()
        rhs = Production([new_component, NonTerminal(rule.name)])
        group = ProductionGroup(implicit=True, productions=[lhs, rhs])
        rule.add_group(group)
    elif isinstance(old_component, ProductionGroup):
        """
        rule: x1 (x2 | x3)*     ==> rule: x1 snt_1
                                    snt_1: e | snt_2 snt_1      (where 'e' represents the empty production)
                                    snt_2: x2 | x3
        """
        rules = create_rule_from_group(old_component, rule.name, 1)
        snt = NonTerminal(rules[0].name)
        if nonempty:
            lhs = Production([snt])
        else:
            lhs = Production()
        rhs = Production([snt, NonTerminal(rule.name)])
        group = ProductionGroup(implicit=True, productions=[lhs, rhs])
        rule.add_group(group)
        new_rules.extend(rules)
    else:
        raise RuntimeError(f"Cannot create rule from list of {old_component.__class__.__name__}.")
    return new_rules


def create_rule_from_group(old_group: ProductionGroup, rule_name: str, snt_cnt: int) -> List[Rule]:
    rule = Rule(_create_snt_rule_name(rule_name, 'opt_grp' if old_group.optional else 'grp', snt_cnt))
    new_group = ProductionGroup(implicit=True)
    rule.add_group(new_group)
    new_rules: List[Rule] = [rule]
    if old_group.optional:
        """
        rule: [ x ]     ==> rule: snt
                            snt: e | x      (where 'e' represents the empty production)
        """
        eps = Production()
        new_group.add_production(eps)
    for old_production in old_group.productions:
        """
        rule: x1 ( x2 | x3 )    ==> rule: x1 snt
                                    snt: x2 | x3
        """
        new_production, rules = transform_production(old_production, rule.name)
        new_group.add_production(new_production)
        new_rules.extend(rules)
    return new_rules
