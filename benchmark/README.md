# Benchmarking Parsing with Zippers

This directory contains a copy of the code used to benchmark Parsing with
Zippers, the results of which appear in the associated paper.

## Requirements

There are two branches of dependencies in this project:

1. The Python code used for tokenization.
2. The OCaml code used for parsing and benchmarking.

### System Requirements

- [m4]
  - `apt install m4`

### Python Requirements

The Python components of this project were written in Python 3.7.3. The following external dependencies are needed, but
their use is explained below:

- [Parso](https://parso.readthedocs.io/en/latest/) (`parso`), v 0.4.0
  - Parso provides a better tokenization experience than the standard library's `tokenize` module, specifically because
    it supports tokenizing code written in version of Python other than the installed version.
  - `pip install parso`

### OCaml Requirements

We used OCaml 4.05.0 for all code written here. The following external dependencies are needed:

`opam switch install 4.05.0`
`opam install core core_bench menhir dypgen`

- [Core](https://ocaml.janestreet.com/ocaml-core/latest/doc/core/index.html) (`core`), v 0.11.3
  - Core is an improved standard library for OCaml, managed by Jane Street. We mostly use this for managing command-line
    options and association lists.
- [Menhir], v ...
  - blah
- [Dypgen], v ...
  - blah
- [core], v ...
- [core_bench], v ...

## Running

All builds and processing can be performed using the top-level `Makefile`. Targets and command-line parameters are
explained further below, but a brief overview is given here.

The default parameter values should be sufficient, and all our tests were run with these values. Assuming you have moved
your base `.py` files into your `$PY_FILE_DIR` (`./lexes/` by default):

```
$ make all
$ make benchmark
```

This will lex all the `.py` files into `.lex` files, generate the necessary source code for the parser generators and
driver programs, and compile the executables (`make all`), then it will perform all benchmarking (`make benchmark`).
Note that benchmarking is a time-consuming process.

If you want to skip the lexing portion, simply replace `make all` with `make default` (or just `make`, as `default` is
the default target).

### Targets

The following targets are supported from the root directory, used as `make <target>`. Parameters are explained in the
next section. Lowercase parameter names here indicate targets which are depended upon by the current target, indicating
that the current target uses all the parameters of the depended-upon target as well.

| Target Name   | Summary                                                                                                   | Parameters Used                                           |
|---------------|-----------------------------------------------------------------------------------------------------------|-----------------------------------------------------------|
| `default`     | Runs `clean`, `generate`, and `build`.                                                                    | `clean`, `generate`, `build`                              |
| `all`         | Runs `clean`, `clean-lex` , `lex`, `generate`, and `build`.                                               | `clean`, `clean-lex`, `lex`, `generate`, `build`          |
| `clean`       | Deletes the contents of `$OUT_DIR`.                                                                       | `$OUT_DIR`                                                |
| `clean-lex`   | Deletes the contents of `$LEX_FILE_DIR`.                                                                  | `$LEX_FILE_DIR`                                           |
| `clean-parse` | Deletes the contents of `$AST_FILE_DIR`.                                                                  | `$AST_FILE_DIR`                                           |
| `clean-all`   | Runs `clean`, `clean-lex`, and `clean-parse`.                                                             | `clean`, `clean-lex`, `clean-parse`                       |
| `generate`    | Generates all the files needed for compiling the executables. Code will be placed in `$OUT_DIR`.          | `$OUT_DIR`, `$PYTHON`, `$GRAMMAR`.                        |
| `build`       | Compiles the executables, `$BENCH_OUT` (for benchmarking) and `$PARSE_OUT` (for parsing).                 | `$BENCH_OUT`, `$PARSE_OUT`, `generate`                    |
| `lex`         | Lexes all `.py` files found in `$PY_FILE_DIR` and outputs the results to `$LEX_FILE_DIR` for later use.   | `$PY_FILE_DIR`, `$LEX_FILE_DIR`, `PYTHON`                 |
| `benchmark`   | Runs benchmarks over all `.lex` files found in `$LEX_FILE_DIR`.                                           | `$LEX_FILE_DIR`, `$BENCH_OUT`, `build`                    |
| `parse`       | Parses all `.lex` files found in `$LEX_FILE_DIR` into `.ast` files placed in `$AST_FILE_DIR`.             | `$LEX_FILE_DIR`, `$AST_FILE_DIR`, `$PARSE_OUT`, `build`   |
| `verify`      | Verifies all existing `.ast` files against the Menhir baseline.                                           | `$AST_FILE_DIR`                                           |

### Parameters

Parameters can be given in the usual Makefile fashion (i.e., `PARAM=value make <target>`). Each supported parameter is
explained below, along with a summary of the default value. Note that all parameters have default values, so you do not
need to specify any parameters to run the targets. Relative paths are given relative to the root directory of this
repository (which should be where this README is located).

| Parameter Name    | Summary                                               | Default Value                                         |
|-------------------|-------------------------------------------------------|-------------------------------------------------------|
| `PYTHON`          | Path to Python 3.7+ executable.                       | `python3`                                             |
| `GRAMMAR`         | Path to Python grammar used for parser generation.    | `./pwz_bench/utility/transformed-python-3.4.grammar`  |
| `OUT_DIR`         | Directory to output all generated code.               | `./out/`                                              |
| `LEX_FILE_DIR`    | Directory where `.lex` files are/should be located.   | `./lexes/`                                            |
| `PY_FILE_DIR`     | Directory where base `.py` files are located.         | `$LEX_FILE_DIR`                                       |
| `AST_FILE_DIR`    | Directory where `.ast` output files should be saved.  | `./parses/`                                           |
| `BENCH_OUT`       | Name of the benchmarking executable.                  | `$OUT_DIR/pwz_bench`                                  |
| `PARSE_OUT`       | Name of the parsing executable.                       | `$OUT_DIR/pwz_parse`                                  |

#TODO: update these!

## Parsing

Although not necessary for running benchmarks, the resulting ASTs of each parse can be output to file. This was
primarily developed for debugging, but can be used to inspect parse results manually.

Assuming you have `.lex` files in `$LEX_FILE_DIR` (which can be achieved by running `make lex` or `make all`; see
above), you can produce `.ast` parse results in the `$AST_FILE_DIR` directory by running:

```
$ make parse
```

Successful parses (i.e., parses which do not produce a shell error) are denoted with ✅, and errors encountered (such as
those due to faulty `.lex` inputs) are marked with ❌. Errors for each parser `$parser` will also be logged to file in
`$AST_FILE_DIR/$parser-parse-errors.txt.

The output of each (successful) parse is a `.ast` file containing an OCaml AST of the resulting parse, formatted as a
single line to reduce overhead caused by whitespace. For a given `.lex` file `$LEX_FILE_DIR/$filename.lex`, parser
`$parser` will output its corresponding `.ast` file to `$AST_FILE_DIR/$parser/$filename.lex.ast`.

### Verification

To spare your undergraduate research assistants from the need to manually sift through the resulting data and compare
the outputs, we have also included a verification target in the Makefile:

```
$ make verify
```

This uses Menhir's outputs as a ground truth. We believe this is most reasonable, as Menhir is the most community-tested
parser tested in this suite, so we assume it is most likely to be correct if there were any discrepancy. All other
parsers' outputs are therefore compared to Menhir's. Successful comparisons are shown with ✅, while failed comparisons
will show ❌. Failed comparisons will also log the failing files' names to `$AST_FILE_DIR/$parser-verify-errors.txt`.
