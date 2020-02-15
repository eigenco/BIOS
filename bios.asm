;;;;
;;
;; We impleme a bare minimum ROM needed to boot MS-DOS 6.22
;;
;;;;

	mov     cx, 0x1e
empty_interrupts:
	mov     bx, cx
	shl     bx, 2
	mov     word [es:bx], empty
	mov     [es:bx+2], cs
	loop	empty_interrupts

prepare_interrupts:
	mov	word [es:0x10*4], int10h
	mov	[es:0x10*4+2], cs

	mov	word [es:0x12*4], int12h
	mov	[es:0x12*4+2], cs

	mov	word [es:0x13*4], int13h
	mov	[es:0x13*4+2], cs

prepare_data_and_stack:
	mov	sp, 0xf000
	mov	ds, sp
	mov	es, sp
	mov	sp, 0xe000
	mov	ss, sp
	mov	sp, 0xfffe

prepare_keyboard:
        mov     al, 0x60
        out     0x64, al
        mov     al, 0x60
        out     0x60, al

prepare_textmode:
	mov	ax, 3h
	int	10h

load_bootsector:
	mov	ah, 2                            ; read sectors
	mov	al, 1                            ; number of sectors to read
	mov	ch, 0                            ; cylinder low
	mov	cl, 1                            ; sector (+ cylinder high << 6)
	mov	dh, 0                            ; head
	mov	bx, 0                            ; segment
	mov	es, bx
	mov	bx, 0x7c00                       ; offset
	int	13h

execute:
        jmp	0x0000:0x7c00

empty:
	iret

%include "int10.asm"

int12h:
        mov     ax, 640
        iret

%include "int13.asm"

times   0xfff0-($-$$) db 0

entry:
	jmp     0xf000:0x0000

times	11 db 0
