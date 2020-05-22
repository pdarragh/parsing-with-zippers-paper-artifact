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

# Checks whether a given variable is non-empty.
define ensure_defined
	$(if $($(1)),\
		,\  # This is where the then-branch would be if there were one.
		$(error $(1) is empty))
endef

driver := pwz_bench.py
mkfile_abs_dir := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

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

default: clean generate build

all: clean clean-lex lex generate build

clean-all: clean clean-py clean-lex clean-parse

clean:
	@echo Cleaning...
	$(RM) -r $(OUT_DIR)/*
	@echo Clean complete.

clean-light:
	@echo Lightly cleaning...
	$(MAKE) -C $(OUT_DIR) clean
	@echo Clean complete.

clean-py:
	$(call ensure_defined,PY_FILE_DIR)
	@echo Cleaning $(PY_FILE_DIR)...
	$(RM) $(PY_FILE_DIR)/*.py
	@echo Clean complete.

clean-lex:
	$(call ensure_defined,LEX_FILE_DIR)
	@echo Cleaning $(LEX_FILE_DIR)...
	$(RM) $(LEX_FILE_DIR)/*.lex
	@echo Clean complete.

clean-parse:
	$(call ensure_defined,AST_FILE_DIR)
	@echo Cleaning $(AST_FILE_DIR)...
	$(RM) -r $(AST_FILE_DIR)/*
	@echo Clean complete.

$(OUT_DIR)/Makefile:
	@echo Generating output files in $(OUT_DIR)...
	$(PYTHON) $(driver) generate $(GRAMMAR_FILE) $(start_symbol_opts) -d $(OUT_DIR) -p all
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

prepare:
	$(call ensure_defined,PY_FILE_DIR)
	@echo Extracting .py files from $(TGZ_FILE) and moving them to $(PY_FILE_DIR)...
	$(PYTHON) $(driver) prepare --py-file-dir $(PY_FILE_DIR) --tgz-filename $(TGZ_FILE)
	@echo Preparation done.

lex:
	$(call ensure_defined,PY_FILE_DIR)
	$(call ensure_defined,LEX_FILE_DIR)
	@echo Lexing all .py files in $(PY_FILE_DIR) and outputting lexes to $(LEX_FILE_DIR)...
	$(PYTHON) $(driver) lex --py-file-dir $(PY_FILE_DIR) --lex-file-dir $(LEX_FILE_DIR)
	@echo Lexing done.

benchmark: build-bench
	$(call ensure_defined,LEX_FILE_DIR)
	$(call ensure_defined,BENCH_FILE_DIR)
	$(eval lex_files := $(wildcard $(LEX_FILE_DIR)/*.lex))
	$(eval parser_opts := $(patsubst %,-p %,$(BENCH_PARSERS)))
	$(PYTHON) $(driver) benchmark --quota-factor $(QUOTA_FACTOR) --resume --lex-file-dir $(LEX_FILE_DIR) --bench-file-dir $(BENCH_FILE_DIR) $(parser_opts) --max-quota $(MAX_QUOTA)

post-process:
	$(call ensure_defined,BENCH_FILE_DIR)
	$(eval parser_opts := $(patsubst %,-p %,$(BENCH_PARSERS)))
	$(PYTHON) $(driver) post-process --overwrite --bench-file-dir $(BENCH_FILE_DIR) $(parser_opts)

parse: build-parse
	$(call ensure_defined,AST_FILE_DIR)
	$(call ensure_defined,LEX_FILE_DIR)
	$(eval parser_opts := $(patsubst %,-p %,$(PARSE_PARSERS)))
	$(PYTHON) $(driver) parse --lex-file-dir $(LEX_FILE_DIR) --ast-file-dir $(AST_FILE_DIR) $(parser_opts) --timeout $(TIMEOUT)

verify:
	$(call ensure_defined,AST_FILE_DIR)
	$(eval parser_opts := $(patsubst %,-p %,$(VERIFY_PARSERS)))
	$(PYTHON) $(driver) verify --ast-file-dir $(AST_FILE_DIR) $(parser_opts)
