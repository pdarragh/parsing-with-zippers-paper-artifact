driver := pwz_bench.py
mkfile_abs_dir := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
MKDIR_P := mkdir -p

PYTHON ?= python3

VERIFY_PARSERS ?= dypgen pwz_nary pwz_nary_look pwz_binary pwd_binary pwd_binary_opt pwd_nary pwd_nary_opt
PARSE_PARSERS ?= menhir $(VERIFY_PARSERS)
BENCH_PARSERS ?= $(PARSE_PARSERS)

TGZ_FILE ?= $(strip $(abspath $(mkfile_abs_dir)/Python-3.4.3.tgz))
GRAMMAR_FILE ?= $(mkfile_abs_dir)/pwz_bench/utility/transformed-python-3.4.grammar
START_SYMBOLS ?= single_input file_input eval_input
GEN_DIR ?= $(strip $(abspath $(mkfile_abs_dir)/gen))
GEN_MAKEFILE ?= $(GEN_DIR)/Makefile
PY_FILE_DIR ?= $(strip $(abspath $(mkfile_abs_dir)/pys))
LEX_FILE_DIR ?= $(strip $(abspath $(mkfile_abs_dir)/lexes))
AST_FILE_DIR ?= $(strip $(abspath $(mkfile_abs_dir)/parses))
BENCH_FILE_DIR ?= $(strip $(abspath $(mkfile_abs_dir)/bench))

TIMEOUT ?= -1
QUOTA_FACTOR ?= 3
MAX_QUOTA ?= 1000

start_symbol_opts := $(patsubst %,-s %, $(START_SYMBOLS))

BENCH_OUT ?= $(GEN_DIR)/pwz_bench
PARSE_OUT ?= $(GEN_DIR)/pwz_parse
export BENCH_OUT
export PARSE_OUT

################################################################################
# Top-level Targets
#
# These are meta targets that combine other targets together.

.PHONY: default all

# By default, just run the preparations and do not begin benchmarking.
default: prepare

# Delete everything, then run the preparations afresh, and then benchmark.
all: clean-all prepare benchmark

################################################################################
# Directory Creation Targets
#
# These targets just allow the easy, silent creation of needed directories.

$(PY_FILE_DIR):
	$(MKDIR_P) $@

$(LEX_FILE_DIR):
	$(MKDIR_P) $@

$(BENCH_FILE_DIR):
	$(MKDIR_P) $@

$(AST_FILE_DIR):
	$(MKDIR_P) $@

################################################################################
# Cleaning Targets
#
# These targets are just for cleaning.
# Note: They are highly destructive!

.PHONY: clean clean-all clean-light clean-generate clean-py clean-lex clean-bench clean-parse

clean: clean-light

clean-all: clean-generate clean-py clean-lex clean-parse clean-bench

clean-light:
	@echo Lightly cleaning...
	-$(MAKE) -C $(GEN_DIR) clean
	@echo Clean complete.

clean-generate:
	@echo Removing $(GEN_DIR)...
	-$(RM) -r $(GEN_DIR)
	@echo Removal complete.

clean-py:
	@echo Removing $(PY_FILE_DIR)...
	-$(RM) -r $(PY_FILE_DIR)
	@echo Removal complete.

clean-lex:
	@echo Removing $(LEX_FILE_DIR)...
	-$(RM) -r $(LEX_FILE_DIR)
	@echo Removal complete.

clean-bench:
	@echo Removing $(BENCH_FILE_DIR)...
	-$(RM) -r $(BENCH_FILE_DIR)
	@echo Removal complete.

clean-parse:
	@echo Removing $(AST_FILE_DIR)...
	-$(RM) -r $(AST_FILE_DIR)
	@echo Removal complete.

################################################################################
# Preparation Targets
#
# These targets are used in preparing everything for benchmarking. This includes
# unpacking the .py files, lexing them, running the code generator, and
# compiling the OCaml parsers.

.PHONY: prepare extract lex generate compile

prepare: extract lex generate compile

extract: $(PY_FILE_DIR)
	@echo Extracting .py files from $(TGZ_FILE) and moving them to $(PY_FILE_DIR)...
	$(PYTHON) $(driver) prepare --py-file-dir $(PY_FILE_DIR) --tgz-filename $(TGZ_FILE) --force-extract
	@echo Preparation done.

