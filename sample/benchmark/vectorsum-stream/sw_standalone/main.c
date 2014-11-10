#include <stdio.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "lib.h"

// If you use Write-back cache, please enable this macro
#define WRITEBACK

#define LOADER_SIZE (256)

typedef unsigned int Uint;

#define MIN_DATA_SIZE (1024 * 1024)

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
  Uint data_size;
  Uint simd_width;

  mem_offset = *((volatile Uint*)(MMAP_MEMORY + 0));
  data_size = *((volatile Uint*)(MMAP_MEMORY + 4));
  simd_width = *((volatile Uint*)(MMAP_MEMORY + 8));

  // initialize
  int i;
  for(i=0; i<data_size * simd_width; i++){
    *((volatile Uint *)(mem_offset + (i * 4))) = xorshift() % 1024;
  }

#ifdef WRITEBACK
  Xil_L1DCacheFlush();
#endif

  Uint sum;
  Uint cycles;
  if(data_size >= MIN_DATA_SIZE){
    *((volatile Uint*)(MMAP_PYCORAM_IP)) = mem_offset;
    *((volatile Uint*)(MMAP_PYCORAM_IP)) = data_size;

    // wait 
    sum = *((volatile Uint*)(MMAP_PYCORAM_IP));
    cycles = *((volatile Uint*)(MMAP_PYCORAM_IP));
  }else{
    sum = 0;
    cycles = 0;
  }

  reset_xorshift();

  //printf("sum=%d\n", 0);
  mylib_display_char('s');
  mylib_display_char('u');
  mylib_display_char('m');
  mylib_display_char(':');
  mylib_display_dec(sum);
  mylib_display_newline();

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

