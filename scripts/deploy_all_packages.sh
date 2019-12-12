#!/bin/bash

set -euo pipefail

export PATH=$ANACONDA_PREFIX/bin:$PATH
script_path="$(dirname "$( readlink -e ${BASH_SOURCE[0]} )" )"
# ooh, pretty colors
source $script_path/b-log.sh
LOG_LEVEL_ALL

skipDeployFile="SKIP_DEPLOY"
declare -a dirListA
for entry in $(git diff --name-only ${CI_COMMIT_BEFORE_SHA} ${CI_COMMIT_SHA} packages/);
do
  i=`dirname $entry`
  dirListA+=("$i")
done

if [ -z "${dirListA+set}" ]
then
    NOTICE "No packages changed according to git, exiting."
    exit 0
fi
# Sort and unique the directory list
dirList="$(printf '%s\n' ${dirListA[@]} | sort | uniq)"

NOTICE "Beginning package deployment"
for packageDir in $dirList;
do
  NOTICE "Entering directory '$packageDir'"
  if [ ! -f "$packageDir/anaconda-project.yml" ]
  then
    WARN "$packageDir/anaconda-project.yml is missing!  Skipping this directory."
    continue
  fi
  if [ -f "$packageDir/$skipDeployFile" ]
  then
    if grep -i -q "$DEPLOY_HOST" "$packageDir/$skipDeployFile"
    then
      WARN "'$DEPLOY_HOST' found in '"$packageDir/$skipDeployFile"'!  Skipping this package for host $DEPLOY_HOST."
      continue
    fi
  fi
  if [ -f $packageDir/SKIP_PREPARE ]
  then
    WARN "'SKIP_PREPARE' file found in '"$packageDir"'! Skipping preparing some packages."
    continue
  fi

  envSpecs=`anaconda-project list-env-specs --directory $packageDir | tail -n +5 | cut -f 1 -d ' '`;
  for spec in $envSpecs;
    do
      if [ -f $packageDir/SKIP_PREPARE ] && [ `grep -w "$spec" $packageDir/SKIP_PREPARE` ]
      then
          NOTICE "Skipping preparing environment $spec"
	  continue
      else
          NOTICE "Preparing environment $spec"
          prepareCommand="anaconda-project prepare --directory $packageDir --env-spec $spec"
          prepareOut="$($prepareCommand)"
          if [[ "$prepareOut" = *"Potential issues"* ]]
          then
            WARN "One or more issues have been found with the package!"
            echo "$prepareOut" | head -n -2 | WARN
            WARN "Continuing with deployment"
          else
            echo "$prepareOut" | INFO
            NOTICE "Finished preparing environment $spec"
          fi
      fi
    done
  NOTICE "Leaving directory '$packageDir'"
done

NOTICE 'Finished package deployment'
