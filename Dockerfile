FROM docker.io/ocaml/opam:debian-12-ocaml-4.05

# Settings
ARG PYTHON_MAIN_VER=3.7
ARG PYTHON_HOTFIX_VER=17
ARG PYTHON_VER=${PYTHON_MAIN_VER}.${PYTHON_HOTFIX_VER}
ARG MAKE_CPU_COUNT=4

# System packages
ENV DEBIAN_FRONTEND=noninteractive
RUN \
    --mount=type=cache,target=/var/cache/apt \
    sudo apt update && sudo apt install -y \
    texlive-full \
    xzdec \
    git \
    build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libsqlite3-dev libreadline-dev libffi-dev curl libbz2-dev \
    && sudo rm -rf /var/lib/apt/lists/*

# OCaml libraries
RUN opam install core.v0.11.3 core_bench.v0.11.0 menhir.20200211 dypgen.20120619-1 -y

# Clone repository
RUN sudo mkdir /artifact
RUN sudo chown opam /artifact
RUN git clone https://github.com/pdarragh/parsing-with-zippers-paper-artifact.git /artifact
WORKDIR /artifact

# Python installation from source
RUN curl -o Python-${PYTHON_VER}.tar.xz https://www.python.org/ftp/python/${PYTHON_VER}/Python-${PYTHON_VER}.tar.xz
RUN tar -xf Python-${PYTHON_VER}.tar.xz
RUN cd Python-${PYTHON_VER} && ./configure --enable-optimizations --enable-shared --with-ensurepip=install && make -j ${MAKE_CPU_COUNT} && sudo make install
RUN sudo rm -rf Python-${PYTHON_VER}.tar.xz Python-${PYTHON_VER}
RUN sudo ldconfig /usr/local/share/python${PYTHON_MAIN_VER}
RUN sudo ln -s /usr/bin/python3 /usr/local/share/python${PYTHON_MAIN_VER}
RUN python3 -m pip install --user parso==0.4.0

# Default to starting a shell in the artifact dir
CMD bash
