from .common import *

from csv import DictReader, DictWriter
from dataclasses import dataclass, field
from math import ceil as round_up
from pathlib import Path
from re import finditer, match
from subprocess import TimeoutExpired, run
from typing import Any, Dict, Generator, Iterable, Iterator, List, Match, Optional, Tuple

import heapq


__all__ = ['run_benchmarks']


FILENAME = 'Filename'
TOKENS = 'Tokens'
QUOTA = 'Quota'
TPR = 'Time/Run'
CONF = '95ci'

FIELDS = [FILENAME, TOKENS, QUOTA, TPR, CONF]

INITIAL_QUOTA = 1
TIMEOUT_MULTIPLIER = 1.2
MAX_BUFFER_DEPTH = 5


class InsufficientQuota(Exception):
    pass


@dataclass(order=True)
class Execution:
    path: Path = field(compare=False)
    quota: int
    secondary_order: int


class ExecutionHeap(Iterable[Execution]):
    def __init__(self):
        self._heap = []
        self._iter = 0

    def __len__(self) -> int:
        return len(self._heap)

    def __bool__(self) -> bool:
        return bool(self._heap)

    def __iter__(self) -> Iterator[Execution]:
        self._iter = 0
        return self

    def __next__(self) -> Execution:
        if self._iter >= len(self):
            raise StopIteration()
        execution = self._heap[self._iter]
        self._iter += 1
        return execution

    def tuples(self) -> Iterable[Tuple[Path, int, int]]:
        for execution in self:
            yield execution.path, execution.quota, execution.secondary_order

    def push_parts(self, p: Path, q: int, so: int):
        heapq.heappush(self._heap, Execution(p, q, so))

    def push(self, execution: Execution):
        heapq.heappush(self._heap, execution)

    def pop(self) -> Optional[Execution]:
        if self:
            return heapq.heappop(self._heap)
        else:
            return None

    def peek(self) -> Optional[Execution]:
        if self:
            return self._heap[0]
        else:
            return None


