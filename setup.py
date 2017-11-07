from setuptools import setup, find_packages
import subprocess
import sys
import shutil
import os

setup(
   name = "ZipML-PYNQ",
   version = 1.0,
   url = 'https://gitlab.com/kaankara/ZipML-PYNQ',
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
