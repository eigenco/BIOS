; System BIOS at F000:0000 - F000:FFFF
;
; Boots with PCemV17 (ami386 and ET4000), disk with MS-DOS 6.22 installed
;
; BIOS interrupts are very partially implemented
;
; Find the correct HDD parameters (cx and dx):
;
; debug
; a
; mov dl,80
; mov ah,8
; int 13
;
; g =100 106

	cpu     8086

start:
	cli

	xor     di, di
	mov     es, di
	mov     cx, 0x1f
.0:
	mov     ax, blank
	stosw
	mov     ax, cs
	stosw
	loop	.0

	mov     word [es:0x09*4], int9
	mov     word [es:0x12*4], int10
	mov     word [es:0x12*4], int12
	mov     word [es:0x13*4], int13

;;;; setup 8259 Programmable Interrupt Controller (PIC) ;;;;

	mov     al, 00010000b
	out     0x20, al

	mov     al, 00001000b
	out     0x21, al

	mov     al, 0
	out     0x21, al

	mov     al, 0
	out     0x21, al

	sti

;;;; setup 8042 keyboard controller ;;;;

	mov     al, 0xF0
	out     0x60, al

	mov     al, 1
	out     0x60, al

;;;; setup VGA registers ;;;;

	mov	bx, cs
	mov	ds, bx

	cpu 186

	mov	si, MISCregs
	mov	dx, 0x3c2
	outsb

	mov	si, SEQregs
	mov	dx, 0x3c4
	mov	cx, 5
	rep	outsw

	mov	si, CRTCregs
	mov	dx, 0x3d4
	mov	cx, 26
	rep	outsw

	mov	si, GCregs
	mov	dx, 0x3ce
	mov	cx, 9
	rep	outsw

	mov	si, ACregs
	mov	dx, 0x3c0
	mov	cx, 42
	rep	outsb

	mov	dx, 0x3da
	in	al, dx
	mov	dx, 0x3c0
	mov	al, 0x20
	out	dx, al
	
	cpu 8086

;;;; load VGA BIOS ;;;;

;	call	0xc000:0x0003

;;;; load and execute boot sector ;;;;

	xor     ax, ax
	mov     es, ax
	mov     ax, 0x0201
	mov     bx, 0x7c00
	mov     cx, 1
	mov     dx, 0x0080
	int     0x13
	jmp     0:0x7c00

;;;; BIOS KEYBOARD INTERRUPT ;;;;

int9:
	in      al, 0x60
	mov     al, 0x20
	out     0x20, al
	iret

;;;; BIOS VIDEO INTERRUPT SERVICE ;;;;

int10:
	iret

;;;; BIOS MEMORY INTERRUPT SERVICE ;;;;

int12:
	mov     ax, 640
	iret

;;;; BIOS DISK INTERRUPT SERVICE ;;;;

int13:
	cmp     ah, 2
	je      read_disk
	cmp     ah, 3
	je      write_disk
	cmp     ah, 8
	je      disk_type
	iret
read_disk:
	push	cx
	push	dx
	push	di

	mov     di, bx                 ; target = es:bx
	mov     bl, al                 ; sectors to read

	mov     al, dh                 ; head
	mov     dx, 0x1f6
	out     dx, al

	mov     al, bl                 ; sectors to read
	mov     dx, 0x1f2
	out     dx, al

	mov     al, cl                 ; sector
	mov     dx, 0x1f3
	out     dx, al

	mov     al, ch                 ; low(cylinder)
	mov     dx, 0x1f4
	out     dx, al

	mov     al, 0x20               ; read
	mov     dx, 0x1f7
	out     dx, al
.0:
	mov     dx, 0x1f7
.1:
	in      al, dx
	test    al, 8
	jz      .1
	mov     cx, 256
	mov     dx, 0x1f0
.2:
	in      ax, dx
	stosw
	loop	.2
	dec     bl
	jnz	.0                     ; until sectors are read

	pop     di
	pop     dx
	pop     cx
	iret

write_disk:
	push	es
	pop     ds
	push	cx
	push	dx
	push	si

	mov     si, bx                 ; target = es:bx
	mov     bl, al                 ; sectors to write

	mov     al, dh                 ; head
	mov     dx, 0x1f6
	out     dx, al

	mov     al, bl                 ; sectors to write
	mov     dx, 0x1f2
	out     dx, al

	mov     al, cl                 ; sector
	mov     dx, 0x1f3
	out     dx, al

	mov     al, ch                 ; low(cylinder)
	mov     dx, 0x1f4
	out     dx, al

	mov     al, 0x30               ; write
	mov     dx, 0x1f7
	out     dx, al
.0:
	mov     dx, 0x1f7
.1:
	in      al, dx
	test    al, 8
	jz      .1
	mov     cx, 256
	mov     dx, 0x1f0
.2:
	lodsw
	out     dx, ax
	loop	.2
	dec     bl
	jnz	.0                     ; until sectors are written

	pop     si
	pop     dx
	pop     cx
	iret

disk_type:
	mov     cx, 0xFD11             ; Type: 47
	mov     dx, 0x0E01             ; Cyln: 255, Head: 15, Sect: 17
blank:
	iret

MISCregs:
	db 0x23	; db 0x63

SEQregs:
	dw 0x0300 ; dw 0x0000
	dw 0x0B01 ; dw 0x0901
	dw 0x0F02 ; dw 0x0F02
	dw 0x0003 ; dw 0x0003
	dw 0x0604 ; dw 0x0204

CRTCregs:
	dw 0x0011
	dw 0x2D00
	dw 0x2701
	dw 0x2802
	dw 0x9003
	dw 0x2B04
	dw 0x8005
	dw 0xBF06
	dw 0x1F07
	dw 0x0008
	dw 0xC009
	dw 0x000A
	dw 0x000B
	dw 0x000C
	dw 0x000D
	dw 0x000E
	dw 0x000F
	dw 0x9C10
	dw 0x8E11
	dw 0x8F12
	dw 0x1413
	dw 0x0014
	dw 0x9615
	dw 0xB916
	dw 0xE317
	dw 0xFF18

GCregs:
	dw 0x0000
	dw 0x0001
	dw 0x0002
	dw 0x0003
	dw 0x0004
	dw 0x0005
	dw 0x0506
	dw 0x0F07
	dw 0xFF08

ACregs:
	dw 0x0000
	dw 0x0101
	dw 0x0202
	dw 0x0303
	dw 0x0404
	dw 0x0505
	dw 0x0606
	dw 0x0707
	dw 0x1008
	dw 0x1109
	dw 0x120A
	dw 0x130B
	dw 0x140C
	dw 0x150D
	dw 0x160E
	dw 0x170F
	dw 0x0110
	dw 0x0011
	dw 0x0F12
	dw 0x0013
	dw 0x0014

times   0xfff0-($-$$) db 0xFF

	jmp     0xF000:start

times   0x10000-($-$$) db 0xFF
