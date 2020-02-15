;;;;
;;
;; This implements the bary minimum BIOS int 13h needed to boot MS-DOS 6.22
;;
;;;;

int13h:
	cmp	ah, 2
	je	_int13h_ah02
	cmp	ah, 8
	je	_int13h_ah08
	iret
_int13h_ah02:
	push	bx
	push	cx
	push	dx
	push	ds
	push	es
	push	si
	push	di

	push	bx                      ; offset
	push	ax                      ; sectors to process
	push	cx                      ; cylinder high = cl >> 6
	push	cx                      ; cylinder low
	push	cx                      ; sector
	push	ax                      ; sectors to process
	push	dx                      ; head

;;;;
;;
;; Primary ATA controller is at ports 1f0h - 1f7h
;;
;;;;

	mov	dx, 0x1f6
	pop	ax                      ; head
	shr	ax, 8
	and	al, 15
	or	al, 0xA0
	out	dx, al

	mov	dx, 0x1f2
	pop	ax                      ; sectors to process
	out	dx, al

	mov	dx, 0x1f3
	pop	ax                      ; sector
	and	al, 63
	out	dx, al

	mov	dx, 0x1f4
	pop	ax                      ; cylinder low
	shr	ax, 8
	out	dx, al

	mov	dx, 0x1f5
	pop	ax                      ; cylinder high
	shr	al, 6
	out	dx, al

	mov	dx, 0x1f7
	mov	al, 0x20                ; read (or 0x30 to write)
	out	dx, al

_int13h_processing:
	in	al, dx
	test	al, 8
	jz	_int13h_processing

	pop	ax
	pop	di
	mov	dx, 0x1f0
_int13h_proc:
	mov	cx, 256
	rep	insw
	dec	al
	cmp	al, 0
	jne	_int13h_proc

	pop	di
	pop	si
	pop	es
	pop	ds
	pop	dx
	pop	cx
	pop	bx
	xor	al, al
	iret

;;;;
;;
;; We have a disk with CHS of 259/16/63
;;
;;;;

_int13h_ah08:
	mov	ch, 3     ; +3
	mov	cl, 64    ; +256 (259 cylinders)
	add	cl, 63    ; sectors/track (63)
	mov	dh, 15    ; heads (16)
	mov	dl, 1
	iret
