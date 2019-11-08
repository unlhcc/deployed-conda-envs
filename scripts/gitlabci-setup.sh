#!/bin/bash

# install (Mini)conda
tag=Linux
curl -s -O https://repo.continuum.io/miniconda/Miniconda3-$MINICONDA_VER-$tag-x86_64.sh
bash Miniconda3-$MINICONDA_VER-$tag-x86_64.sh -b -p $ANACONDA_PREFIX
source ${ANACONDA_PREFIX}/etc/profile.d/conda.sh

# install anaconda-project and friends
conda config --system --set auto_update_conda False
conda activate base
conda install -q -y anaconda-project=0.8.2 anaconda-client=1.6.14 git

# set the channel order
conda config --system --add channels bioconda
conda config --system --add channels conda-forge
conda config --system --add channels hcc
conda config --system --add channels https://conda.anaconda.org/t/${PRIVATE_PACKAGE_TOKEN}/hcc
