from dataclasses import dataclass
from enum import Enum, unique
from parso.python.tokenize import PythonToken
from typing import Any, Dict, Generator, Iterator, List, Optional, Set

import re


__all__ = [
    'TokenClass', 'TOKEN_CLASSES', 'TOKEN_CLASSES_SET', 'PARAMETERIZED_TOKEN_CLASSES',
    'PARAMETERIZED_TOKEN_CLASSES_SET', 'PARAMETERIZED_TOKEN_CLASSES_TO_OCAML_TYPES',
    'PARAMETERIZED_TOKEN_CLASS_NAMES_TO_OCAML_TYPES',
    'TokenEnum', 'AMORPHOUS_TOKENS', 'PARAMETERIZED_TOKENS', 'SPECIAL_TOKENS', 'SPECIAL_TOKENS_SET',
    'SPECIAL_TOKEN_NAMES_SET', 'OPERATORS_TO_TOKENS', 'KEYWORDS_TO_TOKENS',
    'Token', 'ParameterizedToken', 'TokenGenerator', 'tokens_from_py_tokens', 'token_from_py_token',
    'make_string_of_token', 'token_pair_of_token', 'make_token_pair_of_token', 'make_string_token_assoc',
]


@unique
class TokenClass(Enum):
    NEWLINE     = 1
    INDENT      = 2
    DEDENT      = 3
    ENDMARKER   = 4
    OP          = 5
    KEYWORD     = 6
    NAME        = 7
    NUMBER      = 8
    STRING      = 9


TOKEN_CLASSES: List[TokenClass] = list(TokenClass)
TOKEN_CLASSES_SET: Set[TokenClass] = set(TOKEN_CLASSES)

PARAMETERIZED_TOKEN_CLASSES: List[TokenClass] = [TokenClass.NAME, TokenClass.NUMBER, TokenClass.STRING]
PARAMETERIZED_TOKEN_CLASSES_SET: Set[TokenClass] = set(PARAMETERIZED_TOKEN_CLASSES)

# Map the token types to the OCaml types they should be represented with.
PARAMETERIZED_TOKEN_CLASSES_TO_OCAML_TYPES: Dict[TokenClass, str] = {ptc: 'string'
                                                                     for ptc in PARAMETERIZED_TOKEN_CLASSES}
PARAMETERIZED_TOKEN_CLASS_NAMES_TO_OCAML_TYPES: Dict[str, str] = {ptc.name: ty for ptc, ty
                                                                  in PARAMETERIZED_TOKEN_CLASSES_TO_OCAML_TYPES.items()}


_base_int = 0
def auto() -> int:
    global _base_int
    val = _base_int
    _base_int += 1
    return val


