from .tokens import *

from os.path import abspath, dirname, join
from parso.grammar import PythonGrammar
from typing import Optional

import parso.python.tokenize


__all__ = ['tokenize_file', 'load_grammar']


DEFAULT_GRAMMAR_PATH = abspath(join(dirname(__file__), "../python-3.4.grammar"))


def tokenize_file(filename: str, grammar: Optional[PythonGrammar] = None,
                  suppress_error_tokens: bool = False) -> TokenGenerator:
    with open(filename) as f:
        lines = f.readlines()
    start_pos = (1, 0)

    if grammar is None:
        grammar = load_grammar()

    return tokens_from_py_tokens(grammar._tokenize_lines(lines, start_pos), suppress_error_tokens)


def load_grammar(path: Optional[str] = None, version: Optional[str] = None) -> PythonGrammar:
    if path is None:
        if version is None:
            return parso.load_grammar(path=DEFAULT_GRAMMAR_PATH)
        else:
            return parso.load_grammar(version=version)
    else:
        if version is None:
            return parso.load_grammar(path=path)
        else:
            raise ValueError("Cannot specify both path and version for loading grammar.")
