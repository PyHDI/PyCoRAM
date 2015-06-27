FROM ubuntu:14.04
RUN apt-get update && apt-get upgrade -y
RUN apt-get install build-essential -y
RUN apt-get install git -y
RUN apt-get install python python-pip python3 python3-pip -y
RUN apt-get install iverilog gtkwave -y
RUN apt-get install python-pygraphviz -y
RUN pip install jedi epc virtualenv jinja2
RUN pip3 install jedi epc virtualenv jinja2
RUN mkdir /home/pycoram/
WORKDIR "/home/pycoram"
RUN git clone https://github.com/shtaxxx/Pyverilog.git
RUN cd Pyverilog && python setup.py install && cd ../
RUN cd Pyverilog && python3 setup.py install && cd ../
RUN git clone https://github.com/shtaxxx/PyCoRAM.git
RUN cd PyCoRAM && python setup.py install && cd ../
RUN cd PyCoRAM && python3 setup.py install && cd ../
