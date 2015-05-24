PyCoRAM
=======

Python-based Portable IP-core Synthesis Framework for FPGA-based
Computing

Copyright (C) 2013, Shinya Takamaeda-Yamazaki

E-mail: shinya\_at\_is.naist.jp

License
=======

Apache License 2.0 (http://www.apache.org/licenses/LICENSE-2.0)

What's PyCoRAM?
===============

PyCoRAM is a Python-based portable IP-core synthesis framework with
CoRAM (Connected RAM) memory architecture.

PyCoRAM framework generates a portable IP-core package from computing
logic descriptions in Verilog HDL and memory access pattern descriptions
in Python. Designers can easily build an FPGA-based custom accelerator
using a generated IP-core with any common IP-cores on vendor-provided
EDA tools. PyCoRAM framework includes (1) the Verilog-to-Verilog design
translation compiler and (2) the Python-to-Verilog high-level synthesis
(HLS) compiler for generating control circuits of memory operations.

There are some major differences between PyCoRAM and the original
soft-logic implementation of CoRAM.

-  Memory access pattern representation in Python

   -  The original CoRAM uses C language to represent a memory access
      pattern (called 'control thread').
   -  In PyCoRAM, you can easily describe them by using popular
      lightweight scripting language.
   -  A Python script of memory access patterns is translated into an
      RT-level hardware design in Verilog HDL by the Python-to-Verilog
      high-level synthesis compiler.

-  Commercial interconnect supports (AMBA AXI4 and Altera Avalon)

   -  The original CoRAM uses CONNECT to generate an on-chip
      interconnect.
   -  PyCoRAM compiler generates a IP-core design with AMBA AXI4 or
      Altera Avalon. Both are commonly used on vendor-provided EDA
      tools.

-  Parameterized RTL Design Support

   -  The original CoRAM has some limitations in Verilog HDL description
      of computing logic, such as no supports of generate statement.
   -  PyCoRAM has a sophisticated RTL analyzer/translator to convert RTL
      descriptions into synthesizable IP-core package under memory
      abstractions of CoRAM.

Requirements
============

Software
--------

-  Python (2.7 or later, 3.3 or later)
-  Icarus Verilog (0.9.6 or later)

   -  'iverilog -E' command is used for preprocessing Verilog source
      code.

-  Jinja2 (2.7 or later)

   -  The code generator uses Jinja2 template engine.
   -  'pip install jinja2' (for Python 2.x) or 'pip3 install jinja2'
      (for Python 3.x)

-  Pyverilog (Python-based Verilog HDL Design Processing Toolkit)

   -  Install from pip: 'pip install pyverilog' for Python2.7 or 'pip3
      install pyverilog' for Python3
   -  Install from github into this package: 'cd Pycoram; git clone
      https://github.com/shtaxxx/Pyverilog.git; cd pycoram; ln -s
      ../Pyverilog/pyverilog'

for RTL simulation
~~~~~~~~~~~~~~~~~~

-  Icarus Verilog

   -  Icarus Verilog is an open-sourced Verilog simulator

-  Synopsys VCS (option, if you have)

   -  VCS is a very fast commercial Verilog simulator

for bitstream synthesis
~~~~~~~~~~~~~~~~~~~~~~~

-  Xilinx: Vivado (2014.4 or later) and Xilinx Platform Studio (14.6 or
   later)
-  Altera: Qsys (14.0 or later)

Installation
============

If you want to use PyCoRAM as a general library, you can install on your
environment by using setup.py.

If Python 2.7 is used,

::

    python setup.py install

If Python 3.x is used,

::

    python3 setup.py install

Then you can use the pycoram command from your console (the version
number depends on your environment).

::

    pycoram-0.9.3-py3.4.1

Getting Started
===============

First, please make sure TARGET in 'base.mk' in 'sample' is correctly
defined. If you use the installed pycoram command on your environment,
please modify 'TARGET' in base.mk as below (the version number depends
on your environment)

::

    TARGET=pycoram-0.9.3-py3.4.1

You can find the sample projects in 'sample/tests/single\_memory'.

-  ctrl\_thread.py : Control-thread definition in Python
-  userlogic.v : User-defined Verilog code using CoRAM memory blocks

Then type 'make' and 'make run' to simulate sample system.

::

    make build
    make sim

Or type commands as below directly.

::

    python pycoram/pycoram.py sample/default.config -t userlogic -I include/ sample/tests/single_memory/ctrl_thread.py sample/tests/single_memory/userlogic.v
    iverilog -I pycoram_userlogic_v1_00_a/hdl/verilog/ pycoram_userlogic_v1_00_a/test/test_pycoram_userlogic.v 
    ./a.out

PyCoRAM compiler generates a directory for IP-core
(pycoram\_userlogic\_v1\_00\_a, in this example).

'pycoram\_userlogic\_v1\_00\_a.v' includes \* IP-core RTL design
(hdl/verilog/pycoram\_userlogic.v) \* Test bench
(test/test\_pycoram\_userlogic.v) \* XPS setting files
(pycoram\_userlogic\_v2\_1\_0.{mpd,pao,tcl}) \* IP-XACT file
(component.xml)

A bit-stream can be synthesized by using Xilinx Platform Studio, Xilinx
Vivado, and Altera Qsys. In case of XPS, please copy the generated
IP-core into 'pcores' directory of XPS project.

This software has some sample project in 'sample'. To build them, please
modify 'Makefile', so that the corresponding files and parameters are
selected (especially INPUT, MEMIMG and USERTEST)

PyCoRAM Command Options
=======================

Command
-------

::

    python pycoram.py [config] [-t topmodule] [-I includepath]+ [--memimg=filename] [--usertest=filename] [file]+

Description
-----------

-  file

   -  User-logic Verilog file (.v) and control-thread definition file
      (.py). Automatically, .v file is recognized as a user-logic
      Verilog file, and .py file recongnized as a control-thread
      definition, respectively.

-  config

   -  Configuration file which includes memory and device specification

-  -t

   -  Name of user-defined top module, default is "userlogic".

-  -I

   -  Include path for input Verilog HDL files.

-  --memimg

   -  DRAM image file in HEX DRAM (option, if you need). The file is
      copied into test directory. If no file is assigned, the array is
      initialized with incremental values.

-  --usertest

   -  User-defined test code file (option, if you need). The code is
      copied into testbench script.

Publication
===========

-  Shinya Takamaeda-Yamazaki, Kenji Kise and James C. Hoe: PyCoRAM: Yet
   Another Implementation of CoRAM Memory Architecture for Modern
   FPGA-based Computing, The Third Workshop on the Intersections of
   Computer Architecture and Reconfigurable Logic (CARL 2013)
   (Co-located with MICRO-46), December 2013.
   `Paper <http://users.ece.cmu.edu/~jhoe/distribution/2013/carl13pycoram.pdf>`__
   `Slide <http://www.slideshare.net/shtaxxx/pycoramcarl2013>`__

-  Zynq + PyCoRAM (+ Debian) (slideshare, in Japanese)
   `Slide <http://www.slideshare.net/shtaxxx/zynqpycoram>`__

-  PyCoRAM for HLS meet up (slideshare, in Japanese)
   `Slide <http://www.slideshare.net/shtaxxx/pycoram20150116hls>`__

Related Project
===============

`Pyverilog <http://shtaxxx.github.io/Pyverilog/>`__ - Python-based
Hardware Design Processing Toolkit for Verilog HDL - Used as basic code
analyser and generator in PyCoRAM

`CoRAM <http://www.ece.cmu.edu/coram/doku.php?id=home>`__ - A General
Purpose Memory Architecture for FPGAs - The original CoRAM developed at
CMU
