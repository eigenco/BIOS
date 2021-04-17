        org     0x7c00

        mov     ah, 0x00
        mov     dl, 0x80
        int     0x13

        mov     bx, 0x1000
        mov     es, bx
        mov     bx, 0

        mov     ax, 0x020F              ; load 15 sectors
        mov     cx, 2                   ; starting from 2nd sector
        mov     dx, 0                   ; to addr 0x10000
        int     0x13

        cli

        mov     eax, cs
        shl     eax, 4
        add     eax, gdt
        mov     [gdtinfo+2], eax        ; update gdt address

        lgdt    [gdtinfo]               ; load global descriptor table

        mov     eax, cr0
        or      al, 1                   ; enable protected mode
        mov     cr0, eax

        db      0x66
        db      0xEA
        dd      0x10000                 ; kernel address
        dw      8
       
gdt:
        dd      0, 0
        db      0xff, 0xff, 0, 0, 0, 0x9a, 0xcf, 0
        db      0xff, 0xff, 0, 0, 0, 0x92, 0xcf, 0
gdtinfo:
        dw      $ - gdt - 1
        dd      0

        times   510 - ($-$$) nop
        dw      0xaa55

        incbin  "kernel.bin"

        times   512*1440-($-$$) db 0xff ; make this a 720k floppy
