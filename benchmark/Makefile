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
GEN_FILE_DIR ?= $(strip $(abspath $(mkfile_abs_dir)/gen))
GEN_MAKEFILE ?= $(GEN_FILE_DIR)/Makefile
PY_FILE_DIR ?= $(strip $(abspath $(mkfile_abs_dir)/pys))
LEX_FILE_DIR ?= $(strip $(abspath $(mkfile_abs_dir)/lexes))
AST_FILE_DIR ?= $(strip $(abspath $(mkfile_abs_dir)/parses))
BENCH_FILE_DIR ?= $(strip $(abspath $(mkfile_abs_dir)/bench))
GRAPHS_FILE_DIR ?= $(strip $(abspath $(mkfile_abs_dir)/graphs))
OUT_FILE_DIR ?= $(strip $(abspath $(mkfile_abs_dir)/out))
RECURSIVE_CALLS_FILE ?= $(GRAPHS_FILE_DIR)/recursive-calls.csv
PAPER_RESULTS_FILE ?= $(GRAPHS_FILE_DIR)/paper-bench-results.csv
COLLATED_RESULTS_FILE ?= $(OUT_FILE_DIR)/collated-results.csv
CALCULATED_RESULTS_FILE ?= $(OUT_FILE_DIR)/calculated-results.csv
PAPER_CALCULATED_RESULTS_FILE ?= $(OUT_FILE_DIR)/paper-calculated-results.csv
RESULTS_PDF_FILE ?= $(OUT_FILE_DIR)/results.pdf


TIMEOUT ?= -1
QUOTA_FACTOR ?= 3
MAX_QUOTA ?= 1000

start_symbol_opts := $(patsubst %,-s %, $(START_SYMBOLS))

BENCH_OUT ?= $(GEN_FILE_DIR)/pwz_bench
PARSE_OUT ?= $(GEN_FILE_DIR)/pwz_parse
export BENCH_OUT
export PARSE_OUT

# TODO items:
#
# [x] `make all` -> `make prepare`
# [x] three steps: `make prepare`, `make benchmark`, `make post-process`
# [ ] incorporate graphs and calculations into `post-process` target
#   [x] graphs
#   [ ] recursive calls
#   [ ] calculations
# [x] remove pwz-mem parser because it doesn't work
#   - should it be removed, or just commented out?
# [x] check necessity/naming of other `make` targets (parse, verify)
# [ ] clarify parso version requirement
#   - consider updating to more modern parso?
# [ ] update top-level README with better `make` instructions
# [x] move `out` directory to `gen`
# [ ] output graphs and numbers to `out` directory
#   [x] graphs
#   [ ] calculations
# [x] add regular `make clean` target

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

$(OUT_FILE_DIR):
	$(MKDIR_P) $@

$(GRAPHS_FILE_DIR):
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
	-$(MAKE) -C $(GEN_FILE_DIR) clean
	@echo Clean complete.

clean-generate:
	@echo Removing $(GEN_FILE_DIR)...
	-$(RM) -r $(GEN_FILE_DIR)
	@echo Removal complete.

clean-py:
	@echo Removing $(PY_FILE_DIR)...
	-$(RM) -r $(PY_FILE_DIR)
	@echo Removal complete.

clean-lex:
	@echo Removing $(LEX_FILE_DIR)...
	-$(RM) -r $(LEX_FILE_DIR)
	@echo Removal complete.

clean-benchmark:
	@echo Removing $(BENCH_FILE_DIR)...
	-$(RM) -r $(BENCH_FILE_DIR)
	@echo Removal complete.

clean-parse:
	@echo Removing $(AST_FILE_DIR)...
	-$(RM) -r $(AST_FILE_DIR)
	@echo Removal complete.

clean-out:
	@echo Removing $(OUT_FILE_DIR)...
	-$(RM) -r $(OUT_FILE_DIR)
	@echo Removal complete.

################################################################################
# Preparation Targets
#
# These targets are used in preparing everything for benchmarking. This includes
# unpacking the .py files, lexing them, running the code generator, and
# compiling the OCaml parsers.

.PHONY: prepare extract lex generate compile

prepare: extract lex generate compile
	@echo ""
	@echo "****************************************************************"
	@echo "Preparation complete. Now ready to run benchmarks."
	@echo "To run benchmarks, do `make benchmark`."

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
	@echo Generating output files in $(GEN_FILE_DIR)...
	$(PYTHON) $(driver) generate $(GRAMMAR_FILE) $(start_symbol_opts) --output-dir $(GEN_FILE_DIR) -p all
	$(MAKE) -C $(GEN_FILE_DIR) generate
	@echo File generation complete.

$(BENCH_OUT): $(GEN_MAKEFILE)
	$(MAKE) -C $(GEN_FILE_DIR) bench

$(PARSE_OUT): $(GEN_MAKEFILE)
	$(MAKE) -C $(GEN_FILE_DIR) parse

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

.PHONY: post-process collate calculate graphs paper-graphs

post-process: collate calculate graphs

collate: $(OUT_FILE_DIR)
	if [ ! -d "$(BENCH_FILE_DIR)" ]; then echo "$(BENCH_FILE_DIR) does not exist!"; exit 1; fi
	$(eval parser_opts := $(patsubst %,-p %,$(BENCH_PARSERS)))
	$(PYTHON) $(driver) collate --overwrite --bench-file-dir $(BENCH_FILE_DIR) \
		--collated-results-file $(COLLATED_RESULTS_FILE) $(parser_opts)

calculate: $(OUT_FILE_DIR)
	$(eval parser_opts := $(patsubst %,-p %,$(BENCH_PARSERS)))
	$(PYTHON) $(driver) calculate --collated-results-file $(COLLATED_RESULTS_FILE) \
		--calculated-results-file $(CALCULATED_RESULTS_FILE) $(parser_opts)

graphs: $(GRAPHS_FILE_DIR) $(COLLATED_RESULTS_FILE)
	$(PYTHON) $(driver) graphs --overwrite --graphs-file-dir $(GRAPHS_FILE_DIR) \
		--output-dir $(OUT_FILE_DIR) \
		--collated-results-file $(COLLATED_RESULTS_FILE) \
		--recursive-calls-file $(RECURSIVE_CALLS_FILE) \
		--calculated-results-file $(CALCULATED_RESULTS_FILE) \
		--output-file $(RESULTS_PDF_FILE)

paper-graphs: $(GRAPHS_FILE_DIR) $(OUT_FILE_DIR)
	export COLLATED_RESULTS_FILE=PAPER_RESULTS_FILE
	export CALCULATED_RESULTS_FILE=PAPER_CALCULATED_RESULTS_FILE
	$(MAKE) calculate --no-print-directory
	$(MAKE) graphs --no-print-directory

################################################################################
# Usage-Specific Targets
#
# These targets are used for specific use-cases, such as debugging. They can
# safely be ignored most of the time.

.PHONY: parse verify compile-profile

# Run the parsers without benchmarking.
# This produces all of the parsed AST files that the `benchmark` target
# produces, but none of the extra output in $(BENCH_FILE_DIR).
parse: $(AST_FILE_DIR) $(PARSE_OUT)
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
	$(MAKE) -C $(GEN_FILE_DIR) profile
