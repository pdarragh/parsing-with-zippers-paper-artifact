OCAMLOPT ?= ocamlopt
ocamlfind := ocamlfind $(OCAMLOPT) -I .

compilation_extensions := o,cma,cmo,cmi,cmx,cmxa,cmxo,cmxi
interface_extensions := mli,

sources := pwz_abstract_types.ml pwz_types.ml pwz_derive.ml pwz_driver.ml pwz_plug.ml

.PHONY: clean
.PHONY: clean-all
.PHONY: compile
.PHONY: default
.PHONY: interfaces

default: compile

clean:
	$(RM) *.{$(compilation_extensions)}

clean-all: clean
	$(RM) *.{$(interface_extensions)}
	$(RM) pwz

compile: $(sources)
	$(ocamlfind) -c $^

%.cmi: %.mli
	$(ocamlfind) -c $^

%.mli: %.ml
	$(ocamlfind) -i $^ > $@
