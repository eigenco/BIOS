; System BIOS at F000:0000 - F000:FFFF
;
; What works
;  Supaplex
;  Prince of persia

	cpu     8086

start:
	cli
	xor     di, di
	mov     es, di
	mov     cx, 0x1F
blankints:
	mov     ax, blank
	stosw
	mov     ax, cs
	stosw
	loop	blankints
	mov     word [es:0x08*4], int8
	mov     word [es:0x09*4], int9
	mov     word [es:0x13*4], int13
	mov     word [es:0x16*4], int16

;;;; BDA stuff ;;;;

	mov		di, 0x40
	mov		es, di
	mov		word [es:0x1A], 0x1E

;;;; setup 8259 Programmable Interrupt Controller (PIC) ;;;;

	mov		al, 16
	out		0x20, al
	mov		al, 8
	out		0x21, al
	mov		al, 0
	out		0x21, al
	mov		al, 0
	out		0x21, al
	
;;;; setup 8253 Programmable Interval Timer (PIT) ;;;;

	mov		al, 00110110b ; counter 0, mode 3
	out		0x43, al
	mov		al, 0         ; 18.2 Hz
	out		0x40, al
	out		0x40, al
	
;;;; setup 8042 keyboard controller ;;;;

	mov     al, 0xF0
	out     0x60, al
	mov     al, 1
	out     0x60, al

;;;; load ROM extensions ;;;;

	call	0xC000:0x0003 ; VGA BIOS
	
	xor		bx, bx
	mov		es, bx
	mov     ax, word [es:0x10*4]
	mov		bx, word [es:0x10*4+2]
	mov		word [es:0x12*4], ax
	mov		word [es:0x12*4+2], bx
	
	xor		ax, ax
	mov		es, ax	
	mov     word [es:0x10*4], int10
	mov     word [es:0x10*4+2], cs

;;;; LOAD BOOT SECTOR ;;;;

	sti
	mov     ax, 0x0201
	mov     bx, 0x7C00
	mov     cx, 1
	mov     dx, 0x0080
	int     0x13
	jmp     0:0x7C00
	
;;;; PIT INTERRUPT ;;;;

int8:
	push	ax
	mov		al, 0x20
	out		0x20, al
	pop		ax
	iret
	
;;;; BIOS KEYBOARD INTERRUPTs ;;;;

int9:
	push	ax
	push	es
	push	di
	mov		di, 0x40
	mov		es, di
	in      al, 0x60
	cmp		al, 0xB6
	jne		notrshftu	
	mov		[es:0x17], byte 0
	jmp		nobuff
notrshftu:
	cmp		al, 0x36
	jne		notrshft	
	mov		[es:0x17], byte 1
	jmp		nobuff
notrshft:
	cmp		al, 0x80
	jae		nobuff
	inc		word [es:0x1A]
	mov		di, [es:0x1A]	
	mov		byte [es:di], al
nobuff:
	mov     al, 1
	out     0x64, al
	mov		al, 0x20
	out		0x20, al
	pop		di
	pop		es
	pop		ax
    iret

int16:
    push	es
	push	di
	mov		di, 0x40
	mov		es, di
	cmp     ah, 0
    je      getkey
    cmp     ah, 1
    je      checkkey	
	pop		di
	pop		es
    iret
getkey:
	cli
	cmp		word [es:0x1A], 0x1E
	sti
	jne		readkey	
	jmp		getkey
readkey:
	mov		di, [es:0x1A]
	mov		al, [es:di]
	dec		word [es:0x1A]
	mov		bx, cs
	mov		ds, bx
	mov		bx, ascii
	xlat
	pop		di
	pop		es
	iret
checkkey:	
	cli
	cmp		word [es:0x1A], 0x1E
	sti
	je		nokey
	mov		bl, 0
	mov		bh, 1
	cmp		bh, bl	
	pop		di
	pop		es
	retf	2
nokey:		
	pop		di
	pop		es	
	iret
ascii:
	db       0  ; 00
	db       1  ; 01
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
	db       13 ; 0D
	db     0x08 ; 0E <BACKSPACE>
	db       15 ; 0F
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
	db       51 ; 33
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
	db      0xFF; 48 <UP>
	db        0 ; 49
	db        0 ; 4A
	db      0xFF; 4B <LEFT>
	db        0 ; 4C
	db      0xFF; 4D <RIGHT>
	db        0 ; 4E
	db        0 ; 4F
	db      0xFF; 50 <DOWN>

