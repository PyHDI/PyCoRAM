#include <stdio.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "lib.h"

// If you use Write-back cache, please enable this macro
#define WRITEBACK

#define LOADER_SIZE (256)

typedef unsigned int Uint;

//------------------------------------------------------------------------------
void my_sleep(Uint t)
{
  volatile Uint i;
  for(i = 0; i < t; i++);
}

//------------------------------------------------------------------------------
void pycoram_main()
{
  Uint mem_offset;
  Uint address_width;
  Uint dma_size;
  Uint data_size;

  mem_offset = *((volatile Uint*)(MMAP_MEMORY + 0));
  address_width = *((volatile Uint*)(MMAP_MEMORY + 4));
  dma_size = *((volatile Uint*)(MMAP_MEMORY + 8));
  data_size = *((volatile Uint*)(MMAP_MEMORY + 12));

  *((volatile Uint*)(MMAP_PYCORAM_IP)) = (volatile int) mem_offset;
  *((volatile Uint*)(MMAP_PYCORAM_IP)) = (volatile int) address_width;
  *((volatile Uint*)(MMAP_PYCORAM_IP)) = (volatile int) dma_size;
  *((volatile Uint*)(MMAP_PYCORAM_IP)) = (volatile int) data_size;

  // wait 
  Uint cycles = *((volatile Uint*)(MMAP_PYCORAM_IP));

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

