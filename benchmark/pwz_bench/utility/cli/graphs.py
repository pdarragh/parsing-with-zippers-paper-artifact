from os import chdir, getcwd
from pathlib import Path
from shutil import move as move_file
from subprocess import run
from typing import Optional


__all__ = ['generate_graphs_pdf_file']


GRAPHS_TEX_FILE = 'graphs.tex'
DEFAULT_CUBIC_FILE = 'cubic.csv'
DEFAULT_RESULTS_FILE = 'all-bench-results.csv'


def generate_graphs_pdf_file(graphs_dir: Path, out_dir: Path, overwrite: bool = False,
                             cubic_file: Optional[Path] = None, results_file: Optional[Path] = None):
    graphs_tex_file = graphs_dir / GRAPHS_TEX_FILE
    if not overwrite and graphs_tex_file.is_file():
        raise RuntimeError(f"Output file {graphs_tex_file} already exists. Aborting!")
    if cubic_file is None:
        cubic_file = graphs_dir / DEFAULT_CUBIC_FILE
    if results_file is None:
        results_file = graphs_dir / DEFAULT_RESULTS_FILE
    print(f"Generating LaTeX file for graphs at {graphs_tex_file}...")
    graphs_tex_file.write_text(GRAPHS_FILE_CONTENTS.format(cubic=str(cubic_file), results=str(results_file)))
    graphs_pdf_file = graphs_tex_file.with_suffix('.pdf')
    graphs_pdf_file_out = out_dir / graphs_pdf_file.name
    print(f"Generating PDF of graphs at {graphs_pdf_file_out}...")
    prev_dir = getcwd()
    chdir(graphs_dir)
    run(['lualatex', graphs_tex_file])
    chdir(prev_dir)
    move_file(graphs_pdf_file, graphs_pdf_file_out)


