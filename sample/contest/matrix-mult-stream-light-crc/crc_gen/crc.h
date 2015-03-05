
#ifndef APP_320_MM_CRC_H
#define APP_320_MM_CRC_H


void make_crc32_table(unsigned long* crc_table)
{
    unsigned long i, j, c;

    for (i = 0; i < 256; i++) {
        c = i;
        for (j = 0; j < 8; j++) {
            if (c & 1) {
                c = 0xedb88320L ^ (c >> 1);
            } 
            else {
                c = c >> 1;
            }
        }
        crc_table[i] = c;
    }
}

unsigned long update_crc32(unsigned long crc, unsigned long val, unsigned long* crc_table)
{
    int n;
    unsigned long c = crc ^ 0xffffffffL;
    unsigned long byte;
    
    for (n = 0; n < 4; n++) {
        byte = (val >> (n*8)) & 0xff;
        c = crc_table[(c ^ byte) & 0xff] ^ (c >> 8);
    }
    return c ^ 0xffffffffL;
}


#endif 


