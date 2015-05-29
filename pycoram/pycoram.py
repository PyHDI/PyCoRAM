#-------------------------------------------------------------------------------
# pycoram.py
#
# PyCoRAM: Python-based Portable IP-core Synthesis Framework for FPGA-based Computing
# 
# Copyright (C) 2013, Shinya Takamaeda-Yamazaki
# License: Apache 2.0
#-------------------------------------------------------------------------------

import os
import sys
import math
import re
import copy
import shutil
import glob
import collections
from jinja2 import Environment, FileSystemLoader
if sys.version_info[0] < 3:
    import ConfigParser as configparser
else:
    import configparser

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) )

import utils.version
from controlthread.controlthread import ControlThreadGenerator
from rtlconverter.rtlconverter import RtlConverter
from controlthread.coram_module import *
from pyverilog.ast_code_generator.codegen import ASTCodeGenerator
import pyverilog.vparser.ast as vast
import pyverilog.dataflow.identifiervisitor as iv
import pyverilog.dataflow.identifierreplace as ir
import utils.componentgen

TEMPLATE_DIR = os.path.dirname(os.path.abspath(__file__)) + '/template/'

#-------------------------------------------------------------------------------
class PycoramIp(object):
    def __init__(self, signal_width=32, ext_addrwidth=32, ext_datawidth=512,
                 if_type='axi', io_lite=True, single_clock=True,
                 sim_addrwidth=27, hperiod_ulogic=5, hperiod_cthread=5, hperiod_bus=5,
                 topmodule='TOP', memimg=None, usertest=None, output='out.v'):
        self.signal_width = signal_width
        self.ext_addrwidth = ext_addrwidth
        self.ext_datawidth = ext_datawidth
        self.if_type = if_type
        self.io_lite = True
        self.single_clock = True
        self.sim_addrwidth = sim_addrwidth
        self.hperiod_ulogic = hperiod_ulogic
        self.hperiod_cthread = hperiod_cthread
        self.hperiod_bus = hperiod_bus
        self.topmodule = topmodule
        self.memimg = memimg
        self.usertest = usertest
        self.output = output

        self.include_paths = []
        self.macros = []

        self.function_lib = {}
        
        self.rtl_files = []
        self.controlthreads = {}

    def add_include_path(self, path):
        self.include_paths.append(path)
        
    def add_macros(self, macro):
        self.macros.append(macro)
        
    def add_rtl(self, filename):
        self.rtl_files.append(filename)

    def add_function(self, func):
        name = func.__name__
        if name in self.function_lib:
            raise ValueError("function '%s' is already defined." % name)
        self.function_lib[name] = func
        
    def add_controlthread(self, cthread, threadname=None):
        if threadname is None:
            threadname = cthread.__name__
        if threadname in self.controlthreads:
            raise ValueError("cthread '%s' is already defined." % threadname)
        self.controlthreads[threadname] = cthread

    def generate(self):
        for f in self.rtl_files:
            if not os.path.exists(f): raise IOError("file not found: " + f)

        if len(self.rtl_files) == 0:
            raise IOError("RTL file not found")

        print("----------------------------------------")
        print("Input files")
        print("  User-logic: %s" % ', '.join(self.rtl_files) )
        print("  Control-thread: %s" % ', '.join(self.controlthreads.keys()) )
        print("----------------------------------------")
        
        # default values
        configs = {
            'signal_width' : self.signal_width,
            'ext_addrwidth' : self.ext_addrwidth,
            'ext_datawidth' : self.ext_datawidth,
            'single_clock' : self.single_clock,
            'io_lite' : self.io_lite,
            'if_type' : self.if_type,
            'output' : self.output,
            'sim_addrwidth' : self.sim_addrwidth,
            'hperiod_ulogic' : self.hperiod_ulogic,
            'hperiod_cthread' : self.hperiod_cthread,
            'hperiod_bus' : self.hperiod_bus,
        }

        systembuilder = SystemBuilder()
        systembuilder.build(configs,
                            self.topmodule,
                            self.rtl_files,
                            controlthread_funcs=self.controlthreads,
                            function_lib=self.function_lib,
                            userlogic_include=self.include_paths,
                            userlogic_define=self.macros,
                            usertest=self.usertest,
                            memimg=self.memimg)
            
#-------------------------------------------------------------------------------
def log2(v):
    return int(math.ceil(math.log(v, 2)))

