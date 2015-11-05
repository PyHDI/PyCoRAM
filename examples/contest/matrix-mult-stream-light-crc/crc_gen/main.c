#include <stdio.h>
#include "crc.h"

int main()
{
  unsigned long crc_table [256];
  make_crc32_table(crc_table);

  int i;
  for(i=0; i<256; i++){
    printf("8'h%02x: q <= 32'h%08lx;\n", i, crc_table[i]);
  }
  printf("default: q <= 32'hffffffff;\n");

  return 0;
}
