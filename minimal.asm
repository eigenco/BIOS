; System BIOS at F000:0000 - F000:FFFF

	cpu     8086

start:
	mov		di, 0
	mov     es, di
	mov     cx, 0x1F
blints:
	mov     ax, blank
	stosw
	mov     ax, cs
	stosw
	loop	blints

	mov     word [es:0x08*4], int08
	mov     word [es:0x09*4], int09
	mov     word [es:0x12*4], int12
	mov     word [es:0x16*4], int16
	mov     word [es:0x1A*4], int1A

;;;; BIOS DATA AREA ;;;;

	mov		di, 0x40
	mov		es, di
	mov		word [es:0x1A], 0x1E
	
;;;; 8042 KEYBOARD CONTROLLER ;;;;

	mov     al, 0xF0
	out     0x60, al
	mov     al, 0x01
	out     0x60, al
	
;;;; 8259 INTERRUPT CONTROLLER ;;;;

	mov		al, 0x10
	out		0x20, al
	mov		al, 0x08
	out		0x21, al
	mov		al, 0x00
	out		0x21, al
	out		0x21, al
	
;;;; 8253 TIMER ;;;;

	mov		al, 0x36
	out		0x43, al
	mov		al, 0x00
	out		0x40, al
	out		0x40, al

;;;; LOAD BIOS ROM EXTENSIONS ;;;;

	call	0xC000:3 ; VGA BIOS
	call	0xC800:3 ; IDE BIOS
	int		0x19
	
;;;; TIMER INTERRUPT ;;;;

int08:
	push	ds
	push	ax
	mov		ax, 0x40
	mov		ds, ax
	clc
	adc		word [ds:0x6C], 1
	adc		word [ds:0x6E], 0
	mov		al, 0x20
	out		0x20, al
	pop		ax
	pop		ds
blank:
	iret

;;;; KEYBOARD INTERRUPT ;;;;

int09:
	push	ax
	push	es
	push	di
	mov		di, 0x40
	mov		es, di
	in      al, 0x60
	cmp		al, 0xB6
	jne		not_right_shift_up
	mov		[es:0x17], byte 0
	jmp		skip_buffering
not_right_shift_up:
	cmp		al, 0x36
	jne		not_right_shift_down	
	mov		[es:0x17], byte 1
	jmp		skip_buffering
not_right_shift_down:
	cmp		al, 0x80
	jae		skip_buffering
	inc		word [es:0x1A]
	mov		di, [es:0x1A]	
	mov		byte [es:di], al
skip_buffering:
	mov     al, 1
	out     0x64, al
	mov		al, 0x20
	out		0x20, al
	pop		di
	pop		es
	pop		ax
    iret

;;;; CONVENTIONAL MEMORY ;;;;

int12:
	mov		ax, 640
	iret

;;;; BIOS KEYBOARD SERVICE ;;;;

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
	push	bx
	mov		bx, cs
	mov		ds, bx
	mov		bx, ascii
	xlat
	pop		bx
	pop		di
	pop		es
	iret
checkkey:
	cli
	cmp		word [es:0x1A], 0x1E
	sti
	jne		key
	cmp		al, al
key:
	pop		di
	pop		es
	retf	2
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
	db      '=' ; 0D
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
	db      0xFF; 48 <UP>
	db        0 ; 49
	db        0 ; 4A
	db      0xFF; 4B <LEFT>
	db        0 ; 4C
	db      0xFF; 4D <RIGHT>
	db        0 ; 4E
	db        0 ; 4F
	db      0xFF; 50 <DOWN>

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

int1A:
	push	ax
	push	ds
	mov		ax, 0x40
	mov		ds, ax
	mov		cx, [ds:0x6E]
	mov		dx, [ds:0x6C]
	pop		ds
	pop		ax
	iret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	times	0xFFF0-($-$$) db 0xFF

	jmp     0xF000:start

	dw		0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF
	db		0xFF