def run_benchmarks(driver: Path, base_dir: Path, lex_file_dir: Path, bench_file_dir: Path, parsers: List[str],
                   should_resume: bool = False, quota_factor: int = 3, max_quota: Optional[int] = None):
    print(f"Benchmarking all .lex files in {lex_file_dir}...")
    lex_file_tups = get_sorted_files_and_lengths(lex_file_dir, '*.lex')
    max_filename_length = find_longest_filename_length(map(lambda t: t[0], lex_file_tups))
    lex_file_lengths = {lex_file: no_tokens for (lex_file, no_tokens) in lex_file_tups}

    heap = ExecutionHeap()

    for parser in parsers:
        out_file = bench_file_dir / f'{parser}-bench-output.txt'
        err_file = bench_file_dir / f'{parser}-bench-errors.txt'
        res_file = bench_file_dir / f'{parser}-bench-results.csv'
        dest_dir = bench_file_dir / parser
        max_short_length = len(str(dest_dir)) + 1 + max_filename_length

        # Ensure the destination directory exists.
        dest_dir.mkdir(parents=True, exist_ok=True)

        # We can't resume if there are no results, so don't even try.
        if not res_file.is_file():
            should_resume = False

        if not should_resume:
            out_file.write_text('')
            err_file.write_text('')
            res_file.write_text('')
            with open(res_file, mode='w', newline='') as res_csv:
                res_writer = DictWriter(res_csv, FIELDS)
                res_writer.writeheader()

        with open(out_file, 'a') as of, open(err_file, 'a') as ef, open(res_file, 'a') as res_csv:
            res_writer = DictWriter(res_csv, FIELDS)

            def write_out(*args, **kwargs):
                print(*args, flush=True, **kwargs)
                print(*args, file=of, **kwargs)

            def write_err(filename: Path, err_msg: Any):
                ef.write(f"{str(filename):{max_short_length}} -> "
                         + err_msg if isinstance(err_msg, str) else '???'
                         + '\n')

            def write_res(row: Dict[str, Any]):
                res_writer.writerow(row)

            def write_dest(dest_file: Path, text: str):
                dest_file.touch()
                dest_file.write_text(text)

            write_out(f"Outputting {parser} benchmark outputs to {dest_dir}/*.bench...")
            write_out(f"Names of error-producing files will be recorded in {err_file}...")
            if should_resume:
                write_out(f"Resuming from previous progress saved in {res_file}...")
                write_out(f"New results will be appended to {res_file}...")
            else:
                write_out(f"Saving results for each input to {res_file}...")

            # Initialize a buffer to be used for managing consecutive incomplete benchmarks.
            buffer = ExecutionHeap()

            def flush_buffer_to_queue(multiply_quota: Optional[float] = None):
                while buffer:
                    # Requeue the buffered executions, but give them an extra second.
                    execution = buffer.pop()
                    if multiply_quota is None:
                        execution.quota = execution.quota + 1
                    else:
                        execution.quota = round_up(execution.quota * multiply_quota)
                    heap.push(execution)

            def process_queue(max_buffer_size: int):
                # Process queue until empty.
                while heap:
                    execution = heap.pop()
                    lex_file = execution.path
                    quota = execution.quota
                    dest_file = dest_dir / lex_file.with_suffix('.bench').name
                    short_file = dest_file.relative_to(base_dir)
                    # Check if the quota has been exceeded. If it has, remove this execution from the heap, and record
                    # blank values in the output.
                    if max_quota is not None and quota > max_quota:
                        write_out(f"Execution {lex_file.name} exceeds maximum allowable quota. Removing it from the "
                                  f"heap and recording -1 values in {res_file}..")
                        row_dict = {
                            FILENAME: short_file,
                            TOKENS: lex_file_lengths[lex_file],
                            QUOTA: quota,
                            TPR: '',
                            CONF: '',
                        }
                        write_res(row_dict)
                        continue
                    timeout = round_up(quota * TIMEOUT_MULTIPLIER)
                    write_out(f"Benchmarking {lex_file.name:{max_filename_length}} -> {parser} -> quota: {quota} -> "
                              f"timeout: {timeout} -> {str(short_file) + '...':{max_short_length}} ", end='')

                    try:
                        result = run([driver, '+time', '-ascii', '-stabilize-gc', '-width', '1000',
                                      '-parser', parser,
                                      '-input', lex_file,
                                      '-quota', str(quota)],
                                     capture_output=True, timeout=timeout)
                        if result.returncode == 0:
                            output = result.stdout.decode('utf-8')
                            try:
                                # Move incomplete results back onto the queue, since they may have a chance to complete.
                                tpr, ci = extract_fields_from_output(output, (TPR, CONF))
                                tpr = parse_time_per_run_in_ns(tpr)
                                # The floating-point math can cause imprecision, so round to compensate.
                                tpr = f'{round(tpr):_.2f}ns'
                                write_dest(dest_file, output)
                                row_dict = {
                                    FILENAME: short_file,
                                    TOKENS: lex_file_lengths[lex_file],
                                    QUOTA: quota,
                                    TPR: tpr,
                                    CONF: ci,
                                }
                                write_res(row_dict)
                                write_out(f"{GREEN_CHECK} ({TPR}: {tpr} | {CONF}: {ci})")
                                flush_buffer_to_queue(multiply_quota=1.1)
                            except InsufficientQuota:
                                write_out(WHITE_QUESTION)
                                buffer.push(execution)
                            except Exception as e:
                                write_dest(dest_file, output)
                                write_err(short_file, e.args[0] if len(e.args) > 0 else None)
                                write_out(RED_X)
                        else:
                            write_err(short_file, "Non-zero return code.")
                            write_out(RED_X)
                    except TimeoutExpired:
                        write_out(RED_QUESTION)
                        buffer.push(execution)

                    # Test whether we need to empty the buffer and requeue all remaining executions.
                    if buffer and len(buffer) >= max_buffer_size:
                        write_out(f"Buffer filled. Moving remaining executions to next quota...")
                        # Identify the maximum quota among the incomplete executions in the buffer.
                        min_buffer_quota = float('inf')
                        for execution in buffer:
                            min_buffer_quota = min(min_buffer_quota, execution.quota)
                        # Set the new quota.
                        next_quota = min_buffer_quota * quota_factor
                        if heap:
                            min_heap_quota = heap.peek().quota
                        else:
                            min_heap_quota = min_buffer_quota
                        # Migrate all buffered executions to the main queue.
                        while buffer:
                            execution = buffer.pop()
                            heap.push(execution)
                        # Requeue the existing executions in the main queue, changing their quota only if it's less than
                        # or equal to the smallest quota in the heap. This maintains already-adjusted quotas.
                        while heap.peek().quota <= min_heap_quota:
                            execution = heap.pop()
                            if execution.quota <= min_heap_quota:
                                execution.quota = next_quota
                            heap.push(execution)

            # Initialize the queue.
            for i, (path, quota) in enumerate(worklist_generator(lex_file_dir, lex_file_tups, res_file, should_resume)):
                heap.push_parts(path, quota, i)

            # Process until the queue is empty.
            process_queue(MAX_BUFFER_DEPTH)

            # Run anything remaining in the buffer, and disable further use of the buffer.
            if buffer:
                flush_buffer_to_queue()
                process_queue(max_buffer_size=0)

            write_out(f"Benchmarking for {parser} complete.")
    print(f"Benchmarking done.")


