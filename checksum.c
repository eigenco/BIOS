#include <stdio.h>
int main() {
  unsigned char buffer[32768];
  unsigned char checksum = 0;
  int i;
  FILE *f;
  f = fopen("vgabios.bin", "rb");
  fread(buffer, 1, 32768, f);
  for(i=0; i<32768; i++)
    checksum += buffer[i];
  printf("Initial checksum: %x\n", checksum);
  buffer[32767] = 256-checksum;
  checksum = 0;
  for(i=0; i<32768; i++)
    checksum += buffer[i];
  printf("Set checksum: %x\n", checksum);
  fclose(f);
  f = fopen("vgabios.img", "wb");
  fwrite(buffer, 1, 32768, f);
  fwrite(buffer, 1, 32768, f);
  fclose(f);
}
