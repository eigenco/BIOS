%define ATA0	0x300
%define ATA1	0x302
%define ATA2	0x304
%define ATA3	0x306
%define ATA4	0x308
%define ATA5	0x30A
%define ATA6	0x30C
%define ATA7	0x30E

;%define ATA0	0x300
;%define ATA1	0x301
;%define ATA2	0x302
;%define ATA3	0x303
;%define ATA4	0x304
;%define ATA5	0x305
;%define ATA6	0x306
;%define ATA7	0x307
;%define ATA8	0x308

	cpu     186
	db		0x55, 0xAA
	db		8192/512
	jmp		start

start:
	cli

	mov		al, 0x12
	out		0x20, al
	mov		al, 0x08
	out		0x21, al
	out		0x21, al
	mov		al, 11111100b
	out		0x21, al
	
	mov		al, 0x36
	out		0x43, al
	xor		al, al   ; 18.2 Hz
	out		0x40, al
	out		0x40, al
	
	mov		di, 0
	mov     es, di

	mov		word [es:0x08*4+2], cs
	mov		word [es:0x09*4+2], cs
	mov		word [es:0x10*4+2], cs
	mov		word [es:0x12*4+2], cs
	mov		word [es:0x13*4+2], cs
	mov		word [es:0x16*4+2], cs
	mov		word [es:0x08*4+0], INT08
	mov		word [es:0x09*4+0], INT09
	mov		word [es:0x10*4+0], INT10
	mov		word [es:0x12*4+0], INT12
	mov		word [es:0x13*4+0], INT13
	mov		word [es:0x16*4+0], INT16

	mov		al, 0x60
	out		0x64, al
	mov		al, 0x61
	out		0x60, al

	mov		al, 0x01
	mov		dx, ATA1
	out		dx, al                     ; 8-bit transfers
	
	mov     al, 0xEF
	mov     dx, ATA7
	out		dx, al                     ; set feature
	
	mov     dx, ATA7
wait_cf:
	in		al, dx
	test	al, 0x80
	jnz		wait_cf
	
	mov		sp, 0x30
	mov		ss, sp
	mov		sp, 0x0100                 ; IBM compatible stack

	mov		di, 0x40
	mov		es, di
	mov		byte [es:0x49], 3  ; video mode
	mov		word [es:0x4A], 80 ; columns
	mov		word [es:0x50], 0  ; cursor position
	mov		byte [es:0x62], 0  ; page
	mov		byte [es:0x84], 24 ; rows - 1

	xor		ax, ax
	mov		es, ax
	mov		ds, ax
	mov     ax, 0x0201
	mov     bx, 0x7C00
	mov     cx, 1
	mov     dx, 0x0080
	int     0x13                       ; load boot sector

	jmp     0:0x7C00                   ; boot
	
	retf

BLANK:
	iret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

INT08:
	push	ds
	push	ax
	mov		ax, 0x40
	mov		ds, ax
	clc
	adc		word [ds:0x6C], 1
	adc		word [ds:0x6E], 0
	int		0x1C
	mov		al, 0x20
	out		0x20, al
	pop		ax
	pop		ds
	iret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

INT09:
	push	ax
	push	bx
	push	ds
	in		al, 0x60
	cmp		al, 0x7F
	ja		INT09_pass
	mov		ah, al
	mov		bx, cs
	mov		ds, bx	
	mov		bx, ASCII
	xlatb
	mov		bx, 0x40
	mov		ds, bx
	mov		[ds:0x1E], ax
	mov		[ds:0x1A], byte 1 ; implies key has been hit
INT09_pass:
	mov		al, 0x20
	out		0x20, al
	pop		ds
	pop		bx
	pop		ax
    iret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

INT10:
	cmp		ah, 0x00
	je		INT10_SET_VIDEO_MODE
	cmp		ah, 0x0E
	je		INT10_WRITE_CHARACTER
	iret
INT10_SET_VIDEO_MODE:
	;pushf
	;call	0xC000:0x0135
	;call	0xC000:0x10B7 ; PCem/ET4000
	iret
INT10_WRITE_CHARACTER:
	push	ds
	push	si
	push	es
	push	di
	push	ax
	push	bx
	push	cx
	push	dx
	
	mov		di, 0x40
	mov		es, di
	mov		di, [es:0x50]

	cmp		al, 8 ; BACKSPACE
	jne		notBS
	sub		di, 2
	mov		bx, 0xB800
	mov		es, bx
	mov		ax, 0x0720
	stosw
	sub		di, 2
	jmp		nonCHAR
