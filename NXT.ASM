	cpu     8086

	times   0xE000-($-$$) db 0xFF

start:
	cli

	mov     ax, 0x40
	mov     ds, ax
	mov     word [ds:0x72], 0

	xor     al, al
	OUT     81h,AL                          ; dma page reg, chan 2
	OUT     82h,AL                          ; dma page reg, chan 3
	OUT     83h,AL                          ; dma page reg, chan 0,1
	OUT     0Dh,AL                          ; Stop DMA on 8237 chip
	MOV     AL,01011000b                    ; Refresh auto-init dummy read
	OUT     0Bh,AL                          ; ...on channel 0 of DMA chip
	MOV     AL,01000001b                    ; Block verify
	OUT     0Bh,AL                          ; ...on channel 1 of DMA chip
	MOV     AL,01000010b                    ; Block verify
	OUT     0Bh,AL                          ; ...on channel 2 of DMA chip
	MOV     AL,01000011b                    ; Block verify
	OUT     0Bh,AL                          ; ...on channel 3 of DMA chip
	MOV     AL,0FFh                         ; Refresh byte count
	OUT     1,AL                            ; ...send lo order
	OUT     1,AL                            ; ...send hi order
	MOV     AL,0                            ; Initialize 8237 command reg
	OUT     8,AL                            ; ...with zero
	OUT     0Ah,AL                          ; Enable DMA on all channels
	MOV     AL,00110110b                    ; Set up 8253 timer chip
	OUT     43h,AL                          ; ...chan 0 is time of day
	MOV     AL,0                            ; Request a divide by
	OUT     40h,AL                          ; ...65536 decimal
	OUT     40h,AL                          ; ...0000h or 18.2 tick/sec

	mov     ax, 30h                         ; IBM-compatible stack
	mov     ss, ax
	mov     sp, 100h

	; PIC
	mov     al, 0x13
	out     0x20, al
	mov     al, 8
	out     0x21, al
	mov     al, 9
	out     0x21, al
	mov     al, 0xFF
	out     0x21, al

	xor     ax, ax
	mov     es, ax
	mov     cx, 8
clear:
	mov     bx, cx
	shl     bx, 1
	shl     bx, 1
	mov     word [es:bx], blank
	add     bx, 2
	mov     word [es:bx], 0xF000
	inc     cx
	cmp     cx, 0x1f
	jne     clear

	mov     word [es:4*0x08+2], 0xF000
	mov     word [es:4*0x08], INT_8
	mov     word [es:4*0x09+2], 0xF000
	mov     word [es:4*0x09], INT_9
	mov     word [es:4*0x0E+2], 0xF000
	mov     word [es:4*0x0E], INT_E
	mov     word [es:4*0x10+2], 0xF000
	mov     word [es:4*0x10], INT_10
	mov     word [es:4*0x12+2], 0xF000
	mov     word [es:4*0x12], INT_12
	mov     word [es:4*0x13+2], 0xF000
	mov     word [es:4*0x13], INT_13
	mov     word [es:4*0x16+2], 0xF000
	mov     word [es:4*0x16], INT_16
	mov     word [es:4*0x1A+2], 0xF000
	mov     word [es:4*0x1A], INT_1A
	mov     word [es:4*0x1D+2], 0xF000
	mov     word [es:4*0x1D], INT_1D

	sti

	mov     al, 01001000b                   ; enable
	out     61h, al                         ; keyboard

	mov     byte [DS:1Ah],1Eh               ; buffer head pointer
	mov     byte [DS:1Ch],1Eh               ; buffer tail pointer
	mov     byte [DS:80h],1Eh               ; buffer start
	mov     byte [DS:82h],3Eh               ; buffer end

	mov     ax, 3
	int     0x10

	mov     al, 10111100b
	out     21h, al

	xor     ax, ax
	mov     ds, ax
	mov     word [ds:0x78], INT_1E
	mov     [ds:0x7A], cs

	mov     ah, 0
	int     0x13

	mov     ax, 0x0201
	xor     dx, dx
	mov     es, dx
	mov     bx, 0x7C00
	mov     cx, 1
	int     0x13
	jmp     0:0x7C00

; ******** ******** ******** ******** ******** ******** ******** ********

INT_16:
	STI                                     ; Keyboard bios services
	PUSH    DS
	PUSH    BX
	MOV     BX,40h
	MOV     DS,BX                           ; Load work segment
	OR      AH,AH
	JZ      KPD_RD                          ; Read keyboard buffer, AH=0
	DEC     AH
	JZ      KPD_WT                          ; Set Z if char  ready, AH=1
	DEC     AH
	JZ      KPD_SH                          ; Return shift in AL  , AH=2

KPD_XT: POP     BX                              ; Exit INT_16 keypad service
	POP     DS
	IRET

KPD_RD: CLI                                     ; No interrupts, alters buffer
	MOV     BX,[1Ah]                        ;  ...point to buffer head
	CMP     BX,[1Ch]                        ; If not equal to buffer tail
	JNZ     KPD_R1                          ;  ...char waiting to be read
	STI                                     ; Else allow interrupts
	JMP     KPD_RD                          ;  ...wait for him to type

KPD_R1: MOV     AX,[BX]                         ; Fetch the character
	INC     BX                              ;  ...point to next character
	INC     BX                              ;  ...char = scan code + shift
	MOV     [DS:1Ah],BX                     ; Save position in head
	CMP     BX,[82h]                        ;  ...buffer overflowed?
	JNZ     KPD_XT                          ;  ...no, done
	MOV     BX,[80h]                        ; Else reset to point at start
	MOV     [1Ah],BX                        ;  ...and correct head position
	JMP     KPD_XT

KPD_WT: CLI                                     ; No interrupts, critical code
	MOV     BX,[1Ah]                        ;  ...point to buffer head
	CMP     BX,[1Ch]                        ;  ...equal buffer tail?
	MOV     AX,[BX]                         ;     (fetch, look ahead)
	STI                                     ; Enable interrupts
	POP     BX
	POP     DS
	RETF    2                               ; Do IRET, preserve flags

KPD_SH: MOV     AL,[17h]                        ; Read keypad shift status
	JMP     KPD_XT

ASCII:  db      000h,037h,02Eh,020h             ; Scan -> Ascii.  Sign bit set
	db      02Fh,030h,031h,021h             ;  ...if further work needed
	db      032h,033h,034h,035h
	db      022h,036h,038h,03Eh
	db      011h,017h,005h,012h
	db      014h,019h,015h,009h
	db      00Fh,010h,039h,03Ah
	db      03Bh,084h,001h,013h
	db      004h,006h,007h,008h
	db      00Ah,00Bh,00Ch,03Fh
	db      040h,041h,082h,03Ch
	db      01Ah,018h,003h,016h
	db      002h,00Eh,00Dh,042h
	db      043h,044h,081h,03Dh
	db      088h,02Dh,0C0h,023h
	db      024h,025h,026h,027h
	db      028h,029h,02Ah,02Bh
	db      02Ch,0A0h,090h

NOALFA: db      032h,036h,02Dh,0BBh             ; Non-Alphabetic secondary
	db      0BCh,0BDh,0BEh,0BFh             ;  ...translation table
	db      0C0h,0C1h,0C2h,0C3h
	db      0C4h,020h,031h,033h
	db      034h,035h,037h,038h
	db      039h,030h,03Dh,01Bh
	db      008h,05Bh,05Dh,00Dh
	db      05Ch,02Ah,009h,03Bh
	db      027h,060h,02Ch,02Eh
	db      02Fh

CTRLUP: db      040h,05Eh,05Fh,0D4h             ; CTRL uppercase secondary
	db      0D5h,0D6h,0D7h,0D8h             ;  ...translation table
	db      0D9h,0DAh,0DBh,0DCh             ;  ...for non-ASCII control
	db      0DDh,020h,021h,023h
	db      024h,025h,026h,02Ah
	db      028h,029h,02Bh,01Bh
	db      008h,07Bh,07Dh,00Dh
	db      07Ch,005h,08Fh,03Ah
	db      022h,07Eh,03Ch,03Eh
	db      03Fh

CTRLLO: db      003h,01Eh,01Fh,0DEh             ; CTRL lowercase secondary
	db      0DFh,0E0h,0E1h,0E2h             ;  ...translation table
	db      0E3h,0E4h,0E5h,0E6h             ;  ...for non-ASCII control
	db      0E7h,020h,005h,005h
	db      005h,005h,005h,005h
	db      005h,005h,005h,01Bh
	db      07Fh,01Bh,01Dh,00Ah
	db      01Ch,0F2h,005h,005h
	db      005h,005h,005h,005h
	db      005h

ALTKEY: db      0F9h,0FDh,002h,0E8h             ; ALT key secondary
	db      0E9h,0EAh,0EBh,0ECh             ;  ...translation table
	db      0EDh,0EEh,0EFh,0F0h
	db      0F1h,020h,0F8h,0FAh
	db      0FBh,0FCh,0FEh,0FFh
	db      000h,001h,003h,005h
	db      005h,005h,005h,005h
	db      005h,005h,005h,005h
	db      005h,005h,005h,005h
	db      005h

NUMPAD: db      '789-456+1230.'                 ; Keypad secondary tralsator

NUMCTR: db      0F7h,005h,004h,005h             ; Numeric keypad CTRL sec.
	db      0F3h,005h,0F4h,005h             ;  ...translation table
	db      0F5h,005h,0F6h,005h
	db      005h

NUMUPP: db      0C7h,0C8h,0C9h,02Dh             ; Numeric keypad SHIFT sec.
	db      0CBh,005h,0CDh,02Bh             ;  ...translation table
	db      0CFh,0D0h,0D1h,0D2h
	db      0D3h

; ******** ******** ******** ******** ******** ******** ******** ********

INT_9:                                          ; keyboard interrupt
	STI
	PUSH    AX
	PUSH    BX
	PUSH    CX
	PUSH    DX
	PUSH    SI
	PUSH    DI
	PUSH    DS
	PUSH    ES
	CLD
	MOV     AX,40h
	MOV     DS,AX
	IN      AL,60h                          ; Read the scan code data
	PUSH    AX                              ;  ...save it
	IN      AL,61h                          ; Get control port status
	PUSH    AX                              ;  ...save it
	OR      AL,10000000b                    ; Set "latch" bit to
	OUT     61h,AL                          ;  ...acknowledge data
	POP     AX                              ; Restore control status
	OUT     61h,AL                          ;  ...to enable keyboard
	POP     AX                              ;  ...restore scan code
	MOV     AH,AL                           ; Save copy of scan code
	CMP     AL,11111111b                    ;  ...check for overrun
	JNZ     KY_01                           ;  ...no, OK
	JMP     KY_BEP                          ; Else beep bell on overrun

KY_EOI: MOV     AL,20h                          ; Send end_of_interrupt code
	OUT     20h,AL                          ;  ...to 8259 interrupt chip

KY_XIT: POP     ES                              ; Exit the interrupt
	POP     DS
	POP     DI
	POP     SI
	POP     DX
	POP     CX
	POP     BX
	POP     AX
	IRET

KY_01:  AND     AL,01111111b                    ; Valid scan code, no break
	CMP     AL,46h
	JBE     KY_02
	JMP     KY_CT8

KY_02:  MOV     BX,ASCII                        ; Table for ESC thru Scroll Lck
	cs XLATb
	OR      AL,AL                           ; Sign flags "Shift" type key
	JS      KY_FLG                          ;  ...shift,caps,num,scroll etc
	OR      AH,AH                           ; Invalid scan code?
	JS      KY_EOI                          ;  ...exit if so
	JMP     short   KY_ASC                  ; Else normal character

KY_FLG: AND     AL,01111111b                    ; Remove sign flag bit
	OR      AH,AH                           ;  ...check scan code
	JS      KY_SUP                          ;  ...negative, key released
	CMP     AL,10h                          ; Is it a "toggle" type key?
	JNB     KY_TOG                          ;  ...yes
	OR      [DS:17h],AL                     ; Else set bit in "flag" byte
	JMP     KY_EOI                          ;  ...and exit

