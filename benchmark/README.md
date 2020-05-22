# Benchmarking Parsing with Zippers

This directory contains a copy of the code used to benchmark Parsing with
Zippers, the results of which appear in the associated paper.

The short version of this is: install the language runtimes and library
dependencies as outline

## Requirements

There are two branches of dependencies in this project:

1. The Python code used for tokenization and general scripting.
2. The OCaml code used for parsing and benchmarking.

### Python Requirements

To install Python 3.7.3 specifically, we recommend installing from source
according to the instructions on the Python language website. However, this code
should work with any 3.7.x version of Python where x is greater than 3, so it is
likely that simply using your package manager to install `python-3.7` will be
sufficient. Note that we use `pip3` for installing additional dependencies, but
there are alternative methods if you prefer to go that route.

The only non-standard package used directly is `parso`, which can be installed
by doing `pip3 install parso==0.4.0`. Parso provides a better tokenization
experience than the standard library's `tokenize` module, specifically because
it supports tokenizing code written in versions of Python other than the
installed version.

### OCaml Requirements

To install OCaml 4.05.0, first install Opam using your package manger (e.g.,
`apt install opam`). Then, use Opam to install the correct version by doing
`opam switch create pwz ocaml-system.4.05.0`.

In addition, the following external dependencies are needed. They can all be
installed by performing `opam install core core_bench menhir dypgen`.

