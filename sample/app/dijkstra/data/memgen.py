import os
import sys
import struct
import math

#-------------------------------------------------------------------------------
class Node(object):
    def __init__(self, my_id, my_addr, page_addr=None):
        self.my_id = my_id
        self.my_addr = my_addr
        self.page_addr = page_addr
        self.neighbors = []
    def add_edge(self, addr, cost):
        self.neighbors.append( (addr, cost) )

#-------------------------------------------------------------------------------
def make_graph(ifilename):
    global num_nodes
    global num_edges
    global node_addr
    ifile = open(ifilename, 'r')
    for line in iter(ifile.readline, ""):
        sline = line.split()
        if sline[0] == 'c': 
            continue
        if sline[0] == 'p': 
            num_nodes = int(sline[2])
            num_edges = int(sline[3])
            continue
        from_node = int(sline[1])
        to_node = int(sline[2])
        cost = int(sline[3])
        
        if from_node not in nodes:
            my_addr = node_addr
            nodes[from_node] = Node(from_node, my_addr)
            node_addr += 16
        if to_node not in nodes:
            my_addr = node_addr
            nodes[to_node] = Node(to_node, my_addr)
            node_addr += 16

        to_addr = nodes[to_node].my_addr
        nodes[from_node].add_edge(to_addr, cost)

#-------------------------------------------------------------------------------
def make_page_list(ofilename):
    global mem_size_edge
    global mem_size_pad
    of = open(ofilename, 'wb')
    page_addr = PAGE_OFFSET

    for a in range(GLOBAL_OFFSET, PAGE_OFFSET, 4):
        #odata = struct.pack('I', 0)
        odata = struct.pack('I', 0xee)
        of.write(odata)
        mem_size_pad += 4

    for node_id, node in sorted(nodes.items(), key=lambda x:x[1].my_addr):
        node.page_addr = page_addr
        num_of_edges = len(node.neighbors)

        count = 0
        for eaddr, ecost in node.neighbors:

            if count == 0:
                count = EDGES_PER_PAGE 
                if num_of_edges > EDGES_PER_PAGE:
                    page_addr += (8 + EDGES_PER_PAGE * 8)
                    size = EDGES_PER_PAGE
                    next_addr = page_addr
                    odata = struct.pack('II', size, next_addr)
                    of.write(odata)
                    mem_size_edge += 8
                    num_of_edges -= EDGES_PER_PAGE
                else:
                    page_addr += (8 + EDGES_PER_PAGE * 8)
                    size = num_of_edges
                    next_addr = 0
                    odata = struct.pack('II', size, next_addr)
                    of.write(odata)
                    mem_size_edge += 8
                    num_of_edges = 0

            count -= 1
            odata = struct.pack('II', eaddr, ecost)
            of.write(odata)
            mem_size_edge += 8

        for i in range(count * 2):
            odata = struct.pack('I', 0)
            of.write(odata)
            mem_size_edge += 4

    for a in range(page_addr, NODE_OFFSET, 4):
        odata = struct.pack('I', 0)
        of.write(odata)
        mem_size_pad += 4

#-------------------------------------------------------------------------------
def make_node_list(ofilename):
    global mem_size_node
    global mem_size_pad
    of = open(ofilename, 'ab')
    for node_id, node in sorted(nodes.items(), key=lambda x:x[1].my_addr):
        odata = struct.pack('IIII', 0, 0xffffffff, node.page_addr, 0)
        of.write(odata)
        mem_size_node += 16

    for a in range(node_addr, IDTB_OFFSET, 4):
        odata = struct.pack('I', 0)
        of.write(odata)
        mem_size_pad += 4

#--------------------------------------------------------------------------------
def make_idtb_list(ofilename):
    global mem_size_idtb
    global mem_size_pad
    of = open(ofilename, 'ab')
    for node_id, node in sorted(nodes.items(), key=lambda x:x[1].my_addr):
        odata = struct.pack('I', node.my_id)
        of.write(odata)
        mem_size_idtb += 4

    for a in range(IDTB_OFFSET + mem_size_idtb, ADTB_OFFSET, 4):
        odata = struct.pack('I', 0)
        of.write(odata)
        mem_size_pad += 4

#--------------------------------------------------------------------------------
def make_adtb_list(ofilename):
    global mem_size_adtb
    global mem_size_pad
    of = open(ofilename, 'ab')
    last_id = -1
    for node_id, node in sorted(nodes.items(), key=lambda x:x[1].my_id):
        for i in range(last_id, node_id-1, 1):
            odata = struct.pack('I', 0)
            of.write(odata)
            mem_size_adtb += 4
        odata = struct.pack('I', node.my_addr)
        of.write(odata)
        mem_size_adtb += 4
        last_id = node_id

    for a in range(ADTB_OFFSET + mem_size_adtb, MEM_SIZE, 4):
        odata = struct.pack('I', 0)
        of.write(odata)
        mem_size_pad += 4

