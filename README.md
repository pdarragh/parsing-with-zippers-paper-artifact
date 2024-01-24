# Parsing with Zippers (Functional Pearl) Paper Artifact

This is the artifact associated with the ICFP 2020 paper "Parsing with Zippers
(Functional Pearl)" by Pierce Darragh and Michael D Adams.

## Organization

This artifact is organized into two top-level directories:

  * `benchmark` provides the code for running the benchmarking tests we use in
    the paper.
  * `interact` provides a minimal implementation of the Parsing with Zippers
    algorithm and a set of example grammars that can be used for interactive
    testing.
  * `appendix` contains a copy of the code listed in the appendix of the paper.

Instructions for compilation, setup, and use appear in the `README.md` files
located within each of these directories.

## Notes to the Artifact Evaluation Committee

These are notes that are relevant to the AEC.

### Artifact Sub-component READMEs

Both of the top-level sub-components have their own README files. These contain
installation and configuration instructions which are not relevant to the AEC
when using the QEmu virtual machine, because all such dependencies have already
been installed. However, for the curious reviewer (or later paper-reader) who
chooses to install the dependencies themselves, we leave these instructions
intact.

### OCaml Compilation Warnings

The `benchmark` code produces a significant number of warnings. This is mostly
due to the way we copied code from previous papers' work for comparative
benchmarks. OCaml has very specific style guidelines that were not observed in
the previous work, and this stylistic deviations cause a significant number of
warnings to appear during compilation. We apologize for the inconvenience, but
we feel it best not to fix the code to alleviate these constraints at this time.
(However, we will note that we may adjust the code stored on GitHub at a later
date to attend to these warnings.)

### Time-Consuming Benchmarks

Our benchmarks can take a long time to run (certainly more than 10 minutes!).
However, they can be stopped and resumed as-needed. Alternatively, a low timeout
or quota multiplier can be set, or you can remove some of the input files to
reduce the total time taken. These procedures are explained in the associated
`README.md` file.

### Discrepancy in Benchmark Inputs

There is a minor discrepancy between the files that were used for benchmarking
in our paper compared to the files that are now used automatically by the
benchmarking suite. This is because the original group of files tested on were
manually curated from a previous project by a former member of our research
group, which we had not realized until after submission of the paper. The
difference is fewer than 10 files out of approximately 660, and our recent
results do not show any significant difference from the results shown in the
paper. We intend to update the figures and numerical references accordingly
prior to submitting the camera-ready copy.

## System Setup

Here we provide the set of steps we used to install the necessary components in
the QEmu Debian installation. This is provided as both a historical record as
well as to help anybody in installing these packages manually. Hypothetically,
this section could be copied into a shell script and run with super-user
privileges, but we do not recommend this.

NOTE that these instructions were tested on Ubuntu 20.04 (LTS) in a Digital
Ocean droplet. We do not guarantee that these instructions will work on all
platforms.

```
####################
# SET UP UBUNTU
##
# Update the list of packages.
sudo apt update
# Normally, one would perform a system upgrade after this step to ensure all
# pacakges are up to date. However, for the purposes of creating an archival
# copy of our system, we did not. If you wanted to upgrade, you would uncomment
# the following line and execute it:
#sudo apt upgrade -y

####################
# SET UP OCAML
##
# Install the OCaml runtime and additional dependencies.
sudo apt install m4 opam -y
opam init  # Accept the prompts as you choose. We used y and y as our responses.
eval $(opam env)
# We install OCaml version 4.05.
#   NOTE: In some environments, this can fail with a note that the switch
#         couldn't be found. If this happens, use
#         `opam switch create pwz 4.05.0`
# NOTE: There is a step early on, which says (in our instance)
#       "ocaml-base-compiler: make world.opt", that takes a very long time.
opam switch create pwz ocaml-system.4.05.0
eval $(opam env)
##########
# C) OCAML LIBRARIES
##
# Install needed OCaml libraries.
# NOTE: There is one step early on, which says (in our instance)
#       "ocaml-secondary-compiler: make world.opt", that takes a very long time.
opam install core.v0.11.3 core_bench.v0.11.0 menhir.20200211 dypgen.20120619-1 -y

####################
# SET UP PYTHON
##
# Install build requirements for Python 3.7.17 with pip.
# Then compile it from source and install additional dependencies.
sudo apt install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libsqlite3-dev libreadline-dev libffi-dev curl libbz2-dev -y
curl -o Python-3.7.17.tar.xz https://www.python.org/ftp/python/3.7.17/Python-3.7.17.tar.xz
tar -xf Python-3.7.17.tar.xz
cd Python-3.7.17 && ./configure --enable-optimizations --enable-shared --with-ensurepip=install && make -j 4 && sudo make install
sudo ldconfig /usr/local/share/python3.7
sudo ln -s /usr/bin/python3 /usr/local/share/python3.7
python3 -m pip install --user parso==0.4.0

####################
# SET UP LUALATEX
##
# Install LuaLaTeX for generating the results PDF.
sudo apt install luatex texlive-luatex xzdec -y
# Install additional needed libraries.
# NOTE: If you have the space (~6GB), we would recommend instead doing
#       `sudo apt install texlive-full` as this will install all the libraries
#       and options to render the document better. The QEMU VM is limited in
$       size, so we opted to manually install only the bare minimum.
tlmgr init-usertree  # Sometimes this will say "Cannot determing type of tlpdb".
                     # Just run it again and it should work!
tlmgr option repository ftp://tug.org/historic/systems/texlive/2017/tlnet-final
tlmgr install xstring iftex totpages environ trimspaces ncctools comment pgf pgfplots

####################
# SET UP ARTIFACT
##
# Clone the artifact repository from GitHub.
git clone https://github.com/pdarragh/parsing-with-zippers-paper-artifact.git
cd parsing-with-zippers-paper-artifact
cat README.md
```

## Dockerfile

A Dockerfile is provided that creates an environment with the above packages installed, ready for running the benchmarks.
You can build an image yourself by cloning this repository and then running `sudo docker build -t zippers-artifact .` from within the repository root.
After the build has finished, you can open up this environment by running `sudo docker run -i -t zippers-artifact` and you'll be greeted with a ready to go Bash inside the artifact directory.