GRAPHS_FILE_CONTENTS = """\
\\documentclass[acmsmall]{{acmart}}

\\providecommand*{{\\code}}[1]{{\\texttt{{#1}}}}

\\usepackage{{etex}} % Fix "No room for new \\dimen" error
\\usepackage{{pgfplots}}
\\pgfplotsset{{compat=1.15}}
\\pgfplotsset{{lua debug=verbose}}

\\begin{{document}}
\\title{{Graphs for \\emph{{Parsing with Zippers (Functional Pearl)}}}}
\\author{{Pierce Darragh}}
\\orcid{{0000-0002-6490-3466}}
\\affiliation{{
  \\institution{{University of Utah}}
  \\department{{School of Computing}}
  \\streetaddress{{50 S Central Campus Drive, Room 3190}}
  \\city{{Salt Lake City}}
  \\state{{Utah}}
  \\postcode{{84112}}
  \\country{{USA}}
}}
\\author{{Michael D. Adams}}
\\orcid{{0000-0003-3160-6972}}
\\affiliation{{
  \\institution{{University of Michigan}}
  \\department[0]{{Computer Science and Engineering Division}}
  \\department[1]{{Electrical Engineering and Computer Science Department}}
  \\streetaddress{{Bob and Betty Beyster Building, 2260 Hayward Street}}
  \\city{{Ann Arbor}}
  \\state{{Michigan}}
  \\postcode{{48109-2121}}
  \\country{{USA}}
}}
\\maketitle

\\begin{{itemize}}
\\item This document contains graphs of empirically measured data for the ICFP
      2020 paper \\emph{{Parsing with Zippers (Functional Pearl)}} by Pierce
      Darragh and Michael D.~Adams.

\\item This document reads graph data from files named \\code{{{cubic}}} and
      \\code{{{results}}}, so those files should be created before
      compiling this document.

\\item This document should be compiled with \\code{{lualatex}}.
\\end{{itemize}}

\\begin{{figure}}
\\noindent \\centering{{}}\\noindent \\begin{{center}}
\\pgfplotstableset{{col sep=comma}}
\\pgfplotstableread{{{cubic}}}\\benchmarkData
\\begin{{tikzpicture}}
\\begin{{axis}}[
 legend entries={{Measurement, Cubic fitting curve}},
 legend cell align=left,
 legend columns=1,
 legend style={{at={{(1.03,1)}},anchor=north west, draw=none}},
 scaled ticks=false, enlarge x limits=false,
 xmax=500,
 %ymode=log,
 ymin=0, %ymin=5e-8, ymax=5e-2,
 %every tick/.style=black, minor x tick num=1, ytickten={{-20,...,20}},
 xlabel={{Number of tokens in input}},
 ylabel={{Number of recursive calls}}]
\\addplot[mark size=1.0pt,only marks] table [x={{Tokens}}, y={{Calls}}] \\benchmarkData;
\\addplot[domain=0:500,no marks] {{0.5 * x^3 + 2.5 * x^2 + 11 * x + 9}};
\\end{{axis}}
\\end{{tikzpicture}}
\\par\\end{{center}}\\vspace{{-1em}}
\\caption{{\\label{{fig:cubic}}Figure 24 from the paper}}
\\end{{figure}}

\\begin{{figure}}
\\noindent \\centering{{}}\\noindent \\begin{{center}}
\\pgfplotstableset{{col sep=comma}}
\\pgfplotstableread{{{results}}}\\benchmarkData
\\begin{{tikzpicture}}[only marks]
\\begin{{axis}}[
 scaled ticks=false, enlarge x limits=false, xmax=27500, ymode=log,
 ymin=5e-8, ymax=5e-2,
 every tick/.style=black, minor x tick num=1, ytickten={{-20,...,20}},
 xlabel={{Number of tokens in input}},
 ylabel={{Seconds per token parsed}},
 legend entries={{\\small PwD [Might et al.\\ 2011]\\phantom{{.}},\\small Optimized PwD [Adams et al.\\ 2016]\\phantom{{.}},\\small PwZ (this paper) without lookahead\\phantom{{.}},\\small PwZ (this paper) with lookahead\\phantom{{.}},\\small Menhir\\phantom{{.}},\\small \\code{{dypgen}}\\phantom{{.}},}},
 legend cell align=left,
 legend columns=1,
 legend style={{at={{(1.03,1)}},anchor=north west, draw=none}}]
\\addplot[color=gray, mark size=1.5pt, mark=x] table [x={{Tokens}}, y={{pwd_binary Sec/Tok}}] \\benchmarkData;
\\addplot[mark size=1.5pt, mark=+] table [x={{Tokens}}, y={{pwd_binary_opt Sec/Tok}}] \\benchmarkData;
\\addplot[color=gray, mark size=1.5pt, mark=Mercedes star] table [x={{Tokens}}, y={{pwz_nary Sec/Tok}}] \\benchmarkData;
\\addplot[mark size=1.5pt, mark=Mercedes star flipped] table [x={{Tokens}}, y={{pwz_nary_look Sec/Tok}}] \\benchmarkData;
\\addplot[color=gray, mark size=0.5pt] table [x={{Tokens}}, y={{menhir Sec/Tok}}] \\benchmarkData;
\\addplot[mark size=1.0pt, mark=o] table [x={{Tokens}}, y={{dypgen Sec/Tok}}] \\benchmarkData;
\\end{{axis}}
\\end{{tikzpicture}}
\\par\\end{{center}}\\vspace{{-1em}}
\\caption{{\\label{{fig:bench}}Figure 25 from the paper}}
\\end{{figure}}

\\begin{{figure}}
\\noindent \\centering{{}}\\noindent \\begin{{center}}
\\pgfplotstableset{{col sep=comma}}
\\pgfplotstableread{{{results}}}\\benchmarkData
\\begin{{tikzpicture}}[only marks]
\\begin{{axis}}[
 scaled ticks=false, enlarge x limits=false, xmax=2750, ymode=log,
 ymin=2e-6, ymax=7e-5,
 every tick/.style=black, minor x tick num=1, ytickten={{-20,...,20}},
 xlabel={{Number of tokens in input}},
 ylabel={{Seconds per token parsed}},
 legend entries={{PwD (binary)\\phantom{{.}},PwD ($n$-ary)\\phantom{{.}},Optimized PwD (binary)\\phantom{{.}},Optimized PwD ($n$-ary)\\phantom{{.}},PwZ (binary)\\phantom{{.}},PwZ ($n$-ary)\\phantom{{.}}}},
 legend cell align=left,
 legend columns=1,
 legend style={{at={{(1.03,1)}},anchor=north west, draw=none}}]
\\addplot[color=gray, mark size=1.5pt, mark=x] table [x={{Tokens}}, y={{pwd_binary Sec/Tok}}] \\benchmarkData;
\\addplot[mark size=1.5pt, mark=+] table [x={{Tokens}}, y={{pwd_nary Sec/Tok}}] \\benchmarkData;
\\addplot[color=gray, mark size=1.0pt, mark=o] table [x={{Tokens}}, y={{pwd_binary_opt Sec/Tok}}] \\benchmarkData;
\\addplot[mark size=0.5pt] table [x={{Tokens}}, y={{pwd_nary_opt Sec/Tok}}] \\benchmarkData;
\\addplot[color=gray, mark size=1.5pt, mark=Mercedes star] table [x={{Tokens}}, y={{pwz_binary Sec/Tok}}] \\benchmarkData;
\\addplot[mark size=1.5pt, mark=Mercedes star flipped] table [x={{Tokens}}, y={{pwz_nary Sec/Tok}}] \\benchmarkData;
%\\addplot[mark size=1.5pt, mark=x] table [x={{Tokens}}, y={{pwd_binary Sec/Tok}}] \\benchmarkData;
%\\addplot[mark size=1.5pt, mark=+] table [x={{Tokens}}, y={{pwd_binary_opt Sec/Tok}}] \\benchmarkData;
%\\addplot[mark size=1.5pt, mark=Mercedes star] table [x={{Tokens}}, y={{pwz_nary Sec/Tok}}] \\benchmarkData;
%\\addplot[mark size=1.5pt, mark=Mercedes star flipped] table [x={{Tokens}}, y={{pwz_nary_look Sec/Tok}}] \\benchmarkData;
%\\addplot[mark size=0.5pt] table [x={{Tokens}}, y={{menhir Sec/Tok}}] \\benchmarkData;
%\\addplot[mark size=1.0pt, mark=o] table [x={{Tokens}}, y={{dypgen Sec/Tok}}] \\benchmarkData;
\\end{{axis}}
\\end{{tikzpicture}}
\\par\\end{{center}}\\vspace{{-1em}}
\\caption{{\\label{{fig:bench:binary-vs-n-ary}}Figure 26 from the paper}}
\\vspace{{2em}}
\\noindent \\begin{{center}}
\\pgfplotstableset{{col sep=comma}}
\\pgfplotstableread{{{results}}}\\benchmarkData
\\begin{{tikzpicture}}[only marks]
\\begin{{axis}}[
 scaled ticks=false, enlarge x limits=false, xmax=500, ymode=log, % 27500
 ymin=2e-6, ymax=2e-1,
 every tick/.style=black, minor x tick num=1, ytickten={{-20,...,20}},
 xlabel={{Number of tokens in input}},
 ylabel={{Seconds per token parsed}},
 legend entries={{PwD (binary)\\phantom{{.}},PwD ($n$-ary)\\phantom{{.}},Optimized PwD (binary)\\phantom{{.}},Optimized PwD ($n$-ary)\\phantom{{.}},PwZ (binary)\\phantom{{.}},PwZ ($n$-ary)\\phantom{{.}}}},
 legend cell align=left,
 legend columns=1,
 legend style={{at={{(1.03,1)}},anchor=north west, draw=none}}]
\\addplot[color=gray, mark size=1.5pt, mark=x] table [x={{Tokens}}, y={{pwd_binary Sec/Tok}}] \\benchmarkData;
\\addplot[mark size=1.5pt, mark=+] table [x={{Tokens}}, y={{pwd_nary Sec/Tok}}] \\benchmarkData;
\\addplot[color=gray, mark size=1.0pt, mark=o] table [x={{Tokens}}, y={{pwd_binary_opt Sec/Tok}}] \\benchmarkData;
\\addplot[mark size=0.5pt] table [x={{Tokens}}, y={{pwd_nary_opt Sec/Tok}}] \\benchmarkData;
\\addplot[color=gray, mark size=1.5pt, mark=Mercedes star] table [x={{Tokens}}, y={{pwz_binary Sec/Tok}}] \\benchmarkData;
\\addplot[mark size=1.5pt, mark=Mercedes star flipped] table [x={{Tokens}}, y={{pwz_nary Sec/Tok}}] \\benchmarkData;
%\\addplot[mark size=1.5pt, mark=x] table [x={{Tokens}}, y={{pwd_binary Sec/Tok}}] \\benchmarkData;
%\\addplot[mark size=1.5pt, mark=+] table [x={{Tokens}}, y={{pwd_binary_opt Sec/Tok}}] \\benchmarkData;
%\\addplot[mark size=1.5pt, mark=Mercedes star] table [x={{Tokens}}, y={{pwz_nary Sec/Tok}}] \\benchmarkData;
%\\addplot[mark size=1.5pt, mark=Mercedes star flipped] table [x={{Tokens}}, y={{pwz_nary_look Sec/Tok}}] \\benchmarkData;
%\\addplot[mark size=0.5pt] table [x={{Tokens}}, y={{menhir Sec/Tok}}] \\benchmarkData;
%\\addplot[mark size=1.0pt, mark=o] table [x={{Tokens}}, y={{dypgen Sec/Tok}}] \\benchmarkData;
\\end{{axis}}
\\end{{tikzpicture}}
\\par\\end{{center}}\\vspace{{-1em}}
\\caption{{\\label{{fig:bench:binary-vs-n-ary-zoomed-out}}Figure 27 from the paper}}
\\end{{figure}}

\\end{{document}}
"""