#-------------------------------------------------------------------------------
# DO NOT EDIT THESE VALUE
# You can change these parameters by using argument options
#-------------------------------------------------------------------------------
EDGES_PER_PAGE = 8
MEM_SIZE = 1024 * 1024
PAGE_OFFSET = 0x00000100
NODE_OFFSET = 0x00040000
IDTB_OFFSET = 0x00080000
ADTB_OFFSET = 0x00090000

GLOBAL_OFFSET = 0x0

#-------------------------------------------------------------------------------
nodes = {}
node_addr = 0

num_nodes = 0
num_edges = 0
mem_edges = 0

mem_size_pad = 0
mem_size_node = 0
mem_size_edge = 0
mem_size_idtb = 0
mem_size_adtb = 0
    
#-------------------------------------------------------------------------------
if __name__ == '__main__':
    from optparse import OptionParser
    INFO = "Graph Data Converter"
    VERSION = "ver.1.0.0"
    USAGE = "Usage: python memgen.py filename -o outputfilename"

    def showVersion():
        print(INFO)
        print(VERSION)
        print(USAGE)
        sys.exit()

    optparser = OptionParser()
    optparser.add_option("-v","--version",action="store_true",dest="showversion",
                         default=False,help="Show the version")
    optparser.add_option("-o","--output",dest="outputfile",
                         default="out.bin",help="Output file name, default=out.bin")
    optparser.add_option("--edges_per_page",dest="edges_per_page",type=int,
                         default=8,help="Edges Per Page, default=8")
    optparser.add_option("--mem_size",dest="mem_size",type=int,
                         default=1024*1024,help="Memory Size, default=1024 KB")
    optparser.add_option("--page_offset",dest="page_offset",type=int,
                         default=0x100,help="Page Offset, default=0x100")
    optparser.add_option("--node_offset",dest="node_offset",type=int,
                         default=0x40000,help="Node Offset, default=0x40000")
    optparser.add_option("--idtb_offset",dest="idtb_offset",type=int,
                         default=0x80000,help="ID Table Offset, default=0x80000")
    optparser.add_option("--adtb_offset",dest="adtb_offset",type=int,
                         default=0x90000,help="Address Table Offset, default=0x90000")
    optparser.add_option("--global_offset",dest="global_offset",type=int,
                         default=0x0,help="Global Offset, default=0x0")
    (options, args) = optparser.parse_args()
    
    filelist = args
    if options.showversion:
        showVersion()

    for f in filelist:
        if not os.path.exists(f): raise IOError("file not found: %s" % f)

    if len(filelist) == 0:
        showVersion()

    EDGES_PER_PAGE = options.edges_per_page
    MEM_SIZE = options.mem_size + options.global_offset
    PAGE_OFFSET = options.page_offset + options.global_offset
    NODE_OFFSET = options.node_offset + options.global_offset
    IDTB_OFFSET = options.idtb_offset + options.global_offset
    ADTB_OFFSET = options.adtb_offset + options.global_offset
    GLOBAL_OFFSET = options.global_offset

    node_addr = NODE_OFFSET

    make_graph(filelist[0])
    make_page_list(options.outputfile)
    make_node_list(options.outputfile)
    make_idtb_list(options.outputfile)
    make_adtb_list(options.outputfile)

    print("# num of nodes: %d" % num_nodes)
    print("# num of edges: %d" % num_edges)
    print("# memory map (size)")
    print("# edge: %8x - %8x (%11d bytes)" % (PAGE_OFFSET, PAGE_OFFSET + mem_size_edge, mem_size_edge))
    print("# node: %8x - %8x (%11d bytes)" % (NODE_OFFSET, NODE_OFFSET + mem_size_node, mem_size_node))
    print("# idtb: %8x - %8x (%11d bytes)" % (IDTB_OFFSET, IDTB_OFFSET + mem_size_idtb, mem_size_idtb))
    print("# adtb: %8x - %8x (%11d bytes)" % (ADTB_OFFSET, ADTB_OFFSET + mem_size_adtb, mem_size_adtb))

    if PAGE_OFFSET + mem_size_edge > NODE_OFFSET:
        print("memory space for edges is not sufficient.")

    if NODE_OFFSET + mem_size_node > IDTB_OFFSET:
        print("memory space for nodes is not sufficient.")

    if IDTB_OFFSET + mem_size_idtb > ADTB_OFFSET:
        print("memory space for ID table is not sufficient.")

    if ADTB_OFFSET + mem_size_adtb > MEM_SIZE:
        print("memory space for address table is not sufficient.")

    total_size = mem_size_node + mem_size_edge + mem_size_idtb + mem_size_adtb + mem_size_pad 
    print('Total size: %d (0x%x)' % (total_size, total_size))
