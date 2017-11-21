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

import zipml
import numpy as np
import time
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--train', help='/path/to/galaxy_train data set for training', required=True)
parser.add_argument('--test', help='/path/to/galaxy_test data set for testing', required=True)

args = parser.parse_args()

Z = zipml.ZipML_SGD(on_pynq=1, bitstreams_path=zipml.BITSTREAMS, ctrl_base=0x41200000, dma_base=0x40400000, dma_buffer_size=32*1024*1024)

start = time.time()
Z.load_libsvm_data(args.train, 3000, 2048)
print('a loaded, time: ' + str(time.time()-start) )
Z.a_normalize(to_min1_1=0, row_or_column='r')
Z.b_binarize(1)
print('b binarized for ' + str(1.0) + ", time: " + str(time.time()-start) )

# Set training related parameters
num_epochs = 50
step_size = 1.0/(1 << 8)
cost_pos = 1.0
cost_neg = 1.0

# Train on the CPU
start = time.time()
x_history_CPU = Z.L2SVM_SGD(num_epochs, step_size, cost_pos, cost_neg, 0, 1)
print('Training time: ' + str(time.time()-start) )
initial_loss = Z.calculate_L2SVM_loss(np.zeros(Z.num_features), cost_pos, cost_neg, 0, 1)
print('Initial loss: ' + str(initial_loss))
for e in range(0, num_epochs):
	loss = Z.calculate_L2SVM_loss(x_history_CPU[:,e], cost_pos, cost_neg, 0, 1)
	print('Epoch ' + str(e) + ' loss: ' + str(loss) )

# Train on the FPGA
start = time.time()
Z.configure_SGD_FPGA(num_epochs, step_size, cost_pos, cost_neg, 1, 1.0)
x_history_FPGA = Z.SGD_FPGA(num_epochs)
print('Training time: ' + str(time.time()-start) )
initial_loss = Z.calculate_L2SVM_loss(np.zeros(Z.num_features), cost_pos, cost_neg, 0, 1)
print('Initial loss: ' + str(initial_loss))
for e in range(0, num_epochs):
	loss = Z.calculate_L2SVM_loss(x_history_FPGA[:,e], cost_pos, cost_neg, 0, 1)
	print('Epoch ' + str(e) + ' loss: ' + str(loss) )


Z.load_libsvm_data(args.test, 1000, 2048)
Z.a_normalize(to_min1_1=0, row_or_column='r')
Z.b_binarize(1)
matches = Z.binary_classification(np.zeros(Z.num_features))
print('No training: matches ' + str(matches) + ' out of ' + str(Z.num_samples) + ' samples.')
for e in range(0, num_epochs):
	matches = Z.binary_classification(x_history_FPGA[:,e])
	print('matches ' + str(matches) + ' out of ' + str(Z.num_samples) + ' samples.')