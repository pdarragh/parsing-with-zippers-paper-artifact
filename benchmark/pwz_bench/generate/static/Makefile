.PHONY: bench
.PHONY: build
.PHONY: clean
.PHONY: default
.PHONY: dypgen
.PHONY: generate
.PHONY: menhir
.PHONY: parse
.PHONY: profile

this_file := $(lastword $(MAKEFILE_LIST))

build_extensions := o,cma,cmo,cmi,cmx,cmxa,cmxo,cmxi

BENCH_OUT ?= pwz_bench
PARSE_OUT ?= pwz_parse

OCAMLOPT ?= ocamlopt
ocamlfind := ocamlfind $(OCAMLOPT)

men_base := menhir/pymen
men_def := $(men_base).mly
men_mli := $(men_base).mli
men_out := $(men_base).ml

dyp_lib := $(abspath $(shell $(ocamlfind) -where)/../dyp)
dyp_base := dypgen/pydyp
dyp_def := $(dyp_base).dyp
dyp_temp := $(dyp_base)_temp.ml
dyp_type := $(dyp_base).extract_type
dyp_out := $(dyp_base).ml
dyp_mli := $(dyp_base).mli

packages := core core_bench str menhirLib dyp
package_opts := $(patsubst %,-package %, $(packages))
includes := menhir dypgen pwz_nary pwz_nary_list pwz_nary_look pwz_nary_mem pwz_binary pwd_binary pwd_binary_opt pwd_nary pwd_nary_opt
include_opts := $(patsubst %,-I ./%, $(includes)) -I $(dyp_lib)
ocamlfind_opts := $(package_opts) $(include_opts) -linkpkg -thread
ocamlfind_cmd := $(ocamlfind) $(ocamlfind_opts)

common_sources := benchmarking.ml pyast.ml pytokens.ml interface.ml define.ml
menhir_sources := $(men_mli) $(men_out) menhir/menhir_interface.ml
dypgen_sources := $(dyp_mli) $(dyp_out) dypgen/dypgen_interface.ml
pwz_nary_sources := pwz_nary/pwz_nary.ml pwz_nary/pwz_nary_pygram.ml pwz_nary/pwz_nary_interface.ml
pwz_nary_list_sources := pwz_nary_list/pwz_nary_list.ml pwz_nary_list/pwz_nary_list_pygram.ml pwz_nary_list/pwz_nary_list_interface.ml
pwz_nary_look_sources := pwz_nary_look/pwz_nary_look.ml pwz_nary_look/pwz_nary_look_pygram.ml pwz_nary_look/pwz_nary_look_interface.ml
pwz_nary_mem_sources := pwz_nary_mem/pwz_nary_mem.ml pwz_nary_mem/pwz_nary_mem_pygram.ml pwz_nary_mem/pwz_nary_mem_interface.ml
pwz_binary_sources := pwz_binary/pwz_binary.ml pwz_binary/pwz_binary_pygram.ml pwz_binary/pwz_binary_interface.ml
pwd_binary_sources := pwd_binary/pwd_binary.ml pwd_binary/pwd_binary_pygram.ml pwd_binary/pwd_binary_interface.ml
pwd_binary_opt_sources := pwd_binary_opt/pwd_binary_opt.ml pwd_binary_opt/pwd_binary_opt_pygram.ml pwd_binary_opt/pwd_binary_opt_interface.ml
pwd_nary_sources := pwd_nary/pwd_nary.ml pwd_nary/pwd_nary_pygram.ml pwd_nary/pwd_nary_interface.ml
pwd_nary_opt_sources := pwd_nary_opt/pwd_nary_opt.ml pwd_nary_opt/pwd_nary_opt_pygram.ml pwd_nary_opt/pwd_nary_opt_interface.ml
common_cli_sources := pwz_cli_common.ml
base_sources := $(common_sources) $(menhir_sources) $(dypgen_sources) $(pwz_nary_sources) $(pwz_nary_list_sources) $(pwz_nary_look_sources) $(pwz_nary_mem_sources) $(pwz_binary_sources) $(pwd_binary_sources) $(pwd_binary_opt_sources) $(pwd_nary_sources) $(pwd_nary_opt_sources) $(common_cli_sources)
bench_sources := $(base_sources) pwz_bench.ml
parse_sources := $(base_sources) pwz_parse.ml

default: build

build: bench parse

clean:
	$(RM) *.{$(build_extensions)}
	$(RM) */*.{$(build_extensions)}
	$(RM) $(BENCH_OUT)
	$(RM) $(PARSE_OUT)

$(BENCH_OUT): $(bench_sources)
	@echo Building $(notdir $(BENCH_OUT)) executable...
	$(ocamlfind_cmd) -o $@ $^
	@echo Built.

bench: $(BENCH_OUT)

$(PARSE_OUT): $(parse_sources)
	@echo Building $(notdir $(PARSE_OUT)) executable...
	$(ocamlfind_cmd) -o $@ $^
	@echo Built.

parse: $(PARSE_OUT)

profile:
	@echo Performing builds for profiling...
	$(MAKE) -f $(this_file) OCAMLOPT=ocamloptp build
	@echo Profile builds complete.

generate: menhir dypgen

$(men_out): $(men_def)
	@echo Generating Menhir parser...
	menhir --external-tokens Pytokens $^
	@echo Menhir parser generated.

menhir: $(men_out)

pyast.mli: pyast.ml
	$(ocamlfind_cmd) -i $^ > $@

pytokens.mli: pytokens.ml pyast.cmi
	$(ocamlfind_cmd) -i $< > $@

%.cmi: %.mli
	$(ocamlfind_cmd) -c $^

$(dyp_out): $(dyp_def) pyast.cmi pytokens.cmi
	@echo Generating Dypgen parser...
	dypgen --command "$(ocamlfind_cmd) -i $(dyp_temp) > $(dyp_type)" --pv-obj $(dyp_def)
	@echo Dypgen parser generated.

dypgen: $(dyp_out)
