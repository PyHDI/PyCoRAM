#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <sys/time.h>
#include "cma.h"
#include "pycoram.h"

void usage()
{
  printf("usage: memcpy [-s <size>] [-v <value>] [-c] [-h]\n");
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

  cma_open(CMA_SYNC_ON_WC);
  pycoram_open();

  volatile int *a = (volatile int*) cma_malloc(sizeof(int) * size);
  volatile int *b = (volatile int*) cma_malloc(sizeof(int) * size);

  int i;

  if(check) goto verify;

  // initialization of data
  for(i=0; i<size; i++){
    a[i] = i + value;
    b[i] = value;
  }

  cma_cache_clean((char*)a, sizeof(int) * size);
  cma_cache_clean((char*)b, sizeof(int) * size);

  unsigned int src = cma_get_physical_address((void*)a);
  unsigned int dst = cma_get_physical_address((void*)b);
  msync((void*)a, sizeof(int) * size, MS_INVALIDATE);
  msync((void*)b, sizeof(int) * size, MS_INVALIDATE);

  printf("memcpy from src to dst\n");
  printf("src  = %08x\n", src);
  printf("dst  = %08x\n", dst);
  printf("size = %8d\n", size);

  pycoram_write_4b(src);
  printf(".");
  pycoram_write_4b(dst);
  printf(".");
  pycoram_write_4b(size * sizeof(int));
  printf(".\n");
  unsigned int recv;
  pycoram_read_4b(&recv);

 verify:
  if(check){
    printf("check only\n");
  }

  cma_cache_clean((char*)a, sizeof(int) * size);
  cma_cache_clean((char*)b, sizeof(int) * size);
  msync((void*)a, sizeof(int) * size, MS_INVALIDATE);
  msync((void*)b, sizeof(int) * size, MS_INVALIDATE);

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

  pycoram_close();
  cma_close();

  return 0;
}

