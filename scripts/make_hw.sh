#!/bin/bash

# Copyright (C) 2017 Kaan Kara - Systems Group, ETH Zurich

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#*************************************************************************

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