KY_TOG: TEST    Byte [DS:17h],00000100b         ; Control key pressed?
	JNZ     KY_ASC                          ;  ...yes, skip
	TEST    AL,[DS:18h]                     ; Else check "CAPS, NUM, SCRL"
	JNZ     KY_EOI                          ;  ...set, invalid, exit
	OR      [DS:18h],AL                     ; Show set in "flag_1" byte
	XOR     [DS:17h],AL                     ;  ...flip bits in "flag" byte
	JMP     KY_EOI

KY_SUP: CMP     AL,10h                          ; Released - is it "toggle" key
	JNB     KY_TUP                          ;  ...skip if so
	NOT     AL                              ; Else form two's complement
	AND     [DS:17h],AL                     ;  ...to do BIT_CLEAR "flags"
	CMP     AL,11110111b                    ; ALT key release special case
	JNZ     KY_EOI                          ;  ...no, exit
	MOV     AL,[DS:19h]                     ; Else get ALT-keypad character
	MOV     AH,0                            ;  ...pretend null scan code
	MOV     [DS:19h],AH                     ;  ...zero ALT-keypad character
	CMP     AL,AH                           ; Was there a valid ALT-keypad?
	JZ      KY_EOI                          ;  ...no, ignore, exit
	JMP     KY_NUL                          ; Else stuff it in ASCII buffer

KY_TUP: NOT     AL                              ; Form complement of toggle key
	AND     [DS:18h],AL                     ;  ...to do BIT_CLEAR "flag_1"
	JMP     KY_EOI

KY_ASC: TEST    Byte [DS:18h],00001000b         ; Scroll lock pressed?
	JZ      KY_NLK                          ;  ...no
	CMP     AH,45h                          ; Is this a NUM LOCK character?
	JZ      KY_03                           ;  ...no
	AND     Byte [DS:18h],11110111b         ; Else clear bits in "flag_1"

KY_03:  JMP     KY_EOI                          ;  ...and exit

KY_NLK: TEST    Byte [DS:17h],00001000b         ; ALT key pressed?
	JNZ     KY_ALT                          ;  ...yes
	TEST    Byte [DS:17h],00000100b         ; CTRL key pressed?
	JNZ     KY_CTL                          ;  ...yes
	TEST    Byte [DS:17h],00000011b         ; Either shift key pressed?
	JNZ     KSHIFT                          ;  ...yes

KY_LC:  CMP     AL,1Ah                          ; Alphabetic character?
	JA      KY_LC1                          ;  ...no
	ADD     AL,'a'-1                        ; Else add lower case base
	JMP     KY_COM

KY_LC1: MOV     BX,NOALFA                       ; Non-alphabetic character
	SUB     AL,20h
	cs XLATb
	JMP     KY_COM

KY_ALT: CMP     AL,1Ah                          ; Control key pressed?
	JA      KY_AGN                          ;  ...no, skip
	MOV     AL,0                            ; Else illegal key press
	JMP     KY_BFR

KY_AGN: MOV     BX,ALTKEY                       ; Load ALT key translation
	SUB     AL,20h                          ;  ...bias to printing char.
	cs XLATb
	JMP     KY_COM

KY_CTL: CMP     AH,46h                          ; Scroll lock key?
	JNZ     KY_CT1                          ;  ...no, skip
	MOV     Byte [DS:71h],10000000b         ; Else CTRL-"Scroll" = break
	MOV     AX,[DS:80h]                     ;  ...get key buffer start
	MOV     [DS:1Ch],AX                     ;  ...get key tail to start
	MOV     [DS:1Ah],AX                     ;  ...get key head to start
	INT     1Bh                             ; Issue a "Break" interrupt
	SUB     AX,AX
	JMP     KY_CO2

KY_CT1: CMP     AH,45h                          ; Num lock key?
	JNZ     KY_CT2                          ;  ...no, skip
	OR      Byte [DS:18h],00001000b         ; Else show scroll lock
	MOV     AL,20h                          ;  ...send end_of_interrupt
	OUT     20h,AL                          ;  ...to 8259 int. controller
	CMP     Byte [DS:49h],7                 ; Monochrome monitor?
	JZ      KY_POL                          ;  ...yes, skip
	MOV     DX,3D8h                         ; Else reset mode
	MOV     AL,[DS:65h]                     ;  ...for the
	OUT     DX,AL                           ;  ...CGA color card

KY_POL: TEST    Byte [DS:18h],00001000b         ; Wait for him to type
	JNZ     KY_POL                          ;  ...not yet
	JMP     KY_XIT

KY_CT2: CMP     AH,3                            ; Is it a Control @ (null) ?
	JNZ     KY_CT3                          ;  ...no
	MOV     AL,0                            ; Else force a null

KY_CT4: JMP     KY_BFR                          ;  ...save in buffer

KY_CT3: CMP     AL,1Ah                          ; Is it a control character?
	JBE     KY_CT4                          ;  ...yes
	MOV     BX,CTRLLO                       ; Else non-ascii control
	SUB     AL,20h                          ;  ...lower case
	cs XLATb
	JMP     KY_COM

KSHIFT: CMP     AH,37h                          ; Print_Screen pressed?
	JNZ     KY_CT5
	MOV     AL,20h                          ; Yes, send end_of_interrupt
	OUT     20h,AL                          ;  ...to 8259 interrupt chip
	INT     5                               ; Request print_screen service
	JMP     KY_XIT                          ;  ...and exit key service

KY_CT5: CMP     AL,1Ah                          ; Alphabetic char?
	JA      KY_CT6                          ;  ...no
	ADD     AL,'A'-1                        ; Yes, add base for alphabet
	JMP     KY_COM

KY_CT6: MOV     BX,CTRLUP                       ; Non-ascii control
	SUB     AL,20h                          ;  ...upper case
	cs XLATb
	JMP     KY_COM

KY_CT8: SUB     AL,47h                          ; Keypad key, convert origin
	MOV     BL,[DS:17h]                     ;  ...get "flag" byte
	TEST    BL,00001000b                    ; Look for ALT keypad entry
	JNZ     KB_NUM                          ;  ...do special entry thing
	TEST    BL,00000100b                    ; CTRL key pressed?
	JNZ     KY_CTR                          ;  ...skip if so
	TEST    BL,00100000b                    ; Toggle "Num Lock" ?
	JZ      KY_CT9                          ;  ...no, continue
	TEST    BL,00000011b                    ; Shift keys hit?
	JNZ     KY_CTA                          ;  ...no, check "INS"
	JMP     KY_CTD                          ; Else xlat keypad char.

KY_CT9: TEST    BL,00000011b                    ; Shift keys hit?
	JZ      KY_CTA                          ;  ...no, check "INS" key
	JMP     KY_CTD                          ; Else xlat keypad char.

KB_NUM: OR      AH,AH                           ; ALT-keypad entry, scan code
	JS      KY_EO1                          ;  ...out of range
	TEST    Byte [DS:17h],00000100b         ; Else check CTRL state
	JZ      KY_PAD                          ;  ...not pressed, ALT keypad

KY_PAT: CMP     AH,53h                          ; Patch for CTRL ALT - toggle
	JNZ     KY_PA1                          ;  ...not a DEL (reset)
	MOV     Word [DS:72h],1234h             ; Ctrl-Alt-Del, set init flag
	JMP     $                               ;  ...do a warm reboot

KY_PA1: CMP     AH,4Ah                          ; Is it a keypad "-" ?
	JNZ     KY_PAD                          ;  ...no, skip
	PUSH    AX
	PUSH    BX
	PUSH    CX
	IN      AL,61h                          ; Read equipment flags
	XOR     AL,00001100b                    ;  ...toggle speed
	OUT     61h,AL                          ; Write new flags back

	MOV     AH,1                            ; Video func=Set cursor type
	MOV     CX,607h                         ;  ...start at 6, end at 7
	AND     AL,4                            ; Is turbo mode set?
	JZ      KY_CUR                          ;  ...no, keep big cursor
	MOV     CH,0                            ; Else set tiny cursor

KY_CUR: INT     10h                             ; Set cursor type service
	MOV     BX,[DS:80h]                     ;  ...get start of key buf
	MOV     [DS:1Ah],BX                     ;  ...set head  to start
	MOV     [DS:1Ch],BX                     ;  ...set tail  to start
	POP     CX
	POP     BX
	POP     AX

KY_PAD: MOV     BX,NUMPAD                       ; Get keypad translation table
	cs XLATb
	CMP     AL,'0'                          ; Is it a valid ASCII digit?
	JB      KY_EO1                          ;  ...no, ignore it
	SUB     AL,30h                          ; Else convert to number
	MOV     BL,AL                           ;  ...save a copy
	MOV     AL,[DS:19h]                     ; Get partial ALT-keypad sum
	MOV     AH,0Ah                          ;  ...times 10 (decimal)
	MUL     AH
	ADD     AL,BL                           ; Add in new digit to sum
	MOV     [DS:19h],AL                     ;  ...save as new ALT entry

KY_EO1: JMP     KY_EOI                          ; End_of_interrupt, exit

KY_CTR: OR      AH,AH                           ; Key released?
	JS      KY_EO1                          ;  ...ignore if so
	MOV     BX,NUMCTR                       ; Else Numeric Keypad Control
	cs XLATb
	JMP     short   KY_COM                  ;  ...and save it

KY_CTA: CMP     AH,0D2h                         ; Was "INS" key released?
	JNZ     KY_CTB
	AND     Byte [DS:18h],01111111b         ; Yes, clear "INS" in "FLAG_1"
	JMP     short   KY_EO1

KY_CTB: OR      AH,AH                           ; Key released?
	JS      KY_EO1                          ;  ...ignore if so
	CMP     AH,52h                          ; Else check for "INS" press
	JNZ     KY_CTC                          ;  ...not "INS" press
	TEST    Byte [DS:18h],10000000b         ; Was INS key in effect?
	JNZ     KY_EO1                          ;  ...yes, ignore
	XOR     Byte [DS:17h],10000000b         ; Else tog "INS" in "FLAG" byte
	OR      Byte [DS:18h],10000000b         ;  ...set "INS" in "FLAG_1" byte

KY_CTC: MOV     BX,NUMUPP                       ; Numeric Keypad Upper Case
	cs XLATb
	JMP     short   KY_COM

KY_CTD: OR      AH,AH                           ; Was the key released?
	JS      KY_EO1                          ;  ...yes, ignore
	MOV     BX,NUMPAD                       ; Load translation table
	cs XLATb
	JMP     short   KY_COM

KY_COM: CMP     AL,5                            ; Common entry, char in AL
	JZ      KY_EO2                          ;  ...Control E, ignore
	CMP     AL,4
	JA      KY_CO1                          ; Above Control D

	OR      AL,10000000b                    ; Else set sign flag
	JMP     short   KY_CO2

KY_CO1: TEST    AL,10000000b                    ; Is sign bit set?
	JZ      KY_CO3                          ;  ...skip if so
	AND     AL,01111111b                    ; Else mask sign off

KY_CO2: MOV     AH,AL                           ; Save in high order byte
	MOV     AL,0                            ;  ...set scan code to zero

KY_CO3: TEST    Byte [DS:17h],01000000b         ; Test for "CAPS LOCK" state
	JZ      KY_BFR                          ;  ...no, skip
	TEST    Byte [DS:17h],00000011b         ; Test for SHIFT key
	JZ      KY_CO4                          ;  ...skip if no shift
	CMP     AL,'A'                          ; Check for alphabetic key
	JB      KY_BFR                          ;  ...not SHIFT_able
	CMP     AL,'Z'                          ; Check for alphabetic key
	JA      KY_BFR                          ;  ...not SHIFT_able
	ADD     AL,20h                          ; Else do the shift
	JMP     short   KY_BFR

