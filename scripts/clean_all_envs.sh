#!/bin/bash

for d in `ls -1d packages/*`
do
  if [ -d $d/envs ]
  then
    anaconda-project clean --directory $d
  fi
done
