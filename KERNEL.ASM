		bits    32
        org     0x10000
        
        mov     ax, 16
        mov     es, ax
        mov     ds, ax
        mov     ss, ax
        mov     esp, 0x80000

        ; place a "yellow P" at physical address 0x300000
        mov     al, 'P'
        mov     [0x300000], al
        mov     al, 14
        mov     [0x300001], al

;;;; map first physical 4 MB -> identical virtual addresses ;;;;

        mov     eax, 0
        mov     ebx, 0
        mov     cx, 1024
fill_table:
        or      ebx, 7
        mov     [0x201000+eax], ebx
        add     eax, 4
        add     ebx, 4096
        loop    fill_table

;;;; map physical 0x300000 -> virtual 0xd0000 ;;;;

        mov     eax, 0xd0000/4096*4
        mov     [0x201000+eax], dword 0x300000|7

;;;; enable paging ;;;;        

        mov     ebx, 0x201000|7         ; 1st page table at
        mov     [0x200000], ebx         ; 0x201000-0x201FFF

        mov     eax, 0x200000           ; paging directory at
        mov     cr3, eax                ; 0x200000-0x200FFF
        mov     eax, cr0
        or      eax, 0x80000001         ; enable paging
        mov     cr0, eax

;;;; interrupt descriptor table ;;;;

        lidt    [idtinfo]

        mov     eax, isr
        mov     [idt+0x49*8], ax
        mov     word [idt+0x49*8+2], 8
        mov     word [idt+0x49*8+4], 0x8e00
        shr     eax, 16
        mov     [idt+0x49*8+6], ax

;;;; test 0x300000 -> 0xd0000 mapping ;;;;

        mov     ebx, 0xd0000
        mov     ax, [ebx]
        mov     ebx, 0xb8004
        mov     word [ebx], ax

        int     0x49

;;;; enter V86 ;;;;
enter_v86:
		
        xor     ebx, ebx
        push    ebx    ; gs
        push    ebx    ; fs
        push    ebx    ; ds
        push    ebx    ; es
        push    0      ; ss
        push    0      ; sp
        push	dword 1<<17
        push    0      ; cs
        push    0x7e00 ; ip
        iret

idt:                                    
        times   256*8 db 0               ; 64 bits per entry
idtinfo:
        dw      idtinfo - idt - 1
        dd      idt
isr:
        mov     ax, 16
        mov     es, ax
        mov     eax, 0xb8000
        mov     byte [eax+2], 'I'
        mov     byte [eax+3], 15
        iret