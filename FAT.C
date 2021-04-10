/*
 * Sectors: 63
 * Heads: 16
 * Cylinders: 256
 *
 * CX = FF3F
 * DX = 0F01
 *
 */

#include <conio.h>  
#include <stdio.h>

#define file_allocation_table 0x27800
#define root_directory 0x47000
#define data_area 0x4B000

unsigned short i, j, k;
char buf[80];
FILE *f;

/* fat takes 252 sectors with these parameters */
void read_FAT() {
  __asm {
    mov ax, 3
    int 0x10
  }
  for(i=0; i<80*23; i++) {
    fseek(f, file_allocation_table+4+2*i, SEEK_SET);
    fread(&j, 2, 1, f);
    if(j==0) printf(" ");                // free cluster
    if((j>1) && (j<0xFFF0)) printf("*"); // file data cluster
    if(j>0xFFF7) printf("#");            // final cluster of a file
  }
  printf("\n");
  getch();
}

/* directory takes 32 sectors with these parameters */
void read_directory(unsigned long offset) {
  unsigned char attribute;
  unsigned short cluster;
  unsigned long size;
  __asm {
    mov ax, 3
    int 0x10
  }
  for(i=0; i<16; i++) {
    fseek(f, offset + 32*i, SEEK_SET);
    fread(buf, 1, 14, f);
    fseek(f, offset + 32*i + 0x1A, SEEK_SET);
    fread(&cluster, 2, 1, f);
    fseek(f, offset + 32*i + 0x1C, SEEK_SET);
    fread(&size, 4, 1, f);
    attribute = buf[11];
    if(buf[0]==0) break;
    for(j=0; j<8; j++) printf("%c", buf[j]);
    printf(" ");
    for(j=0; j<3; j++) printf("%c", buf[8+j]);
    if(!(attribute&0x10)) printf("  %ld", size);
    if(attribute&0x10) printf("  <DIR> ");
    printf("\t%.4X\n", cluster);
  }
  getch();
} 

unsigned short fetch_next(unsigned short cluster) {
  fseek(f, file_allocation_table + 2 * cluster, SEEK_SET);
  fread(&cluster, 2, 1, f);

  return cluster;
}

int main() {
  f = fopen("std.img", "rb");
  
  read_FAT();
  read_directory(root_directory);
  read_directory(data_area + (0x0065-2) * 4 * 512);
  
  printf("\nNext cluster of cluster 66h is %.4Xh\n", fetch_next(0x0066));

  fclose(f);

  return 0;
}
