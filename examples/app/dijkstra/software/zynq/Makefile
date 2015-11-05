CC=gcc
LIB=../../../../../c_lib/
INCLUDE=-I $(LIB)
OFLAGS=-O3 -g -pg -Wall $(INCLUDE)
#OFLAGS=-O0 -g -pg -Wall $(INCLUDE)
SRCS=main.c
HEADERS=heap.h umem.h pycoram.h
OBJS=$(SRCS:.cc=.o)
TARGET=test.out

DATA=../../data/out.dat
START=1826
GOAL=217

all: $(TARGET)

.PHONY: run	
run:
	time ./$(TARGET)	$(START) $(GOAL) $(DATA)

$(TARGET): $(OBJS) $(HEADERS)
	$(CC) $(OFLAGS) $(OBJS) -o $(TARGET)

$(HEADERS): 
.cc.o:
	$(CC) $(OFLAGS) -c $<

.PHONY: valgrind
valgrind:
	valgrind --leak-check=full ./$(TARGET) $(START) $(GOAL) $(DATA)

.PHONY: gdb
gdb:
	gdb ./$(TARGET)

.PHONY: perf_all
perf_all:
	perf stat ./$(TARGET)	$(START) $(GOAL) $(DATA)

.PHONY: perf_detail
perf_detail:
	perf stat -e instructions -e branch-instructions -e branch-misses -e cache-references -e cache-misses ./$(TARGET)	$(START) $(GOAL) $(DATA)

.PHONY: prof
prof:
	gprof test.out gmon.out

.PHONY: clean
clean:
	rm -rf $(TARGET) $(GEN) *.o $(TARGET).dSYM gmon.out
