#!/bin/bash

set -euo pipefail
export PATH=$ANACONDA_PREFIX/bin:$PATH
script_path="$(dirname "$( readlink -e ${BASH_SOURCE[0]} )" )"
# ooh, pretty colors
source $script_path/b-log.sh
LOG_LEVEL_ALL

NOTICE "Running 'git fetch origin master' to get master branch..."
fetchOut="$(git fetch origin master 2>&1)"
echo "$fetchOut" | INFO

NOTICE  "Finding changed packages according to git..."
# Get a unique list of top-level directories for any changed files
# Get the directory of any changed file
declare -a dirListA
for entry in $(git diff  --name-only master HEAD packages/);
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

# Loop through and only include packages (directories) that have an
# 'anaconda-project.yml' file.
declare -a packageList
packageList=()
for aDir in $dirList;
do
    if [ -e ${aDir}/anaconda-project.yml ]
    then
      packageList+=("$aDir")
    fi
done

# Only test if there's at least one changed package.
if [ -z "${packageList+set}" ]
then
    NOTICE "No packages changed according to git, exiting."
    exit 0
elif [ ${#packageList[@]} -ge 1 ]
then
    NOTICE "Packages changed according to git: ${packageList[@]}"
    NOTICE "Running test on changed package(s)..."
    for package in ${packageList[@]}
    do
        NOTICE "Finding environment specs"
        envSpecs=`anaconda-project list-env-specs --directory $package | tail -n +5 | cut -f 1 -d ' '`
        INFO "Found environment specs: $envSpecs"
        for spec in $envSpecs;
        do
            if [ $spec = "default" ]
            then
                ERROR "'default' environment spec should not be present!"
                exit 1
            else
                NOTICE  "Preparing environment $spec"
                prepareCommand="anaconda-project prepare --directory $package --env-spec $spec"
                INFO "Running command $prepareCommand"
                prepareOut="$($prepareCommand 2>&1)"
                if [[ "$prepareOut" = *"Potential issues"* ]]
                then
                    ERROR "One or more issues have been found with the package!"
                    echo "$prepareOut" | head -n -2 | ERROR
                    ERROR "Please correct the problem and try again."
                    exit 1
                else
                    echo "$prepareOut" | INFO
                    NOTICE "Finished preparing environment $spec"
                fi 
            fi
        done
    done
    NOTICE "Finished testing changed packages."
else
    ERROR "The package list to test is an empty string."
    ERROR "This should never happen, bailing out!"
    exit 1
fi
