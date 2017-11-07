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

import numpy as np
from numpy import linalg as la
import time

class ZipML_SGD:
	def __init__(self, on_pynq, bitstreams_path, ctrl_base, dma_base, dma_buffer_size):
		self.a = None;
		self.b = None;
		self.binarized_b = None;

		self.data_start_index = 0
		self.data_end_index = 0

		self.num_samples = 0;
		self.num_features = 0;
		self.to_int_scaler = 0x00800000
		self.quantization_bits = 0
		self.on_pynq = on_pynq

		if self.on_pynq == 1:
			from pynq import Overlay
			from pynq.mmio import MMIO
			from zipml.modified_dma import DMA
			import zipml.modified_dma as _dma

			self.Overlay = Overlay
			self._dma = _dma

			self.bitstream = 'floatFSGD.bit'
			self.bitstreams_path = bitstreams_path
			ol = self.Overlay(self.bitstreams_path + '/' + self.bitstream)
			ol.download()
			print(self.bitstream + ' is loaded')

			self.max_dma_transfer_size = 7*1024*1024

			self.sgd_ctrl = MMIO(ctrl_base, length=16)
			print('Got sgd_ctrl!')

			config = {
				'DeviceId' : 0,
				'HasStsCntrlStrm' : 0,
				'HasMm2S' : 1,
				'HasMm2SDRE' : 0,
				'Mm2SDataWidth' : 64,
				'HasS2Mm' : 1,
				'HasS2MmDRE' : 0,
				'S2MmDataWidth' : 32,
				'HasSg' : 0,
				'Mm2sNumChannels' : 1,
				'S2MmNumChannels' : 1,
				'Mm2SBurstSize' : 256,
				'S2MmBurstSize' : 256,
				'MicroDmaMode' : 0,
				'AddrWidth' : 32 }
			self.sgd_dma = DMA(dma_base, self._dma.DMA_BIDIRECTIONAL, attr_dict=config)
			print('Got sgd_dma!')

			self.dma_buffer_size = dma_buffer_size
			self.sgd_dma.create_buf(self.dma_buffer_size, cacheable=0)
			print('Allocated buffer of size: ' + str(self.dma_buffer_size) + ' bytes')
			self.dma_buffer = None

	def load_libsvm_data(self, path_to_file, num_samples, num_features):
		if self.on_pynq == 1:
			if self.quantization_bits != 0:
				self.quantization_bits = 0
				self.bitstream = 'floatFSGD.bit'
				ol = self.Overlay(self.bitstreams_path + '/' + self.bitstream)
				ol.download()
				print(self.bitstream + ' is loaded')

			self.num_samples = num_samples
			self.num_features = num_features+1 # Add bias

			if self.num_features%2 == 1:
				self.num_values_one_row = self.num_features+3
			else:
				self.num_values_one_row = self.num_features+2

			print('num_values_one_row: ' + str(self.num_values_one_row))

			self.dma_buffer = self.sgd_dma.get_buf("float *")

			f = open(path_to_file, 'r')
			for i in range(0, self.num_samples):
				self.dma_buffer[int(i*self.num_values_one_row)] = 1
				line = f.readline()
				items = line.split()
				self.dma_buffer[int((i+1)*self.num_values_one_row-2)] = float(items[0])
				for j in range(1, len(items)):
					item = items[j].split(':')
					self.dma_buffer[int( i*self.num_values_one_row + int(item[0]) )] = float(item[1])

			self.total_size = self.num_values_one_row*self.num_samples
			buf = self.sgd_dma.get_cbuf(self.dma_buffer, self.total_size)

			self.ab = np.frombuffer(buf, dtype=np.dtype('f4'), count=self.total_size, offset=0)
			self.ab = np.reshape(self.ab, (self.num_samples, self.num_values_one_row))
			self.a = self.ab[:,0:self.num_features]
			self.b = self.ab[:,self.num_values_one_row-2]

			self.data_start_index = 0
			self.data_end_index = self.total_size
		else:
			if self.quantization_bits != 0:
				self.quantization_bits = 0

			self.num_samples = num_samples
			self.num_features = num_features+1 # Add bias

			self.a = np.zeros((self.num_samples, self.num_features))
			self.b = np.zeros(self.num_samples)

			f = open(path_to_file, 'r')
			for i in range(0, self.num_samples):
				self.a[i, 0] = 1;
				line = f.readline()
				items = line.split()
				self.b[i] = float(items[0])
				for j in range(1, len(items)):
					item = items[j].split(':')
					self.a[i, int(item[0])] = float(item[1])


	def a_normalize(self, to_min1_1, row_or_column):
		if self.quantization_bits != 0:
			raise RuntimeError("Normalization can only be called on non-quantized data!")

		self.a_to_min1_1 = to_min1_1
		if row_or_column == 'r':
			for i in range(0, self.a.shape[0]):
				start = time.time()
				amax = np.amax(self.a[i,1:])
				amin = np.amin(self.a[i,1:])
				arange = amax - amin

				if arange > 0:
					if to_min1_1 == 1:
						self.a[i,1:] = np.subtract( np.divide( np.subtract(self.a[i,1:], amin), arange/2), 1)
					else:
						self.a[i,1:] = np.divide( np.subtract(self.a[i,1:], amin), arange)
		else:
			for j in range(1, self.a.shape[1]):
				amax = np.amax(self.a[:,j])
				amin = np.amin(self.a[:,j])
				arange = amax - amin

				if arange > 0:
					if to_min1_1 == 1:
						self.a[:,j] = np.subtract( np.divide( np.subtract( self.a[:,j], amin ), arange/2), 1)
					else:
						np.divide( np.subtract( self.a[:,j], amin ), arange)


	def __prepare_quantized_memory(self, quantized_a):
		address32 = self.data_end_index
		addressQ = 0
		num_quantized_items_in_word = 32/self.quantization_bits
		mask = (1 << self.quantization_bits)-1
		print('num_quantized_items_in_word: ' + str(num_quantized_items_in_word) )
		print('mask: ' + str(mask) )

		for i in range(0, self.num_samples):
			self.dma_buffer = self.sgd_dma.get_buf("uint32_t *")
			temp = 0
			for j in range(0, self.num_features):
				q = int(quantized_a[i, j])
				#print('q: ' + str(q) + ', ' + hex(q) )
				temp = temp | ( (q&mask) << int(self.quantization_bits*(addressQ%num_quantized_items_in_word)) )
				addressQ += 1
				if addressQ%num_quantized_items_in_word == 0:
					#print( 'temp: ' + hex(temp) )
					self.dma_buffer[address32] = temp
					address32 += 1
					temp = 0
			if addressQ%num_quantized_items_in_word != 0:
				self.dma_buffer[address32] = temp
				address32 += 1
				addressQ += num_quantized_items_in_word-addressQ%num_quantized_items_in_word
				temp = 0
			if address32%2 == 1:
				address32 += 1
				addressQ += num_quantized_items_in_word
			self.dma_buffer = self.sgd_dma.get_buf("float *")
			self.dma_buffer[address32] = self.b[i]
			address32 += 2
			addressQ += 2*num_quantized_items_in_word

		self.data_start_index = self.data_end_index
		self.data_end_index = address32
		return self.data_end_index - self.data_start_index

	def a_quantize(self, quantization_bits):
		if quantization_bits == 1:
			self.bitstream = 'qFSGD1.bit'
		elif quantization_bits == 2:
			self.bitstream = 'qFSGD2.bit'
		elif quantization_bits == 4:
			self.bitstream = 'qFSGD4.bit'
		elif quantization_bits == 8:
			self.bitstream = 'qFSGD8.bit'
		else:
			raise RuntimeError("Quantization function is called with invalid quantization_bits: " + str(quantization_bits) )

		self.quantization_bits = quantization_bits

		num_levels = (1 << (quantization_bits-1)) + 1
		print('num_levels: ' + str(num_levels) )
		if self.a_to_min1_1 == 0:
			quantized_a = np.rint( np.multiply(num_levels-1, self.a) )
		else:
			quantized_a = np.rint( np.multiply((num_levels-1)/2, self.a) )

		# for i in range(0, 5):
		# 	print('a[' + str(i) + ']: ' + str(self.a[i,:]) )
		# 	print('quantized_a[' + str(i) + ']: ' + str(quantized_a[i,:]) )

		if self.on_pynq == 1:
			ol = self.Overlay(self.bitstreams_path + '/' + self.bitstream)
			ol.download()
			print(self.bitstream + ' is loaded')

			self.total_size = self.__prepare_quantized_memory(quantized_a)
			print('self.total_size: ' + str(self.total_size))
			

	def b_normalize(self, to_min1_1):
		bmax = np.amax(self.b)
		bmin = np.amin(self.b)
		brange = bmax- bmin
		if to_min1_1 == 1:
			for i in range(0, self.b.shape[0]):
				self.b[i] = ((self.b[i]-bmin)/brange)*2.0 - 1.0
		else:
			for i in range(0, self.b.shape[0]):
				self.b[i] = (self.b[i]-bmin)/brange


	def b_binarize(self, value):
		self.binarized_b = np.zeros(self.num_samples)
		for i in range(0, self.b.shape[0]):
			if self.b[i] == value:
				self.binarized_b[i] = 1.0
			else:
				self.binarized_b[i] = -1.0


	def calculate_L2SVM_loss(self, x, cost_pos, cost_neg, regularize, use_binarized):
		if use_binarized == 1:
			b_here = self.binarized_b
		else:
			b_here = self.b

		loss = 0
		for i in range(0, self.a.shape[0]):
			dot = np.dot(self.a[i,:], x)
			temp = 1 - dot*b_here[i]
			if temp > 0:
				if b_here[i] > 0:
					loss = loss + 0.5*cost_pos*temp*temp
				else:
					loss = loss + 0.5*cost_neg*temp*temp

		norm = la.norm(x)
		loss = loss + regularize*0.5*norm*norm

		return loss

	def L2SVM_SGD(self, num_epochs, step_size, cost_pos, cost_neg, regularize, use_binarized):
		if use_binarized == 1:
			b_here = self.binarized_b
		else:
			b_here = self.b

		x_history = np.zeros((self.num_features, num_epochs))
		x = np.zeros(self.num_features)

		for epoch in range(0, num_epochs):
			for i in range(0, self.a.shape[0]):
				dot = np.dot(self.a[i,:], x)
				if 1 > b_here[i] * dot:
					if b_here[i] > 0:
						gradient = cost_pos*(dot - b_here[i])*self.a[i,:] + regularize*x	
					else:
						gradient = cost_neg*(dot - b_here[i])*self.a[i,:] + regularize*x
					x = x - step_size*gradient
			x_history[:,epoch] = x
			
		return x_history

	def calculate_LINREG_loss(self, x, regularize):
		loss = 0
		for i in range(0, self.a.shape[0]):
			dot = np.dot(self.a[i,:], x)
			temp = dot - self.b[i]
			loss = loss + temp*temp

		norm = la.norm(x)
		loss = loss/(2*self.num_samples) + regularize*0.5*norm*norm

		return loss

	def LINREG_SGD(self, num_epochs, step_size, regularize):
		x_history = np.zeros((self.num_features, num_epochs))
		x = np.zeros(self.num_features)

		for epoch in range(0, num_epochs):
			for i in range(0, self.a.shape[0]):
				dot = np.dot(self.a[i,:], x)
				gradient = (dot - self.b[i])*self.a[i,:] + regularize*x
				x = x - step_size*gradient
			x_history[:,epoch] = x

		return x_history

	def multi_classification(self, xs, classes):
		matched_class = -1
		count_trues = 0
		for i in range(0, self.a.shape[0]):
			mx = -1000.0
			for c in range(0, len(classes)):
				dot = np.dot(xs[:,c], self.a[i,:])
				if dot > mx:
					mx = dot
					matched_class = classes[c]
			if matched_class == self.b[i]:
				count_trues = count_trues + 1

		return count_trues


	def configure_SGD_FPGA(self, num_epochs, step_size, cost_pos, cost_neg, b_binarize, b_to_binarize):
		if self.on_pynq == 0:
			raise RuntimeError("configure_SGD_FPGA can only be called on PYNQ!")

		# Reserved numbers for configuration
		MAGIC1 = 0x39e904330f1a0df2
		MAGIC2 = 0xb209505f9f560afe
		MAGIC3 = 0x891ebbfdb9d5f766
		MAGIC4 = 0xc049cea2e9f6957d
		MAGIC5 = 0xfe9134a9b660b182
		SEND_CONFIG = 0xabcaabcaabcaabca
		THE_END = 0xabcdabcdabcdabcd

		lambda_shifter = 32
		mini_batch_size = 0
		decrease_step_size = 0

		index64 = int( self.data_end_index/2 )

		self.dma_buffer = self.sgd_dma.get_buf("uint64_t *")
		self.dma_buffer[index64] = THE_END
		index64 += 1

		start_index = index64*2

		self.dma_buffer[index64] = MAGIC1
		index64 += 1
		self.dma_buffer[index64] = ( (b_binarize << 49) + (decrease_step_size << 48) + (mini_batch_size << 32) + lambda_shifter )
		index64 += 1

		self.dma_buffer[index64] = MAGIC2
		index64 += 1
		self.dma_buffer = self.sgd_dma.get_buf("float *")
		if cost_neg == -1 and cost_neg == -1:
			self.dma_buffer[2*index64] = -1;
			self.dma_buffer[2*index64+1] = -1;
		else:
			self.dma_buffer[2*index64] = step_size*cost_neg;
			self.dma_buffer[2*index64+1] = step_size*cost_pos;
		index64 += 1

		self.dma_buffer = self.sgd_dma.get_buf("uint64_t *")
		self.dma_buffer[index64] = MAGIC3
		index64 += 1
		self.dma_buffer = self.sgd_dma.get_buf("float *")
		self.dma_buffer[2*index64] = b_to_binarize
		self.dma_buffer = self.sgd_dma.get_buf("uint32_t *")
		self.dma_buffer[2*index64+1] = self.num_features
		index64 += 1

		self.dma_buffer = self.sgd_dma.get_buf("uint64_t *")
		self.dma_buffer[index64] = MAGIC4
		index64 += 1
		self.dma_buffer = self.sgd_dma.get_buf("uint32_t *")
		self.dma_buffer[2*index64] = self.num_samples
		self.dma_buffer[2*index64+1] = num_epochs
		index64 += 1

		self.dma_buffer = self.sgd_dma.get_buf("uint64_t *")
		self.dma_buffer[index64] = MAGIC5
		index64 += 1
		self.dma_buffer = self.sgd_dma.get_buf("float *")
		self.dma_buffer[2*index64] = step_size
		self.dma_buffer = self.sgd_dma.get_buf("uint32_t *")
		self.dma_buffer[2*index64+1] = self.a_to_min1_1
		index64 += 1

		self.dma_buffer = self.sgd_dma.get_buf("uint64_t *")
		self.dma_buffer[index64] = SEND_CONFIG
		index64 += 1

		end_index = index64*2

		self.sgd_ctrl.write(0x0, 0) # Reset SGD
		time.sleep(0.01)
		self.sgd_ctrl.write(0x0, 1) # Deassert reset
		time.sleep(0.01)

		# Config
		self.sgd_dma.transfer(num_bytes=(end_index-start_index)*4, direction=self._dma.DMA_TO_DEV, offset32=start_index)
		self.sgd_dma.wait(direction=self._dma.DMA_TO_DEV, wait_timeout=5)
		print('Sent')

		self.sgd_dma.transfer(num_bytes=9*4, direction=self._dma.DMA_FROM_DEV, offset32=end_index)
		self.sgd_dma.wait(direction=self._dma.DMA_FROM_DEV, wait_timeout=5)
		print('Config Received')

		self.dma_buffer = self.sgd_dma.get_buf("uint32_t *")

		for i in range(0, 9):
			temp = self.dma_buffer[end_index + i]
			print(hex(temp))

		self.output_offset = end_index+10

	def SGD_FPGA(self, num_epochs):
		if self.on_pynq == 0:
			raise RuntimeError("SGD_FPGA can only be called on PYNQ!")

		print('self.data_start_index: ' + str(self.data_start_index) + ', self.data_end_index: ' + str(self.data_end_index) )

		x_history = np.zeros((self.num_features, num_epochs))

		values_in_one_input_word = 2
		if self.quantization_bits > 0:
			values_in_one_input_word = 64/self.quantization_bits

		accumulation_count = int(self.num_features/values_in_one_input_word) + int(self.num_features%values_in_one_input_word)
		bytes_for_model = int(accumulation_count*values_in_one_input_word*4)
		print('bytes_for_model: ' + str(bytes_for_model))

		for e in range(0, num_epochs):
			transfer_size = ((self.data_end_index - self.data_start_index)+2)*4
			if transfer_size > self.max_dma_transfer_size:
				already_transferred = 0
				while already_transferred < transfer_size:
					if transfer_size - already_transferred > self.max_dma_transfer_size:
						transfer_chunk_size = self.max_dma_transfer_size
					else:
						transfer_chunk_size = transfer_size - already_transferred
					# print('Starting transfer in chunks of size: ' + str(transfer_chunk_size) )
					self.sgd_dma.transfer(num_bytes=transfer_chunk_size, direction=self._dma.DMA_TO_DEV, offset32=self.data_start_index + int(already_transferred/4))
					self.sgd_dma.wait(direction=self._dma.DMA_TO_DEV, wait_timeout=5)
					already_transferred += transfer_chunk_size
			else:
				# print('Starting transfer of size: ' + str(transfer_size) )
				self.sgd_dma.transfer(num_bytes=transfer_size, direction=self._dma.DMA_TO_DEV, offset32=self.data_start_index)
				self.sgd_dma.wait(direction=self._dma.DMA_TO_DEV, wait_timeout=5)
				
			# print('Whole data set is transferred')

			self.sgd_dma.transfer(num_bytes=bytes_for_model, direction=self._dma.DMA_FROM_DEV, offset32=self.output_offset)
			self.sgd_dma.wait(direction=self._dma.DMA_FROM_DEV, wait_timeout=5)

			self.dma_buffer = self.sgd_dma.get_buf("int32_t *")
			for j in range(0, self.num_features):
				temp = self.dma_buffer[self.output_offset + j]
				# print('temp: ' + hex(temp))
				x_history[j,e] = float(temp)/self.to_int_scaler

		return x_history

	def loopback(self):
		ol = self.Overlay(self.bitstreams_path + '/qFSGD4.bit')
		ol.download()
		print('floatFSGD.bit is loaded')

		self.sgd_ctrl.write(0x0, 0) # Reset SGD
		time.sleep(0.01)
		self.sgd_ctrl.write(0x0, 1) # Deassert reset
		time.sleep(0.01)

		LOOPBACK = 0xabababababababab
		UNLOOPBACK = 0xbabababababababa

		start_index = 0

		index64 = int( start_index/2 )

		self.dma_buffer = self.sgd_dma.get_buf("uint64_t *")
		self.dma_buffer[index64] = LOOPBACK
		index64 += 1
		self.dma_buffer[index64] = 0x123456789ABCDEF1
		index64 += 1
		self.dma_buffer[index64] = UNLOOPBACK
		index64 += 1

		end_index = 2*index64

		
		self.sgd_dma.transfer(num_bytes=8, direction=self._dma.DMA_TO_DEV, offset32=0)
		self.sgd_dma.wait(direction=self._dma.DMA_TO_DEV, wait_timeout=5)

		self.sgd_dma.transfer(num_bytes=8, direction=self._dma.DMA_TO_DEV, offset32=2)
		self.sgd_dma.wait(direction=self._dma.DMA_TO_DEV, wait_timeout=5)

		self.sgd_dma.transfer(num_bytes=8, direction=self._dma.DMA_TO_DEV, offset32=4)
		self.sgd_dma.wait(direction=self._dma.DMA_TO_DEV, wait_timeout=5)

		self.sgd_dma.transfer(num_bytes=4, direction=self._dma.DMA_FROM_DEV, offset32=6)
		self.sgd_dma.wait(direction=self._dma.DMA_FROM_DEV, wait_timeout=5)

		self.dma_buffer = self.sgd_dma.get_buf("uint32_t *")

		for i in range(start_index, end_index+1):
			print(hex(self.dma_buffer[i]))
