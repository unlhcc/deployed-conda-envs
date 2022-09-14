#!/bin/bash

# bootstrap anaconda-project env
curl -L  https://micromamba.snakepit.net/api/micromamba/linux-64/latest  | tar -jx -C /usr/local
micromamba create -y -q -p $ANACONDA_PREFIX conda=$MINICONDA_VER python=$PY_VER anaconda-project=$AP_VER anaconda-client=$AC_VER mamba=$MAMBA_VER git -c conda-forge

# activate env
source ${ANACONDA_PREFIX}/etc/profile.d/conda.sh
conda activate base

# set the channel order
conda config --system --add channels bioconda
conda config --system --add channels conda-forge
conda config --system --add channels hcc
conda config --system --add channels https://conda.anaconda.org/t/${PRIVATE_PACKAGE_TOKEN}/hcc
#conda config --system --add channels https://${PYROSETTA_REPO_USERNAME}:${PYROSETTA_REPO_PASSWORD//1}@conda.graylab.jhu.edu
conda config --system --set notify_outdated_conda false
conda config --system --set auto_update_conda false
conda config --system --set auto_activate_base true
