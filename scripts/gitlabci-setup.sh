#!/bin/bash

# install (Mini)conda
tag=Linux
curl -s -O https://repo.continuum.io/miniconda/Miniconda3-$MINICONDA_VER-$tag-x86_64.sh
bash Miniconda3-$MINICONDA_VER-$tag-x86_64.sh -b -p $ANACONDA_PREFIX
export PATH=$ANACONDA_PREFIX/bin:$PATH

# update conda itself and install anaconda-project
conda update -q -y conda
conda install -q -y anaconda-project=0.8.2 anaconda-client=1.6.14

# set the channel order
conda config --add channels conda-forge
conda config --add channels bioconda
conda config --add channels hcc