@unique
class TokenEnum(Enum):
    # Operators.
    ARROW           = ('->',        auto(), TokenClass.OP)
    AT              = ('@',         auto(), TokenClass.OP)
    SEMICOLON       = (';',         auto(), TokenClass.OP)
    COLON           = (':',         auto(), TokenClass.OP)
    COMMA           = (',',         auto(), TokenClass.OP)
    DOT             = ('.',         auto(), TokenClass.OP)
    ELLIPSIS        = ('...',       auto(), TokenClass.OP)
    TILDE           = ('~',         auto(), TokenClass.OP)
    L_PAR           = ('(',         auto(), TokenClass.OP)
    R_PAR           = (')',         auto(), TokenClass.OP)
    L_SQR           = ('[',         auto(), TokenClass.OP)
    R_SQR           = (']',         auto(), TokenClass.OP)
    L_BRC           = ('{',         auto(), TokenClass.OP)
    R_BRC           = ('}',         auto(), TokenClass.OP)
    EQ              = ('=',         auto(), TokenClass.OP)
    EQ_EQ           = ('==',        auto(), TokenClass.OP)
    BANG_EQ         = ('!=',        auto(), TokenClass.OP)
    LT              = ('<',         auto(), TokenClass.OP)
    LE              = ('<=',        auto(), TokenClass.OP)
    LT_LT           = ('<<',        auto(), TokenClass.OP)
    LT_LT_EQ        = ('<<=',       auto(), TokenClass.OP)
    GT              = ('>',         auto(), TokenClass.OP)
    GE              = ('>=',        auto(), TokenClass.OP)
    GT_GT           = ('>>',        auto(), TokenClass.OP)
    GT_GT_EQ        = ('>>=',       auto(), TokenClass.OP)
    NE              = ('<>',        auto(), TokenClass.OP)
    PLUS            = ('+',         auto(), TokenClass.OP)
    PLUS_EQ         = ('+=',        auto(), TokenClass.OP)
    DASH            = ('-',         auto(), TokenClass.OP)
    DASH_EQ         = ('-=',        auto(), TokenClass.OP)
    STAR            = ('*',         auto(), TokenClass.OP)
    STAR_EQ         = ('*=',        auto(), TokenClass.OP)
    STAR_STAR       = ('**',        auto(), TokenClass.OP)
    STAR_STAR_EQ    = ('**=',       auto(), TokenClass.OP)
    SLASH           = ('/',         auto(), TokenClass.OP)
    SLASH_EQ        = ('/=',        auto(), TokenClass.OP)
    SLASH_SLASH     = ('//',        auto(), TokenClass.OP)
    SLASH_SLASH_EQ  = ('//=',       auto(), TokenClass.OP)
    PER             = ('%',         auto(), TokenClass.OP)
    PER_EQ          = ('%=',        auto(), TokenClass.OP)
    AMPERSAND       = ('&',         auto(), TokenClass.OP)
    AMPERSAND_EQ    = ('&=',        auto(), TokenClass.OP)
    PIPE            = ('|',         auto(), TokenClass.OP)
    PIPE_EQ         = ('|=',        auto(), TokenClass.OP)
    CARET           = ('^',         auto(), TokenClass.OP)
    CARET_EQ        = ('^=',        auto(), TokenClass.OP)
    # Keywords.
    AND             = ('and',       auto(), TokenClass.KEYWORD)
    AS              = ('as',        auto(), TokenClass.KEYWORD)
    ASSERT          = ('assert',    auto(), TokenClass.KEYWORD)
    BREAK           = ('break',     auto(), TokenClass.KEYWORD)
    CLASS           = ('class',     auto(), TokenClass.KEYWORD)
    CONTINUE        = ('continue',  auto(), TokenClass.KEYWORD)
    DEF             = ('def',       auto(), TokenClass.KEYWORD)
    DEL             = ('del',       auto(), TokenClass.KEYWORD)
    ELIF            = ('elif',      auto(), TokenClass.KEYWORD)
    ELSE            = ('else',      auto(), TokenClass.KEYWORD)
    EXCEPT          = ('except',    auto(), TokenClass.KEYWORD)
    FALSE           = ('False',     auto(), TokenClass.KEYWORD)
    FINALLY         = ('finally',   auto(), TokenClass.KEYWORD)
    FOR             = ('for',       auto(), TokenClass.KEYWORD)
    FROM            = ('from',      auto(), TokenClass.KEYWORD)
    GLOBAL          = ('global',    auto(), TokenClass.KEYWORD)
    IF              = ('if',        auto(), TokenClass.KEYWORD)
    IMPORT          = ('import',    auto(), TokenClass.KEYWORD)
    IN              = ('in',        auto(), TokenClass.KEYWORD)
    IS              = ('is',        auto(), TokenClass.KEYWORD)
    LAMBDA          = ('lambda',    auto(), TokenClass.KEYWORD)
    NONE            = ('None',      auto(), TokenClass.KEYWORD)
    NONLOCAL        = ('nonlocal',  auto(), TokenClass.KEYWORD)
    NOT             = ('not',       auto(), TokenClass.KEYWORD)
    OR              = ('or',        auto(), TokenClass.KEYWORD)
    PASS            = ('pass',      auto(), TokenClass.KEYWORD)
    RAISE           = ('raise',     auto(), TokenClass.KEYWORD)
    RETURN          = ('return',    auto(), TokenClass.KEYWORD)
    TRUE            = ('True',      auto(), TokenClass.KEYWORD)
    TRY             = ('try',       auto(), TokenClass.KEYWORD)
    WHILE           = ('while',     auto(), TokenClass.KEYWORD)
    WITH            = ('with',      auto(), TokenClass.KEYWORD)
    YIELD           = ('yield',     auto(), TokenClass.KEYWORD)
    # Amorphous literals.
    NEWLINE         = ('',          auto(), TokenClass.NEWLINE)
    INDENT          = ('',          auto(), TokenClass.INDENT)
    DEDENT          = ('',          auto(), TokenClass.DEDENT)
    ENDMARKER       = ('',          auto(), TokenClass.ENDMARKER)
    # Parameterized tokens.
    NAME            = ('',          auto(), TokenClass.NAME)
    NUMBER          = ('',          auto(), TokenClass.NUMBER)
    STRING          = ('',          auto(), TokenClass.STRING)

    def __init__(self, literal: str, tag: int, cls: TokenClass):
        self.literal = literal
        self.tag = tag
        self.cls = cls

    def __eq__(self, other) -> bool:
        try:
            if other not in TokenEnum:
                return NotImplemented
        except TypeError:
            return NotImplemented
        return self.tag == other.tag

    def __hash__(self) -> int:
        return self.tag


AMORPHOUS_TOKENS: List[TokenEnum] = [TokenEnum.NEWLINE, TokenEnum.INDENT, TokenEnum.DEDENT, TokenEnum.ENDMARKER]
PARAMETERIZED_TOKENS: List[TokenEnum] = [TokenEnum.NAME, TokenEnum.NUMBER, TokenEnum.STRING]
SPECIAL_TOKENS: List[TokenEnum] = AMORPHOUS_TOKENS + PARAMETERIZED_TOKENS
SPECIAL_TOKENS_SET: Set[TokenEnum] = set(SPECIAL_TOKENS)
SPECIAL_TOKEN_NAMES_SET: Set[str] = set(t.name for t in SPECIAL_TOKENS)

