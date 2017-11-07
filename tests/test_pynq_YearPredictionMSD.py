import zipml
import numpy as np
import time
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--train', help='/path/to/mnist data set for training', required=True)
args = parser.parse_args()

num_epochs = 10
step_size = 1.0/(1 << 12)

Z = zipml.ZipML_SGD(on_pynq=1, bitstreams_path=zipml.BITSTREAMS, ctrl_base=0x41200000, dma_base=0x40400000, dma_buffer_size=32*1024*1024)

start = time.time()
Z.load_libsvm_data(args.train, 10000, 90)
print('a loaded, time: ' + str(time.time()-start) )
Z.a_normalize(to_min1_1=1, row_or_column='c');
Z.b_normalize(to_min1_1=0)

# Train on the CPU
start = time.time()
x_history = Z.LINREG_SGD(num_epochs=num_epochs, step_size=step_size, regularize=0)
print('Performed linear regression on cadata. Training time: ' + str(time.time()-start))
initial_loss = Z.calculate_LINREG_loss(np.zeros(Z.num_features), 0)
print('Initial loss: ' + str(initial_loss))
for e in range(0, num_epochs):
	loss = Z.calculate_LINREG_loss(x_history[:,e], 0)
	print('Epoch ' + str(e) + ' loss: ' + str(loss) )

Z.a_quantize(quantization_bits=8)

# Train on FPGA
start = time.time()
Z.configure_SGD_FPGA(num_epochs, step_size, -1, -1, 0, 0)
print('FPGA configure time: ' + str(time.time()-start) )
start = time.time()
x_history = Z.SGD_FPGA(num_epochs)
print('FPGA train time: ' + str(time.time()-start) )
initial_loss = Z.calculate_LINREG_loss(np.zeros(Z.num_features), 0)
print('Initial loss: ' + str(initial_loss))
for e in range(0, num_epochs):
	loss = Z.calculate_LINREG_loss(x_history[:,e], 0)
	print('Epoch ' + str(e) + ' loss: ' + str(loss) )
