#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>

#define SIZE (1024)
volatile unsigned int valuebuf [SIZE];

int main(int argc, char** argv) 
{
  int fd = open("/dev/mem", O_RDWR);
  if(fd < 1){
    perror(argv[0]);
    return -1;
  }

  unsigned gpio_addr = 0x70000000;

  unsigned int page_size = sysconf(_SC_PAGESIZE);
  unsigned int page_addr = gpio_addr & (~(page_size-1));
  unsigned int page_offset = gpio_addr - page_addr;
  void* ptr = mmap(NULL, page_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, page_addr);

  printf("---Entering PyCoRAM test---\n\r");
  printf("\r\n Initialize values...\r\n");

  int i;
  int unsigned sum = 0;

  for(i=0; i<SIZE; i++){
    valuebuf[i] = i*i;
    sum += i*i;
  }

  printf("\r\n Checksum = %d\r\n", sum);
  //print("\r\n Cache Flush\r\n");

  // Start Computation on PyCoRAM IP
  //*((volatile unsigned int*)(ptr + page_offset)) = (unsigned int) virt_to_phys(valuebuf);
  *((volatile unsigned int*)(ptr + page_offset)) = 0;
  *((volatile unsigned int*)(ptr + page_offset)) = SIZE;

  // Get Result
  unsigned int result = *((volatile unsigned int*)(ptr + page_offset));
   
  printf("\r\n Result = %d \r\n", result);
  printf("---Exiting PyCoRAM test---\n\r");

  munmap(ptr, page_size);

  return 0;
}
