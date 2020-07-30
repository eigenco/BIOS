setvideo();
#pragma aux setvideo = \
"mov ax, 0x0d" \
"int 0x10";

textmode();
#pragma aux textmode = \
"mov ax, 0x03" \
"int 0x10";

main() {
  unsigned char i, j;
  unsigned char MISC;
  unsigned char ATTR[0x15];
  unsigned char  SEQ[0x05];
  unsigned char   GC[0x09];
  unsigned char CRTC[0x19];

  setvideo();
  
  // read MISC register
  MISC = inp(0x3CC);

  // read attribute registers
  for(i=0; i<=0x14; i++)
  {
    j = inp(0x3da);
    outp(0x3c0, i);
    ATTR[i] = inp(0x3c1);
  }

  // read sequencer registers
  for(i=0; i<=0x04; i++)
  {
    outp(0x3c4, i);
    SEQ[i] = inp(0x3c5);
  }

  // read graphics controller registers
  for(i=0; i<=0x08; i++)
  {
    outp(0x3ce, i);
    GC[i] = inp(0x3cf);
  }

  // read CRT controller registers
  for(i=0; i<=0x18; i++)
  {
    outp(0x3d4, i);
    CRTC[i] = inp(0x3d5);
  }

  textmode();

  printf("misc:\n"); printf("\tdb 0x%.2x\n", MISC);  

  printf("attr:\n");
  printf("\tdb "); for(i=0; i<7; i++) printf("0x%.2x, ", ATTR[i]); printf("0x%.2x\n", ATTR[7]);
  printf("\tdb "); for(i=8; i<15; i++) printf("0x%.2x, ", ATTR[i]); printf("0x%.2x\n", ATTR[15]);
  printf("\tdb "); for(i=16; i<0x14; i++) printf("0x%.2x, ", ATTR[i]); printf("0x%.2x\n", ATTR[0x14]);

  printf("seq:\n"); printf("\tdb "); for(i=0; i<0x04; i++) printf("0x%.2x, ", SEQ[i]);  printf("0x%.2x\n", SEQ[0x04]);
  
  printf("gc:\n"); printf("\tdb "); for(i=0; i<7; i++) printf("0x%.2x, ", GC[i]); printf("0x%.2x\n", GC[7]);
  printf("\tdb 0x%.2x\n", GC[0x08]);
  
  printf("crtc:\n");
  printf("\tdb "); for(i=0; i<7; i++) printf("0x%.2x, ", CRTC[i]); printf("0x%.2x\n", CRTC[7]);
  printf("\tdb "); for(i=8; i<15; i++) printf("0x%.2x, ", CRTC[i]); printf("0x%.2x\n", CRTC[15]);
  printf("\tdb "); for(i=16; i<23; i++) printf("0x%.2x, ", CRTC[i]); printf("0x%.2x\n", CRTC[24]);
  printf("\tdb "); for(i=24; i<0x17; i++) printf("0x%.2x, ", CRTC[i]); printf("0x%.2x\n", CRTC[0x18]);
}
