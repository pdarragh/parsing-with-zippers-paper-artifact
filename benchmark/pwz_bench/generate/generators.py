from .dynamic import *
from .names import *

from pwz_bench.utility import *

from typing import Dict, List


__all__ = ['COMMON_GENERATORS', 'PARSER_GENERATORS']


COMMON_GENERATORS: Dict[CommonEnum, List[FileGenerator]] = {
    CommonEnum.FIRST: [
        StaticFileGenerator('benchmarking.ml'),
        StaticFileGenerator('pyast.ml'),
        DynamicFileGenerator(gen_pytokens_ml, 'pytokens.ml'),
        StaticFileGenerator('interface.ml'),
        StaticFileGenerator('define.ml'),
    ],
    CommonEnum.LAST: [
        StaticFileGenerator('pwz_cli_common.ml'),
    ],
    CommonEnum.FINAL: [
        StaticFileGenerator('pwz_bench.ml'),
        StaticFileGenerator('pwz_parse.ml'),
    ],
    CommonEnum.SPECIAL: [
        StaticFileGenerator('Makefile'),
    ],
}

PARSER_GENERATORS: Dict[ParserEnum, List[FileGenerator]] = {
    ParserEnum.MENHIR: [
        DynamicFileGenerator(gen_pymen_mly, 'pymen.mly'),
        StaticFileGenerator('menhir_interface.ml'),
    ],
    ParserEnum.DYPGEN: [
        DynamicFileGenerator(gen_pydyp_dyp, 'pydyp.dyp'),
        StaticFileGenerator('dypgen_interface.ml'),
    ],
    ParserEnum.PWZ_NARY: [
        StaticFileGenerator('pwz_nary.ml'),
        DynamicFileGenerator(gen_pwz_nary_pygram_ml, 'pwz_nary_pygram.ml'),
        StaticFileGenerator('pwz_nary_interface.ml'),
    ],
    ParserEnum.PWZ_NARY_LIST: [
        StaticFileGenerator('pwz_nary_list.ml'),
        DynamicFileGenerator(gen_pwz_nary_list_pygram_ml, 'pwz_nary_list_pygram.ml'),
        StaticFileGenerator('pwz_nary_list_interface.ml'),
    ],
    ParserEnum.PWZ_NARY_LOOK: [
        StaticFileGenerator('pwz_nary_look.ml'),
        DynamicFileGenerator(gen_pwz_nary_look_pygram_ml, 'pwz_nary_look_pygram.ml'),
        StaticFileGenerator('pwz_nary_look_interface.ml'),
    ],
    ParserEnum.PWZ_BINARY: [
        StaticFileGenerator('pwz_binary.ml'),
        DynamicFileGenerator(gen_pwz_binary_pygram_ml, 'pwz_binary_pygram.ml'),
        StaticFileGenerator('pwz_binary_interface.ml'),
    ],
    ParserEnum.PWD_BINARY: [
        StaticFileGenerator('pwd_binary.ml'),
        DynamicFileGenerator(gen_pwd_binary_pygram_ml, 'pwd_binary_pygram.ml'),
        StaticFileGenerator('pwd_binary_interface.ml'),
    ],
    ParserEnum.PWD_BINARY_OPT: [
        StaticFileGenerator('pwd_binary_opt.ml'),
        DynamicFileGenerator(gen_pwd_binary_opt_pygram_ml, 'pwd_binary_opt_pygram.ml'),
        StaticFileGenerator('pwd_binary_opt_interface.ml'),
    ],
    ParserEnum.PWD_NARY: [
        StaticFileGenerator('pwd_nary.ml'),
        DynamicFileGenerator(gen_pwd_nary_pygram_ml, 'pwd_nary_pygram.ml'),
        StaticFileGenerator('pwd_nary_interface.ml'),
    ],
    ParserEnum.PWD_NARY_OPT: [
        StaticFileGenerator('pwd_nary_opt.ml'),
        DynamicFileGenerator(gen_pwd_nary_opt_pygram_ml, 'pwd_nary_opt_pygram.ml'),
        StaticFileGenerator('pwd_nary_opt_interface.ml'),
    ],
}
