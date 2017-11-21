#!/bin/sh

# This script will grab the LibSVM formatted version of the
# YearPredictionMSD data set if we don't already have it

if [ ! -d "YearPredictionMSD" ]; then
	mkdir YearPredictionMSD
fi

cd ./YearPredictionMSD
if [ -f "YearPredictionMSD" ]; then
	echo "[YearPredictionMSD] Nothing to do. Data is there."
fi
if [ ! -f "YearPredictionMSD" ]; then
	wget https://www.csie.ntu.edu.tw/~cjlin/libsvmtools/datasets/regression/YearPredictionMSD.bz2
	bzip2 -d YearPredictionMSD.bz2
fi
if [ -f "YearPredictionMSD.t" ]; then
	echo "[YearPredictionMSD.t] Nothing to do. Data is there."
fi
if [ ! -f "YearPredictionMSD.t" ]; then
	wget https://www.csie.ntu.edu.tw/~cjlin/libsvmtools/datasets/regression/YearPredictionMSD.t.bz2
	bzip2 -d YearPredictionMSD.t.bz2
fi

