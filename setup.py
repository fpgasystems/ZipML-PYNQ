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

from setuptools import setup, find_packages
import subprocess
import sys
import shutil
import os

setup(
   name = "ZipML-PYNQ",
   version = 1.0,
   url = 'https://github.com/fpgasystems/ZipML-PYNQ',
   license = 'All rights reserved.',
   author = "Kaan Kara",
   author_email = "kaan.kara@inf.ethz.ch",
   include_package_data = True,
   packages = ['zipml'],
   package_data = {
   '' : ['bitstreams/*.bit','bitstreams/*.tcl','__init__.py', 'modified_dma.py', 'zipml_sgd.py', 'libdma.so', 'Notebooks/*.ipynb', 'Notebooks/*.sh'],
   },
   install_requires=[
       'pynq',
   ],
   #dependency_links=['http://github.com/xilinx/PYNQ'],
   description = "Custom overlay for PYNQ-Z1 for training linear models (SVM, linear regression) with low precision data."
)

if os.path.islink('/home/xilinx/jupyter_notebooks/ZipML-Notebooks'):
   os.remove('/home/xilinx/jupyter_notebooks/ZipML-Notebooks')

os.symlink('/opt/python3.6/lib/python3.6/site-packages/zipml/Notebooks', '/home/xilinx/jupyter_notebooks/ZipML-Notebooks')