KY_CO4: CMP     AL,'a'                          ; Check for alphabetic key
	JB      KY_BFR                          ;  ...not SHIFT_able
	CMP     AL,'z'                          ; Check for Alphabetic key
	JA      KY_BFR                          ;  ...not SHIFT_able
	SUB     AL,20h                          ; Else do the shift

KY_BFR: MOV     BX,[DS:1Ch]                     ; BX = tail of buffer
	MOV     DI,BX                           ;  ...save it
	INC     BX                              ;  ...advance
	INC     BX                              ;  ...by word
	CMP     BX,[DS:82h]                     ; End of buffer reached?
	JNZ     KY_CHK                          ;  ...no, skip
	MOV     BX,[DS:80h]                     ; Else BX = beginning of buffer

KY_CHK: CMP     BX,[DS:1Ah]                     ; BX = Buffer Head ?
	JNZ     KY_STF                          ;  ...no, OK
	JMP     short   KY_BEP                  ; Else buffer overrun, beep

KY_STF: MOV     [DI],AX                         ; Stuff scan code, char in bfr
	MOV     [DS:1Ch],BX                     ;  ...and update bfr tail

KY_EO2: JMP     KY_EOI

KY_BEP: MOV     AL,20h                          ; Keyboard beeper routine
	OUT     20h,AL                          ;  ...send end_of_interrupt
	MOV     BX,80h                          ; Cycles in beep
	IN      AL,61h                          ;  ...get status
	PUSH    AX                              ;  ...save copy

KY_BE1: AND     AL,11111100b                    ; Mask off speaker bits
	OUT     61h,AL                          ;  ...disable speaker
KY_BE2: MOV     CX,64h                          ; Constant for pitch
KY_BE3: LOOP    KY_BE3                          ;  ...delay, speaker off
	XOR     AL,00000010b
	OUT     61h,AL                          ; Toggle speaker position
	TEST    AL,00000010b                    ; Full cycle done yet?
	JZ      KY_BE2                          ;  ...no, do other half cycle
	DEC     BX                              ; Else show cycle sent
	JNZ     KY_BE1                          ;  ...more cycles to send
	POP     AX
	OUT     61h,AL                          ; Restore flags
	MOV     CX,32h                          ; Silence counter
KY_BE4: LOOP    KY_BE4                          ; Send nothing for while
	JMP     KY_XIT

KY_NUL: MOV     AH,38h                          ; ALT key pressed, released
	JMP     KY_BFR                          ;  ...for no logical reason

; ******** ******** ******** ******** ******** ******** ******** ********

INT_13:
	STI                                     ; Floppy disk services
	PUSH    BP
	PUSH    SI
	PUSH    DI
	PUSH    DS
	PUSH    ES
	PUSH    BX
	MOV     DI,AX                           ; Request type in DI, for index
	XOR     AX,AX
	MOV     DS,AX
	LES     SI,[DS:78h]                     ; Get disk parameter table
	MOV     AX,40h
	MOV     DS,AX
	MOV     BX,5
	MOV     AX,[ES:BX+SI]                   ; Get (Gap Length, DTL) in AX
	PUSH    AX                              ;  ...save it
	DEC     BX
	DEC     BX
	MOV     AX,[ES:BX+SI]                   ; Get (Bytes/sector,EOT) in AX
	PUSH    AX                              ;  ...save it
	XCHG    CL,DH
	XCHG    DL,CL
	PUSH    DX                              ; Push (Head,Drive) swapped
	PUSH    CX
	PUSH    DI
	MOV     BP,SP                           ; Mark bottom of stack frame
	CALL    FD_XQT                          ;  ...execute at current speed
	MOV     AH,[ES:SI+2]                    ; Get new motor count
	MOV     [DS:40h],AH                     ;  ...and save it
	MOV     AH,[DS:41h]                     ; Get completion status
	CMP     AH,1                            ;  ...check for write protect
	CMC                                     ;  ...was write protect error
	POP     BX
	POP     CX
	POP     DX
	XCHG    DL,CL
	XCHG    CL,DH
	POP     BX                              ; Clean
	POP     BX                              ;  ...up
	POP     BX                              ;  ...stack
	POP     ES
	POP     DS
	POP     DI
	POP     SI
	POP     BP
	RETF    2

FD_XQT: MOV     AL,[BP+1]                       ; Get floppy service number
	OR      AL,AL
	JZ      FD_RST                          ;  ...reset, AH=0
	DEC     AL
	JZ      FD_XQ3                          ;  ...read status, AH=1
	CMP     Byte [BP+2],3                   ; For track number above 3?
	JA      FD_XQ1                          ;  ...yes
	CMP     AL,5                            ; Service within range?
	JBE     FD_XQ2                          ; ...yes

FD_XQ1: MOV     Byte [DS:41h],1                 ; Say write protect error
	RET

FD_XQ2: JMP     FD_001                          ; Execute legal service

FD_XQ3: MOV     AL,[DS:41h]                     ; Return NEC status byte
	RET

FD_RST: MOV     DX,3F2h                         ; Reset the floppy disk system
	CLI
	AND     Byte [DS:3Fh],00001111b         ; Clear "write in progress"
	MOV     AL,[DS:3Fh]                     ;  ...find out busy drives
	MOV     CL,4
	SHL     AL,CL
	TEST    AL,00100000b
	JNZ     FD_RS1                          ; Drive #1 active
	TEST    AL,01000000b
	JNZ     FD_RS2                          ; Drive #2 active
	TEST    AL,10000000b
	JZ      FD_RS0                          ; Drive #3 idle

FD_RS3: INC     AL
FD_RS2: INC     AL
FD_RS1: INC     AL

FD_RS0: MOV     Byte [DS:3Eh],0                 ; All drives need recalibrate
	MOV     Byte [DS:41h],0                 ;  ...no completion status
	OR      AL,00001000b                    ; Interrupt ON in command word
	OUT     DX,AL                           ;  ...send word to controller
	OR      AL,00000100b                    ; "Reset" in command word
	OUT     DX,AL                           ;  ...send word to controller
	STI
	CALL    NC_BSY                          ; Wait for completion
	CALL    NC_STS                          ;  ...read result block
	MOV     AL,[DS:42h]
	CMP     AL,0C0h                         ; Did the reset work
	JZ      FD_RS4                          ;  ...yes
	MOV     Byte [DS:41h],20h               ; Else set controller error
	JMP     short   FD_RS5                  ;  ...return

FD_RS4: MOV     AL,3                            ; Specify command to NEC
	CALL    NEC765                          ;  ...send it
	MOV     AL,[ES:SI]                      ; First byte in param block
	CALL    NEC765                          ;  ...send it
	MOV     AL,[ES:SI+1]                    ; Secnd byte in param block
	CALL    NEC765                          ;  ...send it

FD_RS5: RET

NECFUN  db      003h,000h,0E6h,0C5h,0E6h,04Dh   ; NEC function table lookup
NECDMA  db      000h,000h,046h,04Ah,042h,04Ah   ; DMA modes for 8237
NECWRT  db      000h,000h,000h,080h,000h,080h   ; Write flag   table lookup
NECDRV  db      1,2,4,8                         ; Drive number table lookup
NECERR  db      80h,20h,10h,4,2,1               ; Error code   table lookup
NECSTS  db      04h,10h,08h,04h,03h,02h,20h     ; Disk status  table lookup

FD_001:
	CLI                                     ; Normal (non-reset) commands
	MOV     Byte [DS:41h],0                 ;  ...reset status
	MOV     AL,[BP+1]                       ; Get command word
	MOV     AH,0
	MOV     DI,AX                           ; Save copy, zero-extended
	OUT     0Ch,AL                          ;  ...diddle LSB/MSB flip-flop
	MOV     AL,[CS:DI+NECDMA]               ; Fetch DMA mode
	OUT     0Bh,AL                          ;  ...send it to IC8237
	MOV     AX,[BP+0Ch]                     ; Get segment address
	MOV     CL,4                            ;  ...convert
	ROL     AX,CL                           ;  ...to (offset, 64K page no)
	MOV     CH,AL                           ; Extract page number (0-15.)
	AND     CH,00001111b                    ;  ...for 8237 dma controller
	AND     AL,11110000b                    ; Extract implicit page offset
	ADD     AX,[BP+0Ah]                     ;  ...add explicit user offset
	ADC     CH,0                            ;  ...(page number overflowed)
	MOV     DX,AX                           ; Now save lo 16 bits of addr.
	OUT     4,AL                            ;  ...send lowest 8 bits  " "
	MOV     AL,AH
	OUT     4,AL                            ;  ...send next   8 bits  " "
	MOV     AL,CH
	OUT     81h,AL                          ; 64K page no to DMA page reg
	MOV     AH,[BP+0]
	MOV     AL,0
	SHR     AX,1                            ; Sector cnt * 128
	MOV     CL,[BP+6]                       ; Track count
	SHL     AX,CL                           ;  * sector count
	DEC     AX                              ; - 1
	OUT     5,AL                            ; Send 1/2 of the word count
	XCHG    AL,AH
	OUT     5,AL                            ; Send 2/2 of the word count
	XCHG    AL,AH
	ADD     AX,DX                           ; Compute final address
	JNB     FD_002                          ;  ...ok
	STI
	MOV     Byte [DS:41h],9h                ; Else wrapped around 64K byte
	JMP     FD_64K                          ;  ...page register

FD_002: MOV     AL,2                            ; Disable floppy disk dma
	OUT     0Ah,AL
	MOV     Byte [DS:40h],0FFh              ; Set large motor timeout
	MOV     BL,[BP+2]                       ;  ...get drive number
	MOV     BH,0
	MOV     AL,[CS:BX+NECDRV]               ; Table lookup bit position
	MOV     CH,AL                           ;  ...save mask
	MOV     CL,4
	SHL     AL,CL                           ; Shift mask into place
	OR      AL,BL                           ;  ...or in drive select
	OR      AL,0Ch                          ;  ...or in DMA and NO RESET
	MOV     DX,3F2h
	OUT     DX,AL                           ; Send to floppy control port
	STI
	MOV     AL,[CS:DI+NECWRT]               ; Table lookup for write  flag
	OR      [DS:3Fh],AL                     ;  ...set write flag if active
	OR      AL,AL
	JNS     FD_003                          ;  ...skip if non-write
	MOV     AH,[ES:SI+0Ah]                  ; Motor start from param blk
	OR      AH,AH
	JZ      FD_003                          ;  ...none specified
	TEST    CH,[DS:3Fh]                     ; Was this drive motor running?
	JNZ     FD_003                          ;  ...skip if so
	CALL    FD_WT1                          ; Else delay for motor start

FD_003: OR      [DS:3Fh],CH                     ; Show this motor is running
	TEST    CH,[DS:3Eh]                     ; Drive recalibration needed?
	JNZ     FD_004                          ;  ...no, skip
	OR      [DS:3Eh],CH                       ; Else show recalibrated
	MOV     AL,7                            ; Send RECAL command
	CALL    NEC765                          ;  ...to NEC 765 chip
	MOV     AL,BL
	CALL    NEC765                          ;  ...drive number
	CALL    NC_BSY                          ; Wait for completion of RECAL
	CALL    NEC_04                          ;  ...dummy call to RET

FD_004: MOV     AL,0Fh                          ; Request a seek
	CALL    NEC765                          ;  ...from the NEC 765
	MOV     AL,BL
	CALL    NEC765                          ; Drive number
	MOV     AL,[BP+3]
	CALL    NEC765                          ; Cylinder number
	CALL    NC_BSY                          ;  ...wait for completion
	CALL    NC_STS                          ;  ...read results
	MOV     AL,[ES:SI+9]                    ; Get head settle time
	OR      AL,AL                           ;  ...none specified?
	JZ      FD_005                          ;  ...if none, skip

FD_STL: MOV     CX,226h                         ; Delay time for head settle

FD_STZ: LOOP    FD_STZ                          ;  ...timed wait
	DEC     AL                              ;  ...delay in millisec
	JNZ     FD_STL                          ;  ...wait some more

