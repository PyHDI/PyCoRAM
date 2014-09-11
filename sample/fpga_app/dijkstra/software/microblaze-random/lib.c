#include "lib.h"

inline void send_char(int c)
{
  *((volatile unsigned int*) MMAP_UART_TX) = (volatile unsigned int) (c & 0xff);
}

void mylib_display_dec(int val)
{
  int i;
  int c[DIGIT_DEC];
  int cnt = 0;
  int minus_flag = 0;
  
  if (val < 0) {
    /* ----- setting + or -  ----- */
    minus_flag = 1;
    /* ----- calclate absolute value ----- */
    val *= -1;
  }

  if (val == 0) {
    c[0] = '0';
    cnt = 1;
  } else {
    while (val) {
      c[cnt] = (val%10 == 0) ? '0' :
               (val%10 == 1) ? '1' :
	          (val%10 == 2) ? '2' :
	          (val%10 == 3) ? '3' :
	          (val%10 == 4) ? '4' :
	          (val%10 == 5) ? '5' :
	          (val%10 == 6) ? '6' :
	          (val%10 == 7) ? '7' :
	          (val%10 == 8) ? '8' : '9';
      cnt++;
      val /= 10;
      if ((val == 0) && (minus_flag)) {
        c[cnt] = '-';
        cnt++;
      }
    }
  }
  
  for (i = cnt - 1; i >= 0; i--) {
    send_char(c[i]);
  }
}

void mylib_display_hex(int val)
{
  int i;
  int c[DIGIT_HEX]; 
  int cnt = 0;
  
  while (cnt < DIGIT_HEX) {
    c[cnt] = ((val & 0x0000000f) == 0)  ? '0' :
             ((val & 0x0000000f) == 1)  ? '1' :        
             ((val & 0x0000000f) == 2)  ? '2' :        
             ((val & 0x0000000f) == 3)  ? '3' :        
             ((val & 0x0000000f) == 4)  ? '4' :        
             ((val & 0x0000000f) == 5)  ? '5' :        
             ((val & 0x0000000f) == 6)  ? '6' :        
             ((val & 0x0000000f) == 7)  ? '7' :        
             ((val & 0x0000000f) == 8)  ? '8' :        
             ((val & 0x0000000f) == 9)  ? '9' :        
             ((val & 0x0000000f) == 10) ? 'a' :        
             ((val & 0x0000000f) == 11) ? 'b' :        
             ((val & 0x0000000f) == 12) ? 'c' :        
             ((val & 0x0000000f) == 13) ? 'd' :        
             ((val & 0x0000000f) == 14) ? 'e' : 'f';
    cnt++;
    val = val >> 4;
  }
  
  for (i = cnt - 1; i >= 0; i--) {
    send_char(c[i]);
  }
}

void mylib_display_char(char val)
{
  send_char(val);
}

void mylib_display_newline()
{
  mylib_display_char('\n');
  mylib_display_char('\r');
}

void mylib_finalize()
{
  mylib_display_newline();
  mylib_display_char('E');
  mylib_display_char('N');
  mylib_display_char('D');
  mylib_display_newline();
}