def worklist_generator(lex_file_dir: Path, lex_file_tups: List[Tuple[Path, int]], res_file: Path,
                       should_resume: bool) -> Generator[Tuple[Path, int], None, None]:
    longest_quota = INITIAL_QUOTA
    if not should_resume:
        for lex_file, _ in lex_file_tups:
            yield lex_file, longest_quota
        return
    benchmarked_lex_files = set()
    with open(res_file, mode='r', newline='') as res_csv:
        res_reader = DictReader(res_csv)
        for row in res_reader:
            bench_file = Path(row[FILENAME])
            lex_file = lex_file_dir / bench_file.with_suffix('.lex').name
            benchmarked_lex_files.add(lex_file)
            quota = int(row[QUOTA])
            longest_quota = max(longest_quota, quota)
    for lex_file, _ in lex_file_tups:
        if lex_file in benchmarked_lex_files:
            continue
        yield lex_file, longest_quota


def extract_fields_from_output(output: str, fields: Iterable[str]) -> Tuple[str, ...]:
    values = extract_all_values_from_output(output)
    return tuple((values[field] if field in values else '') for field in fields)


def extract_all_values_from_output(output: str) -> Dict[str, str]:
    lines = output.split('\n')
    # Identify where the data table starts, if there is one.
    data_start = None
    for i, line in enumerate(lines):
        if line.strip().startswith('Name'):
            data_start = i
            break
    if data_start is None:
        raise RuntimeError(f"Unexpected benchmarking output.")
    data = lines[data_start:data_start+3]  # The data table is exactly three lines.
    # When the benchmarks run correctly but do not produce enough non-zero results, the last line of the table is blank.
    # This means a longer quota is needed to produce satisfactory benchmark results.
    if data[-1].strip() == "":
        raise InsufficientQuota()
    # The data table is shaped like this:
    #
    #   Name                     Time R^2   Time/Run            95ci   mWd/Run   mjWd/Run   Prom/Run   Percentage
    #  ------------------------ ---------- ---------- --------------- --------- ---------- ---------- ------------
    #   parser:file.lex:tokens       1.00    12.34ms   -1.23% +2.45%    1.23Mw   123.45kw   123.45kw      100.00%
    #
    # We determine the columns by the second line (the dashes), and use those to pull and strip the names and values.
    columns: List[Tuple[int, int]] = [(column.start(), column.end()) for column in finditer(r'-+', data[1])]
    values: Dict[str, str] = {data[0][s:e].strip(): data[2][s:e].strip() for (s, e) in columns}
    return values


def parse_time_per_run_in_ns(time_per_run: str) -> float:
    # The time per run value is shortened because of using the `-ascii` option. Instead of always being in nanoseconds,
    # it's given in an adjusted form for fewer digits. Let's convert to nanoseconds.
    us2ns = 1_000
    ms2ns = 1_000_000
    s2ns = 1_000_000_000

    def match_suffix(suffix: str) -> Match:
        return match(fr'(\d+(\.\d+)?)({suffix})', time_per_run)

    m = match_suffix('ns')
    if m:
        # Do nothing; we want our results in nanoseconds.
        return float(m.group(1))
    else:
        m = match_suffix('us')
        if m:
            return float(m.group(1)) * us2ns
        else:
            m = match_suffix('ms')
            if m:
                return float(m.group(1)) * ms2ns
            else:
                m = match_suffix('s')
                if m:
                    return float(m.group(1)) * s2ns
                else:
                    m = match_suffix('.*')
                    if not m:
                        raise RuntimeError(f"Time/Run did not return numeric value; got: {time_per_run}.")
                    raise RuntimeError(f"Unexpected time suffix for Time/Run: {m.group(2)}")
