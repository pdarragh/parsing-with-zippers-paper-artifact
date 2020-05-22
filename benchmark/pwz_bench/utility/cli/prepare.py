from contextlib import contextmanager
from os import chdir, getcwd
from os.path import basename, splitext
from pathlib import Path
from shutil import move as move_file
from subprocess import run
from tempfile import TemporaryDirectory


__all__ = ['extract_input_files']


IGNORE_START_PATTERNS = [
    'test/',
    'tests/',
    'turtledemo/',
    'msilib/',
    'plat-',
]
IGNORE_CONTAINS_PATTERNS = [
    '/test/',
    '/tests/',
    'test_',
    '_test',
]


@contextmanager
def temp_dir_and_return_to_orig_dir() -> str:
    orig_dir = Path('.').absolute()
    temp_dir = TemporaryDirectory()
    try:
        yield temp_dir.name
    finally:
        temp_dir.cleanup()
        chdir(orig_dir)


def extract_input_files(dest_dir: Path, tgz_file: Path, force_extract: bool = False):
    dest_dir = dest_dir.absolute()
    # Ensure the target directory is empty of .py files, or that --force-extract has been given.
    if dest_dir.is_dir() and list(dest_dir.glob('*.py')) and not force_extract:
        raise RuntimeError(f".py files found in: {dest_dir}. Remove them or use --force-extract to continue anyway.")
    # Ensure the .tgz file to extract from exists.
    if not tgz_file.exists():
        raise RuntimeError(f".tgz file does not exist: {tgz_file}")
    # Create a temporary directory, promising to return to the CWD after we're done.
    with temp_dir_and_return_to_orig_dir() as temp_dir:
        # Identify the Python-x.x.x/Lib/ directory.
        internal_lib_dir = splitext(basename(tgz_file))[0] + '/Lib/'
        # Extract the contents of the .tgz's Python-x.x.x/Lib/ directory to the temp directory.
        run(['tar', '--strip-components=2', '-xvzf', str(tgz_file), '-C', temp_dir, internal_lib_dir],
            capture_output=True)
        # Change CWD to temp directory.
        chdir(temp_dir)
        # Collect all of the .py files that do not fail the containment checks.
        # Simultaneously, determine the destination filename for these files.
        pairs = ((path, dest_dir / str(path).replace('/', '_')) for path in Path('.').glob('**/*.py')
                 if (not any(str(path).startswith(pat) for pat in IGNORE_START_PATTERNS)
                     and not any(pat in str(path) for pat in IGNORE_CONTAINS_PATTERNS)))
        # Move all of the files from the temporary directory to the destination directory.
        for orig, dest in pairs:
            move_file(orig, dest)
