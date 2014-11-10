#ifndef __LIB_H__
#define __LIB_H__

#define DIGIT_DEC (256)
#define DIGIT_HEX (8)

#define MMAP_UART_TX     (0x60000000)
#define MMAP_UART_LOADER (0x61000000)
#define MMAP_DIJKSTRA    (0x62000000)
#define MMAP_MEMORY      (0xA8000000)

inline void send_char(int c);
void mylib_display_dec(int val);
void mylib_display_hex(int val);
void mylib_display_char(char val);
void mylib_display_newline();
void mylib_finalize();

#endif