#-------------------------------------------------------------------------------
class SystemBuilder(object):
    def __init__(self):
        self.env = Environment(loader=FileSystemLoader(TEMPLATE_DIR))
        self.env.globals['int'] = int
        self.env.globals['log'] = math.log
        self.env.globals['log2'] = log2
        self.env.globals['len'] = len

    #---------------------------------------------------------------------------
    def render(self, template_file,
               userlogic_name, threads,
               def_top_parameters, def_top_localparams, def_top_ioports, name_top_ioports,
               ext_addrwidth=32, ext_burstlength=256,
               single_clock=False, lite=False,
               hdlname=None, common_hdlname=None, testname=None, ipcore_version=None,
               memimg=None, binfile=False, usertestcode=None, simaddrwidth=None, 
               mpd_parameters=None, mpd_ports=None,
               tcl_parameters=None, tcl_ports=None,
               clock_hperiod_userlogic=None,
               clock_hperiod_controlthread=None,
               clock_hperiod_bus=None):

        ext_burstlen_width = log2(ext_burstlength)
        template_dict = {
            'userlogic_name' : userlogic_name,
            'ext_addrwidth' : ext_addrwidth,
            'ext_burstlength' : ext_burstlength,
            'ext_burstlen_width' : ext_burstlen_width,
            
            'threads' : threads,

            'def_top_parameters' : def_top_parameters,
            'def_top_localparams' : def_top_localparams,
            'def_top_ioports' : def_top_ioports,
            'name_top_ioports' : name_top_ioports,

            'hdlname' : hdlname,
            'common_hdlname' : common_hdlname,
            'testname' : testname,
            'ipcore_version' : ipcore_version,
            'memimg' : memimg if memimg is not None else 'None',
            'binfile' : binfile,
            'usertestcode' : '' if usertestcode is None else usertestcode,
            'simaddrwidth' : simaddrwidth,
            
            'mpd_parameters' : () if mpd_parameters is None else mpd_parameters,
            'mpd_ports' : () if mpd_ports is None else mpd_ports,

            'tcl_parameters' : () if tcl_parameters is None else tcl_parameters,
            'tcl_ports' : () if tcl_ports is None else tcl_ports,

            'clock_hperiod_userlogic' : clock_hperiod_userlogic,
            'clock_hperiod_controlthread' : clock_hperiod_controlthread,
            'clock_hperiod_bus' : clock_hperiod_bus,

            'single_clock' : single_clock,
            'lite' : lite
            }
        
        template = self.env.get_template(template_file)
        rslt = template.render(template_dict)
        return rslt

    #---------------------------------------------------------------------------
    def build(self, configs, userlogic_topmodule,  userlogic_filelist,
              controlthread_filelist=None, controlthread_funcs=None, function_lib=None,
              userlogic_include=None, userlogic_define=None, memimg=None, usertest=None):

        # default values
        ext_burstlength = 256
        
        if (configs['single_clock'] and 
            ((configs['hperiod_ulogic'] != configs['hperiod_cthread']) or
             (configs['hperiod_ulogic'] != configs['hperiod_bus']) or
             (configs['hperiod_cthread'] != configs['hperiod_bus']))):
            raise ValueError("All clock periods should be same in single clock mode.")

        # User RTL Conversion
        converter = RtlConverter(userlogic_filelist, userlogic_topmodule,
                                 include=userlogic_include,
                                 define=userlogic_define,
                                 single_clock=configs['single_clock'])
        userlogic_ast = converter.generate()
        top_parameters = converter.getTopParameters()
        top_ioports = converter.getTopIOPorts()

        # dump
        converter.dumpCoramObject()
        
        # Code Generator
        asttocode = ASTCodeGenerator()
        userlogic_code= asttocode.visit(userlogic_ast)

        # Control Thread
        controlthread_codes = []
        generator = ControlThreadGenerator()
        thread_status = {}

        # from files
        if controlthread_filelist is not None: 
            for f in controlthread_filelist:
                (thread_name, ext) = os.path.splitext(os.path.basename(f))
                controlthread_codes.append(
                    generator.compile(thread_name, filename=f, 
                                      signalwidth=configs['signal_width'], 
                                      ext_addrwidth=configs['ext_addrwidth'],
                                      ext_max_datawidth=configs['ext_datawidth'],
                                      dump=True))
                thread_status.update(generator.getStatus())
            
        # from func objects
        if controlthread_funcs is not None: 
            for func_name, func in controlthread_funcs.items():
                controlthread_codes.append(
                    generator.compile(func_name, func=func,
                                      function_lib=function_lib,
                                      signalwidth=configs['signal_width'], 
                                      ext_addrwidth=configs['ext_addrwidth'],
                                      ext_max_datawidth=configs['ext_datawidth'],
                                      dump=True))
                thread_status.update(generator.getStatus())
            
        # Template Render
        threads = []
        for tname, (tmemories, tinstreams, toutstreams, tchannels, tregisters, 
                    tiochannels, tioregisters) in sorted(thread_status.items(), key=lambda x:x[0]):
            threads.append(ControlThread(tname, tmemories, tinstreams, toutstreams, 
                                                      tchannels, tregisters, tiochannels, tioregisters))

        asttocode = ASTCodeGenerator()
        def_top_parameters = []
        def_top_localparams = []
        def_top_ioports = []
        name_top_ioports = []

        for p in top_parameters.values():
            r = asttocode.visit(p)
            if r.count('localparam'):
                def_top_localparams.append( r )
            else:
                def_top_parameters.append( r.replace(';', ',') )

        for pk, (pv, pwidth) in top_ioports.items():
            if configs['if_type'] == 'avalon':
                new_pv = copy.deepcopy(pv)
                new_pv.name = 'coe_' + new_pv.name 
                new_pv = vast.Ioport(new_pv, vast.Wire(new_pv.name, new_pv.width, new_pv.signed))
                def_top_ioports.append( asttocode.visit(new_pv) )
            else:
                new_pv = vast.Ioport(pv, vast.Wire(pv.name, pv.width, pv.signed))
                def_top_ioports.append( asttocode.visit(new_pv) )
            name_top_ioports.append( pk )

        node_template_file = ('node_axi.txt' if configs['if_type'] == 'axi' else 
                              'node_avalon.txt' if configs['if_type'] == 'avalon' else 
                              #'node_wishborn.txt' if configs['if_type'] == 'wishborn' else 
                              'node_general.txt')
        node_code = self.render(node_template_file,
                                userlogic_topmodule, threads, 
                                def_top_parameters, def_top_localparams, def_top_ioports, name_top_ioports, 
                                ext_addrwidth=configs['ext_addrwidth'],
                                ext_burstlength=ext_burstlength,
                                single_clock=configs['single_clock'], lite=configs['io_lite'])

        dmac_memory_template_file = 'dmac_memory.txt'
        dmac_memory_code = self.render(dmac_memory_template_file,
                                       userlogic_topmodule, threads, 
                                       def_top_parameters, def_top_localparams,
                                       def_top_ioports, name_top_ioports, 
                                       ext_addrwidth=configs['ext_addrwidth'],
                                       ext_burstlength=ext_burstlength,
                                       single_clock=configs['single_clock'], lite=configs['io_lite'])

        # finalize of code generation
        synthesized_code_list = []
        synthesized_code_list.append(node_code)
        synthesized_code_list.append(userlogic_code)
        synthesized_code_list.extend(controlthread_codes)
        synthesized_code_list.append(dmac_memory_code)

        common_code_list = []
        pycoram_object = open(TEMPLATE_DIR+'pycoram_object.v', 'r').read()
        dmac_memory_common = open(TEMPLATE_DIR+'dmac_memory_common.v', 'r').read()
        dmac_stream = open(TEMPLATE_DIR+'dmac_stream.v', 'r').read()
        dmac_iochannel = open(TEMPLATE_DIR+'dmac_iochannel.v', 'r').read()
        dmac_ioregister = open(TEMPLATE_DIR+'dmac_ioregister.v', 'r').read()
        common_code_list.append(pycoram_object)
        common_code_list.append(dmac_memory_common)
        common_code_list.append(dmac_stream)
        common_code_list.append(dmac_iochannel)
        common_code_list.append(dmac_ioregister)

        if configs['if_type'] == 'axi':
            common_code_list.append( open(TEMPLATE_DIR+'axi_master_interface.v', 'r').read() )
            if configs['io_lite']: 
                common_code_list.append( open(TEMPLATE_DIR+'axi_lite_slave_interface.v', 'r').read() )
            else:
                common_code_list.append( open(TEMPLATE_DIR+'axi_slave_interface.v', 'r').read() )

        if configs['if_type'] == 'avalon':
            common_code_list.append( open(TEMPLATE_DIR+'avalon_master_interface.v', 'r').read() )
            if configs['io_lite']: 
                common_code_list.append( open(TEMPLATE_DIR+'avalon_lite_slave_interface.v', 'r').read() )
            else:
                common_code_list.append( open(TEMPLATE_DIR+'avalon_slave_interface.v', 'r').read() )

        synthesized_code = ''.join(synthesized_code_list)
        common_code = ''.join(common_code_list)

        # Print settings
        print("----------------------------------------")
        print("Synthesis Setting")
        for k, v in sorted(configs.items(), key=lambda x:x[0]):
            print("  %s : %s" % (str(k), str(v)))

        # write to file, without AXI interfaces
        if configs['if_type'] == 'general':
            self.build_package_general(configs, synthesized_code, common_code)
            return

        if configs['if_type'] == 'axi':
            self.build_package_axi(configs, synthesized_code, common_code, 
                                   threads, 
                                   top_parameters, top_ioports, userlogic_topmodule,
                                   memimg, usertest)
            return
            
        if configs['if_type'] == 'avalon':
            self.build_package_avalon(configs, synthesized_code, common_code,
                                      threads, 
                                      top_parameters, top_ioports, userlogic_topmodule,
                                      memimg, usertest)
            return

        raise ValueError("Interface type '%s' is not supported." % configs['if_type'])

    #---------------------------------------------------------------------------
    def build_package_general(self, configs, synthesized_code, common_code):
        code = synthesized_code + common_code
        f = open(configs['output'], 'w')
        f.write(code)
        f.close()

    #---------------------------------------------------------------------------
    def build_package_axi(self, configs, synthesized_code, common_code, 
                          threads,
                          top_parameters, top_ioports, userlogic_topmodule, 
                          memimg, usertest):
        code = synthesized_code + common_code

        # default values
        ext_burstlength = 256

        # write to files, with AXI interface
        def_top_parameters = []
        def_top_localparams = []
        def_top_ioports = []
        name_top_ioports = []
        mpd_parameters = []
        mpd_ports = []
        ext_params = []
        ext_ports = []

        asttocode = ASTCodeGenerator()

        for pk, pv in top_parameters.items():
            r = asttocode.visit(pv)
            def_top_parameters.append( r )
            if r.count('localparam'):
                def_top_localparams.append( r )
                continue
            _name = pv.name
            _value = asttocode.visit( pv.value )
            _dt = 'string' if r.count('"') else 'integer'
            mpd_parameters.append( (_name, _value, _dt) )

        for pk, (pv, pwidth) in top_ioports.items():
            name_top_ioports.append( pk )
            new_pv = vast.Wire(pv.name, pv.width, pv.signed)
            def_top_ioports.append( asttocode.visit(new_pv) )
            _name = pv.name
            _dir = ('I' if isinstance(pv, vast.Input) else
                    'O' if isinstance(pv, vast.Output) else
                    'IO')
            _vec = '' if pv.width is None else asttocode.visit(pv.width) 
            mpd_ports.append( (_name, _dir, _vec) )

        for pk, (pv, pwidth) in top_ioports.items():
            new_pv = vast.Wire(pv.name, pv.width, pv.signed)
            _name = pv.name
            _dir = ('in' if isinstance(pv, vast.Input) else
                    'out' if isinstance(pv, vast.Output) else
                    'inout')
            _vec = None if pv.width is None else pwidth - 1
            _ids = None if pv.width is None else iv.getIdentifiers(pv.width.msb)
            _d = {}
            if _ids is not None:
                for i in _ids:
                    _d[i] = "(spirit:decode(id('MODELPARAM_VALUE." + i + "')))"
            _msb = (None if _ids is None else
                    asttocode.visit(ir.replaceIdentifiers(pv.width.msb, _d)))
            ext_ports.append( (_name, _dir, _vec, _msb) )

        for pk, pv in top_parameters.items():
            r = asttocode.visit(pv)
            if r.count('localparam'):
                def_top_localparams.append( r )
                continue
            _name = pv.name
            _value = asttocode.visit( pv.value )
            _dt = 'string' if r.count('"') else 'integer'
            ext_params.append( (_name, _value, _dt) )

        # write to files 
        # with AXI interface, create IPcore dir
        ipcore_version = '_v1_00_a'
        mpd_version = '_v2_1_0'
        
        dirname = 'pycoram_' + userlogic_topmodule + ipcore_version + '/'

        # pcore
        mpdname = 'pycoram_' + userlogic_topmodule + mpd_version + '.mpd'
        #muiname = 'pycoram_' + userlogic_topmodule + mpd_version + '.mui'
        paoname = 'pycoram_' + userlogic_topmodule + mpd_version + '.pao'
        tclname = 'pycoram_' + userlogic_topmodule + mpd_version + '.tcl'

        # IP-XACT
        xmlname = 'component.xml'
        xdcname = 'pycoram_' + userlogic_topmodule + '.xdc'
        bdname = 'bd.tcl'
        xguiname = 'xgui.tcl'

        # source
        hdlname = 'pycoram_' + userlogic_topmodule + '.v'
        testname = 'test_pycoram_' + userlogic_topmodule + '.v'
        memname = 'mem.img'
        makefilename = 'Makefile'
        copied_memimg = memname if memimg is not None else None
        binfile = (True if memimg is not None and memimg.endswith('.bin') else False)

        # pcore
        mpdpath = dirname + 'data/'
        #muipath = dirname + 'data/'
        paopath = dirname + 'data/'
        tclpath = dirname + 'data/'

        # IP-XACT
        xmlpath = dirname
        xdcpath = dirname + 'data/'
        bdpath = dirname + 'bd/'
        xguipath = dirname + 'xgui/'

        # source
        hdlpath = dirname + 'hdl/'
        verilogpath = dirname + 'hdl/verilog/'
        testpath = dirname + 'test/'
        makefilepath = dirname + 'test/'

        if not os.path.exists(dirname):
            os.mkdir(dirname)
        if not os.path.exists(dirname + '/' + 'data'):
            os.mkdir(dirname + '/' + 'data')
        if not os.path.exists(dirname + '/' + 'doc'):
            os.mkdir(dirname + '/' + 'doc')
        if not os.path.exists(dirname + '/' + 'bd'):
            os.mkdir(dirname + '/' + 'bd')
        if not os.path.exists(dirname + '/' + 'xgui'):
            os.mkdir(dirname + '/' + 'xgui')
        if not os.path.exists(dirname + '/' + 'hdl'):
            os.mkdir(dirname + '/' + 'hdl')
        if not os.path.exists(dirname + '/' + 'hdl/verilog'):
            os.mkdir(dirname + '/' + 'hdl/verilog')
        if not os.path.exists(dirname + '/' + 'test'):
            os.mkdir(dirname + '/' + 'test')

        # mpd file
        mpd_template_file = 'mpd.txt'
        mpd_code = self.render(mpd_template_file,
                               userlogic_topmodule, threads,
                               def_top_parameters, def_top_localparams, def_top_ioports, name_top_ioports,
                               ext_addrwidth=configs['ext_addrwidth'], ext_burstlength=ext_burstlength,
                               single_clock=configs['single_clock'], lite=configs['io_lite'],
                               hdlname=hdlname,
                               ipcore_version=ipcore_version, 
                               mpd_ports=mpd_ports, mpd_parameters=mpd_parameters)
        f = open(mpdpath+mpdname, 'w')
        f.write(mpd_code)
        f.close()

        # mui file
        #mui_template_file = 'mui.txt'
        #mui_code = self.render(mui_template_file,
        #                       userlogic_topmodule, threads,
        #                       def_top_parameters, def_top_localparams, def_top_ioports, name_top_ioports,
        #                       ext_addrwidth=configs['ext_addrwidth'], ext_burstlength=ext_burstlength,
        #                       single_clock=configs['single_clock'], lite=configs['io_lite'],
        #                       hdlname=hdlname,
        #                       ipcore_version=ipcore_version, 
        #                       mpd_ports=mpd_ports, mpd_parameters=mpd_parameters)
        #f = open(muipath+muiname, 'w')
        #f.write(mui_code)
        #f.close()

        # pao file
        pao_template_file = 'pao.txt'
        pao_code = self.render(pao_template_file,
                               userlogic_topmodule, threads,
                               def_top_parameters, def_top_localparams, def_top_ioports, name_top_ioports,
                               ext_addrwidth=configs['ext_addrwidth'], ext_burstlength=ext_burstlength,
                               single_clock=configs['single_clock'], lite=configs['io_lite'],
                               hdlname=hdlname,
                               ipcore_version=ipcore_version, 
                               mpd_ports=mpd_ports, mpd_parameters=mpd_parameters)
        f = open(paopath+paoname, 'w')
        f.write(pao_code)
        f.close()

        # tcl file
        tcl_code = ''
        if not configs['single_clock']:
            tcl_code = open(TEMPLATE_DIR+'pcore_tcl.tcl', 'r').read()
        f = open(tclpath+tclname, 'w')
        f.write(tcl_code)
        f.close()

        # component.xml
        gen = utils.componentgen.ComponentGen()
        xml_code = gen.generate(userlogic_topmodule, threads,
                                lite=configs['io_lite'], 
                                ext_addrwidth=configs['ext_addrwidth'],
                                ext_burstlength=ext_burstlength,
                                ext_ports=ext_ports,
                                ext_params=ext_params)
        f = open(xmlpath+xmlname, 'w')
        f.write(xml_code)
        f.close()

        # xdc
        xdc_code = ''
        if not configs['single_clock']:
            xdc_code = open(TEMPLATE_DIR+'ipxact.xdc', 'r').read()
        f = open(xdcpath+xdcname, 'w')
        f.write(xdc_code)
        f.close()

        # bd
        bd_code = ''
        bd_code = open(TEMPLATE_DIR+'bd.tcl', 'r').read()
        f = open(bdpath+bdname, 'w')
        f.write(bd_code)
        f.close()
        
        # xgui file
        xgui_template_file = 'xgui_tcl.txt'
        xgui_code = self.render(xgui_template_file,
                                userlogic_topmodule, threads,
                                def_top_parameters, def_top_localparams, def_top_ioports, name_top_ioports,
                                ext_addrwidth=configs['ext_addrwidth'], ext_burstlength=ext_burstlength,
                                single_clock=configs['single_clock'], lite=configs['io_lite'],
                                hdlname=hdlname,
                                ipcore_version=ipcore_version, 
                                mpd_ports=mpd_ports, mpd_parameters=mpd_parameters)
        f = open(xguipath+xguiname, 'w')
        f.write(xgui_code)
        f.close()

        # hdl file
        f = open(verilogpath+hdlname, 'w')
        f.write(code)
        f.close()

        # user test code
        usertestcode = None 
        if usertest is not None:
            usertestcode = open(usertest, 'r').read()

        # test file
        test_template_file = 'test_coram_axi.txt'
        test_code = self.render(test_template_file,
                                userlogic_topmodule, threads,
                                def_top_parameters, def_top_localparams, def_top_ioports, name_top_ioports,
                                ext_addrwidth=configs['ext_addrwidth'], ext_burstlength=ext_burstlength,
                                single_clock=configs['single_clock'], lite=configs['io_lite'],
                                hdlname=hdlname,
                                memimg=copied_memimg, binfile=binfile, 
                                usertestcode=usertestcode,
                                simaddrwidth=configs['sim_addrwidth'], 
                                clock_hperiod_userlogic=configs['hperiod_ulogic'],
                                clock_hperiod_controlthread=configs['hperiod_cthread'],
                                clock_hperiod_bus=configs['hperiod_bus'])
        f = open(testpath+testname, 'w')
        f.write(test_code)
        f.write( open(TEMPLATE_DIR+'axi_master_fifo.v', 'r').read() )
        f.close()

        # memory image for test
        if memimg is not None:
            shutil.copyfile(os.path.expanduser(memimg), testpath+memname)

        # makefile file
        makefile_template_file = 'Makefile.txt'
        makefile_code = self.render(makefile_template_file,
                                    userlogic_topmodule, threads,
                                    def_top_parameters, def_top_localparams, def_top_ioports, name_top_ioports,
                                    ext_addrwidth=configs['ext_addrwidth'], ext_burstlength=ext_burstlength,
                                    single_clock=configs['single_clock'], lite=configs['io_lite'],
                                    testname=testname)
        f = open(makefilepath+makefilename, 'w')
        f.write(makefile_code)
        f.close()

    #---------------------------------------------------------------------------
    def build_package_avalon(self, configs, synthesized_code, common_code, 
                             threads,
                             top_parameters, top_ioports, userlogic_topmodule, 
                             memimg, usertest):
        # default values
        ext_burstlength = 256

        # write to files, with AXI interface
        def_top_parameters = [] 
        def_top_localparams = []
        def_top_ioports = []
        name_top_ioports = []
        tcl_parameters = []
        tcl_ports = []

        asttocode = ASTCodeGenerator()

        for pk, pv in top_parameters.items():
            r = asttocode.visit(pv)
            def_top_parameters.append( r )
            if r.count('localparam'):
                def_top_localparams.append( r )
                continue
            _name = pv.name
            _value = asttocode.visit( pv.value )
            _dt = ('STRING' if r.count('"') else 
                   'INTEGER' if r.count('integer') else
                   'STD_LOGIC_VECTOR')
            tcl_parameters.append( (_name, _value, _dt) )

        for pk, (pv, pwidth) in top_ioports.items():
            name_top_ioports.append( pk )
            new_pv = vast.Wire(pv.name, pv.width, pv.signed)
            def_top_ioports.append( asttocode.visit(new_pv) )
            _name = pv.name
            _dir = ('Input' if isinstance(pv, vast.Input) else
                    'Output' if isinstance(pv, vast.Output) else
                    'Inout')
            _vec = str(pwidth)
            tcl_ports.append( (_name, _dir, _vec) )

        for thread in threads:
            _name = ''.join( ('coe_', thread.name, '_finish') )
            _dir = 'Output'
            _vec = '1'
            tcl_ports.append( (_name, _dir, _vec) )

        # write to files 
        ipcore_version = '_v1_00_a'
        dirname = 'pycoram_' + userlogic_topmodule + ipcore_version + '/'
        tclname = 'pycoram_' + userlogic_topmodule + '.tcl'
        hdlname = 'pycoram_' + userlogic_topmodule + '.v'
        common_hdlname = 'pycoram_common.v'
        testname = 'test_pycoram_' + userlogic_topmodule + '.v'
        memname = 'mem.img'
        makefilename = 'Makefile'
        copied_memimg = memname if memimg is not None else None
        binfile = (True if memimg is not None and memimg.endswith('.bin') else False)
        hdlpath = dirname + 'hdl/'
        verilogpath = dirname + 'hdl/verilog/'
        tclpath = dirname + 'hdl/verilog/'
        testpath = dirname + 'test/'
        makefilepath = dirname + 'test/'

        if not os.path.exists(dirname):
            os.mkdir(dirname)
        if not os.path.exists(dirname + '/' + 'hdl'):
            os.mkdir(dirname + '/' + 'hdl')
        if not os.path.exists(dirname + '/' + 'hdl/verilog'):
            os.mkdir(dirname + '/' + 'hdl/verilog')
        if not os.path.exists(dirname + '/' + 'test'):
            os.mkdir(dirname + '/' + 'test')

        # tcl file
        tcl_template_file = 'qsys_tcl.txt'
        tcl_code = self.render(tcl_template_file,
                               userlogic_topmodule, threads,
                               def_top_parameters, def_top_localparams, def_top_ioports, name_top_ioports,
                               ext_addrwidth=configs['ext_addrwidth'], ext_burstlength=ext_burstlength,
                               single_clock=configs['single_clock'], lite=configs['io_lite'],
                               hdlname=hdlname, common_hdlname=common_hdlname,
                               tcl_ports=tcl_ports, tcl_parameters=tcl_parameters)
        f = open(tclpath+tclname, 'w')
        f.write(tcl_code)
        f.close()

        # hdl file
        f = open(verilogpath+hdlname, 'w')
        f.write(synthesized_code)
        f.close()

        # common hdl file
        f = open(verilogpath+common_hdlname, 'w')
        f.write(common_code)
        f.close()

        # user test code
        usertestcode = None 
        if usertest is not None:
            usertestcode = open(usertest, 'r').read()

        # test file
        test_template_file = 'test_coram_avalon.txt'
        test_code = self.render(test_template_file,
                                userlogic_topmodule, threads,
                                def_top_parameters, def_top_localparams, def_top_ioports, name_top_ioports,
                                ext_addrwidth=configs['ext_addrwidth'], ext_burstlength=ext_burstlength,
                                single_clock=configs['single_clock'], lite=configs['io_lite'],
                                hdlname=hdlname, common_hdlname=common_hdlname,
                                memimg=copied_memimg, binfile=binfile, 
                                usertestcode=usertestcode,
                                simaddrwidth=configs['sim_addrwidth'], 
                                clock_hperiod_userlogic=configs['hperiod_ulogic'],
                                clock_hperiod_controlthread=configs['hperiod_cthread'],
                                clock_hperiod_bus=configs['hperiod_bus'])
        f = open(testpath+testname, 'w')
        f.write(test_code)
        f.write( open(TEMPLATE_DIR+'avalon_master_fifo.v', 'r').read() )
        f.close()

        # memory image for test
        if memimg is not None:
            shutil.copy(memimg, testpath+memname)

        # makefile file
        makefile_template_file = 'Makefile.txt'
        makefile_code = self.render(makefile_template_file,
                                    userlogic_topmodule, threads,
                                    def_top_parameters, def_top_localparams, def_top_ioports, name_top_ioports,
                                    ext_addrwidth=configs['ext_addrwidth'], ext_burstlength=ext_burstlength,
                                    single_clock=configs['single_clock'], lite=configs['io_lite'],
                                    testname=testname)
        f = open(makefilepath+makefilename, 'w')
        f.write(makefile_code)
        f.close()

