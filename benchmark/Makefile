.PHONY: all
.PHONY: benchmark
.PHONY: build
.PHONY: build-bench
.PHONY: build-parse
.PHONY: clean
.PHONY: clean-all
.PHONY: clean-lex
.PHONY: clean-parse
.PHONY: clean-py
.PHONY: default
.PHONY: generate
.PHONY: lex
.PHONY: parse
.PHONY: post-process
.PHONY: prepare
.PHONY: verify

driver := pwz_bench.py
mkfile_abs_dir := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
MKDIR_P := mkdir -p

PYTHON ?= python3

VERIFY_PARSERS ?= dypgen pwz_nary pwz_nary_look pwz_nary_mem pwz_binary pwd_binary pwd_binary_opt pwd_nary pwd_nary_opt
PARSE_PARSERS ?= menhir $(VERIFY_PARSERS)
BENCH_PARSERS ?= $(PARSE_PARSERS)

TGZ_FILE ?= $(strip $(abspath $(mkfile_abs_dir)/Python-3.4.3.tgz))
GRAMMAR_FILE ?= $(mkfile_abs_dir)/pwz_bench/utility/transformed-python-3.4.grammar
START_SYMBOLS ?= single_input file_input eval_input
OUT_DIR ?= $(strip $(abspath $(mkfile_abs_dir)/out))
PY_FILE_DIR ?= $(strip $(abspath $(mkfile_abs_dir)/pys))
LEX_FILE_DIR ?= $(strip $(abspath $(mkfile_abs_dir)/lexes))
AST_FILE_DIR ?= $(strip $(abspath $(mkfile_abs_dir)/parses))
BENCH_FILE_DIR ?= $(strip $(abspath $(mkfile_abs_dir)/bench))

TIMEOUT ?= -1
QUOTA_FACTOR ?= 3
MAX_QUOTA ?= 1000

start_symbol_opts := $(patsubst %,-s %, $(START_SYMBOLS))

BENCH_OUT ?= $(OUT_DIR)/pwz_bench
PARSE_OUT ?= $(OUT_DIR)/pwz_parse
export BENCH_OUT
export PARSE_OUT

default: clean-light prepare generate build

all: clean prepare lex generate build

clean-all: clean-generate clean-py clean-lex clean-parse clean-bench

clean-light:
	@echo Lightly cleaning...
	-$(MAKE) -C $(OUT_DIR) clean
	@echo Clean complete.

clean-generate:
	@echo Removing $(OUT_DIR)...
	-$(RM) -r $(OUT_DIR)
	@echo Removal complete.

clean-py:
	@echo Removing $(PY_FILE_DIR)...
	-$(RM) -r $(PY_FILE_DIR)
	@echo Removal complete.

clean-lex:
	@echo Removing $(LEX_FILE_DIR)...
	-$(RM) -r $(LEX_FILE_DIR)
	@echo Removal complete.

clean-parse:
	@echo Removing $(AST_FILE_DIR)...
	-$(RM) -r $(AST_FILE_DIR)
	@echo Removal complete.

clean-bench:
	@echo Removing $(BENCH_FILE_DIR)...
	-$(RM) -r $(BENCH_FILE_DIR)
	@echo Removal complete.

$(OUT_DIR)/Makefile:
	@echo Generating output files in $(OUT_DIR)...
	$(PYTHON) $(driver) generate $(GRAMMAR_FILE) $(start_symbol_opts) --output-dir $(OUT_DIR) -p all
	$(MAKE) -C $(OUT_DIR) generate
	@echo File generation complete.

generate: $(OUT_DIR)/Makefile

$(BENCH_OUT): generate
	$(MAKE) -C $(OUT_DIR) bench

$(PARSE_OUT): generate
	$(MAKE) -C $(OUT_DIR) parse

build-bench: $(BENCH_OUT)

build-parse: $(PARSE_OUT)

build: build-bench build-parse

profile: generate
	$(MAKE) -C $(OUT_DIR) profile

$(PY_FILE_DIR):
	$(MKDIR_P) $@

$(LEX_FILE_DIR):
	$(MKDIR_P) $@

$(BENCH_FILE_DIR):
	$(MKDIR_P) $@

$(AST_FILE_DIR):
	$(MKDIR_P) $@

prepare: $(PY_FILE_DIR)
	@echo Extracting .py files from $(TGZ_FILE) and moving them to $(PY_FILE_DIR)...
	$(PYTHON) $(driver) prepare --py-file-dir $(PY_FILE_DIR) --tgz-filename $(TGZ_FILE) --force-extract
	@echo Preparation done.

lex: $(LEX_FILE_DIR)
	if [ ! -d "$(PY_FILE_DIR)" ]; then echo "$(PY_FILE_DIR) does not exist!"; exit 1; fi
	@echo Lexing all .py files in $(PY_FILE_DIR) and outputting lexes to $(LEX_FILE_DIR)...
	$(PYTHON) $(driver) lex --py-file-dir $(PY_FILE_DIR) --lex-file-dir $(LEX_FILE_DIR)
	@echo Lexing done.

benchmark: $(BENCH_FILE_DIR) build-bench
	if [ ! -d "$(LEX_FILE_DIR)" ]; then echo "$(LEX_FILE_DIR) does not exist!"; exit 1; fi
	$(eval lex_files := $(wildcard $(LEX_FILE_DIR)/*.lex))
	$(eval parser_opts := $(patsubst %,-p %,$(BENCH_PARSERS)))
	$(PYTHON) $(driver) benchmark --quota-factor $(QUOTA_FACTOR) --resume --lex-file-dir $(LEX_FILE_DIR) --bench-file-dir $(BENCH_FILE_DIR) $(parser_opts) --max-quota $(MAX_QUOTA)

post-process:
	if [ ! -d "$(BENCH_FILE_DIR)" ]; then echo "$(BENCH_FILE_DIR) does not exist!"; exit 1; fi
	$(eval parser_opts := $(patsubst %,-p %,$(BENCH_PARSERS)))
	$(PYTHON) $(driver) post-process --overwrite --bench-file-dir $(BENCH_FILE_DIR) $(parser_opts)

parse: $(AST_FILE_DIR) build-parse
	if [ ! -d "$(LEX_FILE_DIR)" ]; then echo "$(LEX_FILE_DIR) does not exist!"; exit 1; fi
	$(eval parser_opts := $(patsubst %,-p %,$(PARSE_PARSERS)))
	$(PYTHON) $(driver) parse --lex-file-dir $(LEX_FILE_DIR) --ast-file-dir $(AST_FILE_DIR) $(parser_opts) --timeout $(TIMEOUT)

verify:
	if [ ! -d "$(AST_FILE_DIR)" ]; then echo "$(AST_FILE_DIR) does not exist!"; exit 1; fi
	$(eval parser_opts := $(patsubst %,-p %,$(VERIFY_PARSERS)))
	$(PYTHON) $(driver) verify --ast-file-dir $(AST_FILE_DIR) $(parser_opts)