FD_005: MOV     AL,[CS:DI+NECFUN]               ; Translate user service, then
	CALL    NEC765                          ;  ...and send as NEC func
	MOV     AL,[BP+4]                       ;
	AND     AL,1
	SHL     AL,1
	SHL     AL,1
	OR      AL,BL
	CALL    NEC765
	CMP     Byte [BP+1],5                   ; Is this a format request?
	JNZ     FD_006                          ;  ...skip if not
	MOV     AL,[BP+6]                       ; Else use user bytes/sector
	CALL    NEC765
	MOV     AL,[BP+7]                       ;  ... user EOT
	CALL    NEC765
	MOV     AL,[ES:SI+7]                    ; Disk table format gap length
	CALL    NEC765
	MOV     AL,[ES:SI+8]                    ; Disk table format fill byte
	CALL    NEC765
	JMP     short   FD_008

FD_006: MOV     CX,7                            ; Else lookup bytes * 512/sec
	MOV     DI,3                            ;  ...from disk table

FD_007: MOV     AL,[BP+DI]                      ; AL has bytes/sector * 512
	CALL    NEC765
	INC     DI                              ;  ...get next item for table
	LOOP    FD_007                          ;  ...also (EOT,GAP,DTL...)

FD_008: CALL    NC_BSY                          ; Wait on floppy i/o completion
	CALL    NC_ST1                          ;  ...get NEC status
	MOV     AL,[DS:42h]                     ;  ...into AL
	AND     AL,11000000b                    ; Isolate errors
	JZ      FD_012                          ;  ...no errors
	CMP     AL,40h                          ; Test direction bit
	JZ      FD_ERR
	MOV     Byte [DS:41h],20h               ; Set if bad controller
	JMP     short   FD_012                  ;  ...return error

FD_ERR: MOV     AL,[DS:43h]                     ; Read return code from block
	MOV     CX,6                            ;  ...number of error types
	XOR     BX,BX                           ; Start at error type 0

FD_009: TEST    AL,[CS:BX+NECERR]               ; Has error type BX occured?
	JNZ     FD_010                          ;  ...yes
	INC     BX                              ; Else try next error type
	LOOP    FD_009                          ;  ...until done

FD_010: MOV     AL,[CS:BX+NECSTS]               ; Translate error code again
	MOV     [DS:41h],AL                     ;  ...store it as disk status

FD_012: MOV     AL,[DS:45h]                     ; Get bytes read
	CMP     AL,[BP+3]                       ;  ...compare with requested
	MOV     AL,[DS:47h]                     ; Read sectors requested
	JZ      FD_013                          ;  ...return if all read
	MOV     AL,[BP+7]                       ; Else read sectors requested
	INC     AL                              ;  ...add one for luck

FD_013: SUB     AL,[BP+5]                       ; Subtract stectors read
	RET

FD_64K: MOV     AL,0                            ; Overflowed 64K page boundary
	RET                                     ;  ...show no sectors read

NC_BSY: STI                                     ; Wait for operation to finish
	XOR     CX,CX                           ;  ...zero lo order delay
	MOV     AL,2                            ; Load hi order delay

NC_BS1: TEST    Byte [DS:3Eh],10000000b         ; Has interrupt set the flag?
	CLC                                     ;  ...hack to slow CPU
	JNZ     NC_BS2                          ;  ...yes
	LOOP    NC_BS1                          ; Else back for more
	DEC     AL
	JNZ     NC_BS1

	MOV     Byte [DS:41h],80h               ; Time-out, say it completed
	POP     AX
	MOV     AL,0                            ;  ...return time out code
	STC                                     ;  ...error status
	RET

NC_BS2: AND     Byte [DS:3Eh],01111111b         ; Mask off completion status
	RET                                     ;  ...return carry clear

NC_RDY: PUSH    CX                              ; Wait for NEC ready for comand
	XOR     CX,CX
	MOV     DX,3F4h                         ;  ...NEC status port

NC_RD1: IN      AL,DX                           ; Read status of NEC 765 chip
	OR      AL,AL
	JS      NC_RD2                          ;  ...able to accept command
	LOOP    NC_RD1
	MOV     Byte [DS:41h],80h               ; Else show timeout error
	JMP     short   NC_RD3

NC_RD2: TEST    AL,01000000b                    ; Test the direction bit
	JNZ     NC_RD4
	MOV     Byte [DS:41h],20h               ;  ...clear iff controller err

NC_RD3: POP     CX
	STC
	RET

NC_RD4: INC     DX                              ; Load NEC data port
	IN      AL,DX                           ;  ...read it
	PUSH    AX

	MOV     CX,0Ah                          ; Short delay
NC_RD5: LOOP    NC_RD5

	DEC     DX                              ; Load NEC status port
	IN      AL,DX                           ;  ...read status
	TEST    AL,00010000b                    ;  ...set Z flag if done
	CLC                                     ;  ...return success
	POP     AX
	POP     CX
	RET

FD_WT1: PUSH    CX                              ; Millisecond delay in AH
FD_WT2: XOR     CX,CX
FD_WT3: LOOP    FD_WT3
	DEC     AH
	JNZ     FD_WT2
	POP     CX
	RET

; ******** ******** ******** ******** ******** ******** ******** ********

INT_E:                                          ; Disk interrupt entry
	STI
	PUSH    DS
	PUSH    AX
	MOV     AX,40h
	MOV     DS,AX
	OR      Byte [DS:3Eh],10000000b         ; Raise "attention" flag
	MOV     AL,20h                          ; Send end_of_interrupt code
	OUT     20h,AL                          ;  ...to 8259 interrupt chip
	POP     AX
	POP     DS
	IRET

NC_STS: MOV     AL,8                            ; Send a "Request status"
	CALL    NEC765                          ;  ...to the NEC 765 chip

NC_ST1: PUSH    BX                              ; Alternate entry point
	PUSH    CX
	MOV     CX,7
	XOR     BX,BX

NC_ST2: CALL    NC_RDY                          ; Wait for NEC 765 ready
	JB      NC_ST3                          ;  ...NEC 765 error
	MOV     [BX+42h],AL                     ; Save status in BIOS block
	JZ      NC_ST4                          ;  ...NEC 765 ready
	INC     BX                              ; Count more
	LOOP    NC_ST2
	MOV     byte [DS:41h],20h               ; NEC 765 controller error

NC_ST3: STC                                     ; Set error condition
	POP     CX
	POP     BX
	POP     AX
	MOV     AL,0
	RET

NC_ST4: POP     CX                              ; Successful return
	POP     BX
	RET

NEC765: PUSH    CX                              ; Send control to NEC 765 chip
	PUSH    DX
	PUSH    AX
	XOR     CX,CX
	MOV     DX,3F4h                         ; Load NEC 765 status port

NEC_01: IN      AL,DX                           ; Read NEC 765 status
	OR      AL,AL
	JS      NEC_02                          ;  ...done
	LOOP    NEC_01
	MOV     Byte [DS:41h],80h               ; Set time out status
	JMP     NEC_05

NEC_02: TEST    AL,40h                          ; Check data direction
	JZ      NEC_03
	MOV     Byte [DS:41h],20h               ;  ...NEC 765 is gimped
	JMP     NEC_05

NEC_03: INC     DX                              ; Load NEC 765 data port
	POP     AX
	OUT     DX,AL                           ;  ...write user's parameter
	CLC
	POP     DX
	POP     CX
NEC_04: RET

NEC_05: POP     AX                              ; Common error return
	POP     DX
	POP     CX
	POP     AX
	MOV     AL,0
	STC
	RET

; ******** ******** ******** ******** ******** ******** ******** ********

INT_1E:
	db      11001111b                       ; Disk parameter table
	db      2
	db      25h
	db      2
	db      8
	db      2Ah
	db      0FFh
	db      50h
	db      0F6h
	db      19h
	db      4

V_TABLE dw      CRT_0                           ; Set mode
	dw      CRT_1                           ; Set cursor type
	dw      CRT_2                           ; Set cursor position
	dw      CRT_3                           ; Get cursor position
	dw      0                               ; Read light pen position
	dw      CRT_5                           ; Set active display page
	dw      CRT_6                           ; Scroll active page up
	dw      CRT_7                           ; Scroll active page down
	dw      CRT_8                           ; Read attribute/character
	dw      CRT_9                           ; Write attribute/character
	dw      CRT_10                          ; Read character only
	dw      CRT_11                          ; Set color
	dw      CRT_12                          ; Write pixel
	dw      CRT_13                          ; Read  pixel
	dw      CRT_14                          ; Write teletype
	dw      CRT_15                          ; Return current video state

; ******** ******** ******** ******** ******** ******** ******** ********

INT_10:
	STI                                     ; Video bios service AH=(0-15.)
	CLD                                     ;  ...strings auto-increment
	PUSH    BP
	PUSH    ES
	PUSH    DS
	PUSH    SI
	PUSH    DI
	PUSH    DX
	PUSH    CX
	PUSH    BX
	PUSH    AX
	MOV     BX,40h
	MOV     DS,BX
	MOV     BL,[DS:10h]                     ; Get equipment byte
	AND     BL,00110000b                    ;  ...isolate video mode
	CMP     BL,00110000b                    ; Check for monochrome card
	MOV     BX,0B800h
	JNZ     C_01                            ; ...not there, BX --> CGA
	MOV     BX,0B000h                       ; Else          BX --> MONO

C_01:   PUSH    BX                              ; Save video buffer address
	MOV     BP,SP                           ;  ...start of stack frame
	CALL    C_02                            ;  ...then do the function
	POP     SI
	POP     AX
	POP     BX
	POP     CX
	POP     DX
	POP     DI
	POP     SI
	POP     DS
	POP     ES
	POP     BP
	IRET

MAPBYT: PUSH    DX                              ; Mul AL by BX, CX --> buf
	MOV     AH,0
	MUL     BX                              ; Position in AX
	POP     DX
	MOV     CX,[BP+0]                       ; CX --> video buffer
	RET

; ******** ******** ******** ******** ******** ******** ******** ********

INT_1D: db      38h,28h,2Dh,0Ah,1Fh,6,19h       ; Init string for 40 x 25
	db      1Ch,2,7,6,7
	db      0,0,0,0

	db      71h,50h,5Ah,0Ah,1Fh,6,19h       ; Init string for 80 x 25 col
	db      1Ch,2,7,6,7
	db      0,0,0,0

	db      38h,28h,2Dh,0Ah,7Fh,6,64h       ; Init string for GRAPHIX
	db      70h,2,1,6,7
	db      0,0,0,0

	db      61h,50h,52h,0Fh,19h,6,19h       ; Init string for 80 x 25 b/w
	db      19h,2,0Dh,0Bh,0Ch
	db      0,0,0,0

REGENL  dw      0800h                           ; Regen len, 40 x 25
	dw      1000h                           ;            80 x 25
	dw      4000h                           ;            GRAPHIX
	dw      4000h

MAXCOL  db      28h,28h,50h,50h,28h,28h,50h,50h ; Maximum columns

MODES   db      2Ch,28h,2Dh,29h,2Ah,2Eh,1Eh,29h ; Table of mode sets

TABMUL  db      00h,00h,10h,10h,20h,20h,20h,30h ; Table lookup for multiply

C_02:   CMP     AH,0Fh                          ; Is AH a legal video command?
	JBE     C_03
	RET                                     ;  ...error  return if not

C_03:   SHL     AH,1                            ; Make word value
	MOV     BL,AH                           ;  ...then set up BX
	MOV     BH,0
	JMP     Word [CS:BX+V_TABLE]            ;  ...vector to routines

CRT_0:  MOV     AL,[DS:10h]                     ; Set mode of CRT
	MOV     DX,3B4h                         ;  ...mono port
	AND     AL,00110000b                    ;  ...get display type
	CMP     AL,00110000b                    ;  ...equal if mono
	MOV     AL,1                            ; Assume mono display
	MOV     BL,7                            ;  ...mode is 7
	JZ      C0_01                           ;  ...Skip if mono, else CGA
	MOV     BL,[BP+2]                       ; BL = mode number (user AL)
	MOV     DL,0D4h                         ; 3D4 is CGA port
	DEC     AL

