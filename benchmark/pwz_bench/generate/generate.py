from .generators import *
from .names import *

from pwz_bench.utility import *

from itertools import chain
from pathlib import Path
from typing import Dict, List


__all__ = ['SUPPORTED_PARSERS', 'generate_parsers']


STATIC_FILES = Path(__file__).parent / 'static'

SUPPORTED_PARSERS: Dict[str, ParserEnum] = {parser.value: parser for parser in list(ParserEnum)}


def generate_parsers(parsers: List[ParserEnum], output_dir: Path, grammar_file: str, start_symbols: List[str]):
    g = Grammar.build_from_file(grammar_file)
    grammar_desc = GrammarDescription(g, start_symbols)
    for generator in chain(*COMMON_GENERATORS.values()):
        generate_file(generator, output_dir, grammar_desc)
    for parser in parsers:
        for generator in PARSER_GENERATORS[parser]:
            generate_file(generator, output_dir, grammar_desc, suffix=parser.value)


def generate_file(generator: FileGenerator, destination_base: Path, grammar_desc: GrammarDescription, suffix: str = ''):
    if isinstance(generator, DynamicFileGenerator):
        generator.generate(destination_base / suffix, grammar_desc)
    elif isinstance(generator, StaticFileGenerator):
        generator.generate(STATIC_FILES / suffix, destination_base / suffix)
    else:
        raise RuntimeError(f"Unknown FileGenerator value encountered: {generator.__class__.__name__}.")
