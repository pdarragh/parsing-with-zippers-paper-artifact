from .common import *

from pwz_bench.generate.names import ParserEnum

from pathlib import Path
from subprocess import run
from typing import List


__all__ = ['verify_parses']


def verify_parses(base_dir: Path, ast_file_dir: Path, parsers: List[str]):
    menhir_dir = ast_file_dir / ParserEnum.MENHIR.value
    if not menhir_dir.is_dir():
        raise RuntimeError(f"Must produce Menhir parses prior to verification.")
    print(f"Verifying parses, using Menhir's results as ground truth...")
    for parser in parsers:
        parse_dir = ast_file_dir / parser
        parse_file_tups = get_sorted_files_and_lengths(parse_dir, '*.ast')
        max_filename_length = find_longest_filename_length(map(lambda t: t[0], parse_file_tups))
        print(f"Verifying parses by {parser} in {parse_dir}...")
        err_file = ast_file_dir / f'{parser}-verify-errors.txt'
        err_file.write_text('')
        print(f"Names of error-producing verifications will be recorded in {err_file}...")
        for parse_file, _ in parse_file_tups:
            short_file = parse_file.relative_to(base_dir)
            relative_base_length = len(str(short_file.parent))
            max_short_length = relative_base_length + 1 + max_filename_length + 3
            menhir_file = menhir_dir / parse_file.name
            if not menhir_file.is_file():
                raise RuntimeError(f"Missing Menhir parse: {menhir_file}.")
            print(f"Verifying {str(short_file) + '...':{max_short_length}} ", end='', flush=True)
            result = run(['diff', menhir_file, parse_file], capture_output=True)
            if result.returncode == 0:
                print(GREEN_CHECK)
            else:
                with open(err_file, 'a') as ef:
                    ef.write(f"{short_file}\n")
                print(RED_X)
        print(f"Verification with {parser} complete.")
    print(f"Verification done.")
