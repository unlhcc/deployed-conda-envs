#!/usr/bin/env python

import subprocess as sp
import requests
import json
import argparse
import textwrap
import os.path
import sys

def parseOptions():
    """Parse command-line arguments."""
    description =  \
        textwrap.wrap("This helper script generates a lua module file suited for use with Lmod.  " + \
        "You must supply the package name and the path to the environment containing the package.")
    description = "\n".join(description)

    epilog = textwrap.wrap("Example usage: ") + \
        textwrap.wrap("%(prog)s blast ./packages/blast/envs/blast-2.7.1")
    epilog = "\n".join(epilog)

    parser = argparse.ArgumentParser(description=description,formatter_class=argparse.RawDescriptionHelpFormatter,epilog=epilog)
    parser.add_argument("package_name", help="The package name to generate the lua file for.")
    parser.add_argument("environment_path", help="Path to the environment directory.")
    parser.add_argument("--deploy-root", help="The path to the production repository location.  " + \
        "Default is '%(default)s'", default='/util/opt/anaconda/deployed-conda-envs')
    parser.add_argument('-o','--outputdir',help='Output directory for files, defaults to the package directory.')


    args = parser.parse_args()
    return args


def getPackageDetails(package_name, full_path):
    """Run conda-list to get the package version and channel from the environment."""

    cmds = ["conda", "list", "-f", "--json", "-p", full_path, package_name]
    try:
        p = sp.run(cmds, stdout=sp.PIPE, stderr=sp.PIPE, check=True)
        p.stdout = p.stdout.decode(errors='replace')
    except sp.CalledProcessError as e:
        e.stderr = e.stderr.decode(errors='replace')
        e.stdout = e.stdout.decode(errors='replace')
        print("Running 'conda list' failed with errors:")
        print(e.stdout)
        print(e.stderr)
        raise e

    package_info = json.loads(p.stdout)
    if len(package_info) == 0:
        print("Error:  package '{}' not found in environment '{}'.".format(package_name, full_path))
        print("Double-check the package name.")
        sys.exit(1)
    if len(package_info) > 1:
        print("Error:  more than one package found matching '{}*' in environment '{}'.".format(package_name, full_path))
        print("Make sure you specify the full name of the package to avoid multiple results.")
        sys.exit(1)

    returned_name = package_info[0]['name']
    returned_version = package_info[0]['version']
    returned_channel = package_info[0]['channel']

    if not package_name == returned_name:
        print("Error:  the package name in the environment differs from the one provided.")
        print("The package '{}' was found but '{}' was provided.".format(returned_name, package_name))
        print("Be sure to specify the exact name of the package in the environment.")
        sys.exit(1)

    return(returned_name,returned_version,returned_channel)

def queryAnacondaOrg(package_name, channel):
    """Query anaconda.org to get the package details (homepage, description, etc.)"""

    base_url = 'https://api.anaconda.org/package'
    # redirect to the 'anaconda' channel for querying packages in default channel
    if channel == 'defaults':
        channel = 'anaconda'
    full_url = '/'.join([base_url, channel, package_name])
    r = requests.get(full_url)
    if r.status_code == 200:
        package_info = json.loads(r.content)
        homepage = package_info['home']
        summary = package_info['summary']
    else:
        print("Error querying anaconda.org for package information:")
        print("{} - {}".format(r.status_code, r.reason))
        print("The URL queried was:")
        print("{}".format(full_url))
        sys.exit(1)

    return(homepage, summary)

def generateLuaFile(deploy_root, output_dir, abs_env_path, package_name, version, homepage, summary):
    """Generate the lua file."""

    # figure out env name and paths
    # there HAS to be a better way to do this
    # ---
    # the path relative *to the root of the repo*
    relative_path = abs_env_path[abs_env_path.rfind('packages'):]
    if not output_dir:
        output_dir = abs_env_path[:abs_env_path.rfind('envs')]
    # the relative path from the repo root to the package's 'envs/' directory
    envs_path = os.path.split(relative_path)[0]
    # the environment name
    env_name = os.path.split(abs_env_path)[1]
    # the absolute, full path to the deploy location of the env
    deploy_path = os.path.join(deploy_root, relative_path)

    # generate the lua file text
    lua_file_text = []
    # help text
    help_text = textwrap.wrap("help(") + textwrap.wrap("[[") + \
        textwrap.wrap("This module loads {}.".format(package_name.capitalize())) + \
        textwrap.wrap("Version {}".format(version)) + \
        textwrap.wrap("]]") + textwrap.wrap(")")
    help_text = "\n".join(help_text)
    lua_file_text.append(help_text)
    # name
    whatis_name = 'whatis("Name: {}")'.format(package_name.capitalize())
    lua_file_text.append(whatis_name)
    # version
    whatis_version = 'whatis("Version: {}")'.format(version)
    lua_file_text.append(whatis_version)
    # Conda metadata doesn't include category or keywords, but insert the
    # lines to make it easier to manually fill in.
    # ---
    # category
    whatis_category = 'whatis("Category: ")'
    lua_file_text.append(whatis_category)
    # keywords
    whatis_keywords = 'whatis("Keywords: ")'
    lua_file_text.append(whatis_keywords)
    # url
    if homepage != 'None':
        whatis_url = 'whatis("URL: {}")'.format(homepage)
    else:
        whatis_url = 'whatis("URL: UNKNOWN")'
    lua_file_text.append(whatis_url)
    # description
    if summary != 'None':
        whatis_description = 'whatis("Description: {}")'.format(summary)
    else:
        whatis_description = 'whatis("Description: UNKNOWN")'
    lua_file_text.append(whatis_description)
    # blank line for readability
    lua_file_text.append('')
    # environment name
    default_env = 'pushenv("CONDA_DEFAULT_ENV", "{}")'.format(env_name)
    lua_file_text.append(default_env)
    # environment(s) path
    envs_path = 'append_path("CONDA_ENVS_PATH", "{}")'.format(os.path.join(deploy_root,envs_path))
    lua_file_text.append(envs_path)
    # PATH
    prepend_path = 'prepend_path("PATH", "{}")'.format(os.path.join(deploy_path,"bin"))
    lua_file_text.append(prepend_path)

    file_contents = "\n".join(lua_file_text)

    output_file_path = os.path.join(output_dir, env_name + ".lua")
    with open(output_file_path, 'w') as outfile:
        outfile.write(file_contents)

    return output_file_path

def main():
    """Creates a lua Lmod file based on a conda environment direcotry and package name."""
    args = parseOptions()

    abs_env_path = os.path.abspath(args.environment_path)
    if not os.path.isdir(abs_env_path):
        print("Error:  Environment directory '{}' does not exist!".format(abs_env_path))
        sys.exit(1)

    (name, version, channel) = getPackageDetails(args.package_name, abs_env_path)
    (homepage, summary) = queryAnacondaOrg(name, channel)
    generated_file = generateLuaFile(args.deploy_root, args.outputdir, abs_env_path, name, version, homepage, summary)
    print("Generated lua file is at '{}'".format(generated_file))
    sys.exit(0)


if __name__ == '__main__':
    main()
