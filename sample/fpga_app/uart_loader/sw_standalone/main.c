#include <stdio.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "lib.h"

void uart_loader_test();

int main() 
{
  Xil_ICacheEnable();
  Xil_DCacheEnable();

  while(1){ uart_loader_test(); }

  Xil_DCacheDisable();
  Xil_ICacheDisable();
  
  return 0;

}

void uart_loader_test()
{
  // Start Computation on PyCoRAM IP
  *((volatile unsigned int*)(MMAP_UART_LOADER)) = MMAP_MEMORY; // start address
  *((volatile unsigned int*)(MMAP_UART_LOADER)) = 512 * 1024; // size (byte)

  // Get Result
  volatile unsigned int start_address = *((volatile unsigned int*)(MMAP_UART_LOADER));

  mylib_display_char( 'R' );
  mylib_display_char( 'e' );
  mylib_display_char( 'c' );
  mylib_display_char( 'e' );
  mylib_display_char( 'i' );
  mylib_display_char( 'v' );
  mylib_display_char( 'e' );
  mylib_display_char( 'd' );
  mylib_display_newline();

  mylib_display_hex(start_address);
  mylib_display_newline();

  int i;
  volatile unsigned int* p = (volatile unsigned int*) MMAP_MEMORY;
  for(i=0; i<16; i++){
    mylib_display_hex( p[i] );
    mylib_display_char(',');
  }

  mylib_display_newline();
  
  for(i=(512*1024/4)-16; i<512*1024/4; i++){
    mylib_display_hex( p[i] );
    mylib_display_char(',');
  }

  mylib_display_newline();
}
