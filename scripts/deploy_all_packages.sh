#!/bin/bash

set -euo pipefail

export PATH=$ANACONDA_PREFIX/bin:$PATH
script_path="$(dirname "$( readlink -e ${BASH_SOURCE[0]} )" )"
# ooh, pretty colors
source $script_path/b-log.sh
LOG_LEVEL_NOTICE

skipDeployFile="SKIP_DEPLOY"
allPackageDirs=`find packages/ -maxdepth 1 -mindepth 1 -type d`

NOTICE "Beginning package deployment"
for packageDir in $allPackageDirs;
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

  envSpecs=`anaconda-project list-env-specs --directory $packageDir | tail -n +5 | cut -f 1 -d ' '`;
  for spec in $envSpecs;
    do
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
    done
  NOTICE "Leaving directory '$packageDir'"
done

NOTICE 'Finished package deployment'