#---------------------------------------------------------------------------
def main():
    from optparse import OptionParser
    INFO = "PyCoRAM: Python-based Portable IP-core Synthesis Framework for FPGA-based Computing"
    VERSION = utils.version.VERSION
    USAGE = "Usage: python pycoram.py [config] [-t topmodule] [-I includepath]+ [--memimg=filename] [--usertest=filename] [file]+"

    def showVersion():
        print(INFO)
        print(VERSION)
        print(USAGE)
        sys.exit()
    
    optparser = OptionParser()
    optparser.add_option("-v","--version",action="store_true",dest="showversion",
                         default=False,help="Show the version")
    optparser.add_option("-t","--top",dest="topmodule",
                         default="TOP",help="Top module of user logic, Default=userlogic")
    optparser.add_option("-I","--include",dest="include",action="append",
                         default=[],help="Include path")
    optparser.add_option("-D",dest="define",action="append",
                         default=[],help="Macro Definition")
    optparser.add_option("--memimg",dest="memimg",
                         default=None,help="Memory image file, Default=None")
    optparser.add_option("--usertest",dest="usertest",
                         default=None,help="User-defined test bench file, Default=None")

    (options, args) = optparser.parse_args()

    filelist = []
    for arg in args:
        filelist.extend( glob.glob(os.path.expanduser(arg)) )

    if options.showversion:
        showVersion()

    for f in filelist:
        if not os.path.exists(f): raise IOError("file not found: " + f)

    if len(filelist) == 0:
        showVersion()

    configfile = None
    userlogic_filelist = []
    controlthread_filelist = []
    for f in filelist:
        if f.endswith('.v'):
            userlogic_filelist.append(f)
        if f.endswith('.py'):
            controlthread_filelist.append(f)
        if f.endswith('.config'):
            if configfile is not None: raise IOError("Multiple configuration files")
            configfile = f

    print("----------------------------------------")
    print("Input files")
    print("  Configuration: %s" % configfile)
    print("  User-logic: %s" % ', '.join(userlogic_filelist) )
    print("  Control-thread: %s" % ', '.join(controlthread_filelist) )
    print("----------------------------------------")

    # default values
    configs = {
        'signal_width' : 32,
        'ext_addrwidth' : 32,
        'ext_datawidth' : 512,
        'single_clock' : True,
        'io_lite' : True,
        'if_type' : 'axi',
        'output' : 'out.v',
        'sim_addrwidth' : 27,
        'hperiod_ulogic' : 5,
        'hperiod_cthread' : 5,
        'hperiod_bus' : 5,
    }

    confp = configparser.SafeConfigParser()
    if configfile is not None:
        confp.read(configfile)

    if confp.has_section('synthesis'):
        for k, v in confp.items('synthesis'):
            if k == 'single_clock' or k == 'io_lite':
                configs[k] = False if 'n' in v or 'N' in v else True
            elif k == 'signal_width' or k == 'ext_addrwidth' or k == 'ext_datawidth':
                configs[k] = int(v)
            elif k not in configs:
                raise ValueError("No such configuration item: %s" % k)
            else:
                configs[k] = v

    if confp.has_section('simulation'):
        for k, v in confp.items('simulation'):
            if k == 'sim_addrwidth' or k == 'hperiod_ulogic' or k == 'hperiod_cthread' or k == 'hperiod_bus':
                configs[k] = int(v)
            elif k not in configs:
                raise ValueError("No such configuration item: %s" % k)
            else:
                configs[k] = v

    systembuilder = SystemBuilder()
    systembuilder.build(configs,
                        options.topmodule,
                        userlogic_filelist,
                        controlthread_filelist,
                        userlogic_include=options.include,
                        userlogic_define=options.define,
                        usertest=options.usertest,
                        memimg=options.memimg)
    
if __name__ == '__main__':
    main()
