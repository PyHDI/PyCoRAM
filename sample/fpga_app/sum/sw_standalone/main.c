#include <stdio.h>
#include "xparameters.h"
#include "xil_cache.h"

#define SIZE (1024)
volatile unsigned int valuebuf [SIZE];

int main() 
{
   Xil_ICacheEnable();
   Xil_DCacheEnable();

   print("---Entering PyCoRAM test---\n\r");
   print("\r\n Initialize values...\r\n");

   int i;
   int unsigned sum = 0;

   for(i=0; i<SIZE; i++){
     valuebuf[i] = i*i;
     sum += i*i;
   }

   xil_printf("\r\n Checksum = %d\r\n", sum);
   print("\r\n Cache Flush\r\n");

   Xil_DCacheFlush();

   // Start Computation on PyCoRAM IP
   *((volatile int*)(XPAR_PYCORAM_IOCHANNEL_BASEADDR)) = (unsigned int)valuebuf;
   *((volatile int*)(XPAR_PYCORAM_IOCHANNEL_BASEADDR)) = SIZE;

   // Get Result
   unsigned int result = *((volatile int*)(XPAR_PYCORAM_IOCHANNEL_BASEADDR));
   
   xil_printf("\r\n Result = %d \r\n", result);

   print("---Exiting PyCoRAM test---\n\r");

   Xil_DCacheDisable();
   Xil_ICacheDisable();
   return 0;
}
