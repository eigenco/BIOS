; int 08h: clock tick
; int 09h: keypress
; int 10h: video, ah = 0 - 3 and ah = 5 - 15
; int 12h: memory, mov ax, 640
; int 16h: keyboard, ah = 0 - 2
; int 1ah: time of day, ah = 0 - 3
; int 1dh: video mode tables

entry   macro   x
	pad     =BANNER - $ + x - 0E000h
	if pad LT 0
	.err
	%out    'No room for ENTRY point'
	endif
	if pad GT 0
	db      pad DUP(0FFh)
	endif
endm

LF      equ     0Ah
CR      equ     0Dh

ASSUME  DS:code, SS:code, CS:code, ES:code
data    SEGMENT at 40h                          ; IBM compatible data structure
	dw      4 dup(?)        ; 40:00         ; RS232 com. ports - up to four
	dw      4 dup(?)        ; 40:08         ; Printer ports    - up to four
	dw      ?               ; 40:10         ; Equipment present word
						; =  (# serial ports) *     2.
						;  + (1 iff toy port) *    16.
						;  + (# parallel LPT) *    64.
						;  + (1 iff floppies) *   256.
						;  + (# 64K sys ram ) *  1024.
						;  + (init crt mode ) *  4096.
						;  + (# of floppies ) * 16384.
	db      ?               ; 40:12         ; MFG test flags, unused by us
	dw      ?               ; 40:13         ; Memory size, kilobytes
	db      ?               ; 40:15         ; IPL errors<-table/scratchpad
	db      ?                               ;  ...unused
;---------------[Keyboard data area]------------;
	db      ?,?             ; 40:17         ; Shift/Alt/etc. keyboard flags
	db      ?               ; 40:19         ; Alt-KEYPAD char. goes here
	dw      ?               ; 40:1A         ;  --> keyboard buffer head
	dw      ?               ; 40:1C         ;  --> keyboard buffer tail
	dw      16 dup(?)       ; 40:1E         ; Keyboard Buffer (Scan,Value)
;---------------[Diskette data area]------------;
	db      ?               ; 40:3E         ; Drive Calibration bits 0 - 3
	db      ?               ; 40:3F         ; Drive Motor(s) on 0-3,7=write
	db      ?               ; 40:40         ; Ticks (18/sec) til motor off
	db      ?               ; 40:41         ; Floppy return code stat byte
						;  1 = bad ic 765 command req.
						;  2 = address mark not found
						;  3 = write to protected disk
						;  4 = sector not found
						;  8 = data late (DMA overrun)
						;  9 = DMA failed 64K page end
						; 16 = bad CRC on floppy read
						; 32 = bad NEC 765 controller
						; 64 = seek operation failed
						;128 = disk drive timed out
	db      7 dup(?)        ; 40:42         ; Status bytes from NEC 765
;---------------[Video display area]------------;
	db      ?               ; 40:49         ; Current CRT mode  (software)
						;  0 = 40 x 25 text (no color)
						;  1 = 40 x 25 text (16 color)
						;  2 = 80 x 25 text (no color)
						;  3 = 80 x 25 text (16 color)
						;  4 = 320 x 200 grafix 4 color
						;  5 = 320 x 200 grafix 0 color
						;  6 = 640 x 200 grafix 0 color
						;  7 = 80 x 25 text (mono card)
	dw      ?               ; 40:4A         ; Columns on CRT screen
	dw      ?               ; 40:4C         ; Bytes in the regen region
	dw      ?               ; 40:4E         ; Byte offset in regen region
	dw      8 dup(?)        ; 40:50         ; Cursor pos for up to 8 pages
	dw      ?               ; 40:60         ; Current cursor mode setting
	db      ?               ; 40:62         ; Current page on display
	dw      ?               ; 40:63         ; Base addres (B000h or B800h)
	db      ?               ; 40:65         ; ic 6845 mode reg. (hardware)
	db      ?               ; 40:66         ; Current CGA palette
;---------------[Used to setup ROM]-------------;
	dw      ?,?             ; 40:67         ; Eprom base Offset,Segment
	db      ?               ; 40:6B         ; Last spurious interrupt IRQ
;---------------[Timer data area]---------------;
	dw      ?               ; 40:6C         ; Ticks since midnite (lo)
	dw      ?               ; 40:6E         ; Ticks since midnite (hi)
	db      ?               ; 40:70         ; Non-zero if new day
;---------------[System data area]--------------;
	db      ?               ; 40:71         ; Sign bit set iff break
	dw      ?               ; 40:72         ; Warm boot iff 1234h value
;---------------[Hard disk scratchpad]----------;
	dw      ?,?             ; 40:74         ;
;---------------[Timout areas/PRT/LPT]----------;
	db      4 dup(?)        ; 40:78         ; Ticks for LPT 1-4 timeouts
	db      4 dup(?)        ; 40:7C         ; Ticks for COM 1-4 timeouts
;---------------[Keyboard buf start/nd]---------;
	dw      ?               ; 40:80         ; Contains 1Eh, buffer start
	dw      ?               ; 40:82         ; Contains 3Eh, buffer end
data    ENDS

code    SEGMENT
	ORG     0E000h
BANNER:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	ENTRY   0E05Bh                          ; IBM restart entry point

COLD:   MOV     AX,40h                          ; Entered by POWER_ON/RESET
	MOV     DS,AX
	MOV     Word ptr DS:72h,0               ; Show data areas not init

WARM:   CLI                                     ; Begin FLAG test of CPU
	XOR     AX,AX
	JB      HALT
	JO      HALT
	JS      HALT
	JNZ     HALT
	JPO     HALT
	ADD     AX,1
	JZ      HALT
	JPE     HALT
	SUB     AX,8002h
	JS      HALT
	INC     AX
	JNO     HALT
	SHL     AX,1
	JNB     HALT
	JNZ     HALT
	SHL     AX,1
	JB      HALT

	MOV     BX,5555h                        ; Begin REGISTER test of CPU
CPUTST: MOV     BP,BX
	MOV     CX,BP
	MOV     SP,CX
	MOV     DX,SP
	MOV     SS,DX
	MOV     SI,SS
	MOV     ES,SI
	MOV     DI,ES
	MOV     DS,DI
	MOV     AX,DS
	CMP     AX,5555h
	JNZ     CPU1
	NOT     AX
	MOV     BX,AX
	JMP     CPUTST

CPU1:   XOR     AX,0AAAAh
	JZ      CPU_OK

HALT:   HLT

CPU_OK: CLD
	MOV     AL,0                            ; Prepare to initialize
	OUT     0A0h,AL                         ;  ...no NMI interrupts
	MOV     DX,3D8h                         ; Load Color Graphic port
	OUT     DX,AL                           ;  ...no video display
	MOV     DX,3B8h                         ; Load Monochrome port
	INC     AL                              ;  ...no video display
	OUT     DX,AL                           ;  ...write it out
	MOV     AL,99h                          ; Program 8255 PIA chip
	OUT     63h,AL                          ;  ...Ports A  C, inputs
	MOV     AL,0A5h                         ; Set (non)turbo mode
	OUT     61h,AL                          ;  ...on main board
	JMP     RFRESH                          ; Setup 8253 DMA refresh timer

IC8237: MOV     AL,0                            ; Do some initialization
	OUT     81h,AL                          ;  ...dma page reg, chan 2
	OUT     82h,AL                          ;  ...dma page reg, chan 3
	OUT     83h,AL                          ;  ...dma page reg, chan 0,1
	OUT     0Dh,AL                          ; Stop DMA on 8237 chip
	MOV     AL,58h                          ; Refresh auto-init dummy read
	OUT     0Bh,AL                          ;   ...on channel 0 of DMA chip
	MOV     AL,41h                          ; Block verify
	OUT     0Bh,AL                          ;   ...on channel 1 of DMA chip
	MOV     AL,42h                          ; Block verify
	OUT     0Bh,AL                          ;   ...on channel 2 of DMA chip
	MOV     AL,43h                          ; Block verify
	OUT     0Bh,AL                          ;   ...on channel 3 of DMA chip
	MOV     AL,0FFh                         ; Refresh byte count
	OUT     1,AL                            ;   ...send lo order
	OUT     1,AL                            ;   ...send hi order
	MOV     AL,0                            ; Initialize 8237 command reg
	OUT     8,AL                            ;   ...with zero
	OUT     0Ah,AL                          ; Enable DMA on all channels
	MOV     AL,36h                          ; Set up 8253 timer chip
	OUT     43h,AL                          ;   ...chan 0 is time of day
	MOV     AL,0                            ; Request a divide by
	OUT     40h,AL                          ;   ...65536 decimal
	OUT     40h,AL                          ;   ...0000h or 18.2 tick/sec
	MOV     DX,213h                         ; Expansion unit port
	MOV     AL,1                            ;  ...enable it
	OUT     DX,AL                           ;  ...do the enable
	MOV     AX,40h                          ; Get bios impure segment
	MOV     DS,AX                           ;  ...into DS register
	MOV     SI,DS:72h                       ; Save reset flag in SI reg
	XOR     AX,AX                           ;  ...cause memory check
	MOV     BP,AX                           ;  ...will clobber the flag
	MOV     BX,AX                           ; Start at segment 0000h
	MOV     DX,55AAh                        ;  ...get pattern
	CLD                                     ; Strings auto-increment

MEMSIZ: XOR     DI,DI                           ; Location XXXX:0
	MOV     ES,BX                           ;  ...load segment
	MOV     ES:[DI],DX                      ;  ...write pattern
	CMP     DX,ES:[DI]                      ;  ...compare
	JNZ     MEM_ND                          ;  ...failed, memory end
	MOV     CX,2000h                        ; Else zero 16 kilobytes
	REPZ    STOSW                           ;  ...with instruction
	ADD     BH,4                            ;  ...get next 16K bytes
	CMP     BH,0A0h                         ; Found max legal IBM ram?
	JNZ     MEMSIZ                          ;  ...no, then check more

MEM_ND: MOV     DS:72h,SI                       ; Save pointer
	XOR     AX,AX
	MOV     ES,AX                           ; ES = vector segment
	MOV     AX,80h
	MOV     SS,AX                           ; Set up temporary stack at
	MOV     SP,100h                         ;  0080:0100 for memory check
	PUSH    BP
	PUSH    BX
	MOV     BP,2
	CALL    MEMTST                          ; Memory check ES:0 - ES:0400
	POP     AX
	MOV     CL,6
	SHR     AX,CL
	MOV     DS:13h,AX
	POP     AX
	JNB     MEM_01

MEM_01: MOV     DS:15h,AL                       ; Save IPL error code
	XOR     AX,AX
	PUSH    AX
	PUSH    AX
	PUSH    AX
	PUSH    AX
	PUSH    AX
	MOV     AX,30h                          ; Set up IBM-compatible stack
	MOV     SS,AX                           ;  ...segment 0030h
	MOV     SP,100h                         ;  ...offset  0100h
	PUSH    DS
	MOV     BX,0E000h                       ; Check BIOS eprom
	PUSH    CS
	POP     DS                              ;  ...at F000:E000
	MOV     AH,1
	CALL    CHKSUM                          ;  ...for valid checksum
	POP     DS                              ;  ...restore impure<-DS
	JZ      IC8259

IC8259: CLI                                     ; Init interrupt controller
	MOV     AL,13h
	OUT     20h,AL
	MOV     AL,8
	OUT     21h,AL
	MOV     AL,9
	OUT     21h,AL
	MOV     AL,0FFh
	OUT     21h,AL
	PUSH    DS
	XOR     AX,AX                           ; 8 nonsense vectors begin table
	MOV     ES,AX                           ;  ...at segment 0000h
	PUSH    CS
	POP     DS
	MOV     CX,8                            ; Vectors 00h - 07h unused
	XOR     DI,DI                           ;  ...we start at vec 00h

LO_VEC:
	MOV     AX, offset DUMMY
	STOSW
	MOV     AX,CS                           ;  ...bios ROM segment
	STOSW
	LOOP    LO_VEC

	MOV     SI,offset VECTORS               ; SI --> Vector address table
	MOV     CX,18h                          ;  ... vectors 08h - 1Fh busy

HI_VEC: MOVSW                                   ; Get INTERRUPT bios ROM offset
	MOV     AX,CS
	STOSW                                   ;  ...INTERRUPT bios ROM segment
	LOOP    HI_VEC

	MOV     AX,0F600h                       ; AX --> Rom basic segment
	MOV     DS,AX                           ; DS -->  "    "     "
	XOR     BX,BX                           ; BX  =  Rom basic offset
	MOV     AH,4                            ; Four basic roms to check

	MOV     BP,SP                           ; Save the stack pointer
	PUSH    CS                              ;  ...push code segment
	MOV     DX,offset SKIP                  ; Save the code offset
	PUSH    DX                              ;  ...for RAM_PATCH subroutine
	MOV     DX,0EA90h                       ; Mov DX,'NOP,JMP_FAR'
	PUSH    DX                              ;  ...save it on stack
	MOV     DX,0178Bh                       ; Mov DX,'MOV DX,[BX]'
	PUSH    DX                              ;  ...save it on stack
	PUSH    SS                              ; Save stack segment
	MOV     DX,SP                           ;  ...get the stack offset
	ADD     DX,02h                          ;  ...calculate xfer addr.
	PUSH    DX                              ;  ...save it on the stack

	;RETF                                    ; Test for BASIC rom
	db      0CBh

SKIP:   MOV     SP,BP                           ; Restore the stack pointer
	CMP     DL,DH                           ;  ...compare 1st and 2nd byte
	JE      kosher                          ;  ...perfection.  No piracy

B_ROM:  CALL    CHKSUM                          ; Scan for BASIC roms
	JNZ     kosher                          ;  ...bad basic rom
	DEC     AH                              ; Continue
	JNZ     B_ROM                           ;  ...yes, more

	POP     DS                              ; Else valid  basic
	MOV     DI,60h                          ;  ...install basic

	XOR     AX,AX                           ;  ...zero  BASIC interrupt
	STOSW                                   ;  ...offset
	MOV     AX,0F600h                       ;  ...F600h BASIC interrupt
	STOSW                                   ;  ...segment

	PUSH    DS
kosher: POP     DS                              ; Setup special low vectors

	MOV     Word ptr ES:7Ch,0               ; No special graphics chars.
	MOV     Word ptr ES:7Eh,0               ;  ...so zero vector 1Fh
	MOV     DX,61h
	IN      AL,DX                           ; Read machine flags
	OR      AL,30h                          ;  ...clear old parity error
	OUT     DX,AL                           ; Write them back to reset
	AND     AL,0CFh                         ;  ...enable parity
	OUT     DX,AL                           ; Write back, parity enabled
	MOV     AL,80h                          ;  ...allow NMI interrupts
	OUT     0A0h,AL
	MOV     AX,30h                          ; Load monochrome
	MOV     DS:10h,AX                       ;  ...say found
	INT     10h                             ;  ...initialize
	MOV     AX,20h                          ; Load CGA 80 x 25
	MOV     DS:10h,AX                       ;  ...say found
	INT     10h                             ;  ...initialize
	IN      AL,62h
	AND     AL,0Fh
	MOV     AH,AL
	MOV     AL,0ADh
	OUT     61h,AL
	IN      AL,62h
	MOV     CL,4
	SHL     AL,CL
	OR      AL,AH
	MOV     AH,0
	MOV     DS:10h,AX
	AND     AL,30h                          ; Test for Video
	JNZ     LE232                           ;  ...present
	MOV     AX,offset DUMMY                 ; No CRT found, dummy INT_10
	MOV     ES:40h,AX                       ;  ...save offset
	JMP     short LE235

LE232:  CALL    V_INIT                          ; Setup video

LE235:  MOV     AL,8                            ; Read low switches
	OUT     61h,AL
	MOV     CX,2956h

WAIT_1: LOOP    WAIT_1
	MOV     AL,0C8h                         ; Keyboard acknowledge
	OUT     61h,AL                          ;  ...send the request
	XOR     AL,80h                          ; Toggle to enable
	OUT     61h,AL                          ;  ...send key enable
	MOV     AX,1Eh                          ; Offset to buffer start
	MOV     DS:1Ah,AX                       ; Buffer head pointer
	MOV     DS:1Ch,AX                       ; Buffer tail pointer
	MOV     DS:80h,AX                       ; Buffer start
	ADD     AX,20h                          ;  ...size
	MOV     DS:82h,AX                       ; Buffer end
	JMP     short   V_CONT

FAO:    MOV     DL,AL                           ; Formatted ascii output

FAO_1:  MOV     AX,BX                           ; Get position for
	CALL    LOCATE                          ;  ...cursor routine
	PUSH    SI                              ; Get string address
	CALL    PRINT                           ;  ...print string
	MOV     AX,ES:[BP+0]                    ; Get port # to print
	CALL    BIGNUM                          ;  ...four digits
	POP     SI                              ; Restore string address
	INC     BP                              ;  ...Address of port
	INC     BP                              ;  ...is two bytes long
	INC     BH                              ;  ...down one line
	DEC     DL                              ; Decrement device count
	JNZ     FAO_1                           ; ...back for more
	RET

K_BYTE: CLC                                     ; Say no error
	MOV     AL,DL                           ;  ...size "checked"
	INC     AL                              ;  ...show more
	DAA
	MOV     DL,AL
	JNB     KBY_01
	MOV     AL,DH                           ;  ...do carry
	ADC     AL,0
	DAA
	MOV     DH,AL

KBY_01: MOV     AL,DH
	CALL    DIGIT                           ; Print hex digit
	MOV     AL,DL
	MOV     CL,4
	ROR     AL,CL
	CALL    DIGIT                           ; Print hex digit
	MOV     AL,DL
	CALL    DIGIT                           ; Print hex digit
	RET

TIMER:  MOV     DX,241h                         ; Check for timer #2 port
	CLI
	IN      AL,DX                           ;  ..read BCD seconds/100
	STI
	CMP     AL,99h                          ; Are BCD digits in range?
	JBE     SER_01                          ;  ...yes, port exists

	MOV     DX,341h                         ; Check for timer #1 port
	CLI
	IN      AL,DX                           ;  ..read BCD seconds/100
	STI
	CMP     AL,99h                          ; Are BCD digits in range?
	JBE     SER_01                          ;  ...yes, port exists

	STC                                     ; No hardware, ports 0FFh
	RET

SER_01: CLC                                     ; Found timer(s) answering
	RET

V_CONT: MOV     BP,4                            ; Assume monochrome, 4K memory
	MOV     BX,0B000h                       ;  ...segment in BX
	MOV     AL,DS:49h                       ; Get the video mode
	CMP     AL,7                            ;  ...was it mono?
	JZ      M_SEG                           ;  ...yes, skip
	MOV     BP,10h                          ; Else CGA, has 16K memory
	MOV     BX,0B800h                       ;  ...segment in BX

M_SEG:  PUSH    BX
	POP     ES                              ; Load video seg in ES
	MOV     AL,DS:65h
	AND     AL,0F7h
	MOV     DX,DS:63h                       ; Get 6845 index port
	ADD     DX,4                            ;  ...add offset for
	OUT     DX,AL                           ; 6845 controller port

CRTRAM: CALL    MEMTST                          ; Memory check ES:0 - ES:0400
	DEC     BP
	JNZ     CRTRAM                          ; Loop until CRT RAM checked
	JNB     LE2F5

LE2F5:  CALL    V_INIT

NOGAME: MOV     DX,0C000h                       ; ROM segment start
	PUSH    DS

FNDROM: MOV     DS,DX                           ; Load ROM segment
	XOR     BX,BX                           ;  ...ID offset
	MOV     AX,[BX]                         ; Read the ROM id
	CMP     AX,0AA55h
	JNZ     NXTROM                          ;  ...not valid ROM
	MOV     AX,40h
	MOV     ES,AX
	MOV     AH,0
	MOV     AL,[BX+2]                       ; Get ROM size (bytes * 512)
	MOV     CL,5
	SHL     AX,CL                           ; Now ROM size in segments
	ADD     DX,AX                           ;  ...add base segment
	MOV     CL,4
	SHL     AX,CL                           ; ROM address in bytes
	MOV     CX,AX                           ;  ...checksum requires CX
	CALL    CHK_01                          ; Find ROM checksum
	JNZ     BADROM                          ;  ...bad ROM
	PUSH    DX
	MOV     Word ptr ES:67h,3               ; Offset  for ROM being setup
	MOV     ES:69h,DS                       ; Segment for ROM being setup
	CALL    DWORD PTR ES:67h                ;  ...call ROM initialization
	POP     DX
	JMP     short   FND_01

BADROM:

NXTROM: ADD     DX,80h                          ; Segment for next ROM

FND_01: CMP     DX,0F600h                       ; End of ROM space
	JL      FNDROM                          ;  ...no, continue
	POP     DS
	IN      AL,21h                          ; Read interrupt mask register
	AND     AL,0BCh                         ;  ...allow system timer
	OUT     21h,AL                          ;  ...set it
	MOV     AH,1
	MOV     CH,0F0h
	INT     10h                             ; Set cursor type
	CALL    BLANK                           ;  ...clear display
	PUSH    DS
	PUSH    CS
	POP     DS
	POP     ES
	jmp     RESET

VALID:  
	MOV     AX,81Eh                         ; Where to move cursor
	CALL    LOCATE                          ;  ...position cursor
	CALL    PRINT                           ;  ...and print string
	MOV     AX,91Ch                         ; Where to move cursor
	CALL    LOCATE                          ;  ...position cursor
	MOV     BL,17h                          ; Character count

FENCE:  MOV     AL,'-'                          ; Load ascii minus
	CALL    OUTCHR                          ;  ...and print it
	DEC     BL
	JNZ     FENCE
	MOV     AX,0A21h                        ; Where to move cursor
	CALL    LOCATE                          ;  ...position cursor
	MOV     AL,ES:49h                       ; Get CRT mode
	CMP     AL,7
	JZ      FEN_01                          ;  ...monochrome

FEN_01: 
	MOV     BX,0B21h
	MOV     AL,ES:11h                       ; Get equipment byte
	PUSH    AX
	MOV     CL,6
	ROR     AL,CL
	AND     AL,3                            ; Number of printers
	JZ      FEN_02
	MOV     BP,8

FEN_02: POP     AX                              ; Equipment byte restore
	PUSH    AX                              ; Save a copy of equip. byte
	TEST    AL,10h
	JZ      NO_TOY                          ; Jump if no game controller
	MOV     AX,BX
	CALL    LOCATE                          ; Position cursor
	INC     BH                              ;  ...scroll line

NO_TOY: CALL    TIMER                           ; Timer devices?
	JB      NO_TIM                          ;  ...skip if none
	MOV     AX,BX
	CALL    LOCATE                          ; Position cursor
	INC     BH

NO_TIM: POP     AX
	ROR     AL,1                            ; Check for COM port
	AND     AL,3
	JZ      NO_COM                          ; ...skip if no com
	XOR     BP,BP

NO_COM: MOV     AX,121Ch                        ; Where to position cursor
	CALL    LOCATE                          ;  ...position cursor
	PUSH    ES
	MOV     BP,ES:13h                       ; Memory size (1 K blocks)
	DEC     BP
	DEC     BP
	MOV     SI,2
	MOV     DX,SI
	MOV     AX,80h
	MOV     ES,AX

CUTE:   MOV     AX,122Bh                        ; Cursory check of memory
	CALL    LOCATE                          ;  ...position cursor
	CALL    K_BYTE                          ;  ...print size in K
	DEC     BP
	JNZ     CUTE
	POP     ES

RESET:  MOV     BL,2                            ; Do a warm boot
	CALL    BLANK                           ; ...clear display
	MOV     Word ptr ES:72h,1234h           ; Show cold start done
	MOV     AH,1
	MOV     CX,607h                         ; Set underline cursor
	INT     10h
	INT     19h                             ; Boot the machine

KY_PAT: CMP     AH,53h                          ; Patch for CTRL ALT - toggle
	JNZ     KY_PA1                          ;  ...not a DEL (reset)
	JMP     RELOAD                          ; Control-Alt-Del pressed

KY_PA1: CMP     AH,4Ah                          ; Is it a keypad "-" ?
	JNZ     KY_PA2                          ;  ...no, skip
	PUSH    AX
	PUSH    BX
	PUSH    CX
	IN      AL,61h                          ; Read equipment flags
	XOR     AL,0Ch                          ;  ...toggle speed
	OUT     61h,AL                          ; Write new flags back

	MOV     AH,1                            ; Video func=Set cursor type
	MOV     CX,607h                         ;  ...start at 6, end at 7
	AND     AL,4                            ; Is turbo mode set?
	JZ      KY_CUR                          ;  ...no, keep big cursor
	MOV     CH,0                            ; Else set tiny cursor

KY_CUR: INT     10h                             ; Set cursor type service
	MOV     BX,DS:80h                       ;  ...get start of key buf
	MOV     DS:1Ah,BX                       ;  ...set head  to start
	MOV     DS:1Ch,BX                       ;  ...set tail  to start
	POP     CX
	POP     BX
	POP     AX

KY_PA2: JMP     KY_PAD                          ; Calculate ALT keypad entry

RFRESH: MOV     AL,54h                          ; Set up 8237 dma memory refresh
	OUT     43h,AL                          ;  ...channel 1, make pulse
	MOV     AL,12h                          ;  ...every 12h clock ticks
	OUT     41h,AL                          ;  ...64K done in 1 millisecond
	MOV     AL,40h
	OUT     43h,AL
	JMP     IC8237                          ; Continue initialization
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	ENTRY   0E82Eh                          ; IBM entry, key bios service

INT_16: STI                                     ; Keyboard bios services
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
	MOV     BX,DS:1Ah                       ;  ...point to buffer head
	CMP     BX,DS:1Ch                       ; If not equal to buffer tail
	JNZ     KPD_R1                          ;  ...char waiting to be read
	STI                                     ; Else allow interrupts
	JMP     KPD_RD                          ;  ...wait for him to type

KPD_R1: MOV     AX,[BX]                         ; Fetch the character
	INC     BX                              ;  ...point to next character
	INC     BX                              ;  ...char = scan code + shift
	MOV     DS:1Ah,BX                       ; Save position in head
	CMP     BX,DS:82h                       ;  ...buffer overflowed?
	JNZ     KPD_XT                          ;  ...no, done
	MOV     BX,DS:80h                       ; Else reset to point at start
	MOV     DS:1Ah,BX                       ;  ...and correct head position
	JMP     KPD_XT

KPD_WT: CLI                                     ; No interrupts, critical code
	MOV     BX,DS:1Ah                       ;  ...point to buffer head
	CMP     BX,DS:1Ch                       ;  ...equal buffer tail?
	MOV     AX,[BX]                         ;     (fetch, look ahead)
	STI                                     ; Enable interrupts
	POP     BX
	POP     DS
	db      0CAh
	dw      2
	;RETF    2                               ; Do IRET, preserve flags

KPD_SH: MOV     AL,DS:17h                       ; Read keypad shift status
	JMP     KPD_XT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	ENTRY   0E885h                          ; Align INT_9 at correct place

LE885   db      000h,037h,02Eh,020h
	db      02Fh,030h,031h,021h
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

LE8CC   db      032h,036h,02Dh,0BBh
	db      0BCh,0BDh,0BEh,0BFh
	db      0C0h,0C1h,0C2h,0C3h
	db      0C4h,020h,031h,033h
	db      034h,035h,037h,038h
	db      039h,030h,03Dh,01Bh
	db      008h,05Bh,05Dh,00Dh
	db      05Ch,02Ah,009h,03Bh
	db      027h,060h,02Ch,02Eh
	db      02Fh

LE8F1   db      040h,05Eh,05Fh,0D4h
	db      0D5h,0D6h,0D7h,0D8h
	db      0D9h,0DAh,0DBh,0DCh
	db      0DDh,020h,021h,023h
	db      024h,025h,026h,02Ah
	db      028h,029h,02Bh,01Bh
	db      008h,07Bh,07Dh,00Dh
	db      07Ch,005h,08Fh,03Ah
	db      022h,07Eh,03Ch,03Eh
	db      03Fh

LE916   db      003h,01Eh,01Fh,0DEh
	db      0DFh,0E0h,0E1h,0E2h
	db      0E3h,0E4h,0E5h,0E6h
	db      0E7h,020h,005h,005h
	db      005h,005h,005h,005h
	db      005h,005h,005h,01Bh
	db      07Fh,01Bh,01Dh,00Ah
	db      01Ch,0F2h,005h,005h
	db      005h,005h,005h,005h
	db      005h

LE93B   db      0F9h,0FDh,002h,0E8h
	db      0E9h,0EAh,0EBh,0ECh
	db      0EDh,0EEh,0EFh,0F0h
	db      0F1h,020h,0F8h,0FAh
	db      0FBh,0FCh,0FEh,0FFh
	db      000h,001h,003h,005h
	db      005h,005h,005h,005h
	db      005h,005h,005h,005h
	db      005h,005h,005h,005h
	db      005h

LE960   db      '789-456+1230.'

LE96D   db      0F7h,005h,004h,005h
	db      0F3h,005h,0F4h,005h
	db      0F5h,005h,0F6h,005h
	db      005h

LE97A   db      0C7h,0C8h,0C9h,02Dh
	db      0CBh,005h,0CDh,02Bh
	db      0CFh,0D0h,0D1h,0D2h
	db      0D3h

INT_9:  STI                                     ; Key press hardware interrupt
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
	IN      AL,60h                          ; Read the scan code
	PUSH    AX                              ;  ...save it
	IN      AL,61h                          ; Get control port status
	PUSH    AX                              ;  ...save it
	OR      AL,80h
	OUT     61h,AL                          ; Reset keyboard
	POP     AX                              ;  ...restore control status
	OUT     61h,AL                          ;  ...keyboard has been reset
	POP     AX                              ;  ...restore scan code
	MOV     AH,AL                           ; Save a copy of code
	CMP     AL,0FFh                         ;  ...check for overrun
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

KY_01:  AND     AL,7Fh                          ; Valid scan code, no break
	CMP     AL,46h
	JBE     KY_02
	JMP     KY_CT8

KY_02:  MOV     BX,offset LE885                 ; Table for ESC thru Scroll Lck
	XLAT    CS:[BX]                         ;  ...translate to Ascii
	OR      AL,AL                           ; Sign flags "Shift" type key
	JS      KY_FLG                          ;  ...shift,caps,num,scroll etc
	OR      AH,AH                           ; Invalid scan code?
	JS      KY_EOI                          ;  ...exit if so
	JMP     short   KY_ASC                  ; Else normal character

KY_FLG: AND     AL,7Fh                          ; Remove sign flag bit
	OR      AH,AH                           ;  ...check scan code
	JS      KY_SUP                          ;  ...negative, key released
	CMP     AL,10h                          ; Is it a "toggle" type key?
	JNB     KY_TOG                          ;  ...yes
	OR      DS:17h,AL                       ; Else set bit in "flag" byte
	JMP     KY_EOI                          ;  ...and exit

KY_TOG: TEST    Byte ptr DS:17h,4               ; Control key pressed?
	JNZ     KY_ASC                          ;  ...yes, skip
	TEST    AL,DS:18h                       ; Else check "CAPS, NUM, SCRL"
	JNZ     KY_EOI                          ;  ...set, invalid, exit
	OR      DS:18h,AL                       ; Show set in "flag_1" byte
	XOR     DS:17h,AL                       ;  ...flip bits in "flag" byte
	JMP     KY_EOI

KY_SUP: CMP     AL,10h                          ; Released - is it "toggle" key
	JNB     KY_TUP                          ;  ...skip if so
	NOT     AL                              ; Else form two's complement
	AND     DS:17h,AL                       ;  ...to do BIT_CLEAR "flags"
	CMP     AL,0F7h                         ; ALT key release special case
	JNZ     KY_EOI                          ;  ...no, exit
	MOV     AL,DS:19h                       ; Else get ALT-keypad character
	MOV     AH,0                            ;  ...pretend null scan code
	MOV     DS:19h,AH                       ;  ...zero ALT-keypad character
	CMP     AL,AH                           ; Was there a valid ALT-keypad?
	JZ      KY_EOI                          ;  ...no, ignore, exit
	JMP     KY_NUL                          ; Else stuff it in ASCII buffer

KY_TUP: NOT     AL                              ; Form complement of toggle key
	AND     DS:18h,AL                       ;  ...to do BIT_CLEAR "flag_1"
	JMP     KY_EOI

KY_ASC: TEST    Byte ptr DS:18h,8               ; Scroll lock pressed?
	JZ      KY_NLK                          ;  ...no
	CMP     AH,45h                          ; Is this a NUM LOCK character?
	JZ      KY_03                           ;  ...no
	AND     Byte ptr DS:18h,0F7h            ; Else clear bits in "flag_1"

KY_03:  JMP     KY_EOI                          ;  ...and exit

KY_NLK: TEST    Byte ptr DS:17h,8               ; ALT key pressed?
	JNZ     KY_ALT                          ;  ...yes
	TEST    Byte ptr DS:17h,4               ; CTRL key pressed?
	JNZ     KY_CTL                          ;  ...yes
	TEST    Byte ptr DS:17h,3               ; Either shift key pressed?
	JNZ     KY_SKP                          ;  ...yes
	JMP     KY_LC                           ; Else plain old lower case
KY_SKP: JMP     short   KY_PRT                  ; Shift key pressed

KY_ALT: CMP     AL,1Ah                          ; Control key pressed?
	JA      KY_AGN                          ;  ...no, skip
	MOV     AL,0                            ; Else zero character
	JMP     KY_BFR

KY_AGN: MOV     BX,offset LE93B                 ; Load secondary translater
	SUB     AL,20h                          ;  ...assume printing char.
	XLAT    CS:[BX]                         ;  ...translate again
	JMP     KY_COM

KY_CTL: CMP     AH,46h                          ; Scroll lock key?
	JNZ     KY_CT1                          ;  ...no, skip
	MOV     Byte ptr DS:71h,80h             ; Else CTRL-"Scroll" = break
	MOV     AX,DS:80h                       ;  ...get key buffer start
	MOV     DS:1Ch,AX                       ;  ...get key tail to start
	MOV     DS:1Ah,AX                       ;  ...get key head to start
	INT     1Bh                             ; Issue a "Break" interrupt
	SUB     AX,AX
	JMP     KY_CO2

KY_CT1: CMP     AH,45h                          ; Num lock key?
	JNZ     KY_CT2                          ;  ...no, skip
	OR      Byte ptr DS:18h,8               ; Else show scroll lock
	MOV     AL,20h                          ;  ...send end_of_interrupt
	OUT     20h,AL                          ;  ...to 8259 int. controller
	CMP     Byte ptr DS:49h,7               ; Monochrome monitor?
	JZ      KY_POL                          ;  ...yes, skip
	MOV     DX,3D8h                         ; Else reset mode
	MOV     AL,DS:65h                       ;  ...for the
	OUT     DX,AL                           ;  ...CGA color card

KY_POL: TEST    Byte ptr DS:18h,8               ; Wait for him to type
	JNZ     KY_POL                          ;  ...not yet
	JMP     KY_XIT

KY_CT2: CMP     AH,3                            ; Is it a Control \ (null) ?
	JNZ     KY_CT3                          ;  ...no
	MOV     AL,0                            ; Else force a null

KY_CT4: JMP     KY_BFR                          ;  ...save in buffer

KY_CT3: CMP     AL,1Ah                          ; Is it a control character?
	JBE     KY_CT4                          ;  ...yes
	MOV     BX,offset LE916                 ; Else it needs more
	SUB     AL,20h                          ;  ...translation
	XLAT    CS:[BX]
	JMP     KY_COM

KY_PRT: CMP     AH,37h                          ; Print_Screen pressed?
	JNZ     KY_CT5
	MOV     AL,20h                          ; Yes, send end_of_interrupt
	OUT     20h,AL                          ;  ...to 8259 interrupt chip
	INT     5                               ; Request print_screen service
	JMP     KY_XIT                          ;  ...and exit key service

KY_CT5: CMP     AL,1Ah                          ; Alphabetic char?
	JA      KY_CT6                          ;  ...no
	ADD     AL,'A'-1                        ; Yes, add base for alphabet
	JMP     KY_COM

KY_CT6: MOV     BX,offset LE8F1                 ; Needs translation
	SUB     AL,20h
	XLAT    CS:[BX]
	JMP     KY_COM

KY_LC:  CMP     AL,1Ah                          ; Alphabetic character?
	JA      KY_CT7                          ;  ...no
	ADD     AL,'a'-1                        ; Else add lower case base
	JMP     KY_COM

KY_CT7: MOV     BX,offset LE8CC                 ; Character needs translation
	SUB     AL,20h
	XLAT    CS:[BX]                         ;  ...do the xlate
	JMP     KY_COM

KY_CT8: SUB     AL,47h                          ; Keypad key, convert origin
	MOV     BL,DS:17h                       ;  ...get "flag" byte
	TEST    BL,8                            ; Look for ALT keypad entry
	JNZ     KB_NUM                          ;  ...do special entry thing
	TEST    BL,4                            ; CTRL key pressed?
	JNZ     KY_CTR                          ;  ...skip if so
	TEST    BL,20h                          ; Toggle "Num Lock" ?
	JZ      KY_CT9                          ;  ...no, continue
	TEST    BL,3                            ; Shift keys hit?
	JNZ     KY_CTA                          ;  ...yes, continue
	JMP     short   KY_CTD

KY_CT9: TEST    BL,3                            ; Shift keys hit?
	JNZ     KY_CTD                          ;  ...yes, skip
	JMP     short   KY_CTA                  ; Else go here

KB_NUM: OR      AH,AH                           ; ALT-keypad entry, scan code
	JS      KY_EO1                          ;  ...out of range
	TEST    Byte ptr DS:17h,4               ; Else check CTRL state
	JZ      KY_PAD                          ;  ...not pressed, ALT keypad
	JMP     KY_PAT                          ; Else must check for DEL key

	JNZ     KY_PAD                          ; Instruction useless artifact

RELOAD: MOV     Word ptr DS:72h,1234h           ; Show BIOS data area init.
	db      0EAh
	dw      WARM,0F000h

KY_PAD: MOV     BX,offset LE960                 ; Get keypad translation table
	XLAT    CS:[BX]                         ;  ...convert to number
	CMP     AL,'0'                          ; Is it a valid ASCII digit?
	JB      KY_EO1                          ;  ...no, ignore it
	SUB     AL,30h                          ; Else convert to number
	MOV     BL,AL                           ;  ...save a copy
	MOV     AL,DS:19h                       ; Get partial ALT-keypad sum
	MOV     AH,0Ah                          ;  ...times 10 (decimal)
	MUL     AH
	ADD     AL,BL                           ; Add in new digit to sum
	MOV     DS:19h,AL                       ;  ...save as new ALT entry

KY_EO1: JMP     KY_EOI                          ; End_of_interrupt, exit

KY_CTR: OR      AH,AH                           ; Key released?
	JS      KY_EO1                          ;  ...ignore if so
	MOV     BX,offset LE96D                 ; Else translate char
	XLAT    CS:[BX]
	JMP     short   KY_COM                  ;  ...and save it

KY_CTA: CMP     AH,0D2h                         ; Was "INS" key released?
	JNZ     KY_CTB
	AND     Byte ptr DS:18h,7Fh             ; Yes, clear "INS" in "FLAG_1"
	JMP     short   KY_EO1

KY_CTB: OR      AH,AH                           ; Key released?
	JS      KY_EO1                          ;  ...ignore if so
	CMP     AH,52h                          ; Else check for "INS" press
	JNZ     KY_CTC                          ;  ...not "INS" press
	TEST    Byte ptr DS:18h,80h             ; Was INS key in effect?
	JNZ     KY_EO1                          ;  ...yes, ignore
	XOR     Byte ptr DS:17h,80h             ; Else tog "INS" in "FLAG" byte
	OR      Byte ptr DS:18h,80h             ;  ...set "INS" in "FLAG_1" byte

KY_CTC: MOV     BX,offset LE97A
	XLAT    CS:[BX]
	JMP     short   KY_COM

KY_CTD: OR      AH,AH                           ; Was the key released?
	JS      KY_EO1                          ;  ...yes, ignore
	MOV     BX,offset LE960                 ; Load translation table
	XLAT    CS:[BX]                         ;  ...do translate
	JMP     short   KY_COM

KY_COM: CMP     AL,5                            ; Common entry, char in AL
	JZ      KY_EO2                          ;  ...Control E, ignore
	CMP     AL,4
	JA      KY_CO1                          ; Above Control D

	OR      AL,80h                          ; Else set sign flag
	JMP     short   KY_CO2

KY_CO1: TEST    AL,80h                          ; Is sign bit set?
	JZ      KY_CO3                          ;  ...skip if so
	AND     AL,7Fh                          ; Else mask sign off

KY_CO2: MOV     AH,AL                           ; Save in high order byte
	MOV     AL,0                            ;  ...set scan code to zero

KY_CO3: TEST    Byte ptr DS:17h,40h             ; Test for "CAPS LOCK" state
	JZ      KY_BFR                          ;  ...no, skip
	TEST    Byte ptr DS:17h,3               ; Test for SHIFT key
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

KY_BFR: MOV     BX,DS:1Ch                       ; BX = tail of buffer
	MOV     DI,BX                           ;  ...save it
	INC     BX                              ;  ...advance
	INC     BX                              ;  ...by word
	CMP     BX,DS:82h                       ; End of buffer reached?
	JNZ     KY_CHK                          ;  ...no, skip
	MOV     BX,DS:80h                       ; Else BX = beginning of buffer

KY_CHK: CMP     BX,DS:1Ah                       ; BX = Buffer Head ?
	JNZ     KY_STF                          ;  ...no, OK
	JMP     short   KY_BEP                  ; Else buffer overrun, beep

KY_STF: MOV     [DI],AX                         ; Stuff scan code, char in bfr
	MOV     DS:1Ch,BX                       ;  ...and update bfr tail

KY_EO2: JMP     KY_EOI

KY_BEP: MOV     AL,20h                          ; Keyboard beeper routine
	OUT     20h,AL                          ;  ...send end_of_interrupt
	MOV     BX,80h                          ; Cycles in beep
	IN      AL,61h                          ;  ...get status
	PUSH    AX                              ;  ...save copy

KY_BE1: AND     AL,0FCh                         ; Mask off speaker bits
	OUT     61h,AL                          ;  ...disable speaker
KY_BE2: MOV     CX,64h                          ; Constant for pitch
KY_BE3: LOOP    KY_BE3                          ;  ...delay, speaker off
	XOR     AL,2
	OUT     61h,AL                          ; Toggle speaker position
	TEST    AL,2                            ; Full cycle done yet?
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	ENTRY   0F045h                          ; IBM entry point for table

V_TABLE dw      CRT_0                           ; Set mode
	dw      CRT_1                           ; Set cursor type
	dw      CRT_2                           ; Set cursor position
	dw      CRT_3                           ; Get cursor position
	dw      CRT_4                           ; * Read light pen position
	dw      CRT_5                           ; Set active display page
	dw      CRT_6                           ; Scroll active page up
	dw      CRT_7                           ; Scroll active page down
	dw      CRT_8                           ; Read attribute/character
	dw      CRT_9                           ; Write attribute/character
	dw      CRT_10                          ; Read character only
	dw      CRT_11                          ; Set color
	dw      CRT_12                          ; Write pixel
	dw      CRT_13                          ; Read pixel
	dw      CRT_14                          ; Write teletype
	dw      CRT_15                          ; Return current video state

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        
	
	ENTRY   0F065h                          ; IBM entry, video bios service

INT_10: STI                                     ; Video bios services
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
	MOV     BL,DS:10h                       ; Get equipment
	AND     BL,30h
	CMP     BL,30h                          ; Check for monochrome card
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	ENTRY   0F0A4h                          ; IBM entry, SET_MODE tables

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
	JMP     Word ptr CS:[BX+V_TABLE]        ;  ...vector to routines

CRT_0:  MOV     AL,DS:10h                       ; Set mode of CRT
	MOV     DX,3B4h                         ;  ...mono port
	AND     AL,30h                          ;  ...get display type
	CMP     AL,30h                          ;  ...equal if mono
	MOV     AL,1                            ; Assume mono display
	MOV     BL,7                            ;  ...mode is 7
	JZ      C0_01                           ;  ...Skip if mono, else CGA
	MOV     BL,[BP+2]                       ; BL = mode number (user AL)
	MOV     DL,0D4h                         ; 3D4 is CGA port
	DEC     AL

C0_01:  MOV     DS:63h,DX                       ; Save cur. CRT display port
	ADD     DL,4
	OUT     DX,AL                           ; Reset the video
	MOV     DS:49h,BL                       ;  ...save cur. CRT mode
	PUSH    DS
	XOR     AX,AX
	MOV     DS,AX
	LES     SI,DWord ptr DS:74h             ; SI --> INT_1D video param
	POP     DS
	MOV     BH,0
	PUSH    BX
	MOV     BL,CS:[BX+TABMUL]               ; Get BL for index into INT_1D
	ADD     SI,BX
	MOV     CX,10h                          ; Sixteen values to send

C0_02:  MOV     AL,ES:[SI]                      ; Value to send in SI
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

	MOV     DX,DS:63h                       ; Get the port
	ADD     DL,4
	POP     BX
	MOV     AL,CS:[BX+MODES]                ; Load data to set for mode
	OUT     DX,AL                           ;  ...and send it
	MOV     DS:65h,AL                       ;  ...then save active data
	INC     DX
	MOV     AL,30h                          ; Assume not 640 x 200 b/w
	CMP     BL,6                            ;  ...correct?
	JNZ     C0_05
	MOV     AL,3Fh                          ; Palette for 640 x 200 b/w

C0_05:  MOV     DS:66h,AL                       ;  ...save palette
	OUT     DX,AL                           ;  ...send palette
	XOR     AX,AX
	MOV     DS:4Eh,AX                       ; Start at beg. of 1st page
	MOV     DS:62h,AL                       ;  ...active page=page 0
	MOV     CX,8                            ; Do 8 pages of cursor data
	MOV     DI,50h                          ; Page cursor data at 40:50

C0_06:  MOV     [DI],AX                         ; Cursor at upper left of page
	INC     DI                              ;  ...next page
	LOOP    C0_06
	MOV     Word ptr DS:60h,0607h           ; Cursor: Line 6 thru Line 7
	MOV     AL,CS:[BX+MAXCOL]               ; Get display width
	MOV     DS:4Ah,AX                       ;  ...save it
	AND     BL,0FEh
	MOV     AX,Word ptr CS:[BX+REGENL]      ; Get video regen length
	MOV     DS:4Ch,AX                       ;  ...save it
	RET

CRT_1:  MOV     CX,[BP+6]                       ; Set cursor type, from CX
	MOV     DS:60h,CX                       ;  ...save it
	MOV     AH,0Ah                          ; CRT index register 0Ah
	CALL    OT6845                          ;  ...send CH,CL to CRT reg
	RET

CRT_2:  MOV     BL,[BP+5]                       ; Set cursor position, page BH
	SHL     BL,1                            ;  ...(our BL)
	MOV     BH,0
	MOV     AX,[BP+8]                       ; Position in user DX (our AX)
	MOV     [BX+50h],AX                     ;  ...remember cursor position
	JMP     SETCUR                          ;  ...set 6845 cursor hardware

LF1E7:  RET                                     ; Prehistoric relic

CRT_3:  MOV     BL,[BP+5]                       ; Get cursor position, page BH
	SHL     BL,1
	MOV     BH,0
	MOV     AX,[BX+50h]
	MOV     [BP+8],AX                       ;  ...return position in user DX
	MOV     AX,DS:60h                       ; Get cursor mode
	MOV     [BP+6],AX                       ;  ...return in user CX
	RET

CRT_4:  
	RET

CRT_5:  MOV     AL,[BP+2]                       ; Set active display page to AL
	MOV     DS:62h,AL                       ;  ...save new active page
	MOV     AH,0                            ;  ...clear hi order
	PUSH    AX
	MOV     BX,DS:4Ch                       ; Get size of regen. buffer
	MUL     BX                              ;  ...times number of pages
	MOV     DS:4Eh,AX                       ; Now AX = CRT offset, save
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
	CMP     Byte ptr DS:49h,2
	JB      SCR_03                          ;  ...no retrace wait needed
	CMP     Byte ptr DS:49h,3
	JA      SCR_03                          ;  ...no retrace wait needed
	MOV     DX,3DAh                         ; Else 80 x 25, do the kludge

SCR_02: IN      AL,DX                           ; Read CGA status register
	TEST    AL,8                            ;  ...vertical retrace?
	JZ      SCR_02                          ;  ...wait until it is
	MOV     DX,3D8h                         ; Then go and
	MOV     AL,25h                          ;  ...turn the display
	OUT     DX,AL                           ;  ...off to avoid snow

SCR_03: MOV     AX,[BP+8]                       ; Get row,column of upper left
	PUSH    AX
	CMP     Byte ptr [BP+3],7               ; Check for scroll down
	JZ      SCR_04                          ;  ...yes, skip if so
	MOV     AX,[BP+6]                       ; Get row,column of lowr right

SCR_04: CALL    RC2COL                          ; Get byte offset in CRT buf
	ADD     AX,DS:4Eh                       ;  ...add  base  for CRT buf
	MOV     SI,AX
	MOV     DI,AX
	POP     DX
	SUB     DX,[BP+6]                       ; Subtract (row,col) lwr rhgt
	ADD     DX,101h                         ;  ...width of one char
	MOV     BX,DS:4Ah                       ; Get columns in display
	SHL     BX,1                            ;  ...bytes in row of display
	PUSH    DS
	MOV     AL,[BP+2]                       ; Get scroll fill character
	CALL    MAPBYT                          ;  ...calculate offset
	MOV     ES,CX                           ; CX --> byte in buffer
	MOV     DS,CX
	CMP     Byte ptr [BP+3],6               ; Scroll up?
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
	MOV     AL,DS:65h                       ; Get the mode data byte
	MOV     DX,3D8h                         ;  ...load active CRT card port
	OUT     DX,AL                           ;  ...and unblank the screen

SCR_09: RET

SCG_01: CLD                                     ; Assume GRAFIX scroll up
	MOV     AX,[BP+8]                       ; (Row,Col) of lower right
	PUSH    AX
	CMP     Byte ptr [BP+3],7               ; Scroll down?
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
	CMP     Byte ptr DS:49h,6               ;  ...is this 640 x 200?
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
	CMP     Byte ptr [BP+3],6               ; Is this scroll up?
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
	MOV     DI,AX                           ;  ...offset in DI
	POP     AX
	MUL     Word ptr DS:4Ch                 ; Page length X page number
	ADD     DI,AX                           ;  ...current char. position
	MOV     SI,DI                           ;  ...move into si
	MOV     DX,DS:63h                       ; Display port into DX
	ADD     DX,6                            ;  ...get status port
	PUSH    DS
	MOV     BX,[BP+0]                       ; BX --> regen. buffer
	MOV     DS,BX
	MOV     ES,BX
	MOV     AL,[BP+3]                       ; Get user (AH) func request
	CMP     AL,8
	JNZ     C9_01                           ;  ...skip if not read attr

C8_01:  IN      AL,DX                           ; Read CRT display status
	TEST    AL,1                            ;  ...test for hor. retrace
	JNZ     C8_01                           ; Yes, wait for display on
	CLI                                     ;  ...no interrupts now

C8_02:  IN      AL,DX                           ; Read CRT display status
	TEST    AL,1                            ;  ...test for hor. retrace
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
	TEST    AL,1                            ;  ...test for hor. retrace
	JNZ     C9_02                           ; Yes, wait for display on
	CLI                                     ;  ...no interrupts now

C9_03:  IN      AL,DX                           ; Read CRT display status
	TEST    AL,1                            ;  ...test for hor. retrace
	JZ      C9_03                           ;  ...not yet, wait for it

	MOV     AX,BX                           ; Get char/attribute
	STOSW                                   ;  ...write it
	LOOP    C9_02                           ;  ...loop for char. count
	POP     DS
	RET

CA_01:  IN      AL,DX                           ; Read CRT display status
	TEST    AL,1                            ;  ...test for hor. retrace
	JNZ     CA_01                           ;  ...not yet, wait for it
	CLI                                     ;  ...no interrupts now

CA_02:  IN      AL,DX                           ; Read CRT display status
	TEST    AL,1                            ;  ...test for hor. retrace
	JZ      CA_02                           ;  ...not yet, wait for it

	MOV     AL,BL                           ; Get character
	STOSB                                   ;  ...write it
	INC     DI                              ;  ...skip attribute
	LOOP    CA_01                           ;  ...loop for char. count
	POP     DS
	RET

CG8_01: CMP     Byte ptr [BP+3],8               ; Read graphics char/attr. ?
	JNZ     CG9_01                          ;  ...no, must be write
	JMP     CGR_01                          ; Else read char/attr.

CG9_01: MOV     AX,DS:50h                       ; Get cursor position
	CALL    GRAMAP                          ;  ...convert (row,col) -> col
	MOV     DI,AX                           ; Save in displacement register
	PUSH    DS
	MOV     AL,[BP+2]                       ; Get character to write
	MOV     AH,0
	OR      AL,AL                           ; Is it user character set?
	JS      CG9_02                          ;  ...skip if so
	MOV     DX,CS                           ; Else use ROM character set
	MOV     SI,offset GRAFIX                ;  ...offset GRAFIX into SI
	JMP     short   CG9_03

CG9_02: AND     AL,7Fh                          ; Origin to zero
	XOR     BX,BX                           ;  ...then go load
	MOV     DS,BX                           ;  ...user grafix
	LDS     SI,DWord ptr DS:7Ch             ;  ...vector, offset in SI
	MOV     DX,DS                           ;  ...segment into DX

CG9_03: POP     DS                              ; Restore data segment
	MOV     CL,3                            ;  ...char 8 pixels wide
	SHL     AX,CL
	ADD     SI,AX                           ; Add regen. buffer base addr.
	MOV     AX,[BP+0]                       ;  ...get regen buffer addr.
	MOV     ES,AX                           ;  ...into ES
	MOV     CX,[BP+6]                       ;  ...load char. count
	CMP     Byte ptr DS:49h,6               ; Is the mode 640 x 200 b/w?
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
	XOR     AX,ES:[DI]

CG9_07: MOV     ES:[DI],AX                      ; Write new word
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
	XOR     AL,ES:[DI]                      ; Else load attribute

CG8_05: MOV     ES:[DI],AL                      ; Write out attribute
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
	MOV     AX,DS:50h                       ;  ...get cursor position
	CALL    GRAMAP                          ; Convert (row,col) -> columns
	MOV     SI,AX                           ;  ...save in SI
	SUB     SP,8                            ; Grab 8 bytes temp storage
	MOV     DI,SP                           ;  ...save base in DI
	CMP     Byte ptr DS:49h,6               ; Mode 640 x 200 b/w?
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
	MOV     SS:[DI],DL
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
	MOV     SS:[DI],AH                      ;  ...save on stack
	INC     DI                              ;  ...advance
	MOV     AH,[SI+2000h]                   ; Read pixels from other plane
	MOV     SS:[DI],AH                      ; Save pixels on stack
	INC     DI                              ;  ...advance
	ADD     SI,50h                          ; Total pixels in char
	DEC     DH                              ;  ...another row processed
	JNZ     CGR_07                          ;  ...more to do

CGR_08: MOV     DX,CS                           ; Load segment of grafix char
	MOV     DI,offset GRAFIX                ;  ...and offset
	MOV     ES,DX                           ;  ...save offset in ES
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
	LES     DI,DWord ptr DS:7Ch             ; Else load user grafix char
	MOV     BX,ES
	OR      BX,DI
	JZ      CGR_11                          ;  ...not found
	JMP     short   CGR_09                  ; Try using user grafix char

CGR_11: MOV     [BP+2],AL                       ; Return char in user AL
	POP     DS
	ADD     SP,8                            ;  ...return temp storage
	RET

CRT_11: MOV     DX,DS:63h                       ; Set color, get CGA card port
	ADD     DX,5                            ;  ...color select register
	MOV     AL,DS:66h                       ; Get CRT palette
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

C_PAL2: MOV     DS:66h,AL                       ; Save new palette
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
	JMP     short WD_02

WD_01:  SHL     CL,1
	MOV     AL,[BP+2]
	MOV     BL,AL
	AND     AL,3
	ROR     AL,1
	ROR     AL,1
	MOV     AH,3Fh

WD_02:  ROR     AH,CL
	SHR     AL,CL
	MOV     CL,ES:[SI]                      ; Read the char with the dot
	OR      BL,BL
	JNS     WD_03
	XOR     CL,AL                           ; Exclusive or existing color
	JMP     short WD_04

WD_03:  AND     CL,AH                           ; Set new color for dot
	OR      CL,AL

WD_04:  MOV     ES:[SI],CL                      ; Write out char with the dot
	RET

CRT_13: MOV     AX,[BP+0]                       ; AX --> video regen buffer
	MOV     ES,AX                           ;  ...into ES segment
	MOV     DX,[BP+8]                       ; Load row from user DX
	MOV     CX,[BP+6]                       ;  ... col from user CX
	CALL    LOCDOT                          ; Calculate dot offset
	MOV     AL,ES:[SI]                      ;  ...read dot
	JNZ     RD_01                           ;  ...was there
	SHL     AL,CL
	ROL     AL,1
	AND     AL,1
	JMP     short RD_02

RD_01:  SHL     CL,1                            ; Calculate offset in char
	SHL     AL,CL
	ROL     AL,1
	ROL     AL,1
	AND     AL,3

RD_02:  MOV     [BP+2],AL                       ; Return dot pos in user AL
	RET

CRT_14: MOV     BL,DS:62h                       ; Get active video page (0-7)
	SHL     BL,1                            ;  ...as word index
	MOV     BH,0                            ;  ...clear hi order
	MOV     DX,[BX+50h]                     ; Index into cursor position

	MOV     AL,[BP+2]                       ; Get char. to write
	CMP     AL,8                            ;  ...back space?
	JZ      TTY_BS                          ;  ...skip if so
	CMP     AL,LF                           ; Is it a carriage return
	JZ      TTY_LF                          ;  ...skip if so
	CMP     AL,7                            ; Print a bell?
	JZ      BLIP                            ;  ...do beep
	CMP     AL,CR                           ; Is it a line feed?
	JZ      TTY_CR                          ;  ...skip if so
	MOV     BL,[BP+4]                       ; Else write at cur pos
	MOV     AH,0Ah
	MOV     CX,1                            ;  ...one time
	INT     10h
	INC     DL                              ; Advance cursor
	CMP     DL,DS:4Ah                       ;  ...check for line overflow
	JNZ     TTYPOS
	MOV     DL,0                            ; Overflowed, then fake
	JMP     short TTY_LF                    ;  ...new line

TTY_BS: CMP     DL,0                            ; At start of line?
	JZ      TTYPOS                          ;  ...skip if so
	DEC     DL                              ; Else back up
	JMP     short TTYPOS                    ;  ...join common code

BLIP:   MOV     BL,2                            ; Do a short beep
	RET

TTY_CR: MOV     DL,0                            ; Position to start of line

TTYPOS: MOV     BL,DS:62h                       ; Get active video page (0-7)
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
	MOV     DL,DS:4Ah                       ;  ...up
	DEC     DL
	INT     10h
	RET

CRT_15: MOV     AL,DS:4Ah                       ; Get current video state
	MOV     [BP+3],AL                       ;  ...columns
	MOV     AL,DS:49h
	MOV     [BP+2],AL                       ;  ...mode
	MOV     AL,DS:62h
	MOV     [BP+5],AL                       ;  ...page
	RET

MODCHK: PUSH    AX                              ; Set flags acc. to cur. mode
	MOV     AL,DS:49h                       ;  ...get mode
	CMP     AL,7                            ;  ...EQU if mono
	JZ      MODCH1
	CMP     AL,4
	CMC
	JNB     MODCH1                          ;  ...carry set on graphix
	SBB     AL,AL
	STC

MODCH1: POP     AX
	RET

OT6845: MOV     AL,CH                           ; Send CH,CL thru CRT reg AH
	CALL    SENDAX                          ;  ...send CH
	INC     AH                              ;  ...increment
	MOV     AL,CL                           ;  ...send CL

SENDAX: PUSH    DX
	MOV     DX,DS:63h                       ; Load active video port
	XCHG    AL,AH
	OUT     DX,AL                           ; Send hi order
	XCHG    AL,AH
	INC     DL
	OUT     DX,AL                           ;  ... lo order
	POP     DX
	RET

MPRC2C: MOV     BH,0                            ; Convert Row,Col,Page -> Col
	SHL     BX,1                            ;  ...two bytes/column
	MOV     AX,[BX+50h]                     ; Get page number in AX
	JMP     short RC2COL                    ;  ...join common code

LOCDOT: MOV     AL,50h                          ; Dots in char. position
	XOR     SI,SI
	SHR     DL,1                            ; Two bytes/char. position
	JNB     LOCDO1                          ;  ...not overflow
	MOV     SI,2000h                        ; Else on other video plane

LOCDO1: MUL     DL                              ; Multiply position by row
	ADD     SI,AX                           ;  ...add in column position
	MOV     DX,CX                           ; Copy column position
	MOV     CX,302h                         ;  ...regular char size
	CMP     Byte ptr DS:49h,6               ; Mode 640 x 200, b/w?
	PUSHF
	JNZ     LOCDO2                          ;  ...skip if not
	MOV     CX,703h                         ; Else special char. size

LOCDO2: AND     CH,DL
	SHR     DX,CL
	ADD     SI,DX
	XCHG    CL,CH
	POPF
	RET

MOVCUR: CALL    MPRC2C                          ; Map row,col,page to col
	ADD     AX,DS:4Eh                       ;  + byte offset, regen reg.
	SHR     AX,1
	MOV     CX,AX
	MOV     AH,0Eh                          ; Tell 6845 video controller
	CALL    OT6845                          ;  ...to position the cursor
	RET

PENXY:  CALL    PENXY1                          ; Read light pen position HI
	MOV     CH,AL                           ;  ...save in CH
	INC     AH
	CALL    PENXY1                          ; Read light pen position LO
	MOV     CL,AL                           ;  ...save in CL
	RET

PENXY1: PUSH    DX                              ; Read CRT register offset AL
	MOV     DX,DS:63h                       ;  ...get active CRT port
	XCHG    AL,AH
	OUT     DX,AL                           ; Send initialization byte
	INC     DL                              ;  ...increment
	IN      AL,DX                           ; Read pen position byte back
	POP     DX
	RET

RC2COL: PUSH    BX                              ; Map (AH=row,AL=COL) to COL
	MOV     BL,AL
	MOV     AL,AH
	MUL     Byte ptr DS:4Ah                 ; Multiply ROW x (Row/Column)
	MOV     BH,0
	ADD     AX,BX                           ;  ...add in existing COL
	SHL     AX,1                            ;  ...times 2 cause 2 bytes/col
	POP     BX
	RET

GRAMAP: PUSH    BX                              ; Convert (row,col) -> col
	MOV     BL,AL                           ;  ...save column
	MOV     AL,AH                           ;  ...get row
	MUL     Byte ptr DS:4Ah                 ; Multiply by columns/row
	SHL     AX,1
	SHL     AX,1
	MOV     BH,0
	ADD     AX,BX                           ; Add in columns
	POP     BX
	RET

SETCUR: SHR     BL,1                            ; Sets 6845 cursor position
	CMP     DS:62h,BL                       ;  ...is this page visible?
	JNZ     SET_01                          ; No, do nothing in hardware
	CALL    MOVCUR                          ; Else update cursor display

SET_01: RET

	ENTRY   0F841h                          ; IBM entry for memory size

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

INT_12:
	mov     ax, 640
	iret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

NUMBER: PUSH    AX                              ; Save number
	MOV     CL,4
	SHR     AL,CL
	CALL    DIGIT                           ; Out first  digit
	POP     AX
	CALL    DIGIT                           ; Out second digit
	RET

BIGNUM: PUSH    AX                              ; Unsigned word
	MOV     AL,AH
	CALL    NUMBER
	POP     AX
	CALL    NUMBER
	RET

OUTCHR: PUSH    BX
	PUSH    AX
	MOV     AH,0Eh                          ; Teletype print service
	MOV     BL,7                            ;  ...normal intensity
	INT     10h
	POP     AX
	POP     BX
	RET

DIGIT:  PUSH    AX                              ; Print hex digit in AL
	AND     AL,0Fh
	CMP     AL,9
	JBE     D_01
	ADD     AL,'A'-'9'-1

D_01:   ADD     AL,'0'                          ; Make ascii digit
	CALL    OUTCHR                          ; ...print it
	POP     AX
	RET

	MOV     AL,CR                           ; Print carriage return
	CALL    OUTCHR                          ;  ...on screen
	MOV     AL,LF                           ; Print line feed
	CALL    OUTCHR                          ;  ...on screen
	RET

GETCH:  MOV     AH,0                            ; Read keyboard key
	INT     16h
	RET

PRINT:  LODSB                                   ; Print zero terminated string
	OR      AL,AL
	JNZ     PRINT1                          ;  ...not terminator in AX
	RET

PRINT1: CALL    OUTCHR                          ; Print character in AX
	JMP     PRINT                           ;  ...back for more

V_INIT: MOV     AH,DS:10h                       ; Get equipment byte
	AND     AH,30h                          ;  ...extract CRT
	MOV     AL,0                            ;  ...null lo
	CMP     AH,30h                          ; Monochrome?
	JZ      LF9D9                           ;  ...yes
	MOV     AL,1                            ; CGA 40 x 25?
	CMP     AH,10h                          ;  ...yes
	JZ      LF9D9                           ; CGA 80 x 25?
	MOV     AL,3                            ;  ...yes

LF9D9:  MOV     AH,0                            ; Setup subfunction
	INT     10h                             ;  ...to video
	RET

BLANK:  MOV     DX,184Fh                        ; Lower right corner of scroll
	XOR     CX,CX                           ; Upper left  corner of scroll
	MOV     AX,600h                         ; Blank entire window
	MOV     BH,7                            ; Set regular cursor
	INT     10h                             ; Call video service scroll
	MOV     AH,2                            ; Set cursor position
	XOR     DX,DX                           ;  ...upper left corner
	MOV     BH,0                            ;  ...page 0
	INT     10h                             ;  ...call video service
	RET

LOCATE: PUSH    DX
	PUSH    BX
	MOV     DX,AX                           ; Get position for cursor
	MOV     AH,2
	MOV     BH,0                            ;  ...page 0
	INT     10h
	POP     BX
	POP     DX
	RET

CHKSUM: MOV     CX,2000h                        ; Bytes in 2764 eprom

CHK_01: MOV     AL,0                            ;  ...zero checksum

ADDBYT: ADD     AL,[BX]                         ; Add byte to checksum
	INC     BX                              ;  ...BX --> next byte
	LOOP    ADDBYT                          ;  ...loop until done
	OR      AL,AL                           ; Set condition codes
	RET                                     ;  ...and return

MEMTST: MOV     BX,0400h                        ; Load bytes to test
	MOV     AL,55h

PAT_1:  XOR     DI,DI                           ; Pattern #1, 55h bytes
	MOV     CX,BX
	REPZ    STOSB                           ; Fill memory, pattern #1
	XOR     DI,DI
	MOV     CX,BX
	REPZ    SCASB                           ; Scan memory for NOT pattern #1
	JCXZ    PAT_2
	STC                                     ;  ...flunked
	RET

PAT_2:  XOR     DI,DI                           ; Pattern #2 - 0AAh bytes
	MOV     CX,BX
	NOT     AL
	REPZ    STOSB                           ; Fill memory, pattern #2
	XOR     DI,DI
	MOV     CX,BX
	REPZ    SCASB                           ; Scan memory for NOT pattern #2
	JCXZ    PAT_3
	STC                                     ;  ...flunked
	RET

PAT_3:  XOR     DI,DI                           ; Pattern #3 - 01h bytes
	MOV     CX,BX
	MOV     AL,1
	REPZ    STOSB                           ; Fill memory, pattern #3
	XOR     DI,DI
	MOV     CX,BX
	REPZ    SCASB                           ; Scan memory for NOT pattern #3
	JCXZ    PAT_4
	STC                                     ;  ...flunked
	RET

PAT_4:  XOR     DI,DI                           ; Pattern #4 - 0h bytes
	MOV     CX,BX
	DEC     AL
	REPZ    STOSB                           ; Fill memory, pattern #4
	XOR     DI,DI
	MOV     CX,BX
	REPZ    SCASB                           ; Scan memory for NOT pattern #4
	JCXZ    LFA59
	STC                                     ;  ...flunked
	RET

LFA59:  MOV     AX,ES
	ADD     AX,40h                          ; Add 40h to segment number
	MOV     ES,AX
	RET                                     ;  ...passed

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	ENTRY   0FA6Eh                          ; IBM graphics char set entry

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	ENTRY   0FE6Eh                          ; IBM entry, time_of_day clock

INT_1A: STI                                     ; User time_of_day bios service
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
	MOV     DS:6Ch,DX                       ; Set time,  AH=1
	MOV     DS:6Eh,CX                       ;  ...set time hi
	MOV     Byte ptr DS:70h,0               ;  ...not a new day
	JMP     short   TD_02

TD_01:  MOV     CX,DS:6Eh                       ; Read lo order time
	MOV     DX,DS:6Ch                       ;  ... hi order time
	CALL    TD_03                           ; Read resets overflow

TD_02:  STI                                     ; Unfreeze clock
	POP     DS
	IRET

TD_03:  MOV     AL,DS:70h                       ; Zero the overflow and return
	XOR     DS:70h,AL                       ;  ...previous status in flags
	RET

	ENTRY   0FEA5h                          ; IBM entry, hardware clock

INT_8:  STI                                     ; Routine services clock tick
	PUSH    DS
	PUSH    DX
	PUSH    AX
	MOV     AX,40h
	MOV     DS,AX
	DEC     Byte ptr DS:40h                 ; Decrement motor count
	JNZ     TI_01                           ;  ...not time to shut off
	AND     Byte ptr DS:3Fh,0F0h            ; Else show motor off
	MOV     AL,0Ch                          ;  ...send motor off
	MOV     DX,3F2h                         ;  ...to the floppy
	OUT     DX,AL                           ;  ...disk controller

TI_01:  INC     Word ptr DS:6Ch                 ; Bump lo order time of day
	JNZ     TI_02                           ;  ...no carry
	INC     Word ptr DS:6Eh                 ; Bump hi order time of day

TI_02:  CMP     Word ptr DS:6Eh,18h             ; Is it midnight yet?
	JNZ     TI_03                           ;  ...no
	CMP     Word ptr DS:6Ch,0B0h            ; Possibly, check lo order
	JNZ     TI_03                           ;  ...not midnight
	MOV     Word ptr DS:6Eh,0               ; Midnight, reset hi order
	MOV     Word ptr DS:6Ch,0               ;  ...lo order ticks
	MOV     Byte ptr DS:70h,1               ; Show new day since last read

TI_03:  INT     1Ch                             ; Execute user clock service
	MOV     AL,20h                          ;  ...send end_of_interrupt
	OUT     20h,AL                          ;  ...to 8259 interrupt chip
	POP     AX
	POP     DX
	POP     DS
	IRET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	ENTRY   0FEF3h                          ; IBM entry, time_of_day clock

VECTORS dw      int_8                           ; Timer tick
	dw      int_9                           ; Key attention
	dw      DUMMY
	dw      DUMMY
	dw      DUMMY
	dw      DUMMY
	dw      DUMMY
	dw      DUMMY
	dw      int_10                          ; Video bios services
	dw      DUMMY
	dw      int_12                          ; Memories  present
	dw      DUMMY
	dw      DUMMY
	dw      DUMMY
	dw      int_16                          ; Keyboard bios services
	dw      DUMMY
	dw      DUMMY
	dw      DUMMY
	dw      int_1a                          ; Timer bios services
	dw      DUMMY                           ; Keyboard break user service
	dw      DUMMY                           ; System tick user service
	dw      int_1d                          ; Video  parameter table
	dw      DUMMY
	dw      ?                               ; Graphic charactr table ptr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	ENTRY   0FF53h                          ; IBM entry, dummy interrupts

DUMMY:  IRET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	ENTRY   0FFCBh                          ; IBM entry, display CR, LF

P_CRLF: PUSH    DX                              ; Print CR, LF, on line printer
	XOR     DX,DX
	MOV     AH,DL                           ; Function=print
	MOV     AL,LF                           ;     LF
	INT     17h
	MOV     AH,0
	MOV     AL,CR                           ;     CR
	INT     17h
	POP     DX
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	ENTRY   0FFF0h                          ; Hardware power reset entry

	db      0EAh
	dw      COLD,0F000h
	db      "00/00/00"                      ; Release date

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	ENTRY   0FFFEh
	db      0FEh                            ; Computer type (XT)
code    ENDS
END
