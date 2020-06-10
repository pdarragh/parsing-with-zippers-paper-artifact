#!/usr/bin/env python3

from pwz_bench.generate import *
from pwz_bench.utility import *

from pathlib import Path
from typing import List

import argparse


NONE = 'none'
ALL = 'all'

THIS_FILE = Path(__file__).resolve()
THIS_DIR = THIS_FILE.parent
DEFAULT_TGZ_FILE = THIS_DIR / 'Python-3.4.3.tgz'
DEFAULT_GEN_DIR = THIS_DIR / 'gen'
DEFAULT_BENCH = DEFAULT_GEN_DIR / 'pwz_bench'
DEFAULT_PARSE = DEFAULT_GEN_DIR / 'pwz_parse'
DEFAULT_PY_DIR = THIS_DIR / 'pys'
DEFAULT_LEX_DIR = THIS_DIR / 'lexes'
DEFAULT_AST_DIR = THIS_DIR / 'parses'
DEFAULT_BENCH_DIR = THIS_DIR / 'bench'
DEFAULT_GRAPHS_DIR = THIS_DIR / 'graphs'
DEFAULT_OUT_DIR = THIS_DIR / 'out'
DEFAULT_COLLATED_RESULTS_FILE = DEFAULT_BENCH_DIR / 'collated-results.csv'
DEFAULT_RECURSIVE_CALLS_FILE = DEFAULT_GRAPHS_DIR / 'recursive-calls.csv'

PARSER_CHOICES = list(SUPPORTED_PARSERS.keys()) + [NONE, ALL]


def process_parser_choices(choices: List[str]) -> List[ParserEnum]:
    if len(choices) == 0:
        choices = [ALL]
    if ALL in choices:
        if NONE in choices:
            raise RuntimeError(f"Cannot specify both '{ALL}' and '{NONE}' parsers.")
        parsers = list(SUPPORTED_PARSERS.values())
    elif NONE in choices:
        parsers = []
    else:
        added = set()
        parsers = []
        for choice in choices:
            if choice in added:
                continue
            parsers.append(SUPPORTED_PARSERS[choice])
            added.add(choice)
    return parsers


def strs_of_parsers(parsers: List[ParserEnum]) -> List[str]:
    return [parser.value for parser in parsers]


def prepare(args):
    extract_input_files(args.output_dir, args.tgz_filename, args.force_extract)


def lex(args):
    g = load_grammar(args.grammar_file, args.python_version)
    if args.filename is None:
        if args.input_dir is None or args.output_dir is None:
            raise RuntimeError("Must specify either a single file name "
                               "or else both the -I/--input-dir and -O/--output-dir options together.")
        for py_path in Path(args.input_dir).resolve().glob('*.py'):
            out_path = Path(args.output_dir).resolve() / py_path.with_suffix('.py.lex').name
            print(f"Writing {out_path}... ", end='')
            with open(out_path, 'w') as f:
                for tok in tokenize_file(py_path, g):
                    f.write(f"{tok}\n")
            print(f"Done")
    else:
        tok_gen = tokenize_file(args.filename, g)
        for tok in tok_gen:
            print(tok)


def transform(args):
    g = Grammar.build_from_file(args.filename)
    pretty_print_rules(g.rules)


def generate(args):
    parsers = process_parser_choices(args.parsers)
    generate_parsers(parsers, args.output_dir.resolve(), args.filename, args.start_symbols)


def parse(args):
    timeout = args.timeout if args.timeout != -1 else None
    parsers = process_parser_choices(args.parsers)
    run_parsers(args.driver, THIS_DIR, args.input_dir.resolve(), args.output_dir.resolve(),
                strs_of_parsers(parsers), timeout)


def verify(args):
    parsers = process_parser_choices(args.parsers)
    verify_parses(THIS_DIR, args.input_dir, strs_of_parsers(parsers))


def benchmark(args):
    parsers = process_parser_choices(args.parsers)
    run_benchmarks(args.driver, THIS_DIR, args.input_dir.resolve(), args.output_dir.resolve(),
                   strs_of_parsers(parsers), args.resume, args.quota_factor, args.max_quota)


def collate(args):
    parsers = process_parser_choices(args.parsers)
    collate_benchmarking_results(args.input_dir.resolve(), strs_of_parsers(parsers), args.overwrite,
                                 args.output_file.resolve())


