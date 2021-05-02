%macro outport 2
	mov	dx, %1
	mov	al, %2
	out	dx, al
%endmacro

%macro inport 1
	mov	dx, %1
	in	al, dx
%endmacro

	db      0x55
	db      0xAA
	db      64
	jmp	start
start:
	mov	sp, 0x30
	mov	ss, sp
	mov	sp, 0x100

	cli
	mov	di, 0
	mov	es, di
	mov     word [es:0x10*4], INT10
	mov	word [es:0x10*4+2], cs

	; ET4000: set key
	mov	dx, 0x3bf
	mov	al, 3
	out	dx, al
	mov	dx, 0x3d8
	mov	al, 0xa0
	out	dx, al
	mov	dx, 0x46e8
	mov	al, 8
	out	dx, al

	; ET4000: set clocks
	mov	dx, 0x3c4
	mov	ax, 0x0006
	out	dx, ax
	mov	ax, 0xfc07
	out	dx, ax

	; stuff
;	mov	dx, 0x3d4
;	mov	ax, 0x0033
;	out	dx, ax
;	mov	ax, 0x0035
;	out	dx, ax

;	mov	dx, 0x3c0
;	mov	al, 0x16
;	out	dx, al
;	mov	al, 0x00
;	out	dx, al

	mov	ax, 0x13
	int	0x10

	mov	dx, 0x3c6
	mov	al, 0xff
	out	dx, al

	mov	al, 0
loop1:
	mov	dx, 0x3c8
	out	dx, al
	mov	dx, 0x3c9
	out	dx, al
	out	dx, al
	out	dx, al
	inc	al
	cmp	al, 64
	jne	loop1

	mov	bx, 0xa000
	mov	es, bx
	mov	di, 0
loop2:
	mov	ax, di
	and	al, 63
	stosb
	cmp	di, 320*200
	jne	loop2

	jmp	$

INT10:
	cmp	ah, 0x00
	je	INT10_set_video_mode
	mov	al, 0x1a
	mov	bx, 8
	iret
INT10_set_video_mode:
	push	ds
	push	si
	push	ax
	push	bx
	push	cx
	push	dx
	mov	si, VGA_REGS
	call	INT10_load_VGA_regs
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	pop	si
	pop	ds
	iret
INT10_load_VGA_regs:
	mov	bx, cs
	mov	ds, bx

	mov	dx, 0x3c2
	outsb              ; MISC

	mov	cx, 21
atcloop:
	mov	dx, 0x3da
	in	al, dx
	mov	dx, 0x3c0
	lodsb
	out	dx, al
	lodsb
	out	dx, al
	loop	atcloop
;	mov	cx, 42
;	rep	outsb      ; ATC

	mov	dx, 0x3c4
	mov	cx, 0x04+1
	rep	outsw      ; SEQUENCER

	mov	dx, 0x3ce
	mov	cx, 0x08+1
	rep	outsw      ; GDC

	mov	dx, 0x3d4
	mov	ax, 0x0011 ; protect off
	out	dx, ax

	mov	cx, 0x18+1
	rep	outsw      ; CRTC

	mov	dx, 0x3c0
	mov	al, 0x20
	out	dx, al
	mov	dx, 0x3da
	in	al, dx
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

VGA_REGS:
	db 0x63   ; MISC 3c2 (page 96)

	dw 0x0000 ; ATC 3c0/1 (page 96)
	dw 0x0101 ; 0x00 - 0x14, 0x16
	dw 0x0202
	dw 0x0303
	dw 0x0404
	dw 0x0505
	dw 0x0606
	dw 0x0707
	dw 0x0808
	dw 0x0909
	dw 0x0a0a
	dw 0x0b0b
	dw 0x0c0c
	dw 0x0d0d
	dw 0x0e0e
	dw 0x0f0f
	dw 0x4130
	dw 0x0031
	dw 0x0f32
	dw 0x0033
	dw 0x0034

	dw 0x0300 ; SEQUENCER 3c4/5 (page 95)
	dw 0x0101 ; 0x00 - 0x04
	dw 0x0f02
	dw 0x0003
	dw 0x0e04

	dw 0x0000 ; GDC 3ce/f (page 96)
	dw 0x0001 ; 0x00 - 0x08
	dw 0x0002
	dw 0x0003
	dw 0x0004
	dw 0x4005
	dw 0x0506
	dw 0x0f07
	dw 0xff08

	dw 0x5f00 ; CRTC 3d4/5 (page 95)
	dw 0x4f01 ; 0x00 - 0x18
	dw 0x5002
	dw 0x8203
	dw 0x5404
	dw 0x8005
	dw 0xbf06
	dw 0x1f07
	dw 0x0008
	dw 0x4109
	dw 0x000a
	dw 0x000b
	dw 0x000c
	dw 0x000d
	dw 0x000e
	dw 0x000f
	dw 0x9c10
	dw 0x0e11
	dw 0x8f12
	dw 0x2813
	dw 0x4014
	dw 0x9615
	dw 0xb916
	dw 0xa317
	dw 0xff18

	times	32768 - ($-$$) db 0
