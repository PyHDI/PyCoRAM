from setuptools import setup, find_packages

import pycoram.utils.version
import re

m = re.search(r'(\d+\.\d+\.\d+)', pycoram.utils.version.VERSION)
version = m.group(1) if m is not None else '0.0.0'

import sys
script_name = 'pycoram-' + version + '-py' + '.'.join([str(s) for s in sys.version_info[:3]])

setup(name='pycoram',
      version=version,
      description='Python-based Portable IP-core Synthesis Framework for FPGA-based Computing',
      author='Shinya Takamaeda-Yamazaki',
      url='http://shtaxxx.github.io/Pycoram/',
      packages=find_packages(),
      package_data={ 'pycoram.template' : ['*.*'],  },
      entry_points="""
      [console_scripts]
      %s = pycoram.pycoram:main
      """ % script_name,
)