;;;; BIOS VIDEO INTERRUPT ;;;;

int10:
	cmp	    ah, 0
	je	    setmode
	cmp     ah, 0x0E
	je	    putchar	
	cmp		ah, 0x1A
	je		prince_of_persia
	iret
prince_of_persia:
	mov		al, 26
	mov		ah, 122
	mov		bl, 8
	mov		bh, 0
	iret
setmode:
	cmp		al, 0x03
	jne		notTXT	
	int		0x12
notTXT:
	cmp		al, 0x0D
	jne		notEGA	
	int		0x12
notEGA:
	cmp		al, 0x13	
	jne		notMCGA
	int		0x12
notMCGA:
	iret
putchar:
	push	ds
	push	si
	push	es
	push	di
	push	ax
	push	bx
	push	cx
	push	dx

	; load old cursor location from BIOS Data Area
	mov		bx, 0x40
	mov		es, bx
	mov		bx, 0x50
	mov		di, [es:bx]
	cmp		al, 8            ; BACKSPACE
	jne		notbs
	sub		di, 2
	mov		al, ' '
	jmp		nonchar
notbs:
	cmp		al, 13           ; CR
	jne 	notcr
	mov 	bl, al
	mov 	bh, 160
	mov 	ax, di
	div 	bh
	cpu 	186
	shr 	ax, 8
	cpu 	8086
	sub 	di, ax
	jmp 	nonchar
notcr:
	cmp		al, 10           ; LF
	jne 	notlf
	add 	di, 160
	cmp		di, 2*80*25
	jb		continue_normally ; scroll if necessary
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
	jmp 	nonchar
notlf:
	; write characters to VGA adapter
	mov		bx, 0xB800
	mov		es, bx
	mov		ah, 7
	stosw
nonchar:
	; store new cursor location to BIOS Data Area
	mov		bx, 0x40
	mov		es, bx
	mov		bx, 0x50
	mov		[es:bx], di
	
	; set cursor location
	shr 	di, 1
	mov 	bx, di
	mov 	dx, 0x3D4
	mov 	al, 0x0F
	out 	dx, al
	inc 	dx	
	mov 	al, bl
	out 	dx, al ; low byte
	dec 	dx
	mov 	al, 0x0E
	out 	dx, al
	mov 	al, bh
	inc 	dx
	out 	dx, al ; high byte

	pop		dx
	pop		cx
	pop		bx
	pop		ax
	pop		di
	pop		es
	pop		si
	pop		ds
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
	mov     dx, 0x1F6
	out     dx, al

	mov     al, bl                 ; sectors to read
	mov     dx, 0x1F2
	out     dx, al

	mov     al, cl                 ; sector
	inc		dx	
	out     dx, al

	mov     al, ch                 ; low(cylinder)
	inc		dx	
	out     dx, al

	mov     al, 0x20               ; read
	mov     dx, 0x1F7
	out     dx, al
keep_reading:
	mov     dx, 0x1F7
wait_read_ready:
	in      al, dx
	test    al, 8
	jz      wait_read_ready
	mov     cx, 256	
	mov     dx, 0x1F0
read_word:
	in      ax, dx
	stosw
	loop	read_word
	dec     bl
	jnz     keep_reading           ; until sectors are read

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
	mov     dx, 0x1F6
	out     dx, al

	mov     al, bl                 ; sectors to write
	mov     dx, 0x1F2
	out     dx, al

	mov     al, cl                 ; sector
	inc		dx	
	out     dx, al

	mov     al, ch                 ; low(cylinder)
	inc		dx	
	out     dx, al

	mov     al, 0x30               ; write
	mov     dx, 0x1F7
	out     dx, al
keep_writing:
	mov     dx, 0x1F7
wait_write_ready:
	in      al, dx
	test    al, 8
	jz      wait_write_ready
	mov     cx, 256
	mov     dx, 0x1F0
write_word:
	lodsw
	out     dx, ax
	loop	write_word
	dec     bl
	jnz     keep_writing           ; until sectors are written

	pop     si
	pop     dx
	pop     cx
	iret
disk_type:
	mov     cx, 0xFF3F
	mov     dx, 0x0F01
blank:
	iret

	times	0xFFF0-($-$$) db 0xFF

	jmp     0xF000:start

	dw		0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF
	db		0xFF