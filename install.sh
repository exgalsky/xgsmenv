#!/bin/bash

while getopts "v" opt; do
    case $opt in
	v) set -x # print commands as they are run so we know where we are if something fails
	   ;;
    esac
done
echo Starting xgsmenv installation at $(date)
SECONDS=0

# Defaults
if [ -z $CONF ] ; then CONF=perlmutter; fi
if [ -z $PKGS ] ; then PKGS=default;    fi

# Script directory
pushd $(dirname $0) > /dev/null
topdir=$(pwd)
popd > /dev/null

scriptname=$(basename $0)
fullscript="${topdir}/${scriptname}"

CONFDIR=$topdir/conf

CONFIGUREENV=$CONFDIR/$CONF-env.sh
INSTALLPKGS=$CONFDIR/$PKGS-pkgs.sh

export PATH=$CONDADIR/bin:$PATH

# Initialize environment
source $CONFIGUREENV

# Set installation directories
XGSMENV=$PREFIX/$XGSMENVVERSION
CONDADIR=$XGSMENV/conda
MODULEDIR=$XGSMENV/modulefiles/xgsmenv

# Install conda root environment
echo Installing conda root environment at $(date)

mkdir -p $CONDADIR/bin
mkdir -p $CONDADIR/lib

curl -SL $MINICONDA \
  -o miniconda.sh \
    && /bin/bash miniconda.sh -b -f -p $CONDADIR

source $CONDADIR/bin/activate
conda create -y -n xgsmenv python=3.10
conda activate xgsmenv
export PYVERSION=$(python -c "import sys; print(str(sys.version_info[0])+'.'+str(sys.version_info[1]))")
echo Using Python version $PYVERSION

# Install packages
source $INSTALLPKGS

# Compile python modules
echo Pre-compiling python modules at $(date)

python$PYVERSION -m compileall -f "$CONDADIR/lib/python$PYVERSION/site-packages"

# Set permissions
echo Setting permissions at $(date)

chgrp -R $GRP $CONDADIR
chmod -R u=rwX,g=rX,o-rwx $CONDADIR

# Install modulefile
echo Installing the xgsmenv modulefile to $MODULEDIR at $(date)

mkdir -p $MODULEDIR

cp $topdir/modulefile.gen xgsmenv.module

sed -i 's@_CONDADIR_@'"$CONDADIR"'@g' xgsmenv.module
sed -i 's@_XGSMENVVERSION_@'"$XGSMENVVERSION"'@g' xgsmenv.module
sed -i 's@_PYVERSION_@'"$PYVERSION"'@g' xgsmenv.module
sed -i 's@_CONDAPRGENV_@'"$CONDAPRGENV"'@g' xgsmenv.module

cp xgsmenv.module $MODULEDIR/$XGSMENVVERSION
cp xgsmenv.modversion $MODULEDIR/.version_$XGSMENVVERSION

chgrp -R $GRP $MODULEDIR
chmod -R u=rwX,g=rX,o-rwx $MODULEDIR

# All done
echo Done at $(date)
duration=$SECONDS
echo "Installation took $(($duration / 60)) minutes and $(($duration % 60)) seconds."
