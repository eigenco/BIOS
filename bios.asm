; System BIOS at F000:0000 - F000:FFFF
;
; What works
;  MS-DOS 6.22
;  Supaplex
;  Prince of persia
;  Keen 4
;  Eye of the Beholder 2
;  Space Quest 3

%define ATA 0x1F0

	cpu     186

start:

;;;; SETUP INTERRUPT HANDLERS ;;;;

	cli
	xor     di, di
	mov     es, di
	mov     cx, 0x1F
blints:
	mov     ax, blank
	stosw
	mov     ax, cs
	stosw
	loop	blints
	mov     word [es:0x08*4], INT8     ; TIMER HANDLER
	mov     word [es:0x09*4], INT9     ; KEYBOARD HANDLER
	mov     word [es:0x12*4], INT12    ; MEMORY SERVICE
	mov     word [es:0x13*4], INT13    ; DISK SERVICE
	mov     word [es:0x16*4], INT16    ; KEYBOARD SERVICE
	mov     word [es:0x1A*4], INT1A    ; TIME SERVICE

;;;; BIOS DATA AREA ;;;;

	mov		di, 0x40
	mov		es, di
	mov		word [es:0x1A], 0x1E
	mov		word [es:0x1C], 0x1E
	
;;;; IBM COMPATIBLE STACK ;;;;

	mov		sp, 0x30
	mov		ss, sp
	mov		sp, 0x0100
	
;;;; 8259 PROGRAMMABLE INTERRUPT CONTROLLER ;;;;

	mov		al, 16
	out		0x20, al
	mov		al, 8
	out		0x21, al
	xor		al, al	
	out		0x21, al
	xor		al, al
	out		0x21, al
	
;;;; 8253 TIMER ;;;;

	mov		al, 0x36
	out		0x43, al
	xor		al, al   ; 18.2 Hz
	out		0x40, al
	out		0x40, al
	
;;;; 8042 KEYBOARD CONTROLLER ;;;;

	mov     al, 0xF0
	out     0x60, al
	mov     al, 1
	out     0x60, al
	
;;;; LOAD ROM EXTENSIONS ;;;;

	call	0xC000:3 ; VGA BIOS
	
	xor     di, di
	mov     es, di
	mov		word [es:0x10*4+2], cs
	mov     word [es:0x10*4], INT10    ; VIDEO SERVICE

;;;; LOAD BOOT SECTOR ;;;;
	
	xor		ax, ax
	mov		es, ax
	mov		ds, ax
	mov     ax, 0x0201
	mov     bx, 0x7C00
	mov     cx, 1
	mov     dx, 0x0080
	int     0x13
	
	jmp     0:0x7C00

;;;; VIDEO INTERRUPT HANDLER ;;;;

INT10:
	cmp		ah, 0      ; mode
	je		oldint
	cmp		ah, 2      ; set cursor position
	je		oldint
	cmp		ah, 3      ; get cursor position
	je		oldint	
	cmp		ah, 6      ; scroll up
	je		oldint
	cmp		ah, 8      ; read attribute/character
	je		oldint
	cmp		ah, 9      ; write attribute/character
	je		oldint	
	cmp		ah, 0x0E   ; teletype
	je		oldint
	cmp		ah, 0x0F   ; current video state
	je		oldint
	cmp		ah, 0x12
	je		AH12
	cmp		ah, 0x15
	je		AH15
	cmp		ah, 0x1A
	je		AH1A
	iret
AH12:
	mov		bx, 3       ; fucks up MS-DOS edit (is needed for keen 4)
	iret
AH15:
	mov		ah, byte 80 ; columns
	mov		al, byte 3  ; mode
	mov     bh, 0       ; page
	iret
AH1A:
	mov		al, 0x1A
	mov		bx, 8
	iret
oldint:
	pushf
	call	0xC000:0x10B7
	iret

;;;; TIMER INTERRUPT HANDLER ;;;;

INT8:
	push	ds
	push	ax
	mov		ax, 0x40
	mov		ds, ax
	clc
	adc		word [ds:0x6C], 1
	adc		word [ds:0x6E], 0
	int		0x1C ; normally just iret
	mov		al, 0x20
	out		0x20, al
	pop		ax
	pop		ds
	iret

;;;; BIOS CONVENTIONAL MEMORY SERVICE ;;;;

INT12:
	mov		ax, 640
	iret

;;;; BIOS SYSTEM CLOCK COUNTER SERVICE ;;;;

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

;;;; KEYBOARD INTERRUPT HANDLER ;;;;

INT9:
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
	mov     al, 1
	out     0x64, al
	mov		al, 0x20
	out		0x20, al
	
	pop		ds
	pop		di
	pop		es
	pop		bx
	pop		ax
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
	jb		not_yet_16
	sub		bx, 32
not_yet_16:
	mov		[ds:0x1A], bx
	jmp		KBD_exit
