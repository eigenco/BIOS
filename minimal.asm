; System BIOS at F000:0000 - F000:FFFF
; PCem configuration: ET4000AX, XTIDE C:1024 H:16 S:63
; - Initializes: KBD, PIC, PIT, IVT
; - Services: KBD, Time, Conventional MEM
; - Load: VGA BIOS, IDE BIOS

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

	mov     word [es:0x08*4], INT08
	mov     word [es:0x09*4], INT09
	mov     word [es:0x12*4], INT12
	mov     word [es:0x16*4], INT16
	mov     word [es:0x1A*4], INT1A
	
;;;; BIOS DATA AREA ;;;;

	mov		di, 0x40
	mov		es, di
	mov		word [es:0x1A], 0x1E
	mov		word [es:0x1C], 0x1E
	
;;;; 8042 KEYBOARD CONTROLLER ;;;;

	mov     al, 0x60
	out     0x64, al
	mov     al, 0x61
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

;;;; LOAD BIOS ROM EXTENSIONS AND BOOT ;;;;

	call	0xC000:3 ; VGA BIOS
	call	0xC800:3 ; IDE BIOS
	int		0x19

;;;; TIMER INTERRUPT ;;;;

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
blank:
	iret

;;;; KEYBOARD INTERRUPT HANDLER ;;;;

INT09:
	push	ax
	push	bx
	push	es
	push	di
	push	ds
	in      al, 0x60
	mov		di, 0x40
	mov		es, di		
	mov		di, [es:0x1C]
	cmp		al, 0x1D                   ; <CTRL> down
	jne		not_1D
	or      [es:0x17], byte 00000100b	
	jmp		nobuff
not_1D:
	cmp		al, 0x9D                   ; <CTRL> up
	jne		not_9D
	and     [es:0x17], byte 11111011b	
	jmp		nobuff
not_9D:
	cmp		al, 0x38                   ; <ALT> down
	jne		not_38
	or      [es:0x17], byte 00001000b	
	jmp		nobuff
not_38:
	cmp		al, 0xB8                   ; <ALT> up
	jne		not_B8
	and     [es:0x17], byte 11110111b
	jmp		nobuff
not_B8:
	cmp		al, 0x2A                   ; <LSHIFT> down
	jne		not_2A
	or      [es:0x17], byte 00000010b
	jmp		nobuff
not_2A:
	cmp		al, 0xAA                   ; <LSHIFT> up
	jne		not_AA
	and     [es:0x17], byte 11111101b
	jmp		nobuff
not_AA:
	cmp		al, 0x36                   ; <RSHIFT> down
	jne		not_36
	or      [es:0x17], byte 00000001b	
	jmp		nobuff
not_36:
	cmp		al, 0xB6                   ; <RSHIFT> up
	jne		not_B6
	and     [es:0x17], byte 11111110b	
	jmp		nobuff
not_B6:	
	cmp		al, 0x7F
	ja		nobuff
	mov		bx, cs
	mov		ds, bx
	mov		ah, al
	mov		bx, ASCII
	xlatb
	mov		bl, [es:0x17]
	test	bl, 3
	jz		not_SHIFT
	sub		al, 0x20
not_SHIFT:
	mov		bl, [es:0x17]
	test	bl, 4
	jz		not_CTRL
	sub		al, 0x60
not_CTRL:
	mov		bl, [es:0x17]
	test	bl, 8
	jz		not_ALT
	xor		al, al
not_ALT:
	mov		word [es:di], ax
	add		di, 2
	cmp		di, 0x3E
	jb		not_yet_9
	sub		di, 32
not_yet_9:
	mov		[es:0x1C], di
nobuff:
	mov		al, 0x20
	out		0x20, al
	pop		ds
	pop		di
	pop		es
	pop		bx
	pop		ax
    iret

;;;; CONVENTIONAL MEMORY ;;;;

INT12:
	mov		ax, 640
	iret

;;;; BIOS KEYBOARD SERVICE ;;;;

INT16:
	push	ds
	push	bx
	mov		bx, 0x40
	mov		ds, bx
	or		ah, ah
	jz		KBD_read
	dec		ah
	jz		KBD_wait
	xor		ax, ax
KBD_exit:
	pop		bx
	pop		ds
	iret
KBD_read:
	cli
	mov		bx, [ds:0x1A]
	cmp		bx, [ds:0x1C]
	jnz		KBD_rea
	sti
	jmp		KBD_read
KBD_rea:
	mov		ax, [ds:bx]
	add		bx, 2
	cmp		bx, 0x3E
	jb		KBD_not_yet
	sub		bx, 32
KBD_not_yet:
	mov		[ds:0x1A], bx
	jmp		KBD_exit
KBD_wait:
	cli
	mov		bx, [ds:0x1A]
	cmp		bx, [ds:0x1C]
	mov		ax, [ds:bx]
	sti
	pop		bx
	pop		ds
	retf	2
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

INT1A:
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