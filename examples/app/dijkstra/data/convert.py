import os 
import sys

def convert(ifilename, ofilename):
    ifile = open(ifilename, 'r')
    ofile = open(ofilename, 'w')
    for line in iter(ifile.readline, ""):
        sline = line.split()
        if sline[0] == 'c': 
            continue
        if sline[0] == 'p': 
            num_nodes = sline[2]
            num_edges = sline[3]
            ofile.write("%s %s\n" % (num_nodes, num_edges))
            continue
        from_node = sline[1] 
        to_node = sline[2]
        cost = sline[3]
        ofile.write("%s %s %s\n" % (from_node, to_node, cost))

if __name__ == '__main__':
    from optparse import OptionParser
    INFO = "Graph Data Converter"
    VERSION = "ver.1.0.0"
    USAGE = "Usage: python convert.py filename -o outputfilename"

    def showVersion():
        print(INFO)
        print(VERSION)
        print(USAGE)
        sys.exit()

    optparser = OptionParser()
    optparser.add_option("-v","--version",action="store_true",dest="showversion",
                         default=False,help="Show the version")
    optparser.add_option("-o","--output",dest="outputfile",
                         default="out.dat",help="Output file name, default=out.dat")
    (options, args) = optparser.parse_args()
    
    filelist = args
    if options.showversion:
        showVersion()

    for f in filelist:
        if not os.path.exists(f): raise IOError("file not found: %s" % f)

    if len(filelist) == 0:
        showVersion()

    convert(filelist[0], options.outputfile)