notBS:
	cmp		al, 13 ; CR
	jne		notCR
	mov 	bl, al
	mov 	bh, 160
	mov 	ax, di
	div 	bh	
	shr 	ax, 8
	sub 	di, ax
	jmp		nonCHAR
notCR:
	cmp		al, 10 ; LF
	jne		notLF
	add		di, 160
	cmp		di, 2*80*25
	jb		continue_normally
	mov		dx, di
	mov		bx, 0xB800
	mov		ds, bx
	mov		es, bx
	mov		si, 160
	xor		di, di
	mov		cx, 80*25
	rep		movsw
	mov		di, dx
	sub		di, 160
continue_normally:
	jmp		nonCHAR	
notLF:
	cmp		al, 32
	jb		nonCHAR
	mov		bx, 0xB800
	mov		es, bx
	mov		ah, 7
	stosw
nonCHAR:
	mov		bx, 0x40
	mov		es, bx
	mov		[es:0x50], di
	
	pop		dx
	pop		cx
	pop		bx
	pop		ax
	pop		di
	pop		es
	pop		si
	pop		ds
	iret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

INT12:
	mov		ax, 640
	iret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

INT13:
	cmp     ah, 2
	je      read_disk
	cmp     ah, 3
	je      write_disk
	cmp     ah, 8
	je      disk_type
	iret
read_disk:	
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	
	mov     di, bx                     ; destination = es:bx
	mov		si, ax                     ; # of sectors to read
	
	mov		bx, cx
	and		bx, 63                     ; sector is now in bx
		
	shr		cl, 6
	xchg	cl, ch                     ; cylinder is now in cx
	
	xchg	dl, dh
	and		dx, 0x0F

	mov		al, dl
	or		al, 0xA0
	mov     dx, ATA6
	out     dx, al	

	mov		ax, si                     ; # of sectors to read
	mov     dx, ATA2
	out     dx, al
	
	mov		al, bl                     ; sector
	mov     dx, ATA3
	out     dx, al

	mov		al, cl                     ; lo(cylinder)
	mov     dx, ATA4
	out     dx, al
	
	mov		al, ch                     ; hi(cylinder)
	mov     dx, ATA5
	out		dx, al
	
	mov     al, 0x20                   ; read
	mov		dx, ATA7
	out     dx, al
	
	mov		bx, si                     ; # of sectors to read
keep_reading:
	mov     cx, 256
	mov		dx, ATA7
wait_read_ready:
	in      al, dx
	test	al, 8
	jz      wait_read_ready	
read_word:
%ifdef ATA8
	mov     dx, ATA0
	in		al, dx
	mov		ah, al
	mov		dx, 0x308
	in		al, dx
	xchg	al, ah
	stosw
%else
	mov     dx, ATA0
	in		ax, dx
	stosw
%endif
	loop	read_word
	dec     bl
	jnz     keep_reading               ; until sectors are read
	
	pop		si
	pop     di
	pop     dx
	pop     cx
	pop		bx
	pop		ax
	iret

write_disk:
	iret
	push	ds
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	
	mov		si, es
	mov		ds, si
	
	mov     si, bx
	mov		di, ax
		
	mov		bx, cx
	and		bx, 63
		
	shr		cl, 6
	xchg	cl, ch
	
	xchg	dl, dh
	and		dx, 0x0F

	mov		al, dl
	or		al, 0xA0
	mov     dx, ATA6
	out     dx, al	

	mov		ax, di
	mov     dx, ATA2
	out     dx, al
	
	mov		al, bl
	mov     dx, ATA3
	out     dx, al

	mov		al, cl
	mov     dx, ATA4
	out     dx, al
	
	mov		al, ch
	mov     dx, ATA5
	out		dx, al	

	mov     al, 0x30 ; write
	mov		dx, ATA7
	out     dx, al
	mov		bx, di
keep_writing:
	mov     cx, 256
	mov		dx, ATA7
wait_write_ready:
	in      al, dx
	test	al, 8
	jz      wait_write_ready
	mov     dx, ATA0
write_word:
	lodsw
	out		dx, ax
	loop	write_word
	dec     bl

	mov     dx, ATA7
wait_w0:
	in		al, dx
	test	al, 0x80
	jnz		wait_w0

	mov     al, 0xE7
	out		dx, al

wait_w1:
	in		al, dx
	test	al, 0x80
	jnz		wait_w1

	jnz     keep_writing

	pop		si
	pop     di
	pop     dx
	pop     cx
	pop		bx
	pop		ax
	pop		ds
	iret
