#include <stdio.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "lib.h"

//// 128 MB
//#define LOADER_SIZE (128 * 1024 * 1024)
//#define PAGE_OFFSET (MMAP_MEMORY + 0x0000100)
//#define NODE_OFFSET (MMAP_MEMORY + 0x6000000)
//#define IDTB_OFFSET (MMAP_MEMORY + 0x7000000)
//#define ADTB_OFFSET (MMAP_MEMORY + 0x7400000)
//#define HEAP_OFFSET (MMAP_MEMORY + 0x7800000)

//// 2MB
#define LOADER_SIZE (1 * 1024 * 1024)
#define PAGE_OFFSET (MMAP_MEMORY + 0x0000100)
#define NODE_OFFSET (MMAP_MEMORY + 0x0040000)
#define IDTB_OFFSET (MMAP_MEMORY + 0x0080000)
#define ADTB_OFFSET (MMAP_MEMORY + 0x0090000)
#define HEAP_OFFSET (MMAP_MEMORY + 0x0100000)

void uart_loader();
void dijkstra(int start_id, int goal_id);
void main_loop();

int main() 
{
  Xil_ICacheEnable();
  Xil_DCacheEnable();

  while(1){ main_loop(); }

  Xil_DCacheDisable();
  Xil_ICacheDisable();
  
  return 0;
}

void main_loop()
{
  uart_loader();
  dijkstra(1826, 217);
}

void uart_loader()
{
  // Start Computation on PyCoRAM IP
  *((volatile unsigned int*)(MMAP_UART_LOADER)) = MMAP_MEMORY; // start address
  *((volatile unsigned int*)(MMAP_UART_LOADER)) = LOADER_SIZE; // size (byte)

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
}

void dijkstra(int start_id, int goal_id)
{
  volatile unsigned int start_addr = *(volatile unsigned int*)(ADTB_OFFSET + start_id * 4);
  volatile unsigned int goal_addr = *(volatile unsigned int*)(ADTB_OFFSET + goal_id * 4);

  mylib_display_char( 'S' );
  mylib_display_char( ' ' );
  mylib_display_hex(start_id);
  mylib_display_char( ':' );
  mylib_display_hex(start_addr);

  mylib_display_char( ' ' );

  mylib_display_char( 'G' );
  mylib_display_char( ' ' );
  mylib_display_hex(goal_id);
  mylib_display_char( ':' );
  mylib_display_hex(goal_addr);

  mylib_display_newline();

  *((volatile unsigned int*)(MMAP_DIJKSTRA)) = HEAP_OFFSET;
  *((volatile unsigned int*)(MMAP_DIJKSTRA)) = start_addr;
  *((volatile unsigned int*)(MMAP_DIJKSTRA)) = goal_addr;

  volatile unsigned int cost = *((volatile unsigned int*)(MMAP_DIJKSTRA));
  volatile unsigned int cycles = *((volatile unsigned int*)(MMAP_DIJKSTRA));

  mylib_display_char( 'C' );
  mylib_display_char( 'O' );
  mylib_display_char( 'S' );
  mylib_display_char( 'T' );
  mylib_display_char( ':' );
  mylib_display_dec(cost);
  mylib_display_newline();

  mylib_display_char( 'C' );
  mylib_display_char( 'Y' );
  mylib_display_char( 'C' );
  mylib_display_char( 'L' );
  mylib_display_char( 'E' );
  mylib_display_char( 'S' );
  mylib_display_char( ':' );
  mylib_display_dec(cycles);
  mylib_display_newline();
}
