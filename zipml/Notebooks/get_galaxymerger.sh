#!/bin/sh

# This script will grab the LibSVM formatted version of the
# Galaxy Merger data set if we don't already have it

if [ ! -d "galaxymerger" ]; then
	mkdir galaxymerger
fi

cd ./galaxymerger

if [ -f "galaxy_train.dat" ]; then
	echo "[galaxy_train] Nothing to do. Data is there."
fi
if [ ! -f "galaxy_train.dat" ]; then
	wget https://polybox.ethz.ch/index.php/s/iVLwhDuBszL4asc/download
	mv download galaxy_train.dat
fi
if [ -f "galaxy_test.dat" ]; then
	echo "[galaxy_test] Nothing to do. Data is there."
fi
if [ ! -f "galaxy_test.dat" ]; then
	wget https://polybox.ethz.ch/index.php/s/uySQBlS5qdu7DPz/download
	mv download galaxy_test.dat
fi

wget https://polybox.ethz.ch/index.php/s/nzx2LmstzuKLp1d/download
mv download merger.jpeg

wget https://polybox.ethz.ch/index.php/s/yG3vaVfFQLubMtP/download
mv download non_merger.jpeg