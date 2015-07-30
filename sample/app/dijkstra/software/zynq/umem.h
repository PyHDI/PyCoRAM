#ifndef UMEM_H
#define UMEM_H

#define UIO_MEM "/dev/uio0"
// ZedBoard (DRAM 512 MB)
#define UMEM_SIZE (0x10000000)
#define UMEM_OFFSET (0x10000000)
// ZC706 (DRAM 1024 MB)
//#define UMEM_SIZE (0x20000000)
//#define UMEM_OFFSET (0x20000000)

#define UMEM_PAGE_SIZE (4*1024)

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <assert.h>
#include <sys/mman.h>
#include <fcntl.h>

int fd_umem = -1;
volatile char* umem_ptr = NULL;
unsigned int umem_used = 0;

void umem_open()
{
  fd_umem = open(UIO_MEM, O_RDWR);
  if(fd_umem < 1){
    printf("umem_open(): Invalid UIO device file: '%s'\n", UIO_MEM);
    exit(1);
  }
  umem_ptr = (volatile char*) mmap(NULL, UMEM_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED, fd_umem, 0);
  umem_used = 0;
}

void* umem_malloc(unsigned int bytes)
{
  if(umem_ptr == NULL){
    printf("umem_malloc(): UMEM is not opened.\n");
    return NULL;
  }

  unsigned int numpages = bytes / UMEM_PAGE_SIZE;
  if(bytes % UMEM_PAGE_SIZE != 0){
    numpages++;
  }

  unsigned int size = UMEM_PAGE_SIZE*numpages;

  if(umem_used + size > UMEM_SIZE){
    return NULL;
  }

  void* ptr = (void*)(umem_ptr + umem_used);
  umem_used += size;
  return ptr;
}

unsigned int umem_get_physical_address(void* ptr)
{
  return UMEM_OFFSET + ((unsigned int) ptr) - ((unsigned int)umem_ptr);
}

void umem_cache_clean(char* addr, unsigned int bytes)
{
  __clear_cache(addr, addr + bytes);
}

void umem_close()
{
  if(umem_ptr == NULL){
    printf("umem_close(): UMEM is not opened.\n");
    return;
  }
  munmap((void*) umem_ptr, UMEM_SIZE);
  umem_ptr = NULL;
  close(fd_umem);
  fd_umem = -1;
}

#endif
