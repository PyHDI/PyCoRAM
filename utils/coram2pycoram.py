import re
import sys
import os

#-------------------------------------------------------------------------------
# EDIT! getRamName is a conversion rule of SUB_ID 
#-------------------------------------------------------------------------------
def getRamId(oid, sid):
    if 0 <= sid and sid <= 31:
        return 0
    if 32 <= sid and sid <= 63:
        return 1
    if 64 <= sid and sid <= 95:
        return 2
    if 96 <= sid and sid <= 127:
        return 3

def getRamSubId(oid, sid):
    if 0 <= sid and sid <= 31:
        return sid
    if 32 <= sid and sid <= 63:
        return sid - 32
    if 64 <= sid and sid <= 95:
        return sid - 64
    if 96 <= sid and sid <= 127:
        return sid - 96

#-------------------------------------------------------------------------------
# EDIT! getChannelName is a conversion rule of SUB_ID 
#-------------------------------------------------------------------------------
def getChannelId(oid, sid):
    return oid

def getChannelSubId(oid, sid):
    return sid

#-------------------------------------------------------------------------------
# EDIT! getRegisterName is a conversion rule of SUB_ID 
#-------------------------------------------------------------------------------
def getRegisterId(oid, sid):
    return oid

def getRegisterSubId(oid, sid):
    return sid

#-------------------------------------------------------------------------------
def main():
    f = open(sys.argv[1], 'r')
    lines = f.readlines()
    output = []
    
    p_thread = re.compile('(.*)/\*THREAD\*/(.*)')
    p_thread_id = re.compile('(.*)/\*THREAD_ID\*/(.*)')
    p_object_id = re.compile('(.*)/\*OBJECT_ID\*/(.*)')
    p_width = re.compile('(.*)/\*WIDTH\*/(.*)')
    p_depth = re.compile('(.*)/\*DEPTH\*/(.*)')
    p_indexwidth = re.compile('(.*)/\*INDEXWIDTH\*/(.*)')
    p_logdepth = re.compile('(.*)/\*LOGDEPTH\*/(.*)')
    p_sub_id = re.compile('(.*)/\*SUB_ID\*/(.*)')
    
    module_name = None
    thread_name = None
    thread_id = None
    object_id = None
    sub_id = None
    width = None
    indexwidth = None
    depth = None
    
    mode = False

    sub_id_num = None
    sub_id_base = None
    
    buffer = []
    
    print("`include \"coram2pycoram.v\"")
    
    for line in lines:
        if not mode:
            m = p_thread.match(line)
            if m:
                thread_name = re.match('.*(".*").*', m.group(2)).group(1)
                module_name = re.search('(CORAM.*?|ChannelFIFO.*?|ChannelReg.*?) #', line).group(1)
                mode = True
                buffer = []
                buffer.append(line)
                continue
        else:
            m = p_thread_id.match(line)
            if m:
                tid_str = m.group(2)[1:-1]
                thread_id = re.match('([0-9]*\'.)?([0-9a-fA-F]+)', tid_str).group(2)
                #tid_str = m.group(2)
                #thread_id = re.match('(.*),', tid_str).group(1)
                buffer.append(line)
                continue
            m = p_object_id.match(line)
            if m:
                oid_str = m.group(2)[1:-1]
                object_id = re.match('([0-9]*\'.)?([0-9a-fA-F]+)', oid_str).group(2)
                #oid_str = m.group(2)
                #object_id = re.match('(.*),', oid_str).group(1)
                buffer.append(line)
                continue
            m = p_width.match(line)
            if m:
                #width_str = m.group(2)[1:-1]
                #width = re.match('([0-9]*\'.)?([0-9a-fA-F]+)', width_str).group(2)
                width_str = m.group(2)
                width = re.match('(.*),', width_str).group(1)
                buffer.append(line)
                continue
            m = p_depth.match(line)
            if m:
                #depth_str = m.group(2)[1:-1]
                #depth = re.match('([0-9]*\'.)?([0-9a-fA-F]+)', depth_str).group(2)
                depth_str = m.group(2)
                depth = re.match('(.*),', depth_str).group(1)
                buffer.append(line)
                continue
            m = p_indexwidth.match(line)
            if m:
                #indexwidth_str = m.group(2)[1:-1]
                #indexwidth = re.match('([0-9]*\'.)?([0-9a-fA-F]+)', indexwidth_str).group(2)
                indexwidth_str = m.group(2)
                indexwidth = re.match('(.*),', indexwidth_str).group(1)
                buffer.append(line)
                continue
            m = p_logdepth.match(line)
            if m:
                #logdepth_str = m.group(2)[1:-1]
                #logdepth = re.match('([0-9]*\'.)?([0-9a-fA-F]+)', logdepth_str).group(2)
                logdepth_str = m.group(2)
                logdepth = re.match('(.*),', logdepth_str).group(1)
                buffer.append(line)
                continue
            m = p_sub_id.match(line)
            if m:
                #sid_str = m.group(2)[1:-1]
                #sub_id = re.match('([0-9]*\'.)?([0-9a-fA-F]+)', sid_str).group(2)
                #sid_str = m.group(2)
                #sub_id = re.match('(.*)', sid_str).group(1)
                sid_str = m.group(2)
                #sub_id = re.search('([0-9]*\'.)?([0-9a-fA-F]+)', sid_str).group(0)
                sub_id_m = re.search('([0-9]*\'.)?([0-9a-fA-F]+)', sid_str)
                sub_id = sub_id_m.group(0)
                sub_id_num = sub_id_m.group(2)
                sub_id_base = (10 if sub_id_m.group(1).count("'d") > 0 else
                               16 if sub_id_m.group(1).count("'h") > 0 else
                               2 if sub_id_m.group(1).count("'b") > 0 else
                               10)
                buffer.append(line)
                continue
    
        if mode:
            print("PY%s #(" % module_name)
    
            print("/*CORAM_THREAD_NAME*/ %s," % ''.join((thread_name[:-1], '_', thread_id, '"')))
            print("/*CORAM_THREAD_ID*/ %s," % thread_id)

            if module_name.count('CORAM') > 0:
                print("/*CORAM_ID*/ %d," % getRamId(int(object_id), int(sub_id_num, sub_id_base)))
            if module_name.count('ChannelFIFO') > 0:
                print("/*CORAM_ID*/ %d," % getChannelId(int(object_id), int(sub_id_num, sub_id_base)))
            if module_name.count('ChannelRegister') > 0:
                print("/*CORAM_ID*/ %d," % getRegisterId(int(object_id), int(sub_id_num, sub_id_base)))

            if module_name.count('CORAM') > 0:
                print("/*CORAM_SUB_ID*/ %s," % getRamSubId(int(object_id), int(sub_id_num, sub_id_base)))
            if module_name.count('ChannelFIFO') > 0:
                #print("/*CORAM_SUB_ID*/ %s," % getChannelSubId(int(object_id), int(sub_id_num, sub_id_base)))
                print("/*CORAM_SUB_ID*/ %s," % '0')
            if module_name.count('ChannelRegister') > 0:
                #print("/*CORAM_SUB_ID*/ %s," % getRegisterSubId(int(object_id), int(sub_id_num, sub_id_base)))
                print("/*CORAM_SUB_ID*/ %s," % '0')

            print("/*CORAM_ADDR_LEN*/ %s," % indexwidth)
            print("/*CORAM_DATA_WIDTH*/ %s," % width)
            print("/*THREAD*/ %s," % thread_name)
            print(''.join(buffer[1:]))
    
        mode = False
        print(line, end='')

#-------------------------------------------------------------------------------
main()
