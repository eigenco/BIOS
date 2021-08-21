	dw	0xAA55 ; magic word
	db      64     ; size: 64*512 = 32768
	jmp	start  ; jmp to start address
start:
	mov	sp, 0x30
	mov	ss, sp
	mov	sp, 0x100

	cli
	mov	di, 0
	mov	es, di
	mov     word [es:0x10*4], INT10
	mov	word [es:0x10*4+2], cs

	; set key (page 103 of ET4000 data book PDF)
	mov	dx, 0x3bf
	mov	al, 3
	out	dx, al
	mov	dx, 0x3d8
	mov	al, 0xa0
	out	dx, al

	; set clocks, TS Auxiliary Mode (page 143 of ET4000 data book PDF)
	mov	dx, 0x3c4
	mov	ax, 0xfc07
	out	dx, ax

	mov	ax, 0x13
	int	0x10

	mov	dx, 0x3c6 ; PEL mask register
	mov	al, 0xff  ; (anded with palette index)
	out	dx, al

	mov	al, 0
palette_loop:
	mov	dx, 0x3c8
	out	dx, al
	mov	dx, 0x3c9
	out	dx, al
	out	dx, al
	out	dx, al
	inc	al
	cmp	al, 64
	jne	palette_loop

	mov	di, 0xa000
	mov	es, di
	xor	di, di
image_loop:
	mov	ax, di
	and	al, 63
	stosb
	cmp	di, 320*200
	jne	image_loop

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
	outsb              ; program MISC register

	mov	cx, 21
atcloop:
	mov	dx, 0x3da
	in	al, dx
	mov	dx, 0x3c0
	lodsb
	out	dx, al
	lodsb
	out	dx, al     ; program ATC registers
	loop	atcloop

	mov	dx, 0x3c4
	mov	cx, 0x05
	rep	outsw      ; program SEQUENCER registers

	mov	dx, 0x3ce
	mov	cx, 0x08
	rep	outsw      ; program GDC registers

	mov	dx, 0x3d4
	mov	ax, 0x0011 ; disable protect
	out	dx, ax

	mov	cx, 0x19
	rep	outsw      ; program CRTC registers

	mov	dx, 0x3c0
	mov	al, 0x20
	out	dx, al
	mov	dx, 0x3da
	in	al, dx
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

VGA_REGS:
	db 0x63   ; MISC 3c2 (page 96 of ET4000 data book PDF)

	dw 0x0000 ; ATC 3c0 (page 97 of ET4000 data book PDF)
	dw 0x0101
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

	dw 0x0300 ; SEQUENCER 3c4 (page 96 of ET4000 data book PDF)
	dw 0x0101
	dw 0x0f02
	dw 0x0003
	dw 0x0e04

	dw 0x0000 ; GDC 3ce (page 97 of ET4000 data book PDF)
	dw 0x0001
	dw 0x0002
	dw 0x0003
	dw 0x0004
	dw 0x4005
	dw 0x0506
	dw 0x0f07
	dw 0xff08

	dw 0x5f00 ; CRTC 3d4 (page 96 of ET4000 data book PDF)
	dw 0x4f01
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
	dw 0x8e11
	dw 0x8f12
	dw 0x2813
	dw 0x4014
	dw 0x9615
	dw 0xb916
	dw 0xa317
	dw 0xff18

	times	32768 - ($-$$) db 0 ; last byte used for checksum match
