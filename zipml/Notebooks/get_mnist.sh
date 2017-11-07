#!/bin/sh

# This script will grab the LibSVM formatted version of the
# MNIST database if we don't already have it.mnist

if [ ! -d "mnist" ]; then
	mkdir mnist
fi

cd ./mnist
if [ -f "mnist" ]; then
	echo "[mnist] Nothing to do. Data is there."
fi
if [ ! -f "mnist" ]; then
	wget http://www.csie.ntu.edu.tw/~cjlin/libsvmtools/datasets/multiclass/mnist.bz2
	bzip2 -d mnist.bz2
fi
if [ -f "mnist.t" ]; then
	echo "[mnist.t] Nothing to do. Data is there."
fi
if [ ! -f "mnist.t" ]; then
	wget http://www.csie.ntu.edu.tw/~cjlin/libsvmtools/datasets/multiclass/mnist.t.bz2
	bzip2 -d mnist.t.bz2
fi

