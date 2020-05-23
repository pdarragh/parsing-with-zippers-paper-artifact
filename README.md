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

Instructions for compilation, setup, and use appear in the `README.md` files
located within each of these directories.

## Notes to the Artifact Evaluation Committee

These are notes that are relevant to the AEC.

### Time-Consuming Benchmarks

Our benchmarks can take a long time to run (certainly more than 10 minutes!).
However, they can be stopped and resumed as-needed. This procedure is explained
in the associated `README.md` file.

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

```
# Update the list of packages.
sudo apt update
# Normally, one would perform a system upgrade after this step to ensure all
# pacakges are up to date. However, for the purposes of creating an archival
# copy of our system, we did not. If you wanted to upgrade, you would uncomment
# the following line and execute it:
#sudo apt upgrade -y

# Install the OCaml runtime and additional dependencies.
sudo apt install opam -y
opam init  # Accept the prompts as you choose. We used y and y as our responses.
opam switch create pwz ocaml-system.4.05.0
eval $(opam env)
# Install needed libraries. Note that there is one step early on, which says (in
# our instance) "ocaml-secondary-compiler: make world.opt" that appears as
# though nothing is happening, but things are happening! Leave it be!
opam install core core_bench menhir dypgen -y

# Update Python 3, install pip, and install additional dependencies.
sudo apt install python3-distutils -y
wget https://bootstrap.pypa.io/get-pip.py
python3 get-pip.py --prefix /usr/local/
rm get-pip.py
pip3 install parso==0.4.0

# Clone the artifact repository from GitHub.
git clone https://github.com/pdarragh/parsing-with-zippers-paper-artifact.git
```
