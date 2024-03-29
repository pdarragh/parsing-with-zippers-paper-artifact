from .common import *
from collections import defaultdict
from csv import DictReader, DictWriter
from math import exp, isnan as is_nan, log as ln
from pathlib import Path
from typing import Dict, List


ResultsDict = Dict[str, Dict[str, float]]


def calculate_means(collated_results_file: Path, calculated_results_file: Path, parsers: List[str]):
    print(f"Calculating geometric means and outputting results in {calculated_results_file}...")
    parser_columns = {parser : f'{parser} {SPT}' for parser in parsers}
    results: ResultsDict = defaultdict(dict)
    with open(collated_results_file, mode='r', newline='') as res_csv:
        res_reader = DictReader(res_csv)
        for row in res_reader:
            filename = row[FILENAME]
            for parser in parsers:
                results[parser][filename] = float(row[parser_columns[parser]])
    geom_means: Dict[str, Dict[str, float]] = defaultdict(dict)
    for lhs_parser in parsers:
        rhs_parser_means = []
        for rhs_parser in parsers:
            if rhs_parser == lhs_parser:
                geom_mean = 1.0
            else:
                geom_mean = calculate_geometric_mean(results, lhs_parser, rhs_parser)
            geom_means[lhs_parser][rhs_parser] = geom_mean
    with open(calculated_results_file, mode='w', newline='') as out_csv:
        parser_fields = {parser : parser.replace('_', '-') for parser in parsers}
        fields = ['Parser', *parser_fields.values()]
        out_writer = DictWriter(out_csv, fields)
        out_writer.writeheader()
        for lhs_parser in parsers:
            row = {'Parser': parser_fields[lhs_parser]}
            for rhs_parser in parsers:
                row[parser_fields[rhs_parser]] = geom_means[rhs_parser][lhs_parser]
            out_writer.writerow(row)
    print(f"Calculation of means complete.")


def calculate_geometric_mean(results: ResultsDict, lhs_parser: str, rhs_parser: str) -> float:
    ratios = 0
    ratio_count = 0
    lhs_results = results[lhs_parser]
    rhs_results = results[rhs_parser]
    for filename, lhs_result in lhs_results.items():
        rhs_result = rhs_results[filename]
        if is_nan(lhs_result) or is_nan(rhs_result):
            continue
        ratio = lhs_result / rhs_result
        ratios += ln(ratio)
        ratio_count += 1
    arith_mean = ratios / ratio_count
    geom_mean = exp(arith_mean)
    return geom_mean
