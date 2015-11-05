#include <stdio.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "lib.h"

// If you use Write-back cache, please enable this macro
#define WRITEBACK

#define LOADER_SIZE (256)
#define DSIZE (4)

typedef unsigned int Uint;

//------------------------------------------------------------------------------
void my_sleep(Uint t)
{
  volatile Uint i;
  for(i = 0; i < t; i++);
}

//------------------------------------------------------------------------------
static Uint __x = 123456789;
static Uint __y = 362436069;
static Uint __z = 521288629;
static Uint __w = 88675123; 

Uint xorshift()
{ 
  Uint t;
  t = __x ^ (__x << 11);
  __x = __y; __y = __z; __z = __w;
  return __w = (__w ^ (__w >> 19)) ^ (t ^ (t >> 8)); 
}

void reset_xorshift()
{
  __x = 123456789;
  __y = 362436069;
  __z = 521288629;
  __w = 88675123; 
}

//------------------------------------------------------------------------------
void pycoram_main()
{
  Uint mem_offset;
  //Uint address_width;
  Uint dma_size;
  Uint data_size;
  Uint num_entries;
  Uint simd_width;

  mem_offset = *((volatile Uint*)(MMAP_MEMORY + 0));
  //address_width = *((volatile Uint*)(MMAP_MEMORY + 4));
  dma_size = *((volatile Uint*)(MMAP_MEMORY + 8));
  data_size = *((volatile Uint*)(MMAP_MEMORY + 12));
  num_entries = *((volatile Uint*)(MMAP_MEMORY + 16));
  simd_width = *((volatile Uint*)(MMAP_MEMORY + 20));

  // Initialize pointer chain data
  Uint address;
  Uint next_address;
  Uint write_data;
  int i, j, p;
  for(i=0; i<num_entries; i++){
    address = mem_offset + (i * dma_size * DSIZE * simd_width);
    next_address = mem_offset + (xorshift() % num_entries) * dma_size * DSIZE * simd_width;
    *((volatile Uint*)address) = next_address;
    for(j=1; j<dma_size*simd_width; j++){
      address = mem_offset + (i * dma_size * DSIZE * simd_width) + (j * DSIZE);
      *((volatile Uint*)address) = 0xffff;
    }
  }

#ifdef WRITEBACK
  Xil_L1DCacheFlush();
#endif

  *((volatile Uint*)(MMAP_PYCORAM_IP)) = (volatile int) mem_offset;
  //*((volatile Uint*)(MMAP_PYCORAM_IP)) = (volatile int) address_width;
  *((volatile Uint*)(MMAP_PYCORAM_IP)) = (volatile int) dma_size;
  *((volatile Uint*)(MMAP_PYCORAM_IP)) = (volatile int) data_size;

  // wait 
  Uint cycles = *((volatile Uint*)(MMAP_PYCORAM_IP));

  reset_xorshift();

  my_sleep(1000);
  Xil_DCacheInvalidate();

  //printf("cycles=%d\n", 0);
  mylib_display_char('c');
  mylib_display_char('y');
  mylib_display_char('c');
  mylib_display_char('l');
  mylib_display_char('e');
  mylib_display_char(':');
  mylib_display_dec(cycles);
  mylib_display_newline();

  mylib_display_char('E');
  mylib_display_char('N');
  mylib_display_char('D');
}

//------------------------------------------------------------------------------
void uart_loader()
{
  // Start Computation on PyCoRAM IP
  *((volatile Uint*)(MMAP_UART_LOADER)) = MMAP_MEMORY; // start address
  *((volatile Uint*)(MMAP_UART_LOADER)) = LOADER_SIZE; // size (byte)

  // Get Result
  volatile Uint start_address = *((volatile Uint*)(MMAP_UART_LOADER));
  mylib_display_hex(start_address);
  mylib_display_newline();
}

//------------------------------------------------------------------------------
void main_loop()
{
#ifdef WRITEBACK
  Xil_L1DCacheFlush();
#endif
  uart_loader();

#ifdef WRITEBACK
  Xil_L1DCacheFlush();
#endif
  pycoram_main();
}

//------------------------------------------------------------------------------
int main() 
{
  Xil_ICacheEnable();
  Xil_DCacheEnable();

  while(1){ main_loop(); }

  Xil_DCacheDisable();
  Xil_ICacheDisable();
  return 0;
}