KBD_wait:
	cli
	mov		bx, [ds:0x1A]       ; if [40:1A] != [40:1C]
	cmp		bx, [ds:0x1C]       ; there is a key waiting in the buffer
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

;;;; BIOS DISK SERVICE ;;;;

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
	
	;;;;;;;;
	
	mov		bx, cx
	and		bx, 63		               ; sector is now in bx
	
	shr		cl, 6
	xchg	cl, ch                     ; cylinder is now in cx
	
	mov		dl, dh
	and		dx, 0x0F                   ; head is now in dx

	; LBA = (cylinder * TOTAL_HEADS + head) * SECTORS_PER_CYL + sector - 1
	
	mov		ax, cx                     ; ax = cylinder
	shl     ax, 4                      ; ax = ax * 16
	add     ax, dx                     ; ax = ax + head
	mov     dx, 63
	mul     dx                         ; dx:ax = ax * 63
	dec     bx
	clc
	adc     ax, bx
	adc     dx, 0
	mov     bx, ax                     ; dx:ax = dx:ax + sector - 1	
	mov     cx, dx

	mov		al, ch                     ; al = LBA[27:24]
	or		al, 0xE0
	mov     dx, ATA+6
	out     dx, al	

	mov		ax, si                     ; # of sectors to read
	mov     dx, ATA+2
	out     dx, al
	
	mov		al, bl                     ; al = LBA[7:0]
	mov     dx, ATA+3
	out     dx, al

	mov		al, bh                     ; al = LBA[15:8]
	mov     dx, ATA+4
	out     dx, al
	
	mov     al, cl                     ; al = LBA[23:16]
	mov     dx, ATA+5
	out		dx, al
	
	;;;;;;;;
	
	mov     al, 0x20                   ; read
	mov		dx, ATA+7
	out     dx, al
	
	mov		bx, si                     ; # of sectors to read
r_sector_loop:
	in		al, dx
	test	al, 8
	jz		r_sector_loop
	and		dx, 0xFF0
	mov		cx, 256
r_word_loop:
	in		ax, dx
	stosw
	loop	r_word_loop
	or		dx, 7
	dec		bl
	jnz		r_sector_loop
	
	pop		si
	pop     di
	pop     dx
	pop     cx
	pop		bx
	pop		ax
	iret

write_disk:
	push	ds
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	push	si
	
	mov		si, es
	mov		ds, si
	mov     si, bx                     ; destination = es:bx
	mov		di, ax                     ; # of sectors to write

	;;;;;;;;
	
	mov		bx, cx
	and		bx, 63		               ; sector is now in bx
	
	shr		cl, 6
	xchg	cl, ch                     ; cylinder is now in cx
	
	mov		dl, dh
	and		dx, 0x0F                   ; head is now in dx

	; LBA = (cylinder * TOTAL_HEADS + head) * SECTORS_PER_CYL + sector - 1
	
	mov		ax, cx                     ; ax = cylinder
	shl     ax, 4                      ; ax = ax * 16
	add     ax, dx                     ; ax = ax + head
	mov     dx, 63
	mul     dx                         ; dx:ax = ax * 63
	dec     bx
	clc
	adc     ax, bx
	adc     dx, 0
	mov     bx, ax                     ; dx:ax = dx:ax + sector - 1	
	mov     cx, dx

	mov		al, ch                     ; al = LBA[27:24]
	or		al, 0xE0
	mov     dx, ATA+6
	out     dx, al	

	mov		ax, di                     ; # of sectors to write
	mov     dx, ATA+2
	out     dx, al
	
	mov		al, bl                     ; al = LBA[7:0]
	mov     dx, ATA+3
	out     dx, al

	mov		al, bh                     ; al = LBA[15:8]
	mov     dx, ATA+4
	out     dx, al
	
	mov     al, cl                     ; al = LBA[23:16]
	mov     dx, ATA+5
	out		dx, al
	
	;;;;;;;;
	
	mov     al, 0x30                   ; write
	mov		dx, ATA+7
	out     dx, al
	
	mov		bx, di                     ; # of sectors to write
w_sector_loop:
	in		al, dx
	test	al, 8
	jz		w_sector_loop
	and		dx, 0xFF0
	mov		cx, 256
w_word_loop:
	lodsw
	out		dx, ax
	loop	w_word_loop
	or		dx, 7
	dec		bl
	jnz		w_sector_loop
	
	pop		si
	pop     di
	pop     dx
	pop     cx
	pop		bx
	pop		ax
	pop		ds
	iret
disk_type:
    ; 1024 cylinders, 16 heads, 63 sectors per cylinder
	mov     cx, 0xFF3F
	mov     dx, 0x0F01
blank:
	iret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	times	0xFFF0-($-$$) db 0xFF

	jmp     0xF000:start

	dw		0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF
	db		0xFF