C0_01:  MOV     [DS:63h],DX                     ; Save cur. CRT display port
	ADD     DL,4
	OUT     DX,AL                           ; Reset the video
	MOV     [DS:49h],BL                     ;  ...save cur. CRT mode
	PUSH    DS
	XOR     AX,AX
	MOV     DS,AX
	LES     SI,[DS:74h]                     ; SI --> INT_1D video param
	POP     DS
	MOV     BH,0
	PUSH    BX
	MOV     BL,[CS:BX+TABMUL]               ; Get BL for index into INT_1D
	ADD     SI,BX
	MOV     CX,10h                          ; Sixteen values to send

C0_02:  MOV     AL,[ES:SI]                      ; Value to send in SI
	CALL    SENDAX                          ;  ...send it
	INC     AH                              ;  ...bump count
	INC     SI                              ;  ...point to next
	LOOP    C0_02                           ;  ...loop until done

	MOV     BX,[BP+0]                       ; BX --> regen buffer
	MOV     ES,BX                           ;  ...into ES segment
	XOR     DI,DI
	CALL    MODCHK                          ; Set flags acc. to mode
	MOV     CX,2000h                        ;  ...assume CGA
	MOV     AX,0                            ;  ...and graphics
	JB      C0_04                           ;  ...do graphics fill
	JNZ     C0_03                           ;  ...Alphanumeric fill
	MOV     CX,800h                         ;  ...mono card
C0_03:  MOV     AX,7*100h+' '                   ; Word for text fill
C0_04:  REPZ    STOSW                           ;  ...fill regen buffer

	MOV     DX,[DS:63h]                     ; Get the port
	ADD     DL,4
	POP     BX
	MOV     AL,[CS:BX+MODES]                ; Load data to set for mode
	OUT     DX,AL                           ;  ...and send it
	MOV     [DS:65h],AL                     ;  ...then save active data
	INC     DX
	MOV     AL,30h                          ; Assume not 640 x 200 b/w
	CMP     BL,6                            ;  ...correct?
	JNZ     C0_05
	MOV     AL,3Fh                          ; Palette for 640 x 200 b/w

C0_05:  MOV     [DS:66h],AL                     ;  ...save palette
	OUT     DX,AL                           ;  ...send palette
	XOR     AX,AX
	MOV     [DS:4Eh],AX                     ; Start at beg. of 1st page
	MOV     [DS:62h],AL                     ;  ...active page=page 0
	MOV     CX,8                            ; Do 8 pages of cursor data
	MOV     DI,50h                          ; Page cursor data at 40:50

C0_06:  MOV     [DI],AX                         ; Cursor at upper left of page
	INC     DI                              ;  ...next page
	LOOP    C0_06
	MOV     Word [DS:60h],0607h             ; Cursor: Line 6 thru Line 7
	MOV     AL,[CS:BX+MAXCOL]               ; Get display width
	MOV     [DS:4Ah],AX                     ;  ...save it
	AND     BL,11111110b
	MOV     AX,Word [CS:BX+REGENL]          ; Get video regen length
	MOV     [DS:4Ch],AX                     ;  ...save it
	RET

CRT_1:  MOV     CX,[BP+6]                       ; Set cursor type, from CX
	MOV     [DS:60h],CX                     ;  ...save it
	MOV     AH,0Ah                          ; CRT index register 0Ah
	CALL    OT6845                          ;  ...send CH,CL to CRT reg
	RET

CRT_2:  MOV     BL,[BP+5]                       ; Set cursor position, page BH
	SHL     BL,1                            ;  ...(our BL)
	MOV     BH,0
	MOV     AX,[BP+8]                       ; Position in user DX (our AX)
	MOV     [BX+50h],AX                     ;  ...remember cursor position
	JMP     SETCUR                          ;  ...set 6845 cursor hardware

CRT_3:  MOV     BL,[BP+5]                       ; Get cursor position, page BH
	SHL     BL,1
	MOV     BH,0
	MOV     AX,[BX+50h]
	MOV     [BP+8],AX                       ;  ...return position in user DX
	MOV     AX,[DS:60h]                     ; Get cursor mode
	MOV     [BP+6],AX                       ;  ...return in user CX
	RET

CRT_5:  MOV     AL,[BP+2]                       ; Set active display page to AL
	MOV     [DS:62h],AL                     ;  ...save new active page
	MOV     AH,0                            ;  ...clear hi order
	PUSH    AX
	MOV     BX,[DS:4Ch]                     ; Get size of regen. buffer
	MUL     BX                              ;  ...times number of pages
	MOV     [DS:4Eh],AX                     ; Now AX = CRT offset, save
	SHR     AX,1                            ;  ...now word offset
	MOV     CX,AX                           ;  ...save a copy
	MOV     AH,0Ch                          ; CRT index register 0Ch
	CALL    OT6845                          ;  ...send CH,CL thru CRT reg
	POP     BX
	CALL    MOVCUR                          ; Save new parameters
	RET

CRT_6:                                          ; Scroll active page up
CRT_7:  CALL    MODCHK                          ; Scroll active page down
	JNB     SCR_01
	JMP     SCG_01                          ; Graphics scroll

SCR_01: CLD                                     ; Strings go upward
	CMP     Byte [DS:49h],2
	JB      SCR_03                          ;  ...no retrace wait needed
	CMP     Byte [DS:49h],3
	JA      SCR_03                          ;  ...no retrace wait needed
	MOV     DX,3DAh                         ; Else 80 x 25, do the kludge

SCR_02: IN      AL,DX                           ; Read CGA status register
	TEST    AL,00001000b                    ;  ...vertical retrace?
	JZ      SCR_02                          ;  ...wait until it is
	MOV     DX,3D8h                         ; Then go and
	MOV     AL,25h                          ;  ...turn the display
	OUT     DX,AL                           ;  ...off to avoid snow

SCR_03: MOV     AX,[BP+8]                       ; Get row,column of upper left
	PUSH    AX
	CMP     Byte [BP+3],7                   ; Check for scroll down
	JZ      SCR_04                          ;  ...yes, skip if so
	MOV     AX,[BP+6]                       ; Get row,column of lowr right

SCR_04: CALL    RC2COL                          ; Get byte in CRT buf
	ADD     AX,[DS:4Eh]                     ;  ...add  base  for CRT buf
	MOV     SI,AX
	MOV     DI,AX
	POP     DX
	SUB     DX,[BP+6]                       ; Subtract (row,col) lwr rhgt
	ADD     DX,101h                         ;  ...width of one char
	MOV     BX,[DS:4Ah]                     ; Get columns in display
	SHL     BX,1                            ;  ...bytes in row of display
	PUSH    DS
	MOV     AL,[BP+2]                       ; Get scroll fill character
	CALL    MAPBYT                          ;  ...calculate offset
	MOV     ES,CX                           ; CX --> byte in buffer
	MOV     DS,CX
	CMP     Byte [BP+3],6                   ; Scroll up?
	JZ      SCR_05                          ;  ...skip if so
	NEG     AX
	NEG     BX
	STD                                     ; Else start at top of page

SCR_05: MOV     CL,[BP+2]                       ; Get count of lines to scroll
	OR      CL,CL
	JZ      SCR_07                          ;  ...nothing to do
	ADD     SI,AX
	SUB     DH,[BP+2]

SCR_06: MOV     CH,0                            ; Clear hi order word count
	MOV     CL,DL                           ;  ...load lo order word count
	PUSH    DI
	PUSH    SI
	REPZ    MOVSW                           ; Do the scroll
	POP     SI
	POP     DI
	ADD     SI,BX                           ; Move one line in direction
	ADD     DI,BX                           ;       ""       ""
	DEC     DH                              ; One less line to scroll
	JNZ     SCR_06
	MOV     DH,[BP+2]                       ; Now get number of rows

SCR_07: MOV     CH,0                            ; Clear hi order word count
	MOV     AH,[BP+5]                       ;  ...get fill attribute
	MOV     AL,' '                          ;  ...fill character

SCR_08: MOV     CL,DL                           ; Get characters to scroll
	PUSH    DI
	REPZ    STOSW                           ;  ...store fill attr/char
	POP     DI
	ADD     DI,BX                           ; Show row was filled
	DEC     DH
	JNZ     SCR_08                          ;  ...more rows are left
	POP     DS
	CALL    MODCHK                          ; Check for monochrome card
	JZ      SCR_09                          ;  ...skip if so
	MOV     AL,[DS:65h]                     ; Get the mode data byte
	MOV     DX,3D8h                         ;  ...load active CRT card port
	OUT     DX,AL                           ;  ...and unblank the screen

SCR_09: RET

SCG_01: CLD                                     ; Assume GRAFIX scroll up
	MOV     AX,[BP+8]                       ; (Row,Col) of lower right
	PUSH    AX
	CMP     Byte [BP+3],7                   ; Scroll down?
	JZ      SCG_02                          ;  ...skip if so
	MOV     AX,[BP+6]                       ; (Row,Col) of upper left

SCG_02: CALL    GRAMAP                          ; Convert (Row,Col) -> Chars
	MOV     DI,AX
	POP     DX
	SUB     DX,[BP+6]                       ; Chars to copy over
	ADD     DX,101h                         ;  ...width of one char
	SHL     DH,1
	SHL     DH,1
	MOV     AL,[BP+3]                       ; Get command type
	CMP     Byte [DS:49h],6                 ;  ...is this 640 x 200?
	JZ      SCG_03                          ;  ...skip if so
	SHL     DL,1                            ; Else bigger characters
	SHL     DI,1
	CMP     AL,7                            ; Is this scroll down?
	JNZ     SCG_03                          ;  ...skip if not so
	INC     DI

SCG_03: CMP     AL,7                            ; Is this scroll down?
	JNZ     SCG_04                          ;  ...skip if not so
	ADD     DI,0F0h

SCG_04: MOV     BL,[BP+2]                       ; Number of rows to blank
	SHL     BL,1
	SHL     BL,1
	PUSH    BX
	SUB     DH,BL                           ; Subtract from row count
	MOV     AL,50h
	MUL     BL
	MOV     BX,1FB0h
	CMP     Byte [BP+3],6                   ; Is this scroll up?
	JZ      SCG_05                          ;  ...skip if so
	NEG     AX                              ; Else do it
	MOV     BX,2050h
	STD                                     ; ...in reverse

SCG_05: MOV     SI,DI                           ; End of area
	ADD     SI,AX                           ;  ...start
	POP     AX
	OR      AL,AL
	MOV     CX,[BP+0]
	MOV     DS,CX
	MOV     ES,CX
	JZ      SCG_07                          ; No rows to scroll
	PUSH    AX

SCG_06: MOV     CH,0                            ; Zero hi order byte count
	MOV     CL,DL                           ;  ...bytes in row
	PUSH    SI
	PUSH    DI
	REPZ    MOVSB                           ; Copy one plane
	POP     DI
	POP     SI
	ADD     SI,2000h                        ; Load other grafix
	ADD     DI,2000h                        ;  ...video plane
	MOV     CL,DL
	PUSH    SI
	PUSH    DI
	REPZ    MOVSB                           ; Copy other plane
	POP     DI
	POP     SI
	SUB     SI,BX
	SUB     DI,BX
	DEC     DH                              ; One less row to scroll
	JNZ     SCG_06                          ;  ...loop if more to do
	POP     AX
	MOV     DH,AL                           ; Load rows to blank

SCG_07: MOV     AL,[BP+5]                       ; Get fill attribute
	MOV     CH,0

SCG_08: MOV     CL,DL                           ; Get bytes per row
	PUSH    DI
	REPZ    STOSB                           ; Load row with fill attr.
	POP     DI
	ADD     DI,2000h                        ; Do other grafix video plane
	MOV     CL,DL
	PUSH    DI
	REPZ    STOSB                           ; Load row with fill attr.
	POP     DI
	SUB     DI,BX
	DEC     DH                              ; Show one less row to blank
	JNZ     SCG_08                          ;  ...loop if more to do
	RET