_word_re = re.compile(r'\w+')

OPERATORS_TO_TOKENS: Dict[str, TokenEnum] = {token.literal: token
                                             for token in list(TokenEnum)
                                             if token not in SPECIAL_TOKENS_SET
                                             and not _word_re.match(token.literal)}
KEYWORDS_TO_TOKENS: Dict[str, TokenEnum] = {token.literal: token
                                            for token in list(TokenEnum)
                                            if token not in SPECIAL_TOKENS_SET
                                            and _word_re.match(token.literal)}


@dataclass
class Token:
    _token: TokenEnum

    def __init__(self, token: TokenEnum):
        self._token = token

    def __str__(self) -> str:
        return self.string

    def __eq__(self, other) -> bool:
        if not isinstance(other, Token):
            try:
                if other in TokenEnum:
                    return self._token == other
            except TypeError:
                return NotImplemented
            return NotImplemented
        return self._token == other._token

    def __hash__(self) -> int:
        return hash(self._token)

    @property
    def cls(self) -> TokenClass:
        return self._token.cls

    @property
    def string(self) -> str:
        return self._token.name

    @property
    def type(self) -> str:
        return self._token.cls.name

    @property
    def literal(self) -> str:
        return self._token.literal

    @property
    def tag(self) -> int:
        return self._token.tag


@dataclass
class ParameterizedToken(Token):
    _param: str
    _param_type: str

    def __init__(self, token: TokenEnum, param: str):
        super().__init__(token)
        self._param = param
        self._param_type = PARAMETERIZED_TOKEN_CLASSES_TO_OCAML_TYPES[token.cls]

    __eq__ = Token.__eq__

    __hash__ = Token.__hash__

    @property
    def string(self) -> str:
        return f"{self.type} \"{self.param}\""

    @property
    def param(self) -> str:
        return self._param

    @property
    def param_type(self) -> str:
        return self._param_type


TokenGenerator = Generator[Token, Any, None]


def tokens_from_py_tokens(py_tokens: Iterator[PythonToken], suppress_error_tokens: bool = False) -> TokenGenerator:
    for py_token in py_tokens:
        tok = token_from_py_token(py_token, suppress_error_tokens)
        if tok is None:
            continue
        yield tok


def token_from_py_token(py_token: PythonToken, suppress_error_tokens: bool) -> Optional[Token]:
    token_type = py_token.type.name
    token_string = py_token.string
    if token_type == 'NEWLINE':
        return Token(TokenEnum.NEWLINE)
    elif token_type == 'INDENT':
        return Token(TokenEnum.INDENT)
    elif token_type == 'DEDENT':
        return Token(TokenEnum.DEDENT)
    elif token_type == 'ENDMARKER':
        return Token(TokenEnum.ENDMARKER)
    elif token_type == 'OP':
        tok = OPERATORS_TO_TOKENS.get(token_string)
        if tok is None:
            raise RuntimeError(f"Unable to handle operator token with literal form \'{token_string}\'.")
        return Token(tok)
    elif token_type == 'NAME' and token_string in KEYWORDS_TO_TOKENS:
        return Token(KEYWORDS_TO_TOKENS[token_string])
    elif token_type == 'NAME':
        return ParameterizedToken(TokenEnum.NAME, _trim_string(token_string))
    elif token_type == 'NUMBER':
        return ParameterizedToken(TokenEnum.NUMBER, _trim_string(token_string))
    elif token_type == 'STRING':
        return ParameterizedToken(TokenEnum.STRING, _trim_string(repr(token_string)[1:-1]))
    elif token_type in {'ERROR_DEDENT', 'ERRORTOKEN'}:
        if suppress_error_tokens:
            return None
        else:
            raise RuntimeError(f"Error in tokenization: {py_token}.")
    else:
        raise RuntimeError(f"Unexpected PythonToken type: {token_type} from token {py_token}.")


def _trim_string(s: str) -> str:
    if (s.startswith('\'\'\'') and s.endswith('\'\'\'')) or (s.startswith('"""') and s.endswith('"""')):
        return s[3:-3]
    elif (s.startswith('\'') and s.endswith('\'')) or (s.startswith('"') and s.endswith('"')):
        return s[1:-1]
    else:
        return s


def make_string_of_token(tok: str, parameterized: bool) -> str:
    if parameterized:
        return f"{tok}_ s -> s"
    else:
        return f"{tok}_ -> \"{tok}\""


def token_pair_of_token(tok: str, parameter: Optional[str] = None) -> str:
    tag = TokenEnum[tok].tag
    if parameter is not None:
        return f"({tag}, {parameter})"
    else:
        return f"({tag}, \"{tok}\")"


def make_token_pair_of_token(tok: str, parameterized: bool) -> str:
    if parameterized:
        return f"{tok}_ s -> {token_pair_of_token(tok, parameter='s')}"
    else:
        return f"{tok}_ -> {token_pair_of_token(tok)}"


def make_string_token_assoc(tok: str) -> str:
    return f"(\"{tok}\", {tok}_)"
