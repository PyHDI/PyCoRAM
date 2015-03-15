import xml.dom.minidom
import codecs

PORTLIST = ('AWID', 'AWADDR', 'AWLEN', 'AWSIZE', 'AWBURST', 'AWLOCK',
            'AWCACHE', 'AWPROT', 'AWQOS', 'AWUSER', 'AWVALID', 'AWREADY',
            'WDATA', 'WSTRB', 'WLAST', 'WUSER', 'WVALID', 'WREADY', 
            'BID', 'BRESP', 'BUSER', 'BVALID', 'BREADY', 
            'ARID', 'ARADDR', 'ARLEN', 'ARSIZE', 'ARBURST', 'ARLOCK',
            'ARCACHE', 'ARPROT', 'ARQOS', 'ARUSER', 'ARVALID', 'ARREADY', 
            'RID', 'RDATA', 'RRESP', 'RLAST', 'RUSER', 'RVALID', 'RREADY' )

#-------------------------------------------------------------------------------
class ComponentGen(object):
    def __init__(self):
        self.impl = None
        self.doc = None
        self.top = None
        self.userlogic_name = None
        self.threads = None
        self.lite = False
        self.ext_addrwidth = 32
        self.ext_burstlength = 256
        self.ext_ports = ()
        self.ext_params = ()

    #---------------------------------------------------------------------------
    def generate(self, userlogic_name, threads,
                 lite=False, ext_addrwidth=32, ext_burstlength=256, ext_ports=(), ext_params=()):
        self.userlogic_name = userlogic_name
        self.threads = threads
        self.lite = lite
        self.ext_addrwidth = ext_addrwidth
        self.ext_burstlength = ext_burstlength
        self.ext_ports = ext_ports
        self.ext_params = ext_params

        self.init()
        
        self.top.appendChild(self.mkVendor())
        self.top.appendChild(self.mkLibrary())
        self.top.appendChild(self.mkName('pycoram_' + self.userlogic_name.lower()))
        self.top.appendChild(self.mkVersion())
        self.top.appendChild(self.mkBusInterfaces())
        self.top.appendChild(self.mkAddressSpaces())
        self.top.appendChild(self.mkMemoryMaps())
        self.top.appendChild(self.mkModel())

        return self.doc.toprettyxml(indent='  ')

    #---------------------------------------------------------------------------
    def setAttribute(self, obj, name, text):
        attrobj = self.doc.createAttribute(name)
        attrobj.value = text
        obj.setAttributeNode(attrobj)
    
    def setText(self, obj, text):
        textobj = self.doc.createTextNode(str(text))
        obj.appendChild(textobj)

    #---------------------------------------------------------------------------
    def init(self):
        self.impl = xml.dom.minidom.getDOMImplementation()
        self.doc = self.impl.createDocument('spirit', 'spirit:component', None)
        self.top = self.doc.documentElement
        
        self.setAttribute(self.top, 'xmlns:xilinx', "http://www.xilinx.com")
        self.setAttribute(self.top, 'xmlns:spirit',
                          "http://www.spiritconsortium.org/XMLSchema/SPIRIT/1685-2009")
        self.setAttribute(self.top, 'xmlns:xsi', "http://www.w3.org/2001/XMLSchema-instance")

    #---------------------------------------------------------------------------
    def mkVendor(self):
        vendor = self.doc.createElement('spirit:vendor')
        self.setText(vendor, 'PyCoRAM')
        return vendor

    def mkLibrary(self):
        library = self.doc.createElement('spirit:library')
        self.setText(library, 'user')
        return library

    def mkVersion(self):
        version = self.doc.createElement('spirit:version')
        self.setText(version, str(1.0))
        return version

    def mkName(self, v):
        name = self.doc.createElement('spirit:name')
        self.setText(name, v)
        return name

    #---------------------------------------------------------------------------
    def mkBusInterfaces(self):
        bus = self.doc.createElement('spirit:busInterfaces')
        for thread in self.threads:
            for memory in thread.memories:
                bus.appendChild(self.mkBusInterface(thread, memory))
            for instream in thread.instreams:
                bus.appendChild(self.mkBusInterface(thread, instream))
            for outstream in thread.outstreams:
                bus.appendChild(self.mkBusInterface(thread, oustream))
            for iochannel in thread.iochannels:
                bus.appendChild(self.mkBusInterface(thread, iochannel, master=False))
            for ioregister in thread.ioregisters:
                bus.appendChild(self.mkBusInterface(thread, ioregister, master=False))
        for thread in self.threads:
            for memory in thread.memories:
                bus.appendChild(self.mkBusInterfaceReset(thread, memory))
                bus.appendChild(self.mkBusInterfaceClock(thread, memory))
            for instream in thread.instreams:
                bus.appendChild(self.mkBusInterfaceReset(thread, instream))
                bus.appendChild(self.mkBusInterfaceClock(thread, instream))
            for outstream in thread.outstreams:
                bus.appendChild(self.mkBusInterfaceReset(thread, oustream))
                bus.appendChild(self.mkBusInterfaceClock(thread, oustream))
            for iochannel in thread.iochannels:
                bus.appendChild(self.mkBusInterfaceReset(thread, iochannel))
                bus.appendChild(self.mkBusInterfaceClock(thread, iochannel))
            for ioregister in thread.ioregisters:
                bus.appendChild(self.mkBusInterfaceReset(thread, ioregister))
                bus.appendChild(self.mkBusInterfaceClock(thread, ioregister))
        return bus

    #---------------------------------------------------------------------------
    def mkBusInterface(self, thread, obj, master=True):
        name = thread.name + '_' + obj.name + '_AXI'
        datawidth = obj.ext_datawidth
        interface = self.doc.createElement('spirit:busInterface')
        interface.appendChild(self.mkName(name))
        interface.appendChild(self.mkBusType())
        interface.appendChild(self.mkAbstractionType())
        if master:
            interface.appendChild(self.mkMaster(name))
        else:
            interface.appendChild(self.mkSlave(name))
        interface.appendChild(self.mkPortMaps(name))
        interface.appendChild(self.mkParameters(name, datawidth, master))
        return interface

    def mkBusType(self):
        bustype = self.doc.createElement('spirit:busType')
        self.setAttribute(bustype, 'spirit:vendor', "xilinx.com")
        self.setAttribute(bustype, 'spirit:library', "interface")
        self.setAttribute(bustype, 'spirit:name', "aximm")
        self.setAttribute(bustype, 'spirit:version', "1.0")
        return bustype

    def mkAbstractionType(self):
        abstractiontype = self.doc.createElement('spirit:abstractionType')
        self.setAttribute(abstractiontype, 'spirit:vendor', "xilinx.com")
        self.setAttribute(abstractiontype, 'spirit:library', "interface")
        self.setAttribute(abstractiontype, 'spirit:name', "aximm_rtl")
        self.setAttribute(abstractiontype, 'spirit:version', "1.0")
        return abstractiontype

    def mkMaster(self, name):
        master = self.doc.createElement('spirit:master')
        addressspaceref = self.doc.createElement('spirit:addressSpaceRef')
        self.setAttribute(addressspaceref, 'spirit:addressSpaceRef', name)
        return master
    
    def mkSlave(self, name):
        slave = self.doc.createElement('spirit:slave')
        memorymapref = self.doc.createElement('spirit:memoryMapRef')
        self.setAttribute(memorymapref, 'spirit:memoryMapRef', name)
        return slave

    def mkPortMaps(self, name):
        portmaps = self.doc.createElement('spirit:portMaps')
        for port in PORTLIST:
            portmaps.appendChild(self.mkPortMap(name, port))
        return portmaps

    def mkPortMap(self, name, attr):
        portmap = self.doc.createElement('spirit:portMap')
        portmap.appendChild(self.mkLogicalPort(attr))
        portmap.appendChild(self.mkPhysicalPort(name, attr))
        return portmap

    def mkLogicalPort(self, attr):
        logicalport = self.doc.createElement('spirit:logicalPort')
        logicalport.appendChild(self.mkName(attr))
        return logicalport
    
    def mkPhysicalPort(self, name, attr):
        physicalport = self.doc.createElement('spirit:physicalPort')
        physicalport.appendChild(self.mkName(name + '_' + attr))
        return physicalport
    
    def mkParameters(self, name, datawidth, master=True):
        parameters = self.doc.createElement('spirit:parameters')
        parameters.appendChild(self.mkParameterDatawidth(name, datawidth))
        if master:
            parameters.appendChild(self.mkParameterNumReg(name, 4))
        parameters.appendChild(self.mkParameterBurst(name, 0))
        return parameters

    def mkParameterDatawidth(self, name, datawidth):
        parameter = self.doc.createElement('spirit:parameter')
        parameter.appendChild(self.mkName('WIZ.DATA_WIDTH'))
        value = self.doc.createElement('spirit:value')
        self.setAttribute(value, 'spirit:format', "long")
        self.setAttribute(value, 'spirit:id', "BUSIFPARAM_VALUE." +
                          name + ".WIZ.DATA_WIDTH")
        self.setAttribute(value, 'spirit:choiceRef', "choices_0")
        self.setText(value, datawidth)
        parameter.appendChild(value)
        return parameter

    def mkParameterNumReg(self, name, num_reg):
        parameter = self.doc.createElement('spirit:parameter')
        parameter.appendChild(self.mkName('WIZ.NUM_REG'))
        value = self.doc.createElement('spirit:value')
        self.setAttribute(value, 'spirit:format', "long")
        self.setAttribute(value, 'spirit:id', "BUSIFPARAM_VALUE." +
                          name + ".WIZ.NUM_REG")
        self.setAttribute(value, 'spirit:minimum', "4")
        self.setAttribute(value, 'spirit:maximum', "512")
        self.setAttribute(value, 'spirit:rangeType', "long")
        self.setText(value, num_reg)
        parameter.appendChild(value)
        return parameter

    def mkParameterBurst(self, name, num):
        parameter = self.doc.createElement('spirit:parameter')
        parameter.appendChild(self.mkName('SUPPORTS_NARROW_BURST'))
        value = self.doc.createElement('spirit:value')
        self.setAttribute(value, 'spirit:format', "long")
        self.setAttribute(value, 'spirit:id', "BUSIFPARAM_VALUE." +
                          name + ".SUPPORTS_NARROW_BURST")
        self.setAttribute(value, 'spirit:choiceRef', "choices_1")
        self.setText(value, num)
        parameter.appendChild(value)
        return parameter

    #---------------------------------------------------------------------------
    def mkBusInterfaceReset(self, thread, obj):
        name = thread.name + '_' + obj.name + '_AXI'
        datawidth = obj.ext_datawidth
        interface = self.doc.createElement('spirit:busInterface')
        interface.appendChild(self.mkName(name + '_RST'))
        interface.appendChild(self.mkBusTypeReset())
        interface.appendChild(self.mkAbstractionTypeReset())
        interface.appendChild(self.mkSlaveReset())
        interface.appendChild(self.mkPortMapsReset(name))
        interface.appendChild(self.mkParametersReset(name))
        return interface

    def mkBusTypeReset(self):
        bustype = self.doc.createElement('spirit:busType')
        self.setAttribute(bustype, 'spirit:vendor', "xilinx.com")
        self.setAttribute(bustype, 'spirit:library', "signal")
        self.setAttribute(bustype, 'spirit:name', "reset")
        self.setAttribute(bustype, 'spirit:version', "1.0")
        return bustype

    def mkAbstractionTypeReset(self):
        abstractiontype = self.doc.createElement('spirit:abstractionType')
        self.setAttribute(abstractiontype, 'spirit:vendor', "xilinx.com")
        self.setAttribute(abstractiontype, 'spirit:library', "signal")
        self.setAttribute(abstractiontype, 'spirit:name', "reset_rtl")
        self.setAttribute(abstractiontype, 'spirit:version', "1.0")
        return abstractiontype

    def mkSlaveReset(self):
        slave = self.doc.createElement('spirit:slave')
        return slave

    def mkPortMapsReset(self, name):
        portmaps = self.doc.createElement('spirit:portMaps')
        portmaps.appendChild(self.mkPortMapReset(name))
        return portmaps

    def mkPortMapReset(self, name):
        portmap = self.doc.createElement('spirit:portMap')
        portmap.appendChild(self.mkLogicalPort('RST'))
        portmap.appendChild(self.mkPhysicalPortReset(name))
        return portmap

    def mkPhysicalPortReset(self, name):
        physicalport = self.doc.createElement('spirit:physicalPort')
        physicalport.appendChild(self.mkName(name + '_' + 'ARESETN'))
        return physicalport
    
    def mkParametersReset(self, name):
        parameters = self.doc.createElement('spirit:parameters')
        parameters.appendChild(self.mkParameterPolarity(name))
        return parameters

    def mkParameterPolarity(self, name):
        parameter = self.doc.createElement('spirit:parameter')
        parameter.appendChild(self.mkName('POLARITY'))
        value = self.doc.createElement('spirit:value')
        self.setAttribute(value, 'spirit:id', "BUSIFPARAM_VALUE." +
                          name + ".POLARITY")
        self.setText(value, 'ACTIVE_LOW')
        parameter.appendChild(value)
        return parameter

    #---------------------------------------------------------------------------
    def mkBusInterfaceClock(self, thread, obj):
        name = thread.name + '_' + obj.name + '_AXI'
        datawidth = obj.ext_datawidth
        interface = self.doc.createElement('spirit:busInterface')
        interface.appendChild(self.mkName(name + '_CLK'))
        interface.appendChild(self.mkBusTypeClock())
        interface.appendChild(self.mkAbstractionTypeClock())
        interface.appendChild(self.mkSlaveClock())
        interface.appendChild(self.mkPortMapsClock(name))
        interface.appendChild(self.mkParametersClock(name))
        return interface

    def mkBusTypeClock(self):
        bustype = self.doc.createElement('spirit:busType')
        self.setAttribute(bustype, 'spirit:vendor', "xilinx.com")
        self.setAttribute(bustype, 'spirit:library', "signal")
        self.setAttribute(bustype, 'spirit:name', "clock")
        self.setAttribute(bustype, 'spirit:version', "1.0")
        return bustype

    def mkAbstractionTypeClock(self):
        abstractiontype = self.doc.createElement('spirit:abstractionType')
        self.setAttribute(abstractiontype, 'spirit:vendor', "xilinx.com")
        self.setAttribute(abstractiontype, 'spirit:library', "signal")
        self.setAttribute(abstractiontype, 'spirit:name', "clock_rtl")
        self.setAttribute(abstractiontype, 'spirit:version', "1.0")
        return abstractiontype

    def mkSlaveClock(self):
        slave = self.doc.createElement('spirit:slave')
        return slave

    def mkPortMapsClock(self, name):
        portmaps = self.doc.createElement('spirit:portMaps')
        portmaps.appendChild(self.mkPortMapClock(name))
        return portmaps

    def mkPortMapClock(self, name):
        portmap = self.doc.createElement('spirit:portMap')
        portmap.appendChild(self.mkLogicalPort('CLK'))
        portmap.appendChild(self.mkPhysicalPortClock(name))
        return portmap

    def mkPhysicalPortClock(self, name):
        physicalport = self.doc.createElement('spirit:physicalPort')
        physicalport.appendChild(self.mkName(name + '_' + 'ACLK'))
        return physicalport
    
    def mkParametersClock(self, name):
        parameters = self.doc.createElement('spirit:parameters')
        parameters.appendChild(self.mkParameterAssocBusIf(name))
        parameters.appendChild(self.mkParameterAssocReset(name))
        return parameters

    def mkParameterAssocBusIf(self, name):
        parameter = self.doc.createElement('spirit:parameter')
        parameter.appendChild(self.mkName('ASSOCIATED_BUSIF'))
        value = self.doc.createElement('spirit:value')
        self.setAttribute(value, 'spirit:id', "BUSIFPARAM_VALUE." +
                          name + ".ASSOCIATED_BUSIF")
        self.setText(value, name)
        parameter.appendChild(value)
        return parameter

    def mkParameterAssocReset(self, name):
        parameter = self.doc.createElement('spirit:parameter')
        parameter.appendChild(self.mkName('ASSOCIATED_RESET'))
        value = self.doc.createElement('spirit:value')
        self.setAttribute(value, 'spirit:id', "BUSIFPARAM_VALUE." +
                          name + ".ASSOCIATED_RESET")
        self.setText(value, name + '_ARESETN')
        parameter.appendChild(value)
        return parameter

    #---------------------------------------------------------------------------
    def mkAddressSpaces(self):
        spaces = self.doc.createElement('spirit:addressSpaces')
        for thread in self.threads:
            for memory in thread.memories:
                spaces.appendChild(self.mkAddressSpace(thread, memory))
            for instream in thread.instreams:
                spaces.appendChild(self.mkAddressSpace(thread, instream))
            for outstream in thread.outstreams:
                spaces.appendChild(self.mkAddressSpace(thread, oustream))
        return spaces

    def mkAddressSpace(self, thread, obj):
        name = thread.name + '_' + obj.name + '_AXI'
        space = self.doc.createElement('spirit:addressSpace')
        space.appendChild(self.mkName(name))
        range = self.doc.createElement('spirit:range')
        self.setAttribute(range, 'spirit:format', "long")
        self.setAttribute(range, 'spirit:resolve', "dependent")
        self.setAttribute(range, 'spirit:dependency',
                          ("pow(2,(spirit:decode(id(&apos;MODELPARAM_VALUE.C_" +
                           name + "_ADDR_WIDTH&apos;)) - 1) + 1)"))
        self.setAttribute(range, 'spirit:minimum', "0")
        self.setAttribute(range, 'spirit:maximum', "4294967296")
        self.setText(range, 4294967296)
        space.appendChild(range)
        width = self.doc.createElement('spirit:width')
        self.setAttribute(width, 'spirit:format', "long")
        self.setAttribute(width, 'spirit:resolve', "dependent")
        self.setAttribute(width, 'spirit:dependency',
                          ("(spirit:decode(id(&apos;MODELPARAM_VALUE.C_" +
                           name + "_DATA_WIDTH&apos;)) - 1) + 1"))
        self.setText(width, self.ext_addrwidth)
        space.appendChild(width)
        return space

    #---------------------------------------------------------------------------
    def mkMemoryMaps(self):
        maps = self.doc.createElement('spirit:memoryMaps')
        for thread in self.threads:
            for memory in thread.memories:
                maps.appendChild(self.mkMemoryMap(thread, memory))
            for instream in thread.instreams:
                maps.appendChild(self.mkMemoryMap(thread, instream))
            for outstream in thread.outstreams:
                maps.appendChild(self.mkMemoryMap(thread, oustream))
        return maps
    
    def mkMemoryMap(self, thread, obj):
        name = thread.name + '_' + obj.name + '_AXI'
        map = self.doc.createElement('spirit:memoryMap')
        map.appendChild(self.mkName(name))
        baseaddr = self.doc.createElement('spirit:baseAddress')
        self.setAttribute(baseaddr, 'spirit:format', "long")
        self.setAttribute(baseaddr, 'spirit:resolve', "user")
        self.setText(baseaddr, 0)
        map.appendChild(baseaddr)
        range = self.doc.createElement('spirit:range')
        self.setAttribute(range, 'spirit:format', "long")
        self.setText(range, 4096)
        map.appendChild(range)
        width = self.doc.createElement('spirit:width')
        self.setAttribute(width, 'spirit:format', "long")
        self.setText(width, obj.ext_datawidth)
        map.appendChild(width)
        usage = self.doc.createElement('spirit:usage')
        self.setText(usage, 'register')
        map.appendChild(usage)
        map.appendChild(self.mkMemoryMapParameters(name))
        return map

    def mkMemoryMapParameters(self, name):
        parameters = self.doc.createElement('spirit:parameters')
        parameters.appendChild(self.mkMemoryMapParameterBase(name))
        parameters.appendChild(self.mkMemoryMapParameterHigh(name))
        return parameters
    
    def mkMemoryMapParameterBase(self, name):
        base = self.doc.createElement('spirit:parameter')
        base.appendChild(self.mkName('OFFSET_BASE_PARAM'))
        value = self.doc.createElement('spirit:value')
        self.setAttribute(value, 'spirit:id',
                          "ADDRBLOCKPARAM_VALUE." + name + "_REG.OFFSET_BASE_PARAM")
        self.setAttribute(value, 'spirit:dependency',
                          "ADDRBLOCKPARAM_VALUE." + name + "_reg.OFFSET_BASE_PARAM")
        self.setText(value, 'C_' + name + '_BASEADDR')
        base.appendChild(value)
        return base

    def mkMemoryMapParameterHigh(self, name):
        high = self.doc.createElement('spirit:parameter')
        high.appendChild(self.mkName('OFFSET_HIGH_PARAM'))
        value = self.doc.createElement('spirit:value')
        self.setAttribute(value, 'spirit:id',
                          "ADDRBLOCKPARAM_VALUE." + name + "_REG.OFFSET_HIGH_PARAM")
        self.setAttribute(value, 'spirit:dependency',
                          "ADDRBLOCKPARAM_VALUE." + name + "_reg.OFFSET_HIGH_PARAM")
        self.setText(value, 'C_' + name + '_HIGHADDR')
        high.appendChild(value)
        return high

    #---------------------------------------------------------------------------
    def mkModel(self):
        model = self.doc.createElement('spirit:model')
        model.appendChild(self.mkViews())
        model.appendChild(self.mkPorts())
        model.appendChild(self.mkModelParameters())
        return model
    
    #---------------------------------------------------------------------------
    def mkViews(self):
        views = self.doc.createElement('spirit:views')
        views.appendChild(self.mkView('xilinx_verilogsynthesis',
                                      'Verilog Synthesis',
                                      'verilogSource:vivado.xilinx.com:synthesis',
                                      'verilog',
                                      'pycoram_' + self.userlogic_name.lower() + '_v1_0',
                                      'xilinx_verilogsynthesis_view_fileset'))
        views.appendChild(self.mkView('xilinx_verilogbehavioralsimulation',
                                      'Verilog Simulation',
                                      'verilogSource:vivado.xilinx.com:simulation',
                                      'verilog',
                                      'pycoram_' + self.userlogic_name.lower() + '_v1_0',
                                      'xilinx_verilogbehavioralsimulation_view_fileset'))
        views.appendChild(self.mkView('xilinx_softwaredriver'
                                      'Software Driver',
                                      'Verilog Simulation',
                                      ':vivado.xilinx.com:sw.driver',
                                      None,
                                      None,
                                      'xilinx_softwaredriver_view_fileset'))
        views.appendChild(self.mkView('xilinx_xpgui',
                                      'UI Layout',
                                      ':vivado.xilinx.com:xgui.ui',
                                      None,
                                      None,
                                      'xilinx_xpgui_view_fileset'))
        views.appendChild(self.mkView('bd_tcl',
                                      'Block Diagram',
                                      ':vivado.xilinx.com:block.diagram',
                                      None,
                                      None,
                                      'bd_tcl_view_fileset'))
        return views
                         
    def mkView(self, name, displayname, envidentifier, language, modelname, localname):
        view = self.doc.createElement('spirit:view')
        view.appendChild(self.mkName(name))
        
        i_displayname = self.doc.createElement('spirit:displayName')
        self.setText(i_displayname, displayname)
        view.appendChild(i_displayname)
        
        i_envidentifier = self.doc.createElement('spirit:envIdentifier')
        self.setText(i_envidentifier, envidentifier)
        view.appendChild(i_envidentifier)
        
        if language is not None:
            i_language = self.doc.createElement('spirit:language')
            self.setText(i_language, language)
            view.appendChild(i_language)

        if modelname is not None:
            i_modelname = self.doc.createElement('spirit:modelName')
            self.setText(i_modelname, modelname)
            view.appendChild(i_modelname)
        
        filesetref = self.doc.createElement('spirit:fileSetRef')
        i_localname = self.doc.createElement('spirit:localName')
        self.setText(i_localname, localname)
        filesetref.appendChild(i_localname)
        view.appendChild(filesetref)
        
        return view
        
    #---------------------------------------------------------------------------
    def mkPorts(self):
        ports = self.doc.createElement('spirit:ports')
        ports.appendChild(self.mkPortSignal('UCLK', 'in',
                                            None, None, None, None))
        ports.appendChild(self.mkPortSignal('URESETN', 'in',
                                            None, None, None, None))
        for thread in self.threads:
            ports.appendChild(self.mkPortSignal(therad.name + '_CCLK', 'in',
                                                None, None, None, None))
            ports.appendChild(self.mkPortSignal(therad.name + '_CRESETN', 'in',
                                                None, None, None, None))
            for memory in thread.memories:
                for p in self.mkPortMaster(thread, memory): ports.appendChild(p)
            for instream in thread.instreams:
                for p in self.mkPortMaster(thread, instream): ports.appendChild(p)
            for outstream in thread.outstreams:
                for p in self.mkPortMaster(thread, oustream): ports.appendChild(p)
            for iochannel in thread.iochannels:
                for p in self.mkPortSlave(thread, iochannel, lite=self.lite):
                    ports.appendChild(p)
            for ioregister in thread.ioregisters:
                for p in self.mkPortSlave(thread, ioregister, lite=self.lite):
                    ports.appendChild(p)
        for portname, portdir, portlvalue in self.ext_ports:
            lvalue = portlvalue if portlvalue is not None else None
            rvalue = 0 if portlvalue is not None else None
            ports.appendChild(self.mkPortSignal(portname, portdir,
                                                None, lvalue, None, rvalue))
        return ports

    def mkPortMaster(self, thread, obj):
        base = thread.name + '_' + obj.name + '_AXI'
        datawidth = obj.ext_datawidth
        addrwidth = self.ext_addrwidth
        ret = []
        
        def mkStr(b, s):
            return 'spirit:decode(id(&apos;MODELPARAM_VALUE.C_' + b + '_' + s '&apos;))' 
        
        ret.append(self.mkPortSignal(base+'_AWID', 'out',
                                     '('+mkStr(base,'ID_WIDTH')+'-1)', 0, None, 0,
                                     True, True, mkStr(base,'ID_WIDTH')+' >0', 'true'))
        ret.append(self.mkPortSignal(base+'_AWADDR', 'out',
                                     '('+mkStr(base,'ADDR_WIDTH')+'-1)', addrwidth-1, None, 0))
        ret.append(self.mkPortSignal(base+'_AWLEN', 'out',
                                     None, 7, None, 0))
        ret.append(self.mkPortSignal(base+'_AWSIZE', 'out',
                                     None, 2, None, 0))
        ret.append(self.mkPortSignal(base+'_AWBURST', 'out',
                                     None, 1, None, 0))
        ret.append(self.mkPortSignal(base+'_AWLOCK', 'out',
                                     None, None, None, None))
        ret.append(self.mkPortSignal(base+'_AWCACHE', 'out',
                                     None, 3, None, 0))
        ret.append(self.mkPortSignal(base+'_AWPROT', 'out',
                                     None, 2, None, 0))
        ret.append(self.mkPortSignal(base+'_AWQOS', 'out',
                                     None, 3, None, 0))
        ret.append(self.mkPortSignal(base+'_AWUSER', 'out',
                                     '('+mkStr(base,'AWUSER_WIDTH')+'-1)', 0, None, 0,
                                     True, True, mkStr(base,'AWUSER_WIDTH')+' >0', 'false'))
        ret.append(self.mkPortSignal(base+'_AWVALID', 'out',
                                     None, None, None, None))
        ret.append(self.mkPortSignal(base+'_AWREADY', 'in',
                                     None, None, None, None))

        ret.append(self.mkPortSignal(base+'_WDATA', 'out',
                                     '('+mkStr(base,'DATA_WIDTH')+'-1)', datawidth-1, None, 0))
        ret.append(self.mkPortSignal(base+'_WSTRB', 'out',
                                     '('+mkStr(base,'DATA_WIDTH')+'/8-1)', datawidth-1, None, 0))
        ret.append(self.mkPortSignal(base+'_WLAST', 'out',
                                     None, None, None, None))
        ret.append(self.mkPortSignal(base+'_WUSER', 'out',
                                     '('+mkStr(base,'WUSER_WIDTH')+'-1)', 0, None, 0,
                                     True, True, mkStr(base,'WUSER_WIDTH')+' >0', 'false'))
        ret.append(self.mkPortSignal(base+'_WVALID', 'out',
                                     None, None, None, None))
        ret.append(self.mkPortSignal(base+'_WREADY', 'in',
                                     None, None, None, None))

        ret.append(self.mkPortSignal(base+'_BID', 'in',
                                     '('+mkStr(base,'ID_WIDTH')+'-1)', 0, None, 0,
                                     True, True, mkStr(base,'ID_WIDTH')+' >0', 'true'))
        ret.append(self.mkPortSignal(base+'_BRESP', 'in',
                                     None, 1, None, 0))
        ret.append(self.mkPortSignal(base+'_BUSER', 'in',
                                     '('+mkStr(base,'BUSER_WIDTH')+'-1)', 0, None, 0,
                                     True, True, mkStr(base,'BUSER_WIDTH')+' >0', 'false'))
        ret.append(self.mkPortSignal(base+'_BVALID', 'in',
                                     None, None, None, None))
        ret.append(self.mkPortSignal(base+'_BREADY', 'out',
                                     None, None, None, None))

        ret.append(self.mkPortSignal(base+'_ARID', 'out',
                                     '('+mkStr(base,'ID_WIDTH')+'-1)', 0, None, 0,
                                     True, True, mkStr(base,'ID_WIDTH')+' >0', 'true'))
        ret.append(self.mkPortSignal(base+'_ARADDR', 'out',
                                     '('+mkStr(base,'ADDR_WIDTH')+'-1)', addrwidth-1, None, 0))
        ret.append(self.mkPortSignal(base+'_ARLEN', 'out',
                                     None, 7, None, 0))
        ret.append(self.mkPortSignal(base+'_ARSIZE', 'out',
                                     None, 2, None, 0))
        ret.append(self.mkPortSignal(base+'_ARBURST', 'out',
                                     None, 1, None, 0))
        ret.append(self.mkPortSignal(base+'_ARLOCK', 'out',
                                     None, None, None, None))
        ret.append(self.mkPortSignal(base+'_ARCACHE', 'out',
                                     None, 3, None, 0))
        ret.append(self.mkPortSignal(base+'_ARPROT', 'out',
                                     None, 2, None, 0))
        ret.append(self.mkPortSignal(base+'_ARQOS', 'out',
                                     None, 3, None, 0))
        ret.append(self.mkPortSignal(base+'_ARUSER', 'out',
                                     '('+mkStr(base,'ARUSER_WIDTH')+'-1)', 0, None, 0,
                                     True, True, mkStr(base,'ARUSER_WIDTH')+' >0', 'false'))
        ret.append(self.mkPortSignal(base+'_ARVALID', 'out',
                                     None, None, None, None))
        ret.append(self.mkPortSignal(base+'_ARREADY', 'in',
                                     None, None, None, None))

        ret.append(self.mkPortSignal(base+'_RID', 'in',
                                     '('+mkStr(base,'ID_WIDTH')+'-1)', 0, None, 0,
                                     True, True, mkStr(base,'ID_WIDTH')+' >0', 'true'))
        ret.append(self.mkPortSignal(base+'_RDATA', 'in',
                                     '('+mkStr(base,'DATA_WIDTH')+'-1)', datawidth-1, None, 0))
        ret.append(self.mkPortSignal(base+'_RRESP', 'out',
                                     None, 1, None, 0))
        ret.append(self.mkPortSignal(base+'_RLAST', 'in',
                                     None, None, None, None))
        ret.append(self.mkPortSignal(base+'_RUSER', 'in',
                                     '('+mkStr(base,'RUSER_WIDTH')+'-1)', 0, None, 0,
                                     True, True, mkStr(base,'RUSER_WIDTH')+' >0', 'false'))
        ret.append(self.mkPortSignal(base+'_RVALID', 'in',
                                     None, None, None, None))
        ret.append(self.mkPortSignal(base+'_RREADY', 'out',
                                     None, None, None, None))

        ret.append(self.mkPortSignal(base+'_ACLK', 'in',
                                     None, None, None, None))
        ret.append(self.mkPortSignal(base+'_ARESETN', 'in',
                                     None, None, None, None))

        return ret
        
    def mkPortSlave(self, thread, obj, lite=False):
        base = thread.name + '_' + obj.name + '_AXI'
        datawidth = obj.ext_datawidth
        addrwidth = self.ext_addrwidth
        ret = []
        
        def mkStr(b, s):
            return 'spirit:decode(id(&apos;MODELPARAM_VALUE.C_' + b + '_' + s '&apos;))' 

        if not lite:
            ret.append(self.mkPortSignal(base+'_AWID', 'in',
                                         '('+mkStr(base,'ID_WIDTH')+'-1)', 0, None, 0,
                                         True, True, mkStr(base,'ID_WIDTH')+' >0', 'true'))
        ret.append(self.mkPortSignal(base+'_AWADDR', 'in',
                                     '('+mkStr(base,'ADDR_WIDTH')+'-1)', addrwidth-1, None, 0))
        if not lite:
            ret.append(self.mkPortSignal(base+'_AWLEN', 'in',
                                         None, 7, None, 0))
            ret.append(self.mkPortSignal(base+'_AWSIZE', 'in',
                                         None, 2, None, 0))
            ret.append(self.mkPortSignal(base+'_AWBURST', 'in',
                                         None, 1, None, 0))
            ret.append(self.mkPortSignal(base+'_AWLOCK', 'in',
                                         None, None, None, None))
            ret.append(self.mkPortSignal(base+'_AWCACHE', 'in',
                                         None, 3, None, 0))
        ret.append(self.mkPortSignal(base+'_AWPROT', 'in',
                                     None, 2, None, 0))
        if not lite:
            ret.append(self.mkPortSignal(base+'_AWQOS', 'in',
                                         None, 3, None, 0))
            ret.append(self.mkPortSignal(base+'_AWUSER', 'in',
                                         '('+mkStr(base,'AWUSER_WIDTH')+'-1)', 0, None, 0,
                                         True, True, mkStr(base,'AWUSER_WIDTH')+' >0', 'false'))
        ret.append(self.mkPortSignal(base+'_AWVALID', 'in',
                                     None, None, None, None))
        ret.append(self.mkPortSignal(base+'_AWREADY', 'out',
                                     None, None, None, None))

        ret.append(self.mkPortSignal(base+'_WDATA', 'in',
                                     '('+mkStr(base,'DATA_WIDTH')+'-1)', datawidth-1, None, 0))
        ret.append(self.mkPortSignal(base+'_WSTRB', 'in',
                                     '('+mkStr(base,'DATA_WIDTH')+'/8-1)', datawidth-1, None, 0))
        if not lite:
            ret.append(self.mkPortSignal(base+'_WLAST', 'in',
                                         None, None, None, None))
            ret.append(self.mkPortSignal(base+'_WUSER', 'in',
                                         '('+mkStr(base,'WUSER_WIDTH')+'-1)', 0, None, 0,
                                         True, True, mkStr(base,'WUSER_WIDTH')+' >0', 'false'))
        ret.append(self.mkPortSignal(base+'_WVALID', 'in',
                                     None, None, None, None))
        ret.append(self.mkPortSignal(base+'_WREADY', 'out',
                                     None, None, None, None))

        if not lite:
            ret.append(self.mkPortSignal(base+'_BID', 'out',
                                         '('+mkStr(base,'ID_WIDTH')+'-1)', 0, None, 0,
                                         True, True, mkStr(base,'ID_WIDTH')+' >0', 'true'))
        ret.append(self.mkPortSignal(base+'_BRESP', 'out',
                                     None, 1, None, 0))
        if not lite:
            ret.append(self.mkPortSignal(base+'_BUSER', 'out',
                                         '('+mkStr(base,'BUSER_WIDTH')+'-1)', 0, None, 0,
                                         True, True, mkStr(base,'BUSER_WIDTH')+' >0', 'false'))
        ret.append(self.mkPortSignal(base+'_BVALID', 'out',
                                     None, None, None, None))
        ret.append(self.mkPortSignal(base+'_BREADY', 'in',
                                     None, None, None, None))

        if not lite:
            ret.append(self.mkPortSignal(base+'_ARID', 'in',
                                         '('+mkStr(base,'ID_WIDTH')+'-1)', 0, None, 0,
                                         True, True, mkStr(base,'ID_WIDTH')+' >0', 'true'))
        ret.append(self.mkPortSignal(base+'_ARADDR', 'in',
                                     '('+mkStr(base,'ADDR_WIDTH')+'-1)', addrwidth-1, None, 0))
        if not lite:
            ret.append(self.mkPortSignal(base+'_ARLEN', 'in',
                                         None, 7, None, 0))
            ret.append(self.mkPortSignal(base+'_ARSIZE', 'in',
                                         None, 2, None, 0))
            ret.append(self.mkPortSignal(base+'_ARBURST', 'in',
                                         None, 1, None, 0))
            ret.append(self.mkPortSignal(base+'_ARLOCK', 'in',
                                         None, None, None, None))
            ret.append(self.mkPortSignal(base+'_ARCACHE', 'in',
                                         None, 3, None, 0))
        ret.append(self.mkPortSignal(base+'_ARPROT', 'in',
                                     None, 2, None, 0))
        if not lite:
            ret.append(self.mkPortSignal(base+'_ARQOS', 'in',
                                         None, 3, None, 0))
            ret.append(self.mkPortSignal(base+'_ARUSER', 'in',
                                         '('+mkStr(base,'ARUSER_WIDTH')+'-1)', 0, None, 0,
                                         True, True, mkStr(base,'ARUSER_WIDTH')+' >0', 'false'))
        ret.append(self.mkPortSignal(base+'_ARVALID', 'in',
                                     None, None, None, None))
        ret.append(self.mkPortSignal(base+'_ARREADY', 'out',
                                     None, None, None, None))

        if not lite:
            ret.append(self.mkPortSignal(base+'_RID', 'out',
                                         '('+mkStr(base,'ID_WIDTH')+'-1)', 0, None, 0,
                                         True, True, mkStr(base,'ID_WIDTH')+' >0', 'true'))
        ret.append(self.mkPortSignal(base+'_RDATA', 'out',
                                     '('+mkStr(base,'DATA_WIDTH')+'-1)', datawidth-1, None, 0))
        ret.append(self.mkPortSignal(base+'_RRESP', 'in',
                                     None, 1, None, 0))
        if not lite:
            ret.append(self.mkPortSignal(base+'_RLAST', 'out',
                                         None, None, None, None))
            ret.append(self.mkPortSignal(base+'_RUSER', 'out',
                                         '('+mkStr(base,'RUSER_WIDTH')+'-1)', 0, None, 0,
                                         True, True, mkStr(base,'RUSER_WIDTH')+' >0', 'false'))
        ret.append(self.mkPortSignal(base+'_RVALID', 'out',
                                     None, None, None, None))
        ret.append(self.mkPortSignal(base+'_RREADY', 'in',
                                     None, None, None, None))

        ret.append(self.mkPortSignal(base+'_ACLK', 'in',
                                     None, None, None, None))
        ret.append(self.mkPortSignal(base+'_ARESETN', 'in',
                                     None, None, None, None))

        return ret
        
    def mkPortSignal(self, name, direction, lvar, lvalue, rvar, rvalue,
                     withdriver=False,
                     withextension=False, extensionvar=None, extensionvalue='true')
        port = self.doc.createElement('spirit:port')
        port.appendChild(self.mkName(name))
        port.appendChild(self.mkWire(direction, lvar, lvalue, rvar, rvalue, withdriver))
        if withextension:
            port.appendChild(self.mkVendorExtensions(lvar, extensionvalue))
        return port
        
    def mkWire(self, direction, lvar, lvalue, rvar, rvalue, withdriver=False):
        wire = self.doc.createElement('spirit:wire')
        wire.appendChild(self.mkDirection(direction))
        if not (lvalue is None and rvalue is None):
            wire.appendChild(self.mkVector(lvar, lvalue, rvar, rvalue))
        wire.appendChild(self.mkWireTypeDefs('wire'))
        if withdriver:
            wire.appendChild(self.mkDriver())
        return wire

    def mkDirection(self, direction):
        i_direction  = self.doc.createElement('spirit:direction')
        self.setText(i_direction, direction)
        return i_direction
        
    def mkVector(self, lvar, lvalue, rvar, rvalue):
        vector = self.doc.createElement('spirit:vector')
        lresolve = "immediate" if isinstance(lvar, int) else "dependent"
        rresolve = "immediate" if isinstance(rvar, int) else "dependent"
        left = self.doc.createElement('spirit:left')
        self.setAttribute(left, 'spirit:format', "long")
        self.setAttribute(left, 'spirit:resolve', lresolve)
        if lresolve == "dependent":
            self.setAttribute(left, 'spirit:dependency', lvar)
        self.setText(left, lvalue)
        vector.appendChild(left)
        right = self.doc.createElement('spirit:right')
        self.setAttribute(right, 'spirit:format', "long")
        self.setAttribute(right, 'spirit:resolve', rresolve)
        if rresolve == "dependent":
            self.setAttribute(right, 'spirit:dependency', rvar)
        self.setText(right, rvalue)
        vector.appendChild(right)
        return vector

    def mkWireTypeDefs(self, wiretype):
        return self.mkWire(wiretype)
        
    def mkWireTypeDef(self, wiretype):
        wiretypedef = self.doc.createElement('spirit:wireTypeDef')
        typename = self.doc.createElement('spirit:typeName')
        self.setText(typename, wiretype)
        wiretypedef.appendChild(typename)
        viewnameref0 = self.doc.createElement('spirit:viewNameRef')
        self.setText(viewnameref0, 'xilinx_verilogsynthesis')
        wiretypedef.appendChild(viewnameref0)
        viewnameref1 = self.doc.createElement('spirit:viewNameRef')
        self.setText(viewnameref0, 'xilinx_verilogbehavioralsimulation')
        wiretypedef.appendChild(viewnameref1)
        return wiretypedef

    def mkDriver(self):
        driver = self.doc.createElement('spirit:driver')
        defaultvalue = self.doc.createElement('spirit:defaultvalue')
        self.setText(defaultvalue, 0)
        driver.appendChild(defaultvalue)
        return driver

    def mkVendorExtensions(self, var, value='true'):
        extension = self.doc.createElement('spirit:vendorExtensions')
        portinfo = self.doc.createElement('xilinx:portInfo')
        enablement = self.doc.createElement('xilinx:enablement')
        presence = self.doc.createElement('xilinx:presence')
        self.setText(presence, 'optional')
        enablement.appendChild(presence)
        isEnabled = self.doc.createElement('xilinx:isEnabled')
        self.setAttribute(isEnabled, 'xilinx:resolve', "dependent")
        self.setAttribute(isEnabled, 'xilinx:dependency',
                          ("spirit:decode(id(&apos;MODELPARAM_VALUE." + var +
                           "&apos;)) >0"))
        self.setText(isEnabled, value)
        enablement.appendChild(isEnabled)
        portinfo.appendChild(enablement)
        extension.appendChild(portinfo)
        return extension
        
    #---------------------------------------------------------------------------
    def mkModelParameters(self):
        modelparameters = self.doc.createElement('spirit:modelParameters')
        for thread in self.threads:
            ports.appendChild(self.mkPortSignal(therad.name + '_CCLK', 'in',
                                                None, None, None, None))
            ports.appendChild(self.mkPortSignal(therad.name + '_CRESETN', 'in',
                                                None, None, None, None))
            for memory in thread.memories:
                for p in self.mkPortMaster(thread, memory): ports.appendChild(p)
            for instream in thread.instreams:
                for p in self.mkPortMaster(thread, instream): ports.appendChild(p)
            for outstream in thread.outstreams:
                for p in self.mkPortMaster(thread, oustream): ports.appendChild(p)
            for iochannel in thread.iochannels:
                for p in self.mkPortSlave(thread, iochannel, lite=self.lite):
                    ports.appendChild(p)
            for ioregister in thread.ioregisters:
                for p in self.mkPortSlave(thread, ioregister, lite=self.lite):
                    ports.appendChild(p)
        for portname, portdir, portlvalue in self.ext_ports:
            lvalue = portlvalue if portlvalue is not None else None
            rvalue = 0 if portlvalue is not None else None
            ports.appendChild(self.mkPortSignal(portname, portdir,
                                                None, lvalue, None, rvalue))
        
        return modelparameters
    
#-------------------------------------------------------------------------------
if __name__ == '__main__':
    gen = ComponentGen()
    rslt = gen.generate('userlogic', ())
    print(rslt)
