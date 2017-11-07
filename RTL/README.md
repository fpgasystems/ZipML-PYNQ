# RTL Design for the SGD Engines

The top files for training with single-precision floating-point data and quantized data are floatFSGD.vhd and qFSGD.vhd, respectively. The top level interface for both modules is AXI-Stream. 

If you want to explore and change the hardware design, we recommend reading our paper and having a look at the source code:

@inproceedings{kara2017fpga,
  title={FPGA-accelerated Dense Linear Machine Learning: A Precision-Convergence Trade-off},
  author={Kara, Kaan and Alistarh, Dan and Alonso, Gustavo and Mutlu, Onur and Zhang, Ce},
  booktitle={Field-Programmable Custom Computing Machines (FCCM), 2017 IEEE 25th Annual International Symposium on},
  pages={160--167},
  year={2017},
  organization={IEEE}
}


