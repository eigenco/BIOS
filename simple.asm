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

	cpu	8086

start:
	cli

	xor	di, di
	mov	es, di
	mov	cx, 0x1f
.0:
	mov	ax, blank
	stosw
	mov	ax, cs
	stosw
	loop	.0

	mov	word [es:0x09*4], int9
	mov     word [es:0x12*4], int12
	mov     word [es:0x13*4], int13

;;;; setup 8259 Programmable Interrupt Controller (PIC) ;;;;

	mov	al, 00010000b
	out	0x20, al

	mov	al, 00001000b
	out	0x21, al

	mov	al, 0
	out	0x21, al

	mov	al, 0
	out	0x21, al

	sti

;;;; setup 8042 keyboard controller ;;;;

	mov	al, 0xF0
	out	0x60, al

	mov	al, 1
	out	0x60, al

;;;; load VGA BIOS ;;;;

	call	0xc000:0x0003

;;;; load and execute boot sector ;;;;

	xor	ax, ax
	mov	es, ax
	mov	ax, 0x0201
	mov	bx, 0x7c00
	mov	cx, 1
	mov	dx, 0x0080
	int	0x13
	jmp	0:0x7c00

;;;; BIOS KEYBOARD INTERRUPT ;;;;

int9:
	in	al, 0x60
	mov	al, 0x20
	out	0x20, al
	iret

;;;; BIOS MEMORY INTERRUPT SERVICE ;;;;

int12:
	mov	ax, 640
	iret

;;;; BIOS DISK INTERRUPT SERVICE ;;;;

int13:
	cmp	ah, 2
	je	read_disk
	cmp	ah, 3
	je	write_disk
	cmp	ah, 8
	je	disk_type
	iret
read_disk:
	push	cx
	push	dx
	push	di

	mov	di, bx                 ; target = es:bx
	mov	bl, al                 ; sectors to read

	mov     al, dh                 ; head
	mov     dx, 0x1f6
	out     dx, al

	mov	al, bl                 ; sectors to read
	mov     dx, 0x1f2
	out     dx, al

	mov     al, cl                 ; sector
	mov     dx, 0x1f3
	out     dx, al

	mov     al, ch                 ; cylinder
	mov     dx, 0x1f4
	out     dx, al

	mov     al, 0x20               ; read (0x30 for write)
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
	in	ax, dx
	stosw
	loop	.2
	dec     bl
	jnz	.0                     ; until sectors are read

	pop	di
	pop	dx
	pop	cx
	iret

write_disk:
	iret

disk_type:
	mov	cx, 0xFD11             ; Type: 47
	mov	dx, 0x0E01             ; Cyln: 255, Head: 15, Sect: 17
blank:
	iret

times   0xfff0-($-$$) db 0xFF

	jmp     0xF000:start

times   0x10000-($-$$) db 0xFF