CRT_8:                                          ; Read attribute/character
CRT_9:                                          ; Write attribute/character
CRT_10: CALL    MODCHK                          ; Write character only
	JB      CG8_01                          ;  ... graphics operation
	MOV     BL,[BP+5]                       ; Get the display page
	MOV     BH,0
	PUSH    BX
	CALL    MPRC2C                          ; Convert Row,Col,Page -> Col
	MOV     DI,AX                           ;  ...in DI
	POP     AX
	MUL     Word [DS:4Ch]                   ; Page length X page number
	ADD     DI,AX                           ;  ...current char. position
	MOV     SI,DI                           ;  ...move into si
	MOV     DX,[DS:63h]                     ; Display port into DX
	ADD     DX,6                            ;  ...get status port
	PUSH    DS
	MOV     BX,[BP+0]                       ; BX --> regen. buffer
	MOV     DS,BX
	MOV     ES,BX
	MOV     AL,[BP+3]                       ; Get user (AH) func request
	CMP     AL,8
	JNZ     C9_01                           ;  ...skip if not read attr

C8_01:  IN      AL,DX                           ; Read CRT display status
	TEST    AL,00000001b                    ;  ...test for hor. retrace
	JNZ     C8_01                           ; Yes, wait for display on
	CLI                                     ;  ...no interrupts now

C8_02:  IN      AL,DX                           ; Read CRT display status
	TEST    AL,00000001b                    ;  ...test for hor. retrace
	JZ      C8_02                           ;  ...not yet, wait for it

	LODSW                                   ; Read character/attribute
	POP     DS
	MOV     [BP+2],AL                       ; Return character
	MOV     [BP+3],AH                       ;  ..and attribute
	RET

C9_01:  MOV     BL,[BP+2]                       ; Get char. to write
	MOV     BH,[BP+4]                       ;  ...attribute
	MOV     CX,[BP+6]                       ;  ...character count
	CMP     AL,0Ah                          ; Write char. only?
	JZ      CA_01                           ;  ...skip if so

C9_02:  IN      AL,DX                           ; Read CRT display status
	TEST    AL,00000001b                    ;  ...test for hor. retrace
	JNZ     C9_02                           ; Yes, wait for display on
	CLI                                     ;  ...no interrupts now

C9_03:  IN      AL,DX                           ; Read CRT display status
	TEST    AL,00000001b                    ;  ...test for hor. retrace
	JZ      C9_03                           ;  ...not yet, wait for it

	MOV     AX,BX                           ; Get char/attribute
	STOSW                                   ;  ...write it
	LOOP    C9_02                           ;  ...loop for char. count
	POP     DS
	RET

CA_01:  IN      AL,DX                           ; Read CRT display status
	TEST    AL,00000001b                    ;  ...test for hor. retrace
	JNZ     CA_01                           ;  ...not yet, wait for it
	CLI                                     ;  ...no interrupts now

CA_02:  IN      AL,DX                           ; Read CRT display status
	TEST    AL,00000001b                    ;  ...test for hor. retrace
	JZ      CA_02                           ;  ...not yet, wait for it

	MOV     AL,BL                           ; Get character
	STOSB                                   ;  ...write it
	INC     DI                              ;  ...skip attribute
	LOOP    CA_01                           ;  ...loop for char. count
	POP     DS
	RET

CG8_01: CMP     Byte [BP+3],8                   ; Read graphics char/attr. ?
	JNZ     CG9_01                          ;  ...no, must be write
	JMP     CGR_01                          ; Else read char/attr.

CG9_01: MOV     AX,[DS:50h]                     ; Get cursor position
	CALL    GRAMAP                          ;  ...convert (row,col) -> col
	MOV     DI,AX                           ; Save in displacement register
	PUSH    DS
	MOV     AL,[BP+2]                       ; Get character to write
	MOV     AH,0
	OR      AL,AL                           ; Is it user character set?
	JS      CG9_02                          ;  ...skip if so
	MOV     DX,CS                           ; Else use ROM character set
	MOV     SI,GRAFIX                       ;  ...GRAFIX into SI
	JMP     short   CG9_03

CG9_02: AND     AL,7Fh                          ; Origin to zero
	XOR     BX,BX                           ;  ...then go load
	MOV     DS,BX                           ;  ...user grafix
	LDS     SI,[DS:7Ch]                     ;  ...vector, in SI
	MOV     DX,DS                           ;  ...segment into DX

CG9_03: POP     DS                              ; Restore data segment
	MOV     CL,3                            ;  ...char 8 pixels wide
	SHL     AX,CL
	ADD     SI,AX                           ; Add regen. buffer base addr.
	MOV     AX,[BP+0]                       ;  ...get regen buffer addr.
	MOV     ES,AX                           ;  ...into ES
	MOV     CX,[BP+6]                       ;  ...load char. count
	CMP     Byte [DS:49h],6                 ; Is the mode 640 x 200 b/w?
	PUSH    DS
	MOV     DS,DX
	JZ      CG8_02                          ;  ...skip if so
	SHL     DI,1
	MOV     AL,[BP+4]                       ; Get char. attribute
	AND     AX,3
	MOV     BX,5555h
	MUL     BX
	MOV     DX,AX
	MOV     BL,[BP+4]

CG9_04: MOV     BH,8                            ; Char 8 pixels wide
	PUSH    DI
	PUSH    SI

CG9_05: LODSB                                   ; Read the screen
	PUSH    CX
	PUSH    BX
	XOR     BX,BX
	MOV     CX,8

CG9_06: SHR     AL,1                            ; Shift bits thru byte
	RCR     BX,1
	SAR     BX,1
	LOOP    CG9_06

	MOV     AX,BX                           ; Result into AX
	POP     BX
	POP     CX
	AND     AX,DX
	XCHG    AH,AL
	OR      BL,BL
	JNS     CG9_07
	XOR     AX,[ES:DI]

CG9_07: MOV     [ES:DI],AX                      ; Write new word
	XOR     DI,2000h
	TEST    DI,2000h                        ; Is this other plane?
	JNZ     CG9_08                          ;  ...nope
	ADD     DI,50h                          ; Else advance character

CG9_08: DEC     BH                              ; Show another char written
	JNZ     CG9_05                          ;  ...more to go
	POP     SI
	POP     DI
	INC     DI
	INC     DI
	LOOP    CG9_04
	POP     DS
	RET

CG8_02: MOV     BL,[BP+4]                       ; Get display page
	MOV     DX,2000h                        ;  ...size of grafix plane

CG8_03: MOV     BH,8                            ; Pixel count to write
	PUSH    DI
	PUSH    SI

CG8_04: LODSB                                   ; Read from one plane
	OR      BL,BL                           ;  ...done both planes?
	JNS     CG8_05                          ;  ...skip if not
	XOR     AL,[ES:DI]                      ; Else load attribute

CG8_05: MOV     [ES:DI],AL                      ; Write out attribute
	XOR     DI,DX                           ;  ...get other plane
	TEST    DI,DX                           ; Done both planes?
	JNZ     CG8_06                          ;  ...skip if not
	ADD     DI,50h                          ; Else position for now char

CG8_06: DEC     BH                              ; Show row of pixels read
	JNZ     CG8_04                          ;  ...not done all of them
	POP     SI
	POP     DI
	INC     DI
	LOOP    CG8_03
	POP     DS
	RET

CGR_01: CLD                                     ; Increment upwards
	MOV     AX,[DS:50h]                     ;  ...get cursor position
	CALL    GRAMAP                          ; Convert (row,col) -> columns
	MOV     SI,AX                           ;  ...save in SI
	SUB     SP,8                            ; Grab 8 bytes temp storage
	MOV     DI,SP                           ;  ...save base in DI
	CMP     Byte [DS:49h],6                 ; Mode 640 x 200 b/w?
	MOV     AX,[BP+0]                       ;  ...AX --> CRT regen buffer
	PUSH    DS
	PUSH    DI
	MOV     DS,AX
	JZ      CGR_06                          ; Mode is 640 x 200 b/w - skip
	MOV     DH,8                            ; Eight pixels high/char
	SHL     SI,1
	MOV     BX,2000h                        ; Bytes per video plane

CGR_02: MOV     AX,[SI]                         ; Read existing word
	XCHG    AH,AL
	MOV     CX,0C000h                       ; Attributes to scan for
	MOV     DL,0

CGR_03: TEST    AX,CX                           ; Look for attributes
	CLC
	JZ      CGR_04                          ;  ...set, skip
	STC                                     ; Else show not set

CGR_04: RCL     DL,1
	SHR     CX,1
	SHR     CX,1
	JNB     CGR_03                          ;  ...more shifts to go
	MOV     [SS:DI],DL
	INC     DI
	XOR     SI,BX                           ; Do other video plane
	TEST    SI,BX                           ;  ...done both planes?
	JNZ     CGR_05                          ;  ...no, skip
	ADD     SI,50h                          ; Else advance pointer

CGR_05: DEC     DH                              ; Show another pixel row done
	JNZ     CGR_02                          ;  ...more rows to do
	JMP     short   CGR_08

CGR_06: MOV     DH,4                            ; Mode 640 x 200 b/w - special

CGR_07: MOV     AH,[SI]                         ; Read pixels from one plane
	MOV     [SS:DI],AH                      ;  ...save on stack
	INC     DI                              ;  ...advance
	MOV     AH,[SI+2000h]                   ; Read pixels from other plane
	MOV     [SS:DI],AH                      ; Save pixels on stack
	INC     DI                              ;  ...advance
	ADD     SI,50h                          ; Total pixels in char
	DEC     DH                              ;  ...another row processed
	JNZ     CGR_07                          ;  ...more to do

CGR_08: MOV     DX,CS                           ; Load segment of grafix char
	MOV     DI,GRAFIX                       ;  ...and offset
	MOV     ES,DX                           ;  ...save in ES
	MOV     DX,SS
	MOV     DS,DX
	POP     SI
	MOV     AL,0

CGR_09: MOV     DX,80h                          ; Number of char. in grafix set

CGR_10: PUSH    SI
	PUSH    DI
	MOV     CX,8                            ; Bytes to compare for char
	REPZ    CMPSB                           ;  ...do compare
	POP     DI
	POP     SI
	JZ      CGR_11                          ; Found grafix character
	INC     AL                              ;  ...else show another char
	ADD     DI,8                            ;  ...advance one row
	DEC     DX                              ;  ...one less char  to scan
	JNZ     CGR_10                          ; Loop if more char left

	OR      AL,AL                           ; User grafix character set?
	JZ      CGR_11                          ;  ...no, not found
	XOR     BX,BX
	MOV     DS,BX
	LES     DI,[DS:7Ch]                     ; Else load user grafix char
	MOV     BX,ES
	OR      BX,DI
	JZ      CGR_11                          ;  ...not found
	JMP     short   CGR_09                  ; Try using user grafix char

CGR_11: MOV     [BP+2],AL                       ; Return char in user AL
	POP     DS
	ADD     SP,8                            ;  ...return temp storage
	RET

CRT_11: MOV     DX,[DS:63h]                     ; Set color, get CGA card port
	ADD     DX,5                            ;  ...color select register
	MOV     AL,[DS:66h]                     ; Get CRT palette
	MOV     AH,[BP+5]                       ; ...new palette ID, user BH
	OR      AH,AH
	MOV     AH,[BP+4]                       ; ...new palette color, user BL
	JNZ     C_PAL1                          ; Palette ID specified, skip
	AND     AL,0E0h
	AND     AH,1Fh                          ; Null ID = ID 01Fh
	OR      AL,AH                           ;  ...set in color
	JMP     short   C_PAL2

C_PAL1: AND     AL,0DFh
	TEST    AH,1
	JZ      C_PAL2
	OR      AL,20h

C_PAL2: MOV     [DS:66h],AL                     ; Save new palette
	OUT     DX,AL                           ;  ...tell CGA about it
	RET

CRT_12: MOV     AX,[BP+0]                       ; Write pixel
	MOV     ES,AX
	MOV     DX,[BP+8]                       ; Load row from user DX
	MOV     CX,[BP+6]                       ;  ... col from user CX
	CALL    LOCDOT                          ; Find dot offset
	JNZ     WD_01                           ; ...valid
	MOV     AL,[BP+2]                       ; Load user color
	MOV     BL,AL
	AND     AL,1
	ROR     AL,1
	MOV     AH,7Fh
	JMP     short   WD_02

WD_01:  SHL     CL,1
	MOV     AL,[BP+2]
	MOV     BL,AL
	AND     AL,3
	ROR     AL,1
	ROR     AL,1
	MOV     AH,3Fh

WD_02:  ROR     AH,CL
	SHR     AL,CL
	MOV     CL,[ES:SI]                      ; Read the char with the dot
	OR      BL,BL
	JNS     WD_03
	XOR     CL,AL                           ; Exclusive or existing color
	JMP     short   WD_04

WD_03:  AND     CL,AH                           ; Set new color for dot
	OR      CL,AL

WD_04:  MOV     [ES:SI],CL                      ; Write out char with the dot
	RET

CRT_13: MOV     AX,[BP+0]                       ; AX --> video regen buffer
	MOV     ES,AX                           ;  ...into ES segment
	MOV     DX,[BP+8]                       ; Load row from user DX
	MOV     CX,[BP+6]                       ;  ... col from user CX
	CALL    LOCDOT                          ; Calculate dot offset
	MOV     AL,[ES:SI]                      ;  ...read dot
	JNZ     RD_01                           ;  ...was there
	SHL     AL,CL
	ROL     AL,1
	AND     AL,1
	JMP     short   RD_02

RD_01:  SHL     CL,1                            ; Calculate in char
	SHL     AL,CL
	ROL     AL,1
	ROL     AL,1
	AND     AL,3

RD_02:  MOV     [BP+2],AL                       ; Return dot pos in user AL
	RET

CRT_14: MOV     BL,[DS:62h]                     ; Get active video page (0-7)
	SHL     BL,1                            ;  ...as word index
	MOV     BH,0                            ;  ...clear hi order
	MOV     DX,[BX+50h]                     ; Index into cursor position

	MOV     AL,[BP+2]                       ; Get char. to write
	CMP     AL,8                            ;  ...back space?
	JZ      TTY_BS                          ;  ...skip if so
	CMP     AL,0x0A                         ; Is it a carriage return
	JZ      TTY_LF                          ;  ...skip if so
	CMP     AL,7                            ; Print a bell?
	JZ      BLIP                            ;  ...do beep
	CMP     AL,0x0D                         ; Is it a line feed?
	JZ      TTY_CR                          ;  ...skip if so
	MOV     BL,[BP+4]                       ; Else write at cur pos
	MOV     AH,0Ah
	MOV     CX,1                            ;  ...one time
	INT     10h
	INC     DL                              ; Advance cursor
	CMP     DL,[DS:4Ah]                     ;  ...check for line overflow
	JNZ     TTYPOS
	MOV     DL,0                            ; Overflowed, then fake
	JMP     short   TTY_LF                  ;  ...new line

TTY_BS: CMP     DL,0                            ; At start of line?
	JZ      TTYPOS                          ;  ...skip if so
	DEC     DL                              ; Else back up
	JMP     short   TTYPOS                  ;  ...join common code

BLIP:   MOV     BL,2                            ; Do a short
	;CALL    BEEP                            ;  ...beep
	RET

TTY_CR: MOV     DL,0                            ; Position to start of line

TTYPOS: MOV     BL,[DS:62h]                     ; Get active video page (0-7)
	SHL     BL,1                            ;  ...as word index
	MOV     BH,0                            ;  ...clear hi order
	MOV     [BX+50h],DX                     ; Remember the cursor position
	JMP     SETCUR                          ;  ...set 6845 cursor hardware

TTY_LF: CMP     DH,18h                          ; Done all 24 lines on page?
	JZ      TTY_L1                          ;  ...yes, scroll
	INC     DH                              ; Else advance line
	JNZ     TTYPOS

TTY_L1: MOV     AH,2                            ; Position cursor at line start
	INT     10h
	CALL    MODCHK                          ; Is this text mode?
	MOV     BH,0
	JB      TTY_L2                          ; Skip if text mode
	MOV     AH,8
	INT     10h                             ;  ...else read attribute
	MOV     BH,AH

TTY_L2: MOV     AH,6                            ; Now prepare to
	MOV     AL,1                            ;  ...scroll
	XOR     CX,CX                           ;  ...the
	MOV     DH,18h                          ;  ...page
	MOV     DL,[DS:4Ah]                     ;  ...up
	DEC     DL
	INT     10h
	RET

CRT_15: MOV     AL,[DS:4Ah]                     ; Get current video state
	MOV     [BP+3],AL                       ;  ...columns
	MOV     AL,[DS:49h]
	MOV     [BP+2],AL                       ;  ...mode
	MOV     AL,[DS:62h]
	MOV     [BP+5],AL                       ;  ...page
	RET

MODCHK: PUSH    AX                              ; Set flags acc. to cur. mode
	MOV     AL,[DS:49h]                     ;  ...get mode
	CMP     AL,7                            ;  ...EQU if mono
	JZ      MODCH1
	CMP     AL,4
	CMC
	JNB     MODCH1                          ;  ...carry set on graphix
	SBB     AL,AL
	STC

MODCH1: POP     AX
	RET

LOCDOT: MOV     AL,50h                          ; Dots in char. position
	XOR     SI,SI
	SHR     DL,1                            ; Two bytes/char. position
	JNB     LOCDO1                          ;  ...not overflow
	MOV     SI,2000h                        ; Else on other video plane

LOCDO1: MUL     DL                              ; Multiply position by row
	ADD     SI,AX                           ;  ...add in column position
	MOV     DX,CX                           ; Copy column position
	MOV     CX,302h                         ;  ...regular char size
	CMP     Byte [DS:49h],6                 ; Mode 640 x 200, b/w?
	PUSHF
	JNZ     LOCDO2                          ;  ...skip if not
	MOV     CX,703h                         ; Else special char. size

LOCDO2: AND     CH,DL
	SHR     DX,CL
	ADD     SI,DX
	XCHG    CL,CH
	POPF
	RET

PENXY:  CALL    PENXY1                          ; Read light pen position HI
	MOV     CH,AL                           ;  ...save in CH
	INC     AH
	CALL    PENXY1                          ; Read light pen position LO
	MOV     CL,AL                           ;  ...save in CL
	RET

PENXY1: PUSH    DX                              ; Read CRT register AL
	MOV     DX,[DS:63h]                     ;  ...get active CRT port
	XCHG    AL,AH
	OUT     DX,AL                           ; Send initialization byte
	INC     DL                              ;  ...increment
	IN      AL,DX                           ; Read pen position byte back
	POP     DX
	RET

MPRC2C: MOV     BH,0                            ; Convert Row,Col,Page -> Col
	SHL     BX,1                            ;  ...two bytes/column
	MOV     AX,[BX+50h]                     ; Get page number in AX
						;  ...join common code
RC2COL: PUSH    BX                              ; Map (AH=row,AL=COL) to COL
	MOV     BL,AL
	MOV     AL,AH
	MUL     Byte [DS:4Ah]                   ; Multiply ROW x (Row/Column)
	MOV     BH,0
	ADD     AX,BX                           ;  ...add in existing COL
	SHL     AX,1                            ;  ...times 2 cause 2 bytes/col
	POP     BX
	RET

GRAMAP: PUSH    BX                              ; Convert (row,col) -> col
	MOV     BL,AL                           ;  ...save column
	MOV     AL,AH                           ;  ...get row
	MUL     Byte [DS:4Ah]                   ; Multiply by columns/row
	SHL     AX,1
	SHL     AX,1
	MOV     BH,0
	ADD     AX,BX                           ; Add in columns
	POP     BX
	RET

SETCUR: SHR     BL,1                            ; Sets 6845 cursor position
	CMP     [DS:62h],BL                     ;  ...is this page visible?
	JNZ     SEND01                          ; No, do nothing in hardware

MOVCUR: CALL    MPRC2C                          ; Map row,col,page to col
	ADD     AX,[DS:4Eh]                     ;  + byte offset, regen reg.
	SHR     AX,1
	MOV     CX,AX
	MOV     AH,0Eh                          ; Tell 6845 video controller
						;  ...to position the cursor

OT6845: MOV     AL,CH                           ; Send CH,CL thru CRT reg AH
	CALL    SENDAX                          ;  ...send CH
	INC     AH                              ;  ...increment
	MOV     AL,CL                           ;  ...send CL

SENDAX: PUSH    DX
	MOV     DX,[DS:63h]                     ; Load active video port
	XCHG    AL,AH
	OUT     DX,AL                           ; Send hi order
	XCHG    AL,AH
	INC     DL
	OUT     DX,AL                           ;  ... lo order
	POP     DX

SEND01: RET

; ******** ******** ******** ******** ******** ******** ******** ********

INT_12:
	mov     ax, 640
	iret

; ******** ******** ******** ******** ******** ******** ******** ********

	times 0xFA6E-($-$$) db 0xFF             ; IBM graphics char set entry

