HCC Deployed Conda Environments
===============================

This repository holds configuration files to control the deployment of software
via conda environments on HCC resources.  The configuration, testing, and deployment
is done using the [Anaconda Project] (http://anaconda-project.readthedocs.io/en/latest/index.html)
software.  Environments are defined via yaml configuration files.  Each
environment may list one or more packages needed to specify what to install, any
other needed software, particular versions of dependencies, python version(s), etc.

The minimal set of packages (and dependencies) can then be "locked" into a specific
set of packages and versions needed to exactly reproduce the environment in another
location.  This allows identical conda environments to be programmatically created on
all HCC resources.

The structure of the repository is:
* `README.md` - this readme
* `anaconda-project.yml.edu` - an example project configuration file
* `scripts/` - scripts that run via CI jobs to test and deploy the packages
* `packages/` - the main body of the repository

Each directory under `packages/` is an Anaconda Project directory.  Typicially that
will be a particular software package.  For example, `packages/foo` for the software
package "foo".  Inside `packages/foo`, the `anaconda-project.yml` file will be created
to define environments to create.  For example, you may create environments named
`foo-1.0` and `foo-1.1` to have different versions of the package available.  If the
package is Python-based, you could create `foo-1.0-py27` for a Python 2.7 version,
`foo-1.0-py36` for Python 3.6, etc.  Once the environment has been minimally defined, 
it is then "locked".  This generates an `anaconda-project-lock.yml` file with the
specific versions needed to identicially recreate the environment.  The new
environment(s) can then be tested locally.  When testing is complete, the two 
yaml files are then added to a new git branch.  When the branch is pushed, a CI
job will run to test the new environment.  After the branch is merged, a CI job
will run on each cluster to deploy the new environment(s).

How to add a new package
------------------------

### Setup your environment

If you have not already, you will need to download and install [Ananconda] (https://www.anaconda.com/download).
Update Conda to the latest version and install the `anaconda-project` package:

```
conda update -y conda
conda install -y anaconda-project
```
Verify the `anaconda-project` command works by running `anaconda-project --version`:

```
[fedora@adam-build-host ~]$ anaconda-project --version
0.8.2
```

The `anaconda-project` command is used to do all manipulation, and provides
subcommands to define environments, instantiate them, etc.  Run `anaconda-project -h`
to see all the available subcommands.

Set the channel order to include the hcc channel, along with bioconda and
conda-forge, in the correct order:

```
conda config --add channels conda-forge
conda config --add channels bioconda
conda config --add channels hcc
```

### Add the package

For this example, we'll be adding the `blast` package, version 2.7.1.  Create
a directory under `packages` to hold the yaml files:

```
mkdir packages/blast
```

Copy the example yaml file (drop the `.example` from the filename) into that 
directory and cd into it:

```
cp anaconda-project.yml.example packages/blast/anaconda-project.yml
cd packages/blast
```

Open the `anaconda-project.yml` in an editor and change the `name` and 
`description` fields as appropriate.

Creating environments using `anaconda-project` is similar to using `conda`.
Each environment is given a name and a list of required packages and versions
to be installed.  **Note that the environment name cannot contain spaces.**
This will break the script that parses those names for testing and deployment.
Create an environment called `blast-2.7.1` and specify version
2.7.1 is required:

```
anaconda-project add-env-spec -n blast-2.7.1 blast=2.7.1
```

Since this is the first environment added, it print a message saying the 
env_specs section is empty and prompt to add a new spec.  Answer yes:

```
anaconda-project.yml: The env_specs section is empty.
Add an environment spec to anaconda-project.yml? y
```

It will then "solve" the environment (resolving dependencies, etc.) and create
it under a new `envs` subdirectory.  You should see the normal output as 
`conda` creates a new environment, followed by the last line saying the
environment was added:

```
Added environment blast-2.7.1 to the project file.
```

However, there is an idiosyncrasy to `anaconda-project` when it creates an
environment for the first time.  It also creates an environment called `default`
with the `anaconda` package as a requirement.  You can see this by running the 
command to list all envs:

```
[fedora@adam-build-host blast]$ anaconda-project list-env-specs
Environments for project: /home/fedora/anaconda-project-test/packages/blast

Name         Description
====         ===========
blast-2.7.1
default      Default environment spec for running commands
```

**This `default` environment must be removed before committing the new yaml
files.**  To do this, run the command to delete the environment:

```
[fedora@adam-build-host blast]$ anaconda-project remove-env-spec -n default
Nothing to clean up for environment 'default'.
Removed environment default from the project file.
```

Verify it's no longer present by running the list envs command again:

```
[fedora@adam-build-host blast]$ anaconda-project list-env-specs
Environments for project: /home/fedora/anaconda-project-test/packages/blast

Name         Description
====         ===========
blast-2.7.1
```

*Note that this is only necessary when adding a package for the first time.*
When adding additional versions, etc. `anaconda-project` will not recreate
the `default` environment.

### Test the environment

The new environment is created in the `envs` subdirectory.  To test it, run
`source activate` along with the full path to the environment directory:

```
[fedora@adam-build-host blast]$ source activate $PWD/envs/blast-2.7.1
```

Run whatever commands you think are necessary to verify everything is correct, 
i.e.

```
(blast-2.7.1) [fedora@adam-build-host blast]$ blastn -version
blastn: 2.7.1+
 Package: blast 2.7.1, build Mar 29 2018 05:00:23
 ```
 
### Lock the environment
 
Although the environment was created by giving a single package and version
requirement, that's not sufficient to completely define it.  Almost every 
package has at least one dependency; many have several or more.  The version
of these dependencies can change over time; creating a new environment with the
same package tomorrow can result in different behavior if the dependencies have
changed.  To avoid this, the environment can be "locked".  This creates a 
complete list of all dependencies and versions needed to identicially re-create
the environment elsewhere and at any time.  By locking the environment, we
guarantee identical and reproducible behavior.  To lock the environment, run

```
anaconda-project lock
```

You should see output similar to the following:

```
Updating locked dependencies for env spec blast-2.7.1...
Resolving conda packages for linux-64
Changes to locked dependencies for blast-2.7.1:
  platforms:
+   linux-64
  packages:
+   linux-64:
+     blast=2.7.1=boost1.64_3
<< long list of dependencies >>
Added locked dependencies for env spec blast-2.7.1 to anaconda-project-lock.yml.
Project dependencies are locked.
```

There will also be a newly created `anaconda-project-lock.yml` file that 
contains the complete environment specification.

### Create a branch and commit the yaml files

The two yaml files are what get committed to git.  Create a new branch, using
the package name and version for clarity:

```
git checkout -b blast-2.7.1
```

Change directory back to the top-level of the repo, and add and commit the new
files:

```
cd ../..
git add packages/blast/anaconda-project-lock.yml packages/blast/anaconda-project.yaml
git commit -m "Added blast 2.7.1."
```

Then push your new branch to gitlab:

```
git push origin blast-2.7.1
```

A CI test job will run to test creating the environment from scratch, along
with a few other sanity checks.  If the test fails, add any fixes to your branch 
and do a push which will trigger another build.  Rinse and repeat until 
everything works.

### Create a merge request

Assuming the test job passes, create a merge request on the repository page
to merge your branch into master.  Upon merge, another CI job will be
triggered.  This will deploy the new environment(s) on all three HCC machines
under `/util/opt/anaconda/deployed-conda-envs`.  You can then create a module
file adding the `bin/` path of the new environment.

### Adding a version, updating the existing environment(s), etc.

If you are adding a new version to an existing package or updating an existing
environment in some other way, you can simply run the relevant `anaconda-project`
command(s), followed by the lock command.  For example, suppose the blast package
with version 2.7.1 has already been added and you wish to add version 2.6.0.
The two yaml files in `packages/blast` directory thus already exist.
In the `packages/blast` directory, run

```
anaconda-project add-env-spec -n blast-2.6.0 blast=2.6.0
anaconda-project lock
```

to add a new environment with the 2.6.0 version and update the lock file.
Proceed as above to create a new branch, add and commit the updated files, create
a merge request, etc.

### Skip deploying a package on a particular resource

By default, a package and its environments are deployed to all three HCC machines.
There may be instances where it is desireable to not deploy a particular package
to a particular machine.  To do so, create a file called `SKIP_DEPLOY` alongside
the yaml files in the package's directory.  Add the names of the machines to
skip deployment on (`Crane`, `Tusker`, `Sandhills`) to the file, one name per line.
