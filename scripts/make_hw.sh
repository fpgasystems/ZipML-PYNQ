#!/bin/bash

if [[ $# -eq 0 ]]; then 
	echo "Usage: ./make_hw.sh <quantization_bits>"
	exit
fi

if [[ $1 -eq 0 ]]; then
	QUANTIZATION_BITS=0
	LOG2_QUANTIZATION_BITS=-1
	echo "QUANTIZATION_BITS: $QUANTIZATION_BITS"
	IP_NAME="floatFSGD"
elif [[ $1 -eq 1 ]]; then
	QUANTIZATION_BITS=1
	LOG2_QUANTIZATION_BITS=0
	echo "QUANTIZATION_BITS: $QUANTIZATION_BITS"
	IP_NAME="qFSGD"
elif [[ $1 -eq 2 ]]; then
	QUANTIZATION_BITS=2
	LOG2_QUANTIZATION_BITS=1
	echo "QUANTIZATION_BITS: $QUANTIZATION_BITS"
	IP_NAME="qFSGD"
elif [[ $1 -eq 4 ]]; then
	QUANTIZATION_BITS=4
	LOG2_QUANTIZATION_BITS=2
	echo "QUANTIZATION_BITS: $QUANTIZATION_BITS"
	IP_NAME="qFSGD"
elif [[ $1 -eq 8 ]]; then
	QUANTIZATION_BITS=8
	LOG2_QUANTIZATION_BITS=3
	echo "QUANTIZATION_BITS: $QUANTIZATION_BITS"
	IP_NAME="qFSGD"
else
	echo "Provide one of the following values for <quantization_bits>: 0, 1, 2, 4 or 8"
	exit
fi


if [ -n "$PYNQ_SGD_ROOT" ]; then
	echo "PYNQ_SGD_ROOT=$PYNQ_SGD_ROOT"

	SCRIPT_DIR="$PYNQ_SGD_ROOT/scripts"

	IP_REPO="$PYNQ_SGD_ROOT/output/$IP_NAME"
	VIVADO_SCRIPT=$SCRIPT_DIR/package_SGD.tcl
	vivado -mode batch -notrace -source $VIVADO_SCRIPT -tclargs $IP_NAME $IP_REPO $SCRIPT_DIR $LOG2_QUANTIZATION_BITS

	PROJ_NAME="pynq-sgd-vivado-Q$QUANTIZATION_BITS"
	VIVADO_OUT_DIR="$PYNQ_SGD_ROOT/output/$PROJ_NAME"
	VIVADO_SCRIPT=$SCRIPT_DIR/make-vivado-proj.tcl
	vivado -mode batch -notrace -source $VIVADO_SCRIPT -tclargs $PROJ_NAME $VIVADO_OUT_DIR $SCRIPT_DIR $IP_REPO $LOG2_QUANTIZATION_BITS

else
	echo "PYNQ_SGD_ROOT is NOT set!"
fi