lex: $(LEX_FILE_DIR)
	if [ ! -d "$(PY_FILE_DIR)" ]; then echo "$(PY_FILE_DIR) does not exist!"; exit 1; fi
	@echo Lexing all .py files in $(PY_FILE_DIR) and outputting lexes to $(LEX_FILE_DIR)...
	$(PYTHON) $(driver) lex --py-file-dir $(PY_FILE_DIR) --lex-file-dir $(LEX_FILE_DIR)
	@echo Lexing done.

generate: $(GEN_MAKEFILE)

compile: $(BENCH_OUT) $(PARSE_OUT)

$(GEN_MAKEFILE):
	@echo Generating output files in $(GEN_DIR)...
	$(PYTHON) $(driver) generate $(GRAMMAR_FILE) $(start_symbol_opts) --output-dir $(GEN_DIR) -p all
	$(MAKE) -C $(GEN_DIR) generate
	@echo File generation complete.

$(BENCH_OUT): $(GEN_MAKEFILE)
	$(MAKE) -C $(GEN_DIR) bench

$(PARSE_OUT): $(GEN_MAKEFILE)
	$(MAKE) -C $(GEN_DIR) parse

################################################################################
# Benchmarking Target
#
# This target runs the benchmarks.
# It requires all the code to have been generated and compiled.

.PHONY: benchmark

benchmark: $(BENCH_FILE_DIR)
	if [ ! -f "$(BENCH_OUT)" ]; then echo "$(BENCH_OUT) executable does not exist! Try running `make prepare` first!"; exit 1; fi
	if [ ! -d "$(LEX_FILE_DIR)" ]; then echo "$(LEX_FILE_DIR) does not exist!"; exit 1; fi
	$(eval lex_files := $(wildcard $(LEX_FILE_DIR)/*.lex))
	$(eval parser_opts := $(patsubst %,-p %,$(BENCH_PARSERS)))
	$(PYTHON) $(driver) benchmark --quota-factor $(QUOTA_FACTOR) --resume --lex-file-dir $(LEX_FILE_DIR) --bench-file-dir $(BENCH_FILE_DIR) $(parser_opts) --max-quota $(MAX_QUOTA)

################################################################################
# Post-Processing Targets

.PHONY: post-process collate

post-process: collate

collate:
	if [ ! -d "$(BENCH_FILE_DIR)" ]; then echo "$(BENCH_FILE_DIR) does not exist!"; exit 1; fi
	$(eval parser_opts := $(patsubst %,-p %,$(BENCH_PARSERS)))
	$(PYTHON) $(driver) collate --overwrite --bench-file-dir $(BENCH_FILE_DIR) $(parser_opts)

################################################################################
# Usage-Specific Targets
#
# These targets are used for specific use-cases, such as debugging. They can
# safely be ignored most of the time.

.PHONY: parse verify compile-profile

# Run the parsers without benchmarking.
# This produces all of the parsed AST files that the `benchmark` target
# produces, but none of the extra output in $(BENCH_FILE_DIR).
parse: $(AST_FILE_DIR) build-parse
	if [ ! -d "$(LEX_FILE_DIR)" ]; then echo "$(LEX_FILE_DIR) does not exist!"; exit 1; fi
	$(eval parser_opts := $(patsubst %,-p %,$(PARSE_PARSERS)))
	$(PYTHON) $(driver) parse --lex-file-dir $(LEX_FILE_DIR) --ast-file-dir $(AST_FILE_DIR) $(parser_opts) --timeout $(TIMEOUT)

# Verify that all the parses are consistent.
# This uses Menhir as the ground truth parsers and compares all the other parse
# results to it. `verify` is only useful after running `parse` (or `benchmark`)
# so that there are parse results to compare.
verify:
	if [ ! -d "$(AST_FILE_DIR)" ]; then echo "$(AST_FILE_DIR) does not exist!"; exit 1; fi
	$(eval parser_opts := $(patsubst %,-p %,$(VERIFY_PARSERS)))
	$(PYTHON) $(driver) verify --ast-file-dir $(AST_FILE_DIR) $(parser_opts)

# Compile the generated code with profiling options.
# This is necessary to run the code with instrumentation. It it useful for
# debugging, but otherwise should not be used.
compile-profile: $(GEN_MAKEFILE)
	$(MAKE) -C $(GEN_DIR) profile
