from .common import *
from collections import defaultdict
from csv import DictReader, DictWriter
from pathlib import Path
from re import compile as re_compile
from typing import Dict, List, Optional


__all__ = ['collate_benchmarking_results']


# Default name of the output file.
DEFAULT_OUT_FILENAME = 'collated-results.csv'
# Regular expressions.
EXTRACT_TPR_RE = re_compile(r'([\d_]+(?:\.\d+)?)\D+')
TPR_BIGDIG_RE = re_compile(r'(\d+)\.0+')
TPR_SIGFIG_RE = re_compile(r'(\d+\.0*[1-9]\d{2})\d*')


def collate_benchmarking_results(bench_file_dir: Path, parsers: List[str], overwrite: bool = False,
                                 out_file: Optional[Path] = None):
    if out_file is None:
        out_file = bench_file_dir / DEFAULT_OUT_FILENAME
    print(f"Collating benchmarking results and outputting results in {out_file}...")
    if out_file.is_file():
        if not overwrite:
            raise RuntimeError(f"Output file {out_file} already exists. Aborting!")
    tprs: Dict[str, Dict[str, float]] = defaultdict(dict)
    toks: Dict[str, int] = {}
    missing_parsers = set()
    for parser in parsers:
        res_file = bench_file_dir / f'{parser}-bench-results.csv'
        if not res_file.is_file():
            print(f"No results found for parser {parser} at {res_file}. Skipping.")
            missing_parsers.add(parser)
            continue
        with open(res_file, mode='r', newline='') as res_csv:
            res_reader = DictReader(res_csv)
            for row in res_reader:
                filename = Path(row[FILENAME]).with_suffix('.lex').name
                if filename not in toks:
                    toks[filename] = int(row[TOKENS])
                tpr = float_of_raw_tpr(row[TPR])
                tprs[filename][parser] = tpr
    # Remove parsers which had no results files.
    parsers = [parser for parser in parsers if parser not in missing_parsers]
    with open(out_file, mode='w', newline='') as out_csv:
        parser_fields = {parser: f'{parser} {SPT}' for parser in parsers}
        fields = [FILENAME, TOKENS, *parser_fields.values()]
        out_writer = DictWriter(out_csv, fields)
        out_writer.writeheader()
        for filename, no_tokens in sorted(toks.items(), key=lambda t: (t[1], t[0])):
            row = {FILENAME: filename, TOKENS: no_tokens}
            for parser in parsers:
                row[parser_fields[parser]] = compute_spt(tprs[filename].get(parser, None), toks[filename])
            out_writer.writerow(row)
    print(f"Benchmarking collation complete.")


def float_of_raw_tpr(tpr: str) -> Optional[float]:
    if not tpr:
        # There was no data for this benchmark, indicating that the execution timed out.
        return None
    m = EXTRACT_TPR_RE.match(tpr)
    if m is None:
        raise RuntimeError(f"Could not parse {TPR} value: {tpr}.")
    return float(m.group(1))


def compute_spt(tpr: Optional[float], tokens: int) -> str:
    if tpr is None:
        return 'nan'  # We use pgfplot for plotting graphs, which will ignore 'nan' values.
    # Time/Run is assumed to be in nanoseconds.
    s2ns = 1_000_000_000
    nspt = tpr / tokens
    spt = nspt / s2ns
    result = f'{spt:.12f}'
    # Preserve only three significant digits after the decimal.
    m = TPR_BIGDIG_RE.fullmatch(result)
    if m is not None:
        return f'{m.group(1)}.000'
    m = TPR_SIGFIG_RE.fullmatch(result)
    if m is not None:
        return f'{m.group(1)}'
    raise RuntimeError(f"Unable to compute s/tok for TPR value: {tpr}.")



"""
import math
import pandas as pd
import matplotlib.pyplot as plt
resfile = 'bench/all-bench-results.csv'
df = pd.read_csv(resfile, float_precision='high')
max_val = max(df.max()[2:])
min_val = min(df.min()[2:])
def get_scale(v):
    return math.pow(10, round(math.log10(v)))

max_scale = get_scale(max_val)
min_scale = get_scale(min_val)
scale = (min_scale, max_scale)




df.plot.scatter(1, 4, logy=True, ylim=(10e-8, 10e-4))
plt.draw()
plt.show()

"""
