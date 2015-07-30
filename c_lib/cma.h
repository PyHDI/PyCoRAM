#ifndef CMA_H
#define CMA_H

#define CMA_SYNC_OFF   (0)
#define CMA_SYNC_ON    (1)
#define CMA_SYNC_ON_WC (2)
#define CMA_SYNC_ON_DC (3)

/* SYNC_MODE:
 * 0: CPU cache ON (very fast, but no consistent)
 * 1: CPU cache OFF, O_SYNC (slow)
 * 2: CPU cache OFF, O_SYNC, Write Combine ON (fast)
 * 3: CPU cache OFF, O_SYNC, DMA coherent (fast)
 */

#define DEV_CMA "/dev/udmabuf0"
#define DEV_CMA_ADDR "/sys/class/udmabuf/udmabuf0/phys_addr"
#define DEV_CMA_SIZE "/sys/class/udmabuf/udmabuf0/size"
#define DEV_CMA_SYNC_MODE "/sys/class/udmabuf/udmabuf0/sync_mode"
#define DEV_CMA_DEBUG_VMA "/sys/class/udmabuf/udmabuf0/debug_vma"

#define CMA_PAGE_SIZE (4*1024)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <assert.h>
#include <sys/mman.h>
#include <fcntl.h>

int fd_cma = -1;
volatile char* cma_ptr = NULL;
unsigned int cma_used = 0;
unsigned int cma_offset = 0;
unsigned int cma_size = 0;

void cma_check(unsigned int sync_mode, unsigned int* paddr, unsigned int* size)
{
  int fd;
  char attr[1024];
  unsigned int buf_size;
  unsigned int phys_addr;
  /* unsigned int debug_vma = 0; */

  fd = open(DEV_CMA_ADDR, O_RDONLY);
  if(fd < 0){
    printf("cma_check(): Cannot open %s\n", DEV_CMA_ADDR);
    exit(1);
  }
  read(fd, attr, 1024);
  sscanf(attr, "%x", &phys_addr);
  close(fd);

  fd = open(DEV_CMA_SIZE, O_RDONLY);
  if(fd < 0){
    printf("cma_check(): Cannot open %s\n", DEV_CMA_SIZE);
    exit(1);
  }
  read(fd, attr, 1024);
  sscanf(attr, "%d", &buf_size);
  close(fd);

  fd = open(DEV_CMA_SYNC_MODE, O_WRONLY);
  if(fd < 0){
    printf("cma_check(): Cannot open %s\n", DEV_CMA_SYNC_MODE);
    exit(1);
  }
  sprintf(attr, "%d", sync_mode);
  write(fd, attr, strlen(attr));
  close(fd);

  /*
  fd = open(DEV_CMA_DEBUG_VMA, O_WRONLY);
  if(fd < 0){
    printf("cma_check(): Cannot open %s\n", DEV_CMA_DEBUG_VMA);
    exit(1);
  }
  sprintf(attr, "%d", debug_vma);
  write(fd, attr, strlen(attr));
  close(fd);
  */

  *paddr = phys_addr;
  *size = buf_size;
}

void cma_open(unsigned int sync_mode)
{
  if(sync_mode > CMA_SYNC_ON_DC){
    sync_mode = CMA_SYNC_ON_DC;
  }

  unsigned int paddr;
  unsigned int size;
  cma_check(sync_mode, &paddr, &size);
  cma_offset = paddr;
  cma_size = size;

  if(sync_mode == 0){
    fd_cma = open(DEV_CMA, O_RDWR);
  }else{
    fd_cma = open(DEV_CMA, O_RDWR | O_SYNC);
  }

  if(fd_cma < 1){
    printf("cma_open(): Invalid device file: '%s'\n", DEV_CMA);
    exit(1);
  }
  cma_ptr = (volatile char*) mmap(NULL, cma_size, PROT_READ|PROT_WRITE, MAP_SHARED, fd_cma, 0);
  if(cma_ptr == MAP_FAILED){
    printf("cma_open(): mmap failed.\n");
    exit(1);
  }
  cma_used = 0;
}

void* cma_malloc(unsigned int bytes)
{
  if(cma_ptr == NULL){
    printf("cma_malloc(): CMA is not opened.\n");
    return NULL;
  }

  unsigned int numpages = bytes / CMA_PAGE_SIZE;
  if(bytes % CMA_PAGE_SIZE != 0){
    numpages++;
  }

  unsigned int size = CMA_PAGE_SIZE*numpages;

  if(cma_used + size > cma_size){
    return NULL;
  }

  void* ptr = (void*)(cma_ptr + cma_used);
  cma_used += size;
  return ptr;
}

unsigned int cma_get_physical_address(void* ptr)
{
  return cma_offset + ((unsigned int) ptr) - ((unsigned int)cma_ptr);
}

void cma_cache_clean(char* addr, unsigned int bytes)
{
  //__clear_cache(addr, addr + bytes);
  msync((void*)addr, bytes, MS_SYNC);
}

void cma_close()
{
  if(cma_ptr == NULL){
    printf("cma_close(): CMA is not opened.\n");
    return;
  }
  munmap((void*) cma_ptr, cma_size);
  cma_ptr = NULL;
  close(fd_cma);
  fd_cma = -1;
}

#endif
