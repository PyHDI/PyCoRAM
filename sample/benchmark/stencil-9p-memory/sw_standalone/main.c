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
  Uint mesh_size;
  Uint iter_num;
  Uint a_offset;
  Uint b_offset;

  mesh_size = *((volatile Uint*)(MMAP_MEMORY + 0));
  iter_num = *((volatile Uint*)(MMAP_MEMORY + 4));
  a_offset = *((volatile Uint*)(MMAP_MEMORY + 8));
  b_offset = *((volatile Uint*)(MMAP_MEMORY + 12));

  // initialize
  int x, y;
  for(y=0; y<mesh_size; y++){
    for(x=0; x<mesh_size; x++){
      *((volatile Uint *)(a_offset + (y * mesh_size + x) * 4)) = xorshift() % 1024;
      *((volatile Uint *)(b_offset + (y * mesh_size + x) * 4)) = xorshift() % 1024;
    }
  }

#ifdef WRITEBACK
  Xil_L1DCacheFlush();
#endif

  *((volatile Uint*)(MMAP_PYCORAM_IP)) = mesh_size;
  *((volatile Uint*)(MMAP_PYCORAM_IP)) = iter_num;
  *((volatile Uint*)(MMAP_PYCORAM_IP)) = a_offset;
  *((volatile Uint*)(MMAP_PYCORAM_IP)) = b_offset;

  // wait 
  Uint sum = *((volatile Uint*)(MMAP_PYCORAM_IP));
  Uint cycles = *((volatile Uint*)(MMAP_PYCORAM_IP));

  my_sleep(1000);
  Xil_DCacheInvalidate();

  for(y = 0; y < 16; y++) {
    for(x = 0; x < 8; x++) {
      Uint v = *((volatile Uint*)(a_offset + (y * mesh_size + x) * 4));
      mylib_display_hex(v);
      mylib_display_char(' ');
    }
    mylib_display_newline();
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

