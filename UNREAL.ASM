        org     0x100

        cli
        mov     eax, cs
        shl     eax, 4
        add     eax, gdt
        mov     [gdtinfo+2], eax
        lgdt    [gdtinfo]
        mov     eax, cr0
        or      al, 1
        mov     cr0, eax
        mov     bx, 8
        mov     ds, bx
        mov     es, bx
        and     al, 0xfe
        mov     cr0, eax

        mov     ax, 0
        mov     ds, ax
        mov     es, ax
        mov     eax, 0xb8000
        mov     [eax+0], byte '!'
        mov     [eax+1], byte 15

        int     0x20
gdt:
        dd      0, 0
        db      0xff, 0xff, 0, 0, 0, 10010010b, 11001111b, 0
gdtinfo:
        dw      $ - gdt - 1
        dd      0
