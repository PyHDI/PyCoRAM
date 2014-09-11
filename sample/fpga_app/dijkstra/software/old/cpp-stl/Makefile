CC=g++
OFLAGS=-std=c++0x -O3 -g -pg -Wall 
#OFLAGS=-std=c++0x -O0 -g -pg -Wall 
SRCS=dijkstra.cc
HEADERS=dijkstra.h
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
