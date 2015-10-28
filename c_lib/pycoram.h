#ifndef PYCORAM_H
#define PYCORAM_H

#define UIO_PYCORAM "/dev/uio1"
#define PYCORAM_SIZE (0x00001000)

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <sys/mman.h>
#include <fcntl.h>

int fd_pycoram = -1;
volatile int* pycoram_ptr = NULL;

void pycoram_open()
{
  fd_pycoram = open(UIO_PYCORAM, O_RDWR);
  if(fd_pycoram < 1){
    printf("Invalid UIO device file: '%s'\n", UIO_PYCORAM);
    exit(1);
  }
  pycoram_ptr = (volatile int*) mmap(NULL, PYCORAM_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd_pycoram, 0);
}

void pycoram_write_4b(unsigned int data)
{
  volatile unsigned int busy = *(pycoram_ptr + 1);
  while((busy & 0x2) != 0){
    busy = *(pycoram_ptr + 1);
  }
  *pycoram_ptr = (volatile unsigned int) data;
}

void pycoram_read_4b(unsigned int* data)
{
  volatile unsigned int busy = *(pycoram_ptr + 1);
  while((busy & 0x1) != 0){
    busy = *(pycoram_ptr + 1);
  }
  volatile unsigned int r = *pycoram_ptr;
  *data = r;
}

void pycoram_close()
{
  if(pycoram_ptr == NULL){
    printf("pycoram_close(): UIO is not opened.\n");
    return;
  }
  munmap((void*) pycoram_ptr, PYCORAM_SIZE);
  pycoram_ptr = NULL;
  close(fd_pycoram);
  fd_pycoram = -1;
}

#endif
