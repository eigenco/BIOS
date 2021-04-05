	; debug
	; a
	; mov dl,80
	; mov ah,8
	; int 13
	; g =100 106

%macro waitcf 0
	mov     dx, 0x30E
%%wait_cf:
	in		al, dx
	test	al, 0x80
	jnz		%%wait_cf
%endmacro

	cpu     186

	db		0x55, 0xAA
	db		8192/512
	jmp		start

start:
	xor		di, di
	mov		es, di
	mov		di, cs
	mov		word [es:0x13*4+2], di
	mov		word [es:0x13*4], int13
	
	mov		al, 0x01
	mov		dx, 0x302
	out		dx, al                     ; 8-bit transfers
	
	mov     al, 0xEF
	mov     dx, 0x30E
	out		dx, al                     ; set feature
	
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
	and		bx, 63                     ; sector is now in ebx
		
	shr		cl, 6
	xchg	cl, ch                     ; cylinder is now in cx
	
	xchg	dl, dh
	and		dx, 0x0F

	mov		al, dl
	or		al, 0xA0
	mov     dx, 0x30C
	out     dx, al	

	mov		ax, si                     ; # of sectors to read
	mov     dx, 0x304
	out     dx, al
	
	mov		al, bl                     ; sector
	mov     dx, 0x306
	out     dx, al

	mov		al, cl                     ; lo(cylinder)
	mov     dx, 0x308
	out     dx, al
	
	mov		al, ch                     ; hi(cylinder)
	mov     dx, 0x30A
	out		dx, al
	
	mov     al, 0x20                   ; read
	mov		dx, 0x300+2*7
	out     dx, al
	mov		bx, si                     ; # of sectors to read
keep_reading:
	mov     cx, 256
	mov		dx, 0x300+2*7
wait_read_ready:
	in      al, dx
	test	al, 8
	jz      wait_read_ready
	mov     dx, 0x300
read_word:
	in		ax, dx
	stosw
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
	and		bx, 63                     ; sector is now in bx
		
	shr		cl, 6
	xchg	cl, ch                     ; cylinder is now in cx
	
	xchg	dl, dh
	and		dx, 0x0F                   ; head is now in dx

	mov		al, dl
	or		al, 0xA0
	mov     dx, 0x30C
	out     dx, al	

	mov		ax, di                     ; # of sectors to read
	mov     dx, 0x304
	out     dx, al
	
	mov		al, bl                     ; sector
	mov     dx, 0x306
	out     dx, al

	mov		al, cl                     ; lo(cylinder)
	mov     dx, 0x308
	out     dx, al
	
	mov		al, ch                     ; hi(cylinder)
	mov     dx, 0x30A
	out		dx, al	

	mov     al, 0x30                   ; write
	mov		dx, 0x300+2*7
	out     dx, al
	mov		bx, di                     ; # of sectors to read
keep_writing:
	mov     cx, 256
	mov		dx, 0x300+2*7
wait_write_ready:
	in      al, dx
	test	al, 8
	jz      wait_write_ready
	mov     dx, 0x300
write_word:
	lodsw
	out		dx, ax
	loop	write_word
	dec     bl
	waitcf
	mov     al, 0xE7                   ; cache flush
	mov     dx, 0x30E
	out		dx, al
	waitcf
	jnz     keep_writing               ; until sectors are written
	
	pop		si
	pop     di
	pop     dx
	pop     cx
	pop		bx
	pop		ax
	pop		ds
	iret
disk_type: ; Sectors: 63, Heads: 16, Cylinders: 256
	mov		cx, 0xFF3F
	mov		dx, 0x0F01
	iret