from .parse import *
from .tokenize import *

from dataclasses import dataclass, field
from re import compile as re_compile
from typing import Dict, List, NamedTuple, Tuple


__all__ = ['TokenCollection', 'GrammarDescription']


TokenCollection = NamedTuple('TokenCollection', [('named',      List[str]),
                                                 ('nameless',   List[str]),
                                                 ('typed',      List[Tuple[str, str]])])


TOKEN_NAME_RE = re_compile(r'[a-zA-Z][a-zA-Z0-9_]*')


@dataclass
class GrammarDescription:
    base_grammar: Grammar
    start_symbols: List[str]
    terminal_names: Dict[Terminal, str] = field(init=False, default_factory=dict)
    tokens: TokenCollection = field(init=False)

    def __post_init__(self):
        named: List[str] = []
        nameless: List[str] = []
        typed: List[Tuple[str, str]] = []
        for terminal in self.base_grammar.terminals:
            val = terminal.val
            # Determine whether the terminal's value is considered an alphanumeric name.
            if TOKEN_NAME_RE.match(val):
                name = val.upper()
                # Named tokens can either have types assigned, or just be lone tokens.
                ty = PARAMETERIZED_TOKEN_CLASS_NAMES_TO_OCAML_TYPES.get(name)
                if ty is None:
                    named.append(name)
                else:
                    tup = (name, ty)
                    typed.append(tup)
            else:
                # Tokens which at first appear nameless may actually just be operators. These have names prescribed by
                # the tokenizer module, so attempt to look up the name there first.
                token = OPERATORS_TO_TOKENS.get(val)
                if token is None:
                    # This token really is nameless. We generate a name for it.
                    name = f'TOKEN_{len(nameless) + 1}'
                    nameless.append(name)
                else:
                    # We can give this token a name! Add it to the rest of the named tokens.
                    name = token.name
                    named.append(name)
            self.terminal_names[terminal] = name
        # Sort the named and typed tokens (separately) for nicer output.
        # Note that nameless tokens are not sorted because we'd get them back in lexicographical order (instead of a
        # more natural numeric ordering).
        named.sort()
        typed.sort()
        self.tokens = TokenCollection(named, nameless, typed)
