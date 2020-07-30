main() {
  unsigned char far *mem = (unsigned char far*)0xF000FA6EL;
  unsigned short i, j, k;

  for(i=0; i<128; i++)
  {
    printf("db 0x%.2x, ", mem[8*i]);
    for(j=1; j<7; j++)
      printf("0x%.2x, ", mem[8*i+j]);
    printf("0x%.2x\n", mem[8*i+7]);
  }
}
