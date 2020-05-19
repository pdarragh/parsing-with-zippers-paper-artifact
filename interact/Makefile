OCAMLOPT ?= ocamlopt
ocamlfind := ocamlfind $(OCAMLOPT) -I .

compilation_extensions := o,cma,cmo,cmi,cmx,cmxa,cmxo,cmxi
interface_extensions := mli,

sources := types.ml cst.ml pwz.ml grammars.ml

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

interfaces: $(patsubst %.ml, %.mli, $(sources))

pwz.mli: pwz.ml types.cmi
	$(ocamlfind) -i $< > $@

%.cmi: %.mli
	$(ocamlfind) -c $^

%.mli: %.ml
	$(ocamlfind) -i $^ > $@
