%macro outp 2
	mov     dx, %1
	mov     al, %2
	out     dx, al
%endmacro

%macro delay 0
	mov     ah, 0x86
	xor     cx, cx
	mov     dx, 10
	int     0x15
%endmacro

	cpu     386

	db		0x55, 0xAA
	db		8192/512
	jmp		start

start:
	; WaitForKey();
	outp    0x279, 2
	outp    0xA79, 2

	; SendKey();
	outp    0x279, 0
	outp    0x279, 0
	outp    0x279, 0x6A
	outp    0x279, 0xB5
	outp    0x279, 0xDA
	outp    0x279, 0xED
	outp    0x279, 0xF6
	outp    0x279, 0xFB
	outp    0x279, 0x7D
	outp    0x279, 0xBE
	outp    0x279, 0xDF
	outp    0x279, 0x6F
	outp    0x279, 0x37
	outp    0x279, 0x1B
	outp    0x279, 0x0D
	outp    0x279, 0x86
	outp    0x279, 0xC3
	outp    0x279, 0x61
	outp    0x279, 0xB0
	outp    0x279, 0x58
	outp    0x279, 0x2C
	outp    0x279, 0x16
	outp    0x279, 0x8B
	outp    0x279, 0x45
	outp    0x279, 0xA2
	outp    0x279, 0xD1
	outp    0x279, 0xE8
	outp    0x279, 0x74
	outp    0x279, 0x3A
	outp    0x279, 0x9D
	outp    0x279, 0xCE
	outp    0x279, 0xE7
	outp    0x279, 0x73
	outp    0x279, 0x39

	; Wake(0);
	outp    0x279, 3
	outp    0xA79, 0
	delay

	; WriteCsn(1);
	outp    0x279, 6
	outp    0xA79, 1
	delay

	; Wake(1);
	outp    0x279, 3
	outp    0xA79, 1
	delay

	; WriteByte(7, 3);
	outp    0x279, 7
	outp    0xA79, 3

	; reg[0x30] = 0x01;
	outp    0x279, 0x30
	outp    0xA79, 0x01

	; reg[0x60] = 0x0170;
	outp    0x279, 0x61
	outp    0xA79, 0x70
	outp    0x279, 0x60
	outp    0xA79, 0x01

	; reg[0x62] = 0x0376;
	outp    0x279, 0x63
	outp    0xA79, 0x76
	outp    0x279, 0x62
	outp    0xA79, 0x03

	xor		di, di
	mov		es, di
	mov		di, cs
	mov		word [es:0x13*4+2], di
	mov		word [es:0x13*4], int13
	
	retf

int13:
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
	and		ebx, 63		               ; sector is now in ebx
	
	shr		cl, 6
	xchg	cl, ch
	and		ecx, 1023                  ; cylinder is now in cx
	
	xchg	dl, dh
	and		edx, 0x0F                  ; head is now in edx

	; LBA = (cylinder * TOTAL_HEADS + head) * TOTAL_SECTORS + sector - 1
	mov		eax, ecx                   ; eax = cylinder
	shl		eax, 4                     ; eax = eax * 16
	add		eax, edx                   ; eax = eax + heads
	mov		ecx, 63
	mul		ecx                        ; eax = eax * 63
	add		eax, ebx                   ; eax = eax + sector
	dec		eax                        ; eax = eax - 1
	mov		ebx, eax

	shr		eax, 24                    ; al = LBA[27:24]
	or		al, 0xE0
	mov     dx, 0x176
	out     dx, al	

	mov		ax, si                     ; # of sectors to read
	mov     dx, 0x172
	out     dx, al
	
	mov		ax, bx                     ; al = LBA[7:0]
	mov     dx, 0x173
	out     dx, al

	mov		eax, ebx
	shr		ax, 8                      ; al = LBA[15:8]
	mov     dx, 0x174
	out     dx, al
	
	mov		eax, ebx
	shr		eax, 16                    ; al = LBA[23:16]
	mov     dx, 0x175
	out		dx, al
	
	mov     al, 0x20                   ; read
	mov		dx, 0x177
	out     dx, al
	
	mov		bx, si                     ; # of sectors to read
r_sector_loop:
	in		al, dx
	test	al, 8
	jz		r_sector_loop
	and		dx, 0x1f0
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
	mov		di, ax                     ; # of sectors to read
		
	mov		bx, cx
	and		ebx, 63		               ; sector is now in ebx
	
	shr		cl, 6
	xchg	cl, ch
	and		ecx, 1023                  ; cylinder is now in cx
	
	xchg	dl, dh
	and		edx, 0x0F                  ; head is now in edx

	; LBA = (cylinder * TOTAL_HEADS + head) * TOTAL_SECTORS + sector - 1
	mov		eax, ecx                   ; eax = cylinder
	shl		eax, 4                     ; eax = eax * 16
	add		eax, edx                   ; eax = eax + heads
	mov		ecx, 63
	mul		ecx                        ; eax = eax * 63
	add		eax, ebx                   ; eax = eax + sector
	dec		eax                        ; eax = eax - 1
	mov		ebx, eax

	shr		eax, 24                    ; al = LBA[27:24]
	or		al, 0xE0
	mov     dx, 0x176
	out     dx, al	

	mov		ax, di                     ; # of sectors to read
	mov     dx, 0x172
	out     dx, al
	
	mov		ax, bx                     ; al = LBA[7:0]
	mov     dx, 0x173
	out     dx, al

	mov		eax, ebx
	shr		ax, 8                      ; al = LBA[15:8]
	mov     dx, 0x174
	out     dx, al
	
	mov		eax, ebx
	shr		eax, 16                    ; al = LBA[23:16]
	mov     dx, 0x175
	out		dx, al
	
	mov     al, 0x30                   ; write
	mov		dx, 0x177
	out     dx, al
	
	mov		bx, di                     ; # of sectors to write
w_sector_loop:
	or		dx, 7
	in		al, dx
	test	al, 8
	jz		w_sector_loop
	and		dx, 0x170
	mov		cx, 256
w_word_loop:
	lodsw
	out		dx, ax
	loop	w_word_loop
	or		dx, 7
w_wait_a:
	in		al, dx
	test	al, 0x80
	jnz		w_wait_a
	mov     ah, 0x86
	xor     cx, cx
	mov     dx, 1
	int     0x15
	mov		dx, 0x177
w_wait_b:
	in		al, dx
	test	al, 0x80
	jnz		w_wait_b
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
	mov		cx, 0xFFFF
	mov		dx, 0x0F01
	iret