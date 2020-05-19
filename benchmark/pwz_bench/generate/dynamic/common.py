from pwz_bench.utility import *

from itertools import chain
from typing import List


__all__ = ['gen_pytokens_ml']


BENCH_OUT = 'pwz_bench'
PARSE_OUT = 'pwz_parse'


MAKEFILE = """\
{phony_target_declarations}

this_file := $(lastword $(MAKEFILE_LIST))

build_extensions := o,cma,cmo,cmi,cmx,cmxa,cmxo,cmxi

BENCH_OUT ?= {bench_out}
PARSE_OUT ?= {parse_out}

OCAMLOPT ?= ocamlopt
ocamlfind := ocamlfind $(OCAMLOPT)

packages := core core_bench str {packages}
package_opts := $(patsubst %,-package %, $(packages))
includes := {include_dirs}}
include_opts := $(patsubst %,-I ./%, $(includes)) -I $(dyp_lib)
ocamlfind_opts := $(package_opts) $(include_opts) -linkpkg -thread
ocamlfind_cmd := $(ocamlfind) $(ocamlfind_opts)

{sources}
base_sources := {base_sources}
bench_sources := 

default: build

build: bench parse

clean
"""


PYTOKENS_ML = """\
open Core

type ast = Pyast.ast

type tag = int
type lab = string
type token_pair = (tag * lab)

type token =
    | {token_type_def}

let string_of_token (t : token) : string =
    match t with
    | {string_of_token_clauses}

let token_pair_of_token (t : token) : token_pair =
    match t with
    | {token_pair_of_token_clauses}

let string_token_assoc : (string * token) list =
    [ {string_token_assoc_elements}
    ]

let token_of_string (s : string) : token =
    let pat_match (pat : string) : bool = Str.string_match (Str.regexp pat) s 0 in
    let matched (s : string) : string = Str.matched_group 1 s in
    if pat_match {token_of_string_patterns}
    else try  List.Assoc.find_exn ~equal:String.equal string_token_assoc s
         with Not_found -> failwith ("Could not find token '" ^ s ^ "' in string_token_assoc.")

let token_pair_of_string (s : string) : token_pair = token_pair_of_token (token_of_string s)
"""


def gen_pytokens_ml(desc: GrammarDescription) -> List[str]:
    all_tokens = set(chain(desc.tokens.named, desc.tokens.nameless, map(lambda p: p[0], desc.tokens.typed)))
    lines = PYTOKENS_ML.format(
        token_type_def='\n    | '.join(chain((f"{n}_" for n in chain(desc.tokens.named,
                                                                     desc.tokens.nameless)),
                                             (f"{n}_ of {t}" for n, t in desc.tokens.typed))),
        string_of_token_clauses='\n    | '.join(chain(map(lambda t: make_string_of_token(t, False),
                                                          chain(desc.tokens.named,
                                                                desc.tokens.nameless)),
                                                      map(lambda p: make_string_of_token(p[0], True),
                                                          desc.tokens.typed))),
        token_pair_of_token_clauses='\n    | '.join(chain(map(lambda t: make_token_pair_of_token(t, False),
                                                              chain(desc.tokens.named,
                                                                    desc.tokens.nameless)),
                                                          map(lambda p: make_token_pair_of_token(p[0], True),
                                                              desc.tokens.typed))),
        string_token_assoc_elements='\n    ; '.join(map(make_string_token_assoc,
                                                        chain(desc.tokens.named,
                                                              desc.tokens.nameless))),  # Typed tokens are not added.
        token_of_string_patterns='\n    else if pat_match '.join(chain(
            [fr'"^{token.name}$" then {token.name}_'
             for token in AMORPHOUS_TOKENS
             if token.name in all_tokens],
            [fr'"^{token.name} \"\\(.*\\)\"$" then {token.name}_ (matched s)'
             for token in PARAMETERIZED_TOKENS
             if token.name in all_tokens]))
    ).split('\n')
    return lines
