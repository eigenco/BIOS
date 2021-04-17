        org     0x10000
        bits    32
        
        mov     ax, 8
        mov     es, ax

        ; place a "yellow exclamation mark" at physical address 0x300000
        mov     al, '!'
        mov     [0x300000], al
        mov     al, 14
        mov     [0x300001], al

;;;; map first physical 4 MB -> identical virtual addresses ;;;;

        mov     eax, 0
        mov     ebx, 0
        mov     cx, 1024
fill_table:
        or      ebx, 3
        mov     [0x201000+eax], ebx
        add     eax, 4
        add     ebx, 4096
        loop    fill_table

;;;; map physical 0x300000 -> virtual 0xd0000 ;;;;

        mov     eax, 0xd0000/4096*4
        mov     [0x201000+eax], dword 0x300000|3

;;;; enable paging ;;;;        

        mov     ebx, 0x201000|3         ; 1st page table at
        mov     [0x200000], ebx         ; 0x201000-0x201FFF

        mov     eax, 0x200000           ; paging directory at
        mov     cr3, eax                ; 0x200000-0x200FFF
        mov     eax, cr0
        or      eax, 0x80000000         ; enable paging
        mov     cr0, eax

;;;; interrupt descriptor table ;;;;

        lidt    [idtinfo]

        mov     eax, isr8
        mov     [idt+8*8], ax
        mov     word [idt+8*8+2], 8
        mov     word [idt+8*8+4], 0x0e00
        shr     eax, 16
        mov     [idt+8*8+6], ax

        mov     eax, isr9
        mov     [idt+9*8], ax
        mov     word [idt+9*8+2], 8
        mov     word [idt+9*8+4], 0x0e00
        shr     eax, 16
        mov     [idt+9*8+6], ax

        mov     eax, isrD
        mov     [idt+0x0d*8], ax
        mov     word [idt+0x0d*8+2], 8
        mov     word [idt+0x0d*8+4], 0x0e00
        shr     eax, 16
        mov     [idt+0x0d*8+6], ax

        sti

;;;; test 0x300000 -> 0xd0000 mapping ;;;;

        mov     ebx, 0xd0000
        mov     ax, [ebx]
        mov     ebx, 0xb8000+160
        mov     word [ebx], ax

        mov     dx, 0x330
        mov     al, 0
        out     dx, al

        jmp     $

idt:                                    
        times   256*8 db 0               ; 64 bits per entry
idtinfo:
        dw      idtinfo - idt - 1
        dd      idt
isr8:
        mov     al, 0x20
        out     0x20, al
        iret
isr9:
        in      al, 0x60
        mov     ax, 8
        mov     es, ax
        mov     eax, [pos]
        mov     byte [eax+2], '*'
        mov     byte [eax+3], 15
        add     eax, 2
        mov     [pos], eax
        mov     eax, 0xb800
        mov     byte [eax+0], ' '
        mov     byte [eax+1], 7
        mov     al, 0x20
        out     0x20, al
        iret
pos:
        dd      0xb8000
isrD:
        mov     ax, 8
        mov     es, ax
        mov     byte [eax+0], '!'
        mov     byte [eax+1], 14
        iret