GRAFIX  db      000h,000h,000h,000h             ; Graphics character set
	db      000h,000h,000h,000h
	db      07Eh,081h,0A5h,081h
	db      0BDh,099h,081h,07Eh
	db      07Eh,0FFh,0DBh,0FFh
	db      0C3h,0E7h,0FFh,07Eh
	db      06Ch,0FEh,0FEh,0FEh
	db      07Ch,038h,010h,000h

	db      010h,038h,07Ch,0FEh
	db      07Ch,038h,010h,000h
	db      038h,07Ch,038h,0FEh
	db      0FEh,07Ch,038h,07Ch
	db      010h,010h,038h,07Ch
	db      0FEh,07Ch,038h,07Ch
	db      000h,000h,018h,03Ch
	db      03Ch,018h,000h,000h

	db      0FFh,0FFh,0E7h,0C3h
	db      0C3h,0E7h,0FFh,0FFh
	db      000h,03Ch,066h,042h
	db      042h,066h,03Ch,000h
	db      0FFh,0C3h,099h,0BDh
	db      0BDh,099h,0C3h,0FFh
	db      00Fh,007h,00Fh,07Dh
	db      0CCh,0CCh,0CCh,078h

	db      03Ch,066h,066h,066h
	db      03Ch,018h,07Eh,018h
	db      03Fh,033h,03Fh,030h
	db      030h,070h,0F0h,0E0h
	db      07Fh,063h,07Fh,063h
	db      063h,067h,0E6h,0C0h
	db      099h,05Ah,03Ch,0E7h
	db      0E7h,03Ch,05Ah,099h

	db      080h,0E0h,0F8h,0FEh
	db      0F8h,0E0h,080h,000h
	db      002h,00Eh,03Eh,0FEh
	db      03Eh,00Eh,002h,000h
	db      018h,03Ch,07Eh,018h
	db      018h,07Eh,03Ch,018h
	db      066h,066h,066h,066h
	db      066h,000h,066h,000h

	db      07Fh,0DBh,0DBh,07Bh
	db      01Bh,01Bh,01Bh,000h
	db      03Eh,063h,038h,06Ch
	db      06Ch,038h,0CCh,078h
	db      000h,000h,000h,000h
	db      07Eh,07Eh,07Eh,000h
	db      018h,03Ch,07Eh,018h
	db      07Eh,03Ch,018h,0FFh

	db      018h,03Ch,07Eh,018h
	db      018h,018h,018h,000h
	db      018h,018h,018h,018h
	db      07Eh,03Ch,018h,000h
	db      000h,018h,00Ch,0FEh
	db      00Ch,018h,000h,000h
	db      000h,030h,060h,0FEh
	db      060h,030h,000h,000h

	db      000h,000h,0C0h,0C0h
	db      0C0h,0FEh,000h,000h
	db      000h,024h,066h,0FFh
	db      066h,024h,000h,000h
	db      000h,018h,03Ch,07Eh
	db      0FFh,0FFh,000h,000h
	db      000h,0FFh,0FFh,07Eh
	db      03Ch,018h,000h,000h

	db      000h,000h,000h,000h
	db      000h,000h,000h,000h
	db      030h,078h,078h,030h
	db      030h,000h,030h,000h
	db      06Ch,06Ch,06Ch,000h
	db      000h,000h,000h,000h
	db      06Ch,06Ch,0FEh,06Ch
	db      0FEh,06Ch,06Ch,000h

	db      030h,07Ch,0C0h,078h
	db      00Ch,0F8h,030h,000h
	db      000h,0C6h,0CCh,018h
	db      030h,066h,0C6h,000h
	db      038h,06Ch,038h,076h
	db      0DCh,0CCh,076h,000h
	db      060h,060h,0C0h,000h
	db      000h,000h,000h,000h

	db      018h,030h,060h,060h
	db      060h,030h,018h,000h
	db      060h,030h,018h,018h
	db      018h,030h,060h,000h
	db      000h,066h,03Ch,0FFh
	db      03Ch,066h,000h,000h
	db      000h,030h,030h,0FCh
	db      030h,030h,000h,000h

	db      000h,000h,000h,000h
	db      000h,030h,030h,060h
	db      000h,000h,000h,0FCh
	db      000h,000h,000h,000h
	db      000h,000h,000h,000h
	db      000h,030h,030h,000h
	db      006h,00Ch,018h,030h
	db      060h,0C0h,080h,000h

	db      07Ch,0C6h,0CEh,0DEh
	db      0F6h,0E6h,07Ch,000h
	db      030h,070h,030h,030h
	db      030h,030h,0FCh,000h
	db      078h,0CCh,00Ch,038h
	db      060h,0CCh,0FCh,000h
	db      078h,0CCh,00Ch,038h
	db      00Ch,0CCh,078h,000h

	db      01Ch,03Ch,06Ch,0CCh
	db      0FEh,00Ch,01Eh,000h
	db      0FCh,0C0h,0F8h,00Ch
	db      00Ch,0CCh,078h,000h
	db      038h,060h,0C0h,0F8h
	db      0CCh,0CCh,078h,000h
	db      0FCh,0CCh,00Ch,018h
	db      030h,030h,030h,000h

	db      078h,0CCh,0CCh,078h
	db      0CCh,0CCh,078h,000h
	db      078h,0CCh,0CCh,07Ch
	db      00Ch,018h,070h,000h
	db      000h,030h,030h,000h
	db      000h,030h,030h,000h
	db      000h,030h,030h,000h
	db      000h,030h,030h,060h

	db      018h,030h,060h,0C0h
	db      060h,030h,018h,000h
	db      000h,000h,0FCh,000h
	db      000h,0FCh,000h,000h
	db      060h,030h,018h,00Ch
	db      018h,030h,060h,000h
	db      078h,0CCh,00Ch,018h
	db      030h,000h,030h,000h

	db      07Ch,0C6h,0DEh,0DEh
	db      0DEh,0C0h,078h,000h
	db      030h,078h,0CCh,0CCh
	db      0FCh,0CCh,0CCh,000h
	db      0FCh,066h,066h,07Ch
	db      066h,066h,0FCh,000h
	db      03Ch,066h,0C0h,0C0h
	db      0C0h,066h,03Ch,000h

	db      0F8h,06Ch,066h,066h
	db      066h,06Ch,0F8h,000h
	db      0FEh,062h,068h,078h
	db      068h,062h,0FEh,000h
	db      0FEh,062h,068h,078h
	db      068h,060h,0F0h,000h
	db      03Ch,066h,0C0h,0C0h
	db      0CEh,066h,03Eh,000h

	db      0CCh,0CCh,0CCh,0FCh
	db      0CCh,0CCh,0CCh,000h
	db      078h,030h,030h,030h
	db      030h,030h,078h,000h
	db      01Eh,00Ch,00Ch,00Ch
	db      0CCh,0CCh,078h,000h
	db      0E6h,066h,06Ch,078h
	db      06Ch,066h,0E6h,000h

	db      0F0h,060h,060h,060h
	db      062h,066h,0FEh,000h
	db      0C6h,0EEh,0FEh,0FEh
	db      0D6h,0C6h,0C6h,000h
	db      0C6h,0E6h,0F6h,0DEh
	db      0CEh,0C6h,0C6h,000h
	db      038h,06Ch,0C6h,0C6h
	db      0C6h,06Ch,038h,000h

	db      0FCh,066h,066h,07Ch
	db      060h,060h,0F0h,000h
	db      078h,0CCh,0CCh,0CCh
	db      0DCh,078h,01Ch,000h
	db      0FCh,066h,066h,07Ch
	db      06Ch,066h,0E6h,000h
	db      078h,0CCh,0E0h,070h
	db      01Ch,0CCh,078h,000h

	db      0FCh,0B4h,030h,030h
	db      030h,030h,078h,000h
	db      0CCh,0CCh,0CCh,0CCh
	db      0CCh,0CCh,0FCh,000h
	db      0CCh,0CCh,0CCh,0CCh
	db      0CCH,078h,030h,000h
	db      0C6h,0C6h,0C6h,0D6h
	db      0FEh,0EEh,0C6h,000h

	db      0C6h,0C6h,06Ch,038h
	db      038h,06Ch,0C6h,000h
	db      0CCh,0CCh,0CCh,078h
	db      030h,030h,078h,000h
	db      0FEh,0C6h,08Ch,018h
	db      032h,066h,0FEh,000h
	db      078h,060h,060h,060h
	db      060h,060h,078h,000h

	db      0C0h,060h,030h,018h
	db      00Ch,006h,002h,000h
	db      078h,018h,018h,018h
	db      018h,018h,078h,000h
	db      010h,038h,06Ch,0C6h
	db      000h,000h,000h,000h
	db      000h,000h,000h,000h
	db      000h,000h,000h,0FFh

	db      030h,030h,018h,000h
	db      000h,000h,000h,000h
	db      000h,000h,078h,00Ch
	db      07Ch,0CCh,076h,000h
	db      0E0h,060h,060h,07Ch
	db      066h,066h,0DCh,000h
	db      000h,000h,078h,0CCh
	db      0C0h,0CCh,078h,000h

	db      01Ch,00Ch,00Ch,07Ch
	db      0CCh,0CCh,076h,000h
	db      000h,000h,078h,0CCh
	db      0FCh,0C0h,078h,000h
	db      038h,06Ch,060h,0F0h
	db      060h,060h,0F0h,000h
	db      000h,000h,076h,0CCh
	db      0CCh,07Ch,00Ch,0F8h

	db      0E0h,060h,06Ch,076h
	db      066h,066h,0E6h,000h
	db      030h,000h,070h,030h
	db      030h,030h,078h,000h
	db      00Ch,000h,00Ch,00Ch
	db      00Ch,0CCh,0CCh,078h
	db      0E0h,060h,066h,06Ch
	db      078h,06Ch,0E6h,000h

	db      070h,030h,030h,030h
	db      030h,030h,078h,000h
	db      000h,000h,0CCh,0FEh
	db      0FEh,0D6h,0C6h,000h
	db      000h,000h,0F8h,0CCh
	db      0CCh,0CCh,0CCh,000h
	db      000h,000h,078h,0CCh
	db      0CCh,0CCh,078h,000h

	db      000h,000h,0DCh,066h
	db      066h,07Ch,060h,0F0h
	db      000h,000h,076h,0CCh
	db      0CCh,07Ch,00Ch,01Eh
	db      000h,000h,0DCh,076h
	db      066h,060h,0F0h,000h
	db      000h,000h,07Ch,0C0h
	db      078h,00Ch,0F8h,000h

	db      010h,030h,07Ch,030h
	db      030h,034h,018h,000h
	db      000h,000h,0CCh,0CCh
	db      0CCh,0CCh,076h,000h
	db      000h,000h,0CCh,0CCh
	db      0CCh,078h,030h,000h
	db      000h,000h,0C6h,0D6h
	db      0FEh,0FEh,06Ch,000h

	db      000h,000h,0C6h,06Ch
	db      038h,06Ch,0C6h,000h
	db      000h,000h,0CCh,0CCh
	db      0CCh,07Ch,00Ch,0F8h
	db      000h,000h,0FCh,098h
	db      030h,064h,0FCh,000h
	db      01Ch,030h,030h,0E0h
	db      030h,030h,01Ch,000h

	db      018h,018h,018h,000h
	db      018h,018h,018h,000h
	db      0E0h,030h,030h,01Ch
	db      030h,030h,0E0h,000h
	db      076h,0DCh,000h,000h
	db      000h,000h,000h,000h
	db      000h,010h,038h,06Ch
	db      0C6h,0C6h,0FEh,000h

; ******** ******** ******** ******** ******** ******** ******** ********

INT_1A:
	STI                                     ; User time_of_day bios service
	PUSH    DS
	PUSH    AX
	MOV     AX,40h
	MOV     DS,AX
	POP     AX                              ; Get request type
	CLI                                     ;  ...freeze clock
	OR      AH,AH
	JZ      TD_01                           ; Read time, AH=0
	DEC     AH
	JNZ     TD_02                           ;  ...invalid request
	MOV     [DS:6Ch],DX                     ; Set time,  AH=1
	MOV     [DS:6Eh],CX                     ;  ...set time hi
	MOV     Byte [DS:70h],0                 ;  ...not a new day
	JMP     short   TD_02

TD_01:  MOV     CX,[DS:6Eh]                     ; Read lo order time
	MOV     DX,[DS:6Ch]                     ;  ... hi order time
	CALL    TD_03                           ; Read resets overflow

TD_02:  STI                                     ; Unfreeze clock
	POP     DS
	IRET

TD_03:  MOV     AL,[DS:70h]                     ; Zero the overflow and return
	XOR     [DS:70h],AL                     ;  ...previous status in flags
	RET

INT_8:  STI                                     ; Routine services clock tick
	PUSH    DS
	PUSH    DX
	PUSH    AX
	MOV     AX,40h
	MOV     DS,AX
	DEC     Byte [DS:40h]                   ; Decrement motor count
	JNZ     TI_01                           ;  ...not time to shut off
	AND     Byte [DS:3Fh],11110000b         ; Else show motor off
	MOV     AL,0Ch                          ;  ...send motor off
	MOV     DX,3F2h                         ;  ...to the floppy
	OUT     DX,AL                           ;  ...disk controller

TI_01:  INC     Word [DS:6Ch]                   ; Bump lo order time of day
	JNZ     TI_02                           ;  ...no carry
	INC     Word [DS:6Eh]                   ; Bump hi order time of day

TI_02:  CMP     Word [DS:6Eh],18h               ; Is it midnight yet?
	JNZ     TI_03                           ;  ...no
	CMP     Word [DS:6Ch],0B0h              ; Possibly, check lo order
	JNZ     TI_03                           ;  ...not midnight
	MOV     Word [DS:6Eh],0                 ; Midnight, reset hi order
	MOV     Word [DS:6Ch],0                 ;  ...lo order ticks
	MOV     Byte [DS:70h],1                 ; Show new day since last read

TI_03:  INT     1Ch                             ; Execute user clock service
	MOV     AL,20h                          ;  ...send end_of_interrupt
	OUT     20h,AL                          ;  ...to 8259 interrupt chip
	POP     AX
	POP     DX
	POP     DS
	IRET

; ******** ******** ******** ******** ******** ******** ******** ********

blank:
	iret

	times   0xFFF0-($-$$) db 0xFF

	jmp     0xF000:start

	times   65536-($-$$) db 0xFF