disk_type:
	mov		cx, 0xFFFF
	mov		dx, 0x0F01
	iret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

INT16:	
	push	ds
	or		ah, ah
	jz		INT16_AH00
	dec		ah
	jz		INT16_AH01
	jmp		INT16_END
INT16_AH00:
	mov		ax, 0x40
	mov		ds, ax
	mov		ax, [ds:0x1E]
	cli
	mov		[ds:0x1A], word 0 ; implies no key has been hit
	mov		ax, [ds:0x1E]
	sti
INT16_END:
	pop		ds
	iret
INT16_AH01:
	mov		ax, 0x40
	mov		ds, ax
	mov		al, [ds:0x1A]
	and 	al, 1
	jz		INT16_END
	or		al, 1
	pop		ds
	retf	2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASCII:
	db       0  ; 00
	db     0x1B ; 01 <ESC>
	db      '1' ; 02
	db      '2' ; 03
	db      '3' ; 04
	db      '4' ; 05
	db      '5' ; 06
	db      '6' ; 07
	db      '7' ; 08
	db      '8' ; 09
	db      '9' ; 0A
	db      '0' ; 0B
	db       12 ; 0C
	db      '=' ; 0D
	db     0x08 ; 0E <BACKSPACE>
	db     0x09 ; 0F <TAB>
	db      'q' ; 10
	db      'w' ; 11
	db      'e' ; 12
	db      'r' ; 13
	db      't' ; 14
	db      'y' ; 15
	db      'u' ; 16
	db      'i' ; 17
	db      'o' ; 18
	db      'p' ; 19
	db       26 ; 1A
	db       27 ; 1B
	db     0x0D ; 1C <ENTER>
	db       29 ; 1D
	db      'a' ; 1E
	db      's' ; 1F
	db      'd' ; 20
	db      'f' ; 21
	db      'g' ; 22
	db      'h' ; 23
	db      'j' ; 24
	db      'k' ; 25
	db      'l' ; 26
	db       39 ; 27
	db       40 ; 28
	db       41 ; 29
	db       42 ; 2A
	db      '\' ; 2B
	db      'z' ; 2C
	db      'x' ; 2D
	db      'c' ; 2E
	db      'v' ; 2F
	db      'b' ; 30
	db      'n' ; 31
	db      'm' ; 32
	db      ',' ; 33
	db      '.' ; 34
	db      '/' ; 35
	db      0xFF; 36 <SHIFT>
	db       55 ; 37
	db       56 ; 38
	db      ' ' ; 39 <SPACE>
	db		  0 ; 3A
	db        0 ; 3B
	db        0 ; 3C
	db        0 ; 3D
	db        0 ; 3E
	db        0 ; 3F
	db        0 ; 40
	db        0 ; 41
	db        0 ; 42
	db        0 ; 43
	db        0 ; 44
	db        0 ; 45
	db        0 ; 46
	db        0 ; 47
	db        0 ; 48 <UP>
	db        0 ; 49
	db        0 ; 4A
	db        0 ; 4B <LEFT>
	db        0 ; 4C
	db        0 ; 4D <RIGHT>
	db        0 ; 4E
	db        0 ; 4F
	db        0 ; 50 <DOWN>
	db		  0 ; 51
	db        0 ; 52
	db        0 ; 53
	db        0 ; 54
	db        0 ; 55
	db        0 ; 56
	db        0 ; 57
	db        0 ; 58
	db        0 ; 59
	db        0 ; 5A
	db        0 ; 5B
	db        0 ; 5C
	db        0 ; 5D
	db        0 ; 5E
	db        0 ; 5F
	db        0 ; 60
	db		  0 ; 61
	db        0 ; 62
	db        0 ; 63
	db        0 ; 64
	db        0 ; 65
	db        0 ; 66
	db        0 ; 67
	db        0 ; 68
	db        0 ; 69
	db        0 ; 6A
	db        0 ; 6B
	db        0 ; 6C
	db        0 ; 6D
	db        0 ; 6E
	db        0 ; 6F
	db        0 ; 70
	db		  0 ; 71
	db        0 ; 72
	db        0 ; 73
	db        0 ; 74
	db        0 ; 75
	db        0 ; 76
	db        0 ; 77
	db        0 ; 78
	db        0 ; 79
	db        0 ; 7A
	db        0 ; 7B
	db        0 ; 7C
	db        0 ; 7D
	db        0 ; 7E
	db        0 ; 7F