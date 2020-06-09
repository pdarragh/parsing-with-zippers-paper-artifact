from enum import Enum, unique


__all__ = ['ParserEnum', 'CommonEnum']


@unique
class ParserEnum(Enum):
    MENHIR = 'menhir'
    DYPGEN = 'dypgen'
    PWZ_NARY = 'pwz_nary'
    PWZ_NARY_LIST = 'pwz_nary_list'
    PWZ_NARY_LOOK = 'pwz_nary_look'
    PWZ_BINARY = 'pwz_binary'
    PWD_BINARY = 'pwd_binary'
    PWD_BINARY_OPT = 'pwd_binary_opt'
    PWD_NARY = 'pwd_nary'
    PWD_NARY_OPT = 'pwd_nary_opt'


@unique
class CommonEnum(Enum):
    FIRST = 'first'
    LAST = 'last'
    FINAL = 'final'
    SPECIAL = 'special'
