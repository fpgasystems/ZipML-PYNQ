import zipml
import numpy as np
import time
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--train', help='/path/to/mnist data set for training', required=True)
parser.add_argument('--test', help='/path/to/mnist.t data set for testing', required=True)
args = parser.parse_args()

num_epochs = 10
step_size = 1.0/(1 << 12)
cost_pos = 1.0
cost_neg = 1.5

Z = zipml.ZipML_SGD(on_pynq=1, bitstreams_path=zipml.BITSTREAMS, ctrl_base=0x41200000, dma_base=0x40400000, dma_buffer_size=32*1024*1024)

start = time.time()
Z.load_libsvm_data(args.train, 10000, 780)
print('a loaded, time: ' + str(time.time()-start) )
Z.a_normalize(to_min1_1=0, row_or_column='r')


xs = np.zeros((Z.num_features, 10))
for c in range(0, 10):
	start = time.time()
	Z.b_binarize(c)
	print('b binarized for ' + str(c) + ", time: " + str(time.time()-start) )
	start = time.time()
	
	Z.configure_SGD_FPGA(num_epochs, step_size, cost_pos, cost_neg, 1, c)
	x_history = Z.SGD_FPGA(num_epochs)

	print('Training time: ' + str(time.time()-start) )
	initial_loss = Z.calculate_L2SVM_loss(np.zeros(Z.num_features), cost_pos, cost_neg, 0, 1)
	print('Initial loss: ' + str(initial_loss))
	for e in range(0, num_epochs):
		loss = Z.calculate_L2SVM_loss(x_history[:,e], cost_pos, cost_neg, 0, 1)
		print('Epoch ' + str(e) + ' loss: ' + str(loss) )

	xs[:,c] = x_history[:,num_epochs-1]



Z.a_quantize(quantization_bits=1)
xs = np.zeros((Z.num_features, 10))
for c in range(0, 10):
	start = time.time()
	Z.b_binarize(c)
	print('b binarized for ' + str(c) + ", time: " + str(time.time()-start) )
	start = time.time()
	
	Z.configure_SGD_FPGA(num_epochs, step_size, cost_pos, cost_neg, 1, c)
	x_history = Z.SGD_FPGA(num_epochs)

	print('Training time: ' + str(time.time()-start) )
	initial_loss = Z.calculate_L2SVM_loss(np.zeros(Z.num_features), cost_pos, cost_neg, 0, 1)
	print('Initial loss: ' + str(initial_loss))
	for e in range(0, num_epochs):
		loss = Z.calculate_L2SVM_loss(x_history[:,e], cost_pos, cost_neg, 0, 1)
		print('Epoch ' + str(e) + ' loss: ' + str(loss) )

	xs[:,c] = x_history[:,num_epochs-1]



Z.load_libsvm_data(args.test, 10000, 780)
Z.a_normalize(to_min1_1=0, row_or_column='r');

classes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
matches = Z.multi_classification(xs, classes)

print('matches ' + str(matches) + ' out of ' + str(Z.num_samples) + ' samples.')
