#!/bin/bash

set -euo pipefail

source $ANACONDA_PREFIX/etc/profile.d/conda.sh
conda activate base
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

# Use mamba for speed
export CONDA_EXE=mamba

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
          prepareCommand="anaconda-project prepare --refresh --directory $packageDir --env-spec $spec"
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
  NOTICE "Finding commands for $packageDir"
  apCommands=`anaconda-project list-commands --directory $packageDir | tail -n +5 | cut -f 1 -d ' '`
  if [ -z "$apCommands" ]
  then
    NOTICE "No commands found"
  elif [ -n "$apCommands" ]
  then
    echo "Command(s) found"
    for apCommand in $apCommands
    do
           NOTICE "Found command named $apCommand"
           if [ -f $packageDir/SKIP_COMMANDS_DEPLOY ] && [ `grep -x "$apCommand" $packageDir/SKIP_COMMANDS_DEPLOY` ]
           then
                NOTICE "Skipping command $apCommand"
                continue
           fi
           cmdCommand="anaconda-project run --directory $packageDir $apCommand"
           cmdOut="$($cmdCommand 2>&1)"
           echo "$cmdOut" | INFO
    done
    NOTICE "Finished running commands for $packageDir"
  fi
  NOTICE "Leaving directory '$packageDir'"
done

NOTICE 'Finished package deployment'
