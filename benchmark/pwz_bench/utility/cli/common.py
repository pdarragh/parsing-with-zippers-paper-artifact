from operator import itemgetter
from pathlib import Path
from subprocess import run
from typing import Iterator, List, Tuple


__all__ = [
    'GREEN_CHECK', 'RED_X', 'WHITE_QUESTION', 'RED_QUESTION',
    'get_sorted_files_and_lengths', 'count_lines_in_file', 'find_longest_filename_length'
]


GREEN_CHECK = '✅'
RED_X = '❌'
WHITE_QUESTION = '❔'
RED_QUESTION = '❓'


def get_sorted_files_and_lengths(file_dir: Path, pattern='*') -> List[Tuple[Path, int]]:
    return sorted(map(lambda p: (p, count_lines_in_file(p)), file_dir.glob(pattern)), key=itemgetter(1, 0))


def count_lines_in_file(file: Path) -> int:
    if not file.is_file():
        raise RuntimeError(f"File does not exist: {file}.")
    res = run(['wc', '-l', file], capture_output=True)
    return int(res.stdout.strip().partition(b' ')[0])


def find_longest_filename_length(files: Iterator[Path], basenames_only: bool=True) -> int:
    length = 0
    for file in files:
        length = max(length, len(file.name if basenames_only else str(file)))
    return length
