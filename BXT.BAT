cycles max
del *.rom
del *.obj
del *.bin
..\masm pcxt
..\link pcxt
..\debug.com pcxt.exe < pcxt.txt
