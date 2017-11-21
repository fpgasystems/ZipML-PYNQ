# Copyright 2015 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

"""Simple image classification with Inception.

Run image classification with Inception trained on ImageNet 2012 Challenge data
set.

This program creates a graph from a saved GraphDef protocol buffer,
and runs inference on an input JPEG image. It outputs human readable
strings of the top 5 predictions along with their probabilities.

Change the --image_file argument to any jpg image to compute a
classification of that image.

Please see the tutorial and website for a detailed description of how
to use this script to perform image recognition.

https://tensorflow.org/tutorials/image_recognition/
"""

#*************************************************************************
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

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import argparse
import os.path
import re
import sys
import tarfile
import cv2
from os import listdir
from os.path import isfile, join
from random import shuffle

import numpy as np
from six.moves import urllib
import tensorflow as tf

FLAGS = None

# pylint: disable=line-too-long
DATA_URL = 'http://download.tensorflow.org/models/image/imagenet/inception-2015-12-05.tgz'
# pylint: enable=line-too-long

def create_graph():
  """Creates a graph from saved GraphDef file and returns a saver."""
  # Creates graph from saved graph_def.pb.
  with tf.gfile.FastGFile(os.path.join(FLAGS.model_dir, 'classify_image_graph_def.pb'), 'rb') as f:
    graph_def = tf.GraphDef()
    graph_def.ParseFromString(f.read())
    _ = tf.import_graph_def(graph_def, name='')

def produce_line(label, features):
  line = str(label) + ' '
  for i in range(0,len(features)):
    line = line + str(i) + ':' + str(features[i])+' '
  line = line + '\n'
  return line

def maybe_download_and_extract():
  """Download and extract model tar file."""
  dest_directory = FLAGS.model_dir
  if not os.path.exists(dest_directory):
    os.makedirs(dest_directory)
  filename = DATA_URL.split('/')[-1]
  filepath = os.path.join(dest_directory, filename)
  if not os.path.exists(filepath):
    def _progress(count, block_size, total_size):
      sys.stdout.write('\r>> Downloading %s %.1f%%' % (
          filename, float(count * block_size) / float(total_size) * 100.0))
      sys.stdout.flush()
    filepath, _ = urllib.request.urlretrieve(DATA_URL, filepath, _progress)
    print()
    statinfo = os.stat(filepath)
    print('Successfully downloaded', filename, statinfo.st_size, 'bytes.')
  tarfile.open(filepath, 'r:gz').extractall(dest_directory)


def main(_):
  maybe_download_and_extract()

  f = open(FLAGS.output, 'w')
  f.write('label index0:feature0 index1:feature1 ...\n')

  create_graph()

  with tf.Session() as sess:
    features_tensor = sess.graph.get_tensor_by_name('pool_3:0')

    num_images = 0
    for image in listdir(FLAGS.image_dir):
      image_data = tf.gfile.FastGFile(FLAGS.image_dir+image, 'rb').read()

      jpeg_image = sess.run(sess.graph.get_tensor_by_name('DecodeJpeg:0'), {'DecodeJpeg/contents:0': image_data})

      feature = sess.run(features_tensor, {'DecodeJpeg:0': jpeg_image})
      features = feature.flatten()
      line = produce_line(FLAGS.label, features)

      f.write(line)

      num_images += 1
      print('#Processed images: ' + str(num_images))


def mix_files(files_to_mix):

  lines = []
  for file in files_to_mix:
    f = open(file, 'r')
    first_line = True
    for line in f:
      if first_line == False:
        lines.append(line)
      else:
        first_line = False

  print('#lines: ' + str(len(lines)))

  shuffle(lines)

  f = open(FLAGS.train, 'w')
  for i in range( 0, int(FLAGS.len_train) ):
    f.write(lines[i])
  f.close()

  f = open(FLAGS.test, 'w')
  for i in range( int(FLAGS.len_train), int(FLAGS.len_train)+int(FLAGS.len_test) ):
    f.write(lines[i])
  f.close()

if __name__ == '__main__':
  parser = argparse.ArgumentParser()
  parser.add_argument(
      '--model_dir',
      type=str,
      default='./model/',
      help="""\
      Path to classify_image_graph_def.pb,
      imagenet_synset_to_human_label_map.txt, and
      imagenet_2012_challenge_label_map_proto.pbtxt.\
      """
  )
  parser.add_argument(
      '--image_dir',
      type=str,
      default='',
      help='Absolute path to image directory.'
  )
  parser.add_argument(
    '--label',
    help='label of images in this directory',
    default='0')
  parser.add_argument(
    '--output', 
    help='file to write extracted features')
  parser.add_argument('--gpu', help='the physical ids of GPUs to use')

  parser.add_argument('--mix', help='files to mix')
  parser.add_argument('--len_train', help='how many samples for train')
  parser.add_argument('--train', help='training file output')
  parser.add_argument('--len_test', help='how many samples for testing')
  parser.add_argument('--test', help='test file output')

  FLAGS, unparsed = parser.parse_known_args()


  if FLAGS.gpu:
    os.environ['CUDA_VISIBLE_DEVICES'] = FLAGS.gpu

  if FLAGS.mix != None:
    if FLAGS.train == None or FLAGS.len_train == None:
      print('Specify the training output file for the extracted features to be written to!')
      sys.exit()
    if FLAGS.test == None or FLAGS.len_test == None:
      print('Specify the test output file for the extracted features to be written to!')
      sys.exit()

    files_to_mix = FLAGS.mix.split( )
    mix_files(files_to_mix)

  else:
    if FLAGS.image_dir == None:
      print('Specify a directory where images to be transferred are located!')
      sys.exit()
    if FLAGS.label == None:
      print('Specify the label for the images in the directory!')
      sys.exit()
    if FLAGS.output == None:
      print('Specify the output file for the extracted features to be written to!')
      sys.exit()

    tf.app.run(main=main, argv=[sys.argv[0]] + unparsed)
