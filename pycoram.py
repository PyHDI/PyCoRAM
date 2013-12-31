#-------------------------------------------------------------------------------
# pycoram.py
#
# PyCoRAM: Yet Another Implementation of CoRAM Memory Architecture
# 
# Copyright (C) 2013, Shinya Takamaeda-Yamazaki
# License: Apache 2.0
#-------------------------------------------------------------------------------

import os
import sys
import math
import re
from jinja2 import Environment, FileSystemLoader

import utils.version
from controlthread.controlthread import ControlThreadGenerator
from rtlconverter.rtlconverter import RtlConverter
import controlthread.coram_module as coram_module
from pyverilog.ast_code_generator.codegen import ASTCodeGenerator
import pyverilog.vparser.ast as vast

TEMPLATE_DIR = os.path.dirname(os.path.abspath(__file__)) + '/template/'

#-------------------------------------------------------------------------------
class SystemBuilder(object):
    def __init__(self):
        self.env = Environment(loader=FileSystemLoader(TEMPLATE_DIR))
        self.env.globals['int'] = int
        self.env.globals['log'] = math.log

    def render(self, template_file,
               userlogic_name, 
               threads, 
               def_top_parameters, def_top_localparams, def_top_ioports,
               name_top_ioports,
               ext_addrwidth=32, ext_burstlength=256,
               single_clock=False,
               hdlname=None, testname=None, ipcore_version=None,
               memimg=None, usertestcode=None, simaddrwidth=None, 
               mpd_parameters=None, mpd_ports=None,
               clock_hperiod_userlogic=None,
               clock_hperiod_controlthread=None,
               clock_hperiod_axi=None):

        ext_burstlen_width = int(math.ceil(math.log(ext_burstlength,2) + 1))
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
            'testname' : testname,
            'ipcore_version' : ipcore_version,
            'memimg' : memimg if memimg is not None else 'None',
            'usertestcode' : '' if usertestcode is None else usertestcode,
            'simaddrwidth' : simaddrwidth,
            
            'mpd_parameters' : () if mpd_parameters is None else mpd_parameters,
            'mpd_ports' : () if mpd_ports is None else mpd_ports,

            'clock_hperiod_userlogic' : clock_hperiod_userlogic,
            'clock_hperiod_controlthread' : clock_hperiod_controlthread,
            'clock_hperiod_axi' : clock_hperiod_axi,

            'single_clock' : single_clock,
            }
        
        template = self.env.get_template(template_file)
        rslt = template.render(template_dict)
        return rslt

    def build(self, controlthread_filelist,
              userlogic_topmodule, userlogic_filelist,
              userlogic_include=None, userlogic_define=None,
              signalwidth=64, ext_addrwidth=32, ext_max_datawidth=512,
              ext_burstlength=256, 
              ipcore_version='v1_00_a',
              memimg=None, usertest=None, simaddrwidth=20, 
              noaxi=False, outputfilename='out.v',
              clock_hperiod_userlogic=5,
              clock_hperiod_controlthread=5,
              clock_hperiod_axi=5,
              single_clock=False):
        
        # User Logic
        if (single_clock and 
            ((clock_hperiod_userlogic != clock_hperiod_controlthread) or
             (clock_hperiod_userlogic != clock_hperiod_axi) or
             (clock_hperiod_controlthread != clock_hperiod_axi))):
            raise ValueError("All clock periods should be same in single clock mode.")
            
        converter = RtlConverter(userlogic_filelist, userlogic_topmodule,
                                 include=userlogic_include,
                                 define=userlogic_define,
                                 single_clock=single_clock)
        userlogic_ast = converter.generate()
        top_parameters = converter.getTopParameters()
        top_ioports = converter.getTopIOPorts()

        converter.dumpCoramObject()

        asttocode = ASTCodeGenerator()
        userlogic_code= asttocode.visit(userlogic_ast)

        # Control Thread
        controlthread_codes = []
        generator = ControlThreadGenerator()
        thread_status = {}
        for f in controlthread_filelist:
            (thread_name, ext) = os.path.splitext(os.path.basename(f))
            controlthread_codes.append(
                generator.compile(f, thread_name,
                                  signalwidth=signalwidth, 
                                  ext_addrwidth=ext_addrwidth,
                                  ext_max_datawidth=ext_max_datawidth,
                                  dump=True))
            thread_status.update(generator.getStatus())

        # Template Render
        threads = []
        for tname, (tmemories, tinstreams, toutstreams, tchannels, tregisters, tiochannels, tioregisters) in sorted(thread_status.items(), key=lambda x:x[0]):
            threads.append( coram_module.ControlThread(tname, tmemories, tinstreams, toutstreams, tchannels, tregisters, tiochannels, tioregisters) )

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
        for pk, pv in top_ioports.items():
            new_pv = vast.Ioport(pv, vast.Wire(pv.name, pv.width, pv.signed))
            def_top_ioports.append( asttocode.visit(new_pv) )
            name_top_ioports.append( pk )

        node_template_file = 'node.txt' if noaxi else 'node_axi.txt'
        node_code = self.render(node_template_file,
                                userlogic_topmodule, threads, 
                                def_top_parameters, def_top_localparams, def_top_ioports, name_top_ioports, 
                                ext_addrwidth=ext_addrwidth,
                                ext_burstlength=ext_burstlength,
                                single_clock=single_clock)

        dmac_multibank_template_file = 'dmac_memory.txt'
        dmac_multibank_code = self.render(dmac_multibank_template_file,
                                          userlogic_topmodule, threads, 
                                          def_top_parameters, def_top_localparams, def_top_ioports, name_top_ioports, 
                                          ext_addrwidth=ext_addrwidth,
                                          ext_burstlength=ext_burstlength,
                                          single_clock=single_clock)

        # finalize of code generation
        entire_code = []
        entire_code.append(node_code)
        entire_code.append(userlogic_code)
        entire_code.extend(controlthread_codes)

        dmac_stream = open(TEMPLATE_DIR+'dmac_stream.v', 'r').read()
        dmac_iochannel = open(TEMPLATE_DIR+'dmac_iochannel.v', 'r').read()
        dmac_ioregister = open(TEMPLATE_DIR+'dmac_ioregister.v', 'r').read()
        entire_code.append(dmac_multibank_code)
        entire_code.append(dmac_stream)
        entire_code.append(dmac_iochannel)
        entire_code.append(dmac_ioregister)
        if not noaxi:
            entire_code.append( open(TEMPLATE_DIR+'axi_master_fifo.v', 'r').read() )
            entire_code.append( open(TEMPLATE_DIR+'axi_slave_fifo.v', 'r').read() )
        code = ''.join(entire_code)

        # write to file, without AXI interfaces
        if noaxi: 
            f = open(outputfilename, 'w')
            f.write(code)
            f.close()
            return

        # write to files, with AXI interface
        def_top_parameters = []
        def_top_ioports = []
        mpd_parameters = []
        mpd_ports = []

        for pk, pv in top_parameters.items():
            r = asttocode.visit(pv)
            def_top_parameters.append( r )
            if r.count('localparam'):
                continue
            _name = pv.name
            _value = asttocode.visit( pv.value )
            _dt = 'string' if r.count('"') else 'integer'
            mpd_parameters.append( (_name, _value, _dt) )

        for pk, pv in top_ioports.items():
            new_pv = vast.Wire(pv.name, pv.width, pv.signed)
            def_top_ioports.append( asttocode.visit(new_pv) )
            _name = pv.name
            _dir = ('I' if isinstance(pv, vast.Input) else
                    'O' if isinstance(pv, vast.Output) else
                    'IO')
            _vec = '' if pv.width is None else asttocode.visit(pv.width) 
            mpd_ports.append( (_name, _dir, _vec) )

        # write to files 
        # with AXI interface, create IPcore dir
        ipcore_version = '_v1_00_a'
        mpd_version = '_v2_1_0'
        dirname = 'pycoram_' + userlogic_topmodule + ipcore_version + '/'
        mpdname = 'pycoram_' + userlogic_topmodule + mpd_version + '.mpd'
        #muiname = 'pycoram_' + userlogic_topmodule + mpd_version + '.mui'
        paoname = 'pycoram_' + userlogic_topmodule + mpd_version + '.pao'
        tclname = 'pycoram_' + userlogic_topmodule + mpd_version + '.tcl'
        hdlname = 'pycoram_' + userlogic_topmodule + '.v'
        testname = 'test_pycoram_' + userlogic_topmodule + '.v'
        memname = 'mem.img'
        makefilename = 'Makefile'
        copied_memimg = memname if memimg is not None else None

        hdlpath = dirname + 'hdl/'
        verilogpath = dirname + 'hdl/verilog/'
        mpdpath = dirname + 'data/'
        #muipath = dirname + 'data/'
        paopath = dirname + 'data/'
        tclpath = dirname + 'data/'
        testpath = dirname + 'test/'
        makefilepath = dirname + 'test/'

        if not os.path.exists(dirname):
            os.mkdir(dirname)
        if not os.path.exists(dirname + '/' + 'data'):
            os.mkdir(dirname + '/' + 'data')
        if not os.path.exists(dirname + '/' + 'doc'):
            os.mkdir(dirname + '/' + 'doc')
        if not os.path.exists(dirname + '/' + 'hdl'):
            os.mkdir(dirname + '/' + 'hdl')
        if not os.path.exists(dirname + '/' + 'hdl/verilog'):
            os.mkdir(dirname + '/' + 'hdl/verilog')
        if not os.path.exists(dirname + '/' + 'test'):
            os.mkdir(dirname + '/' + 'test')

        # hdl file
        f = open(verilogpath+hdlname, 'w')
        f.write(code)
        f.close()

        # mpd file
        mpd_template_file = 'mpd.txt'
        mpd_code = self.render(mpd_template_file,
                               userlogic_topmodule, threads, 
                               def_top_parameters, def_top_localparams, def_top_ioports, name_top_ioports,
                               ext_addrwidth=ext_addrwidth, ext_burstlength=ext_burstlength,
                               single_clock=single_clock,
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
        #                       ext_addrwidth=ext_addrwidth, ext_burstlength=ext_burstlength, 
        #                       single_clock=single_clock,
        #                       mpd_parameters=mpd_parameters)
        #f = open(muipath+muiname, 'w')
        #f.write(mui_code)
        #f.close()

        # pao file
        pao_template_file = 'pao.txt'
        pao_code = self.render(pao_template_file,
                               userlogic_topmodule, threads,
                               def_top_parameters, def_top_localparams, def_top_ioports, name_top_ioports,
                               ext_addrwidth=ext_addrwidth, ext_burstlength=ext_burstlength,
                               single_clock=single_clock,
                               hdlname=hdlname, ipcore_version=ipcore_version)
        f = open(paopath+paoname, 'w')
        f.write(pao_code)
        f.close()

        # tcl file
        tcl_code = ''
        if not single_clock:
            tcl_code = open(TEMPLATE_DIR+'tcl.tcl', 'r').read()
        f = open(tclpath+tclname, 'w')
        f.write(tcl_code)
        f.close()

        # user test code
        usertestcode = None 
        if usertest is not None:
            usertestcode = open(usertest, 'r').read()

        # test file
        test_template_file = 'test_coram.txt'
        test_code = self.render(test_template_file,
                                userlogic_topmodule, threads,
                                def_top_parameters, def_top_localparams, def_top_ioports, name_top_ioports,
                                ext_addrwidth=ext_addrwidth, ext_burstlength=ext_burstlength,
                                single_clock=single_clock,
                                hdlname=hdlname,
                                memimg=copied_memimg, simaddrwidth=simaddrwidth, usertestcode=usertestcode,
                                clock_hperiod_userlogic=clock_hperiod_userlogic,
                                clock_hperiod_controlthread=clock_hperiod_controlthread,
                                clock_hperiod_axi=clock_hperiod_axi)
        f = open(testpath+testname, 'w')
        f.write(test_code)
        f.close()

        # memory image for test
        if memimg is not None:
            f = open(testpath+memname, 'w')
            f.write(open(memimg, 'r').read())
            f.close()

        # makefile file
        makefile_template_file = 'Makefile.txt'
        makefile_code = self.render(makefile_template_file,
                                    userlogic_topmodule, threads,
                                    def_top_parameters, def_top_localparams, def_top_ioports, name_top_ioports,
                                    ext_addrwidth=ext_addrwidth, ext_burstlength=ext_burstlength,
                                    single_clock=single_clock,
                                    testname=testname)
        f = open(makefilepath+makefilename, 'w')
        f.write(makefile_code)
        f.close()

def main():
    from optparse import OptionParser
    INFO = "PyCoRAM: Yet Another Implementation of CoRAM Memory Architecture for Modern FPGA-based computing"
    VERSION = utils.version.VERSION
    USAGE = "Usage: python pycoram.py [-t topmodule] [-I includepath]+ [file]+"

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
    optparser.add_option("--signalwidth",dest="signalwidth",type=int,
                         default=64,help="Signal width, Default=64")
    optparser.add_option("--extaddrwidth",dest="extaddrwidth",type=int,
                         default=32,help="External bus address width, Default=32")
    optparser.add_option("--extdatawidth",dest="extdatawidth",type=int,
                         default=512,help="Maximum External bus data width, Default=512")
    optparser.add_option("--ipver",dest="ipcore_version",
                         default="v1_00_a",help="IPcore version, Default=v1_00_a")
    optparser.add_option("--memimg",dest="memimg",
                         default=None,help="Memory image file, Default=None")
    optparser.add_option("--simaddrwidth",dest="simaddrwidth",type=int,
                         default=20,help="Simulated DRAM address width, Default=20")
    optparser.add_option("--usertest",dest="usertest",
                         default=None,help="User-defined test code file, Default=None")
    optparser.add_option("--singleclock",action="store_true",dest="single_clock",
                         default=False,help="Use single clock mode")
    optparser.add_option("--hperiod_ulogic",dest="hperiod_ulogic",type=int,
                         default=5,help="Clock Half Period (User logic), Default=5")
    optparser.add_option("--hperiod_cthread",dest="hperiod_cthread",type=int,
                         default=5,help="Clock Half Period (Control Thread), Default=5")
    optparser.add_option("--hperiod_axi",dest="hperiod_axi",type=int,
                         default=5,help="Clock Half Period (AXI), Default=5")
    optparser.add_option("--noaxi",action="store_true",dest="noaxi",
                         default=False,help="without AXI interface")
    optparser.add_option("-o","--output",dest="outputfile",
                         default="out.v",help="Output file name in no-AXI mode, Default=out.v")
    (options, args) = optparser.parse_args()

    filelist = args
    if options.showversion:
        showVersion()

    for f in filelist:
        if not os.path.exists(f): raise IOError("file not found: " + f)

    if len(filelist) == 0:
        showVersion()

    userlogic_filelist = []
    controlthread_filelist = []
    for f in filelist:
        if f.endswith('.v'):
            userlogic_filelist.append(f)
        if f.endswith('.py'):
            controlthread_filelist.append(f)
    
    systembuilder = SystemBuilder()
    systembuilder.build(controlthread_filelist,
                        options.topmodule, userlogic_filelist,
                        userlogic_include=options.include,
                        userlogic_define=options.define,
                        signalwidth=options.signalwidth,
                        ext_addrwidth=options.extaddrwidth,
                        ext_max_datawidth=options.extdatawidth,
                        ipcore_version=options.ipcore_version,
                        memimg=options.memimg,
                        usertest=options.usertest,
                        simaddrwidth=options.simaddrwidth,
                        noaxi=options.noaxi,
                        outputfilename=options.outputfile,
                        clock_hperiod_userlogic=options.hperiod_ulogic,
                        clock_hperiod_controlthread=options.hperiod_cthread,
                        clock_hperiod_axi=options.hperiod_axi,
                        single_clock=options.single_clock)
    
if __name__ == '__main__':
    main()
