from setuptools import setup, find_packages

import pycoram.utils.version
import re
import os

m = re.search(r'(\d+\.\d+\.\d+)', pycoram.utils.version.VERSION)
version = m.group(1) if m is not None else '0.0.0'

def read(filename):
    return open(os.path.join(os.path.dirname(__file__), filename)).read()

import sys
script_name = 'pycoram'

setup(name='pycoram',
      version=version,
      description='Python-based Portable IP-core Synthesis Framework for FPGA-based Computing',
      long_description=read('README.rst'),
      keywords = 'FPGA, Verilog HDL, High-Level Synthesis',
      author='Shinya Takamaeda-Yamazaki',
      author_email='shinya.takamaeda_at_gmail_com',
      license="Apache License 2.0",
      url='https://github.com/PyHDI/PyCoRAM',
      packages=find_packages(),
      package_data={ 'pycoram.template' : ['*.*'], },
      install_requires=[ 'pyverilog', 'Jinja2' ],
      extras_require={
          'test' : [ 'pytest', 'pytest-pythonpath' ],
      },
      entry_points="""
      [console_scripts]
      %s = pycoram.run_pycoram:main
      """ % script_name,
)