- [Core](https://ocaml.janestreet.com/ocaml-core/latest/doc/core/index.html),
  v 0.11.3
    - Core is an improved standard library for OCaml, managed by Jane Street. We
      mostly use this for managing command-line options and association lists.
- [Core_bench](https://ocaml.janestreet.com/ocaml-core/latest/doc/core_bench/Core_bench/index.html),
  v 0.11.0
    - A micro-benchmarking library for OCaml, managed by Jane Street. This is
      used for all benchmarking.
- [Menhir](http://gallium.inria.fr/~fpottier/menhir/), v 20200211
    - LR(1) parser generator for OCaml. We use this to compare performance.
- [Dypgen](http://dypgen.free.fr), v 20120619-1
    - GLR parser generator for OCaml. We use this to compare performance.

## Running

All builds and processing can be performed using the top-level `Makefile`.
Targets and command-line parameters are explained further below, but a brief
overview is given here.

To generate and compile the various parsers, do:

```
$ make all
```

This will extract the suggested `.py` files from the 3.4.3 Python source code,
lex the resultilng files, generate the compiler code, and build the project.
This will not run the benchmarks yet.

To run the benchmark suite, do:

```
$ make benchmark
```

Note that this is a **long** process. Benchmarking on a dedicated cloud computer
took nearly a full day. The `TIMEOUT` parameter can be adjusted according to the
options detailed below if you wish to run a smaller sample benchmark.

The benchmark process is smart, however. You can cancel the running benchmarks
(by the typical `CTRL+c` / `<C-c>`) and later resume the benchmarks (via `make
benchmark`) and it will pick up right where you left off.

### Targets

The following targets are supported from the root directory, used as `make
<target>`. Parameters are explained in the next section. Lowercase parameter
names here indicate targets which are depended upon by the current target,
indicating that the current target uses all the parameters of the depended-upon
target as well.

| Target Name      | Summary                                                                                                 | Parameters Used                                         |
|------------------|---------------------------------------------------------------------------------------------------------|---------------------------------------------------------|
| `default`        | Runs `clean-light`, `generate`, and `build`.                                                            | `clean`, `generate`, `build`                            |
| `all`            | Runs `clean-all`, `prepare`, `lex`, `generate`, and `build`.                                            | `clean`, `clean-lex`, `lex`, `generate`, `build`        |
| `clean-light`    | Runs the `clean` target in `$OUT_DIR/Makefile`.                                                         | `$OUT_DIR`                                              |
| `clean-generate` | Deletes `$OUT_DIR`.                                                                                     |                                                         |
| `clean-py`       | Deletes `$PY_FILE_DIR`.                                                                                 | `$PY_FILE_DIR`                                          |
| `clean-lex`      | Deletes `$LEX_FILE_DIR`.                                                                                | `$LEX_FILE_DIR`                                         |
| `clean-parse`    | Deletes `$AST_FILE_DIR`.                                                                                | `$AST_FILE_DIR`                                         |
| `clean-bench`    | Deletes `$BENCH_FILE_DIR`.                                                                              | `$BENCH_FILE_DIR`                                       |
| `clean-all`      | Runs `clean-generate`, `clean-py`, `clean-lex`, `clean-parse`, and `clean-bench`.                       | `clean`, `clean-lex`, `clean-parse`                     |
| `generate`       | Generates all the files needed for compiling the executables. Code will be placed in `$OUT_DIR`.        | `$OUT_DIR`, `$PYTHON`, `$GRAMMAR_FILE`.                 |
| `build`          | Compiles the executables, `$BENCH_OUT` (for benchmarking) and `$PARSE_OUT` (for parsing).               | `$BENCH_OUT`, `$PARSE_OUT`, `generate`                  |
| `prepare`        | Extracts the necessary files from the Python source code tarball into `$PY_FILE_DIR`.                   | `$TGZ_FILE`, `$PY_FILE_DIR`                             |
| `lex`            | Lexes all `.py` files found in `$PY_FILE_DIR` and outputs the results to `$LEX_FILE_DIR` for later use. | `$PY_FILE_DIR`, `$LEX_FILE_DIR`, `PYTHON`               |
| `benchmark`      | Runs benchmarks over all `.lex` files found in `$LEX_FILE_DIR`.                                         | `$LEX_FILE_DIR`, `$BENCH_OUT`, `build`                  |
| `parse`          | Parses all `.lex` files found in `$LEX_FILE_DIR` into `.ast` files placed in `$AST_FILE_DIR`.           | `$LEX_FILE_DIR`, `$AST_FILE_DIR`, `$PARSE_OUT`, `build` |
| `verify`         | Verifies all existing `.ast` files against the Menhir baseline.                                         | `$AST_FILE_DIR`                                         |

### Parameters

Parameters can be given in the usual Makefile fashion (i.e., `PARAM=value make
<target>`). Each supported parameter is explained below, along with a summary of
the default value. Note that all parameters have default values, so you do not
need to specify any parameters to run the targets. Relative paths are given
relative to the root directory of this repository (which should be where this
README is located).

| Parameter Name   | Summary                                                               | Default Value                                        |
|------------------|-----------------------------------------------------------------------|------------------------------------------------------|
| `PYTHON`         | Path to Python 3.7+ executable.                                       | `python3`                                            |
| `TGZ_FILE`       | Path to the Python source code tarball.                               | `./Python-3.4.3.tgz`                                 |
| `GRAMMAR_FILE`   | Path to Python grammar used for parser generation.                    | `./pwz_bench/utility/transformed-python-3.4.grammar` |
| `START_SYMBOLS`  | Space-separated list of start symbols in `$GRAMMAR_FILE`.             | `single_input file_input eval_input`                 |
| `OUT_DIR`        | Directory to output all generated code.                               | `./out/`                                             |
| `PY_FILE_DIR`    | Directory where base `.py` files are located.                         | `./pys/`                                             |
| `LEX_FILE_DIR`   | Directory where `.lex` files are/should be located.                   | `./lexes/`                                           |
| `AST_FILE_DIR`   | Directory where `.ast` output files should be saved.                  | `./parses/`                                          |
| `BENCH_FILE_DIR` | Directory where benchmarking `.bench` files should be saved.          | `./bench/`                                           |
| `BENCH_OUT`      | Name of the benchmarking executable.                                  | `$OUT_DIR/pwz_bench`                                 |
| `PARSE_OUT`      | Name of the parsing executable.                                       | `$OUT_DIR/pwz_parse`                                 |
| `TIMEOUT`        | Maximum length of timeout during benchmarking in seconds.             | -1 (no maximum timeout)                              |
| `QUOTA_FACTOR`   | The factor by which to increase the quota during subsequent runs.     | 3                                                    |
| `MAX_QUOTA`      | The maximum allowable quota value. Benchmarks that go over this fail. | 1000                                                 |
| `VERIFY_PARSERS` | Space-separated list of parsers to run for `verify` target.           | (every parser except Menhir)                         |
| `PARSE_PARSERS`  | Space-separated list of parsers to run for `parse` target.            | `menhir $(VERIFY_PARSERS)`                           |
| `BENCH_PARSERS`  | Space-separated list of parsers to run for `bench` target.            | `$PARSE_PARSERS`                                     |

The list of supported parsers (for use with the `xxx_PARSERS` parameters) is:

  * `menhir`
  * `dypgen`
  * `pwz_nary`
  * `pwz_nary_look`
  * `pwz_nary_mem`
  * `pwz_binary`
  * `pwd_binary`
  * `pwd_binary_opt`
  * `pwd_nary`
  * `pwd_nary_opt`

### Included Files

We bundle version 3.4.3 of the Python standard library. This was the version of
Python used when this project originally started, and all benchmarks in the
paper were made using this version. More recent versions *should* work, but this
is the one we tested. To attempt the process with a different version, we
suggest downloading the `.tgz` file of the desired version of Python from the
Python language website, placing it in this directory, and using the `TGZ_FILE`
variable during the `make` process.

We also include a transformed version of the Python 3.4 grammar specification in
the file `./pwz_bench/utility/transformed-python-3.4.grammar`. The Python
grammar specification as-given is heavily left-recursive, which is problematic
for some parsers in this suite (such as Menhir, which is LR(1)). We manually
transformed this grammar specification to be non-left-recursive.

## Parsing

Although not necessary for running benchmarks, the resulting ASTs of each parse
can be output to file. This was primarily developed for debugging, but can be
used to inspect parse results manually.

Assuming you have `.lex` files in `$LEX_FILE_DIR` (which can be achieved by
running `make lex` or `make all`; see above), you can produce `.ast` parse
results in the `$AST_FILE_DIR` directory by running:

```
$ make parse
```

Successful parses (i.e., parses which do not produce a shell error) are denoted
with ✅, and errors encountered (such as those due to faulty `.lex` inputs) are
marked with ❌. Errors for each parser `$parser` will also be logged to file in
`$AST_FILE_DIR/$parser-parse-errors.txt.

The output of each (successful) parse is a `.ast` file containing an OCaml AST
of the resulting parse, formatted as a single line to reduce overhead caused by
whitespace. For a given `.lex` file `$LEX_FILE_DIR/$filename.lex`, parser
`$parser` will output its corresponding `.ast` file to
`$AST_FILE_DIR/$parser/$filename.lex.ast`.

### Verification

To spare you and your research assistants from the need to manually sift through
the resulting data and compare the outputs, we have also included a verification
target in the Makefile:

```
$ make verify
```

This uses Menhir's outputs as a ground truth. We believe this is most
reasonable, as Menhir is the most community-tested parser tested in this suite,
so we assume it is most likely to be correct if there were any discrepancy. All
other parsers' outputs are therefore compared to Menhir's. Successful
comparisons are shown with ✅, while failed comparisons will show ❌. Failed
comparisons will also log the failing files' names to
`$AST_FILE_DIR/$parser-verify-errors.txt`.
