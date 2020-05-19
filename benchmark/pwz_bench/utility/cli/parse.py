from .common import *

from pathlib import Path
from subprocess import TimeoutExpired, run
from time import time
from typing import List, Optional


__all__ = ['run_parsers']


def run_parsers(driver: Path, base_dir: Path, lex_file_dir: Path, ast_file_dir: Path, parsers: List[str],
                timeout: Optional[int]):
    print(f"Parsing all .lex files in {lex_file_dir} and outputting ASTs to parser subdirectories in {ast_file_dir}...")
    lex_file_tups = get_sorted_files_and_lengths(lex_file_dir, '*.lex')
    max_filename_length = find_longest_filename_length(map(lambda t: t[0], lex_file_tups))
    for parser in parsers:
        output_file_path = ast_file_dir / f'{parser}-parse-output.txt'
        with open(output_file_path, 'w') as output_file:
            def write(*args, **kwargs):
                print(*args, flush=True, **kwargs)
                print(*args, file=output_file, flush=True, **kwargs)
            out_dir = ast_file_dir / parser
            out_dir.mkdir(parents=True, exist_ok=True)
            write(f"Outputting {parser} parses to {out_dir}/*.ast...")
            write(f"All output will be recorded in {output_file_path}...")
            err_file = ast_file_dir / f'{parser}-parse-errors.txt'
            err_file.write_text('')
            write(f"Names of error-producing files will be recorded in {err_file}...")
            try:
                for lex_file, tokens in lex_file_tups:
                    out_file = out_dir / lex_file.with_suffix('.ast').name
                    short_file = out_file.relative_to(base_dir)
                    relative_base_length = len(str(short_file.parent))
                    max_short_length = relative_base_length + 1 + max_filename_length + 3
                    write(f"Parsing {lex_file.name:{max_filename_length}} -> {parser} "
                          f"-> {str(short_file) + '...':{max_short_length}} ", end='')
                    t_0 = time()
                    result = run([driver, parser, lex_file], capture_output=True, timeout=timeout)
                    t_1 = time()
                    d_t = t_1 - t_0
                    if result.returncode == 0:
                        out_file.touch()
                        out_file.write_bytes(result.stdout)
                        write(f"{GREEN_CHECK} ({tokens} tok | {d_t:.4f} sec | {tokens / d_t:.4f} tok/sec)")
                    else:
                        with open(err_file, 'a') as ef:
                            ef.write(f"{short_file}\n")
                        write(RED_X)
            except TimeoutExpired:
                write(f"timed out.")
                write(f"Stopping further parsing with {parser} due to expected timeouts in remaining parses.")
            else:
                write(f"Parsing with {parser} complete.")
    print(f"Parsing done.")
