from .rule_components import *

from ..tokenize import *

from typing import Dict, List


__all__ = ['parse_grammar_file', 'tokenize_grammar_file']


DEFAULT_GRAMMAR_VERSION = '3.6'

COLON = TokenEnum.COLON
ALT = TokenEnum.PIPE
LIST = TokenEnum.STAR
NE_LIST = TokenEnum.PLUS
BEG_OPT = TokenEnum.L_SQR
END_OPT = TokenEnum.R_SQR
BEG_GROUP = TokenEnum.L_PAR
END_GROUP = TokenEnum.R_PAR
NEWLINE = TokenEnum.NEWLINE
INDENT = TokenEnum.INDENT
DEDENT = TokenEnum.DEDENT
NAME = TokenEnum.NAME
NUMBER = TokenEnum.NUMBER
STRING = TokenEnum.STRING


def parse_grammar_file(filename: str) -> Dict[str, Rule]:
    tokens = tokenize_grammar_file(filename)
    raw_rules = separate_rules(tokens)
    return parse_rules(raw_rules)


def tokenize_grammar_file(filename: str) -> List[Token]:
    grammar = load_grammar(version=DEFAULT_GRAMMAR_VERSION)
    return list(tokenize_file(filename, grammar, suppress_error_tokens=True))


def separate_rules(tokens: List[Token]) -> List[List[Token]]:
    rules: List[List[Token]] = []
    colon_idxs = [i for (i, t) in enumerate(tokens) if t == COLON]
    # An extra index is appended at the end to get the final rule. Its value is set to len(tokens) to slice everything
    # except the final token (which is ENDMARKER).
    colon_idxs.append(len(tokens))
    prev_idx = colon_idxs[0]
    for idx in colon_idxs[1:]:
        # The slice uses (index - 1) because colons are the second token of each rule (the first being the rule's name).
        rule = tokens[prev_idx - 1:idx - 1]
        rules.append(rule)
        prev_idx = idx
    return rules


def parse_rules(raw_rules: List[List[Token]]) -> Dict[str, Rule]:
    rules: Dict[str, Rule] = {}
    for raw_rule in raw_rules:
        rule = parse_rule(raw_rule)
        rules[rule.name] = rule
    return rules


def parse_rule(raw_rule: List[Token]) -> Rule:
    _filter_tokens(raw_rule)
    rule_name_token = raw_rule[0]
    assert isinstance(rule_name_token, ParameterizedToken)
    name = rule_name_token.param
    rule = Rule(name)
    idx = 2
    while idx < len(raw_rule):
        group = ProductionGroup(implicit=True)
        rule.add_group(group)
        idx = parse_group(raw_rule, idx, group)
    # Reduce groups whose only element is another group.
    for i, group in enumerate(rule.groups):
        # If this group has exactly one production...
        if len(group.productions) == 1:
            production = group.productions[0]
            # ...and that production has exactly one component...
            if len(production.components) == 1:
                component = production.components[0]
                # ...and that component is a ProductionGroup...
                if isinstance(component, ProductionGroup):
                    # ...then we can lift the inner Group to the top.
                    rule.groups[i] = component
                    if not component.optional:
                        # Top-level groups are usually implicit, unless they're optional.
                        component.implicit = True
    return rule


def _filter_tokens(tokens: List[Token]):
    i = 0
    while i < len(tokens):
        if tokens[i] == NEWLINE:
            del(tokens[i])
        else:
            i += 1


def parse_group(tokens: List[Token], idx: int, group: ProductionGroup) -> int:
    """
    Begins parsing the next production group in `tokens`, starting at index `idx`. The return value is the new current
    index in the existing list of tokens.
    """
    while idx < len(tokens):
        token = tokens[idx]
        if token in {END_GROUP, END_OPT}:
            idx += 1
            break
        production = Production()
        group.add_production(production)
        idx = parse_production(tokens, idx, production)
    if idx < len(tokens):
        peek = tokens[idx]
        if peek == LIST:
            group.repeat = Repeat.list
            idx += 1
        elif peek == NE_LIST:
            group.repeat = Repeat.ne_list
            idx += 1
    return idx


def parse_production(tokens: List[Token], idx: int, production: Production) -> int:
    while idx < len(tokens):
        token: Token = tokens[idx]
        if token in {INDENT, DEDENT}:
            idx += 1  # Ignore indentation.
        elif token in {END_GROUP, END_OPT}:
            break  # Break without incrementing the index because this must be detected in parse_group.
        elif token == ALT:
            idx += 1
            break  # ALT tokens mark the ends of productions.
        elif token == BEG_GROUP:
            idx += 1
            group = ProductionGroup()
            production.add_component(group)
            idx = parse_group(tokens, idx, group)
        elif token == BEG_OPT:
            idx += 1
            group = ProductionGroup(optional=True)
            production.add_component(group)
            idx = parse_group(tokens, idx, group)
        elif token == LIST:
            production.components[-1].repeat = Repeat.list
            idx += 1
        elif token == NE_LIST:
            production.components[-1].repeat = Repeat.ne_list
            idx += 1
        elif token == NAME:
            # NAME tokens represent both terminals and non-terminals.
            token: ParameterizedToken
            if token.param.isupper():
                production.add_component(Terminal(token.param))
            elif token.param.islower():
                production.add_component(NonTerminal(token.param))
            else:
                raise RuntimeError(f"Unexpected mixed-case NAME token: {token.param}.")
            idx += 1
        elif token == STRING:
            # STRING tokens represent terminal literals.
            token: ParameterizedToken
            production.add_component(Literal(token.param))
            idx += 1
        else:
            raise RuntimeError(f"Unexpected token: {token}.")
    return idx
