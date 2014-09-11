CC=gcc
OFLAGS=-O3 -g -pg -Wall
#OFLAGS=-O0 -g -pg -Wall
SRCS=main.c
HEADERS=heap.h
OBJS=$(SRCS:.cc=.o)
TARGET=test.out

START=1826
GOAL=217
NEDGES= 40000
NODES = 2000

all: $(TARGET)

.PHONY: run	
run:
	time ./$(TARGET)	$(START) $(GOAL) $(NEDGES) $(NODES)

$(TARGET): $(OBJS) $(HEADERS)
	$(CC) $(OFLAGS) $(OBJS) -o $(TARGET)

$(HEADERS): 
.cc.o:
	$(CC) $(OFLAGS) -c $<

.PHONY: valgrind
valgrind:
	valgrind --leak-check=full ./$(TARGET) $(START) $(GOAL) $(NEDGES) $(NODES)

.PHONY: gdb
gdb:
	gdb ./$(TARGET)

.PHONY: perf_all
perf_all:
	perf stat ./$(TARGET)	$(START) $(GOAL) $(NEDGES) $(NODES)

.PHONY: perf_detail
perf_detail:
	perf stat -e instructions -e branch-instructions -e branch-misses -e cache-references -e cache-misses ./$(TARGET)	$(START) $(GOAL) $(NEDGES) $(NODES)

.PHONY: prof
prof:
	gprof test.out gmon.out

.PHONY: clean
clean:
	rm -rf $(TARGET) $(GEN) *.o $(TARGET).dSYM gmon.out