def graphs(args):
    generate_graphs_pdf_file(args.input_dir.resolve(), args.output_dir.resolve(), args.overwrite,
                             args.recursive_calls_file.resolve(), args.collated_results_file.resolve())


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers()

    prepare_parser = subparsers.add_parser('prepare')
    prepare_parser.add_argument('-t', '--tgz-filename', type=Path, default=DEFAULT_TGZ_FILE,
                                help="the .tgz file of Python source code to extract inputs from")
    prepare_parser.add_argument('-O', '--output-dir', '--py-file-dir', type=Path, default=DEFAULT_PY_DIR,
                                help="the directory to move the extracted .py test files to")
    prepare_parser.add_argument('--force-extract', action='store_true',
                                help="force the extraction to proceed even if the destination directory contains .py files")
    prepare_parser.set_defaults(func=prepare)

    lex_parser = subparsers.add_parser('lex')
    lex_parser.add_argument('filename', nargs='?',
                            help="the Python file to lex")
    lex_parser.add_argument('-I', '--input-dir', '--py-file-dir',
                            help="a directory to find .py files in to lex; must be used with -O/--output-dir")
    lex_parser.add_argument('-O', '--output-dir', '--lex-file-dir',
                            help="a directory to output .lex files; must be used with -I/--input-dir")
    lex_parser.add_argument('--python-version',
                            help="the version of Python to use while lexing, as a string")
    lex_parser.add_argument('--grammar-file',
                            help="a Python grammar file to use while lexing")
    lex_parser.set_defaults(func=lex)

    transform_parser = subparsers.add_parser('transform')
    transform_parser.add_argument('filename',
                                  help="the grammar file to transform to a Menhir-compatible grammar")
    transform_parser.set_defaults(func=transform)

    generate_parser = subparsers.add_parser('generate')
    generate_parser.add_argument('filename',
                                 help="the grammar file to build a parser generator from")
    generate_parser.add_argument('-p', '--parser', choices=PARSER_CHOICES, action='append', default=[], dest='parsers',
                                 help="the parser to generate; can be given more than once or left out to generate all")
    generate_parser.add_argument('-O', '--output-dir', type=Path, default=DEFAULT_GEN_DIR,
                                 help="the directory to write all generated files to")
    generate_parser.add_argument('-s', '--start-symbol', action='append', dest='start_symbols',
                                 help="specify a non-terminal as a start symbol; can be given more than once")
    generate_parser.set_defaults(func=generate)

    parse_parser = subparsers.add_parser('parse')
    parse_parser.add_argument('driver', type=Path, default=DEFAULT_PARSE, nargs='?',
                              help="the compiled parsing executable")
    parse_parser.add_argument('-I', '--input-dir', '--lex-file-dir', type=Path, default=DEFAULT_LEX_DIR,
                              help="the directory to read .lex files from")
    parse_parser.add_argument('-O', '--output-dir', '--ast-file-dir', type=Path, default=DEFAULT_AST_DIR,
                              help="the directory to output parsers' .ast files to")
    parse_parser.add_argument('-p', '--parser', choices=PARSER_CHOICES, action='append', default=[], dest='parsers',
                              help="the parser to use; can be given more than once or left out to run all parsers")
    parse_parser.add_argument('-t', '--timeout', type=int,
                              help="the number of seconds to wait before timing out a parse (and all subsequent parses "
                                   "with the same parser); leave unspecified or give -1 for no timeout")
    parse_parser.set_defaults(func=parse)

    verify_parser = subparsers.add_parser('verify')
    verify_parser.add_argument('-I', '--input-dir', '--ast-file-dir', type=Path, default=DEFAULT_AST_DIR,
                               help="the directory to read parsed .ast files from")
    verify_parser.add_argument('-p', '--parser', choices=PARSER_CHOICES, action='append', default=[], dest='parsers',
                               help="the parser to verify; can be given more than once or left out to run all parsers")
    verify_parser.set_defaults(func=verify)

    bench_parser = subparsers.add_parser('benchmark')
    bench_parser.add_argument('driver', type=Path, default=DEFAULT_BENCH, nargs='?',
                              help="the compiled benchmarking executable")
    bench_parser.add_argument('-I', '--input-dir', '--lex-file-dir', type=Path, default=DEFAULT_LEX_DIR,
                              help="the directory to read .lex files from")
    bench_parser.add_argument('-O', '--output-dir', '--bench-file-dir', type=Path, default=DEFAULT_BENCH_DIR,
                              help="the directory to output parsers' .bench files to")
    bench_parser.add_argument('-p', '--parser', choices=PARSER_CHOICES, action='append', default=[], dest='parsers',
                              help="the parser to benchmark; can be given more than once or left out to run all parsers")
    bench_parser.add_argument('-r', '--resume', action='store_true',
                              help="attempt to resume from previously saved partial benchmarking results")
    bench_parser.add_argument('-q', '--quota-factor', type=int, default=3,
                              help="the multiplier to use when increasing the quota")
    bench_parser.add_argument('--max-quota', type=int, default=None,
                              help="the maximum allowable quota; executions that go beyond this will be abandoned")
    bench_parser.set_defaults(func=benchmark)

    collate_parser = subparsers.add_parser('collate')
    collate_parser.add_argument('-I', '--input-dir', '--bench-file-dir', type=Path, default=DEFAULT_BENCH_DIR,
                                help="the directory to retrieve completed benchmarking results from")
    collate_parser.add_argument('-O', '--output-file', '--collated-results-file', type=Path, default=DEFAULT_COLLATED_RESULTS_FILE,
                                help="the name of the file to write collated results to")
    collate_parser.add_argument('-p', '--parser', choices=PARSER_CHOICES, action='append', default=[], dest='parsers',
                                help="the parser to benchmark; can be given more than once or left out to run all parsers")
    collate_parser.add_argument('-o', '--overwrite', action='store_true',
                                help="delete the existing output file if it already exists")
    collate_parser.set_defaults(func=collate)

    graphs_parser = subparsers.add_parser('graphs')
    graphs_parser.add_argument('-I', '--input-dir', '--graphs-file-dir', type=Path, default=DEFAULT_GRAPHS_DIR,
                              help="the directory to find and place graphing-related files in")
    graphs_parser.add_argument('-O', '--output-dir', type=Path, default=DEFAULT_OUT_DIR,
                               help="the directory to output the PDF file to")
    graphs_parser.add_argument('-r', '--collated-results-file', type=Path, default=DEFAULT_COLLATED_RESULTS_FILE,
                              help="the name of the file containing collated results")
    graphs_parser.add_argument('-c', '--recursive-calls-file', type=Path, default=DEFAULT_RECURSIVE_CALLS_FILE,
                              help="the name of the file mapping the number of recursive calls to the number of tokens")
    graphs_parser.add_argument('-o', '--overwrite', action='store_true',
                              help="delete the existing .tex file if it already exists")
    graphs_parser.set_defaults(func=graphs)

    parsed_args = parser.parse_args()
    parsed_args.func(parsed_args)
