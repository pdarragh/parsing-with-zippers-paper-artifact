from .grammar_description import *

from abc import ABC
from dataclasses import dataclass
from os import makedirs
from pathlib import Path
from shutil import copyfile
from typing import Callable, List


__all__ = ['GeneratorFunc', 'FileGenerator', 'DynamicFileGenerator', 'StaticFileGenerator']


GeneratorFunc = Callable[[GrammarDescription], List[str]]


@dataclass
class FileGenerator(ABC):
    @staticmethod
    def make_destination_dir_for_file(path: Path):
        makedirs(path.parent, exist_ok=True)


@dataclass
class DynamicFileGenerator(FileGenerator):
    func: GeneratorFunc
    filename: str

    def generate(self, to_dir: Path, grammar_desc: GrammarDescription):
        destination_file = to_dir / self.filename
        self.make_destination_dir_for_file(destination_file)
        destination_file.write_text('\n'.join(self.func(grammar_desc)))


@dataclass
class StaticFileGenerator(FileGenerator):
    filename: str

    def generate(self, from_dir: Path, to_dir: Path):
        origin_file = from_dir / self.filename
        destination_file = to_dir / self.filename
        self.make_destination_dir_for_file(destination_file)
        # PyCharm doesn't like that I'm putting Paths here instead of PathLikes... which is silly.
        # noinspection PyTypeChecker
        copyfile(origin_file, destination_file)
