#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <sys/mman.h>
#include <fcntl.h>

#define UIO_MEM "/dev/uio0"
#define UIO_PYCORAM "/dev/uio1"

#define UMEM_SIZE (0x10000000)
#define UMEM_ADDR (0x10000000)
#define MAP_SIZE (0x00001000)

void cache_clean(char* addr, int size)
{
  __clear_cache(addr, addr + size);
}

void usage()
{
  printf("usage: pycoram_memcpy -s <size> -v <value> -c\n");
}

int main(int argc, char *argv[])
{
  int c;
  int value = 0;
  int check = 0;
  unsigned int size = 1024;
  while ((c = getopt(argc, argv, "s:v:ch")) != -1) {
    switch(c) {
    case 's':
      size = atoi(optarg);
      break;
    case 'v':
      value = atoi(optarg);
      break;
    case 'c':
      check = 1;
      break;
    case 'h':
      usage();
      return 0;
    default:
      printf("invalid option: %c\n", c);
      usage();
      return -1;
    }
  }

  int fd_mem = open(UIO_MEM, O_RDWR);
  if(fd_mem < 1){
    perror(argv[0]);
    printf("Invalid UIO device file: '%s'\n", UIO_MEM);
    return -1;
  }
  volatile unsigned int *usermemory = (volatile unsigned int*) mmap(NULL, UMEM_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd_mem, 0);

  int fd_pycoram = open(UIO_PYCORAM, O_RDWR);
  if(fd_pycoram < 1){
    perror(argv[0]);
    printf("Invalid UIO device file: '%s'\n", UIO_PYCORAM);
    return -1;
  }
  volatile unsigned int *pycoram = (volatile unsigned int*) mmap(NULL, MAP_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd_pycoram, 0);

  volatile int *a = (volatile int*) &usermemory[0];
  volatile int *b = (volatile int*) &usermemory[size];

  // initialization of data
  int i;

  if(check) goto verify;

  for(i=0; i<size * 2; i++){
    //printf("write %10d\n", i);
    a[i] = i + value;
  }

  cache_clean((char*)usermemory, size * sizeof(int) * 2);
  msync((void*)usermemory, UMEM_SIZE, MS_SYNC);

  int src = UMEM_ADDR;
  int dst = UMEM_ADDR + size * sizeof(int);

  printf("memcpy from 'a' to 'b'\n");
  printf("src  = %08x\n", src);
  printf("dst  = %08x\n", dst);
  printf("size = %8d\n", size);

  *pycoram = (volatile unsigned int) src;
  printf(".");
  *pycoram = (volatile unsigned int) dst;
  printf(".");
  *pycoram = (volatile unsigned int) size * sizeof(int);
  printf(".\n");
  volatile int recv = *pycoram;

 verify:
  if(check){
    printf("check only\n");
  }

  cache_clean((char*)usermemory, size * sizeof(int) * 2);
  msync((void*)usermemory, UMEM_SIZE, MS_INVALIDATE);

  int mismatch = 0;
  for(i=0; i<size; i++){
    //printf("read  %10d\n", b[i]);
    if(a[i] != b[i]){
      mismatch = 1;
      printf("%10d %10d\n", a[i], b[i]);
    }
    if(i==size-1){
      //printf("read  %10d\n", b[i]);
    }
  }

  if(mismatch){
    printf("NG\n");
  }else{
    printf("OK\n");
  }

  munmap((void*) usermemory, UMEM_SIZE);
  munmap((void*) pycoram, MAP_SIZE);

  return 0;
}

