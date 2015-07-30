CC=gcc
LIB=../../../../c_lib/
INCLUDE=-I $(LIB)
OFLAGS=-O3 -g -pg -Wall $(INCLUDE)
#OFLAGS=-O0 -g -pg -Wall $(INCLUDE)
SRCS=main.c
HEADERS=
OBJS=$(SRCS:.cc=.o)
TARGET=test.out

all: $(TARGET)

.PHONY: run	
run:
	time ./$(TARGET)

$(TARGET): $(OBJS) $(HEADERS)
	$(CC) $(OFLAGS) $(OBJS) -o $(TARGET)

$(HEADERS): 
.cc.o:
	$(CC) $(OFLAGS) -c $<

.PHONY: valgrind
valgrind:
	valgrind --leak-check=full ./$(TARGET)

.PHONY: gdb
gdb:
	gdb ./$(TARGET)

.PHONY: perf_all
perf_all:
	perf stat ./$(TARGET)

.PHONY: perf_detail
perf_detail:
	perf stat -e instructions -e branch-instructions -e branch-misses -e cache-references -e cache-misses ./$(TARGET)

.PHONY: prof
prof:
	gprof test.out gmon.out

.PHONY: clean
clean:
	rm -rf $(TARGET) $(GEN) *.o $(TARGET).dSYM gmon.out
