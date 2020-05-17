;	SCCSID = @(#)forproc.asm	1.2 85/07/25
.xlist
.xcref
BREAK   MACRO   subtitle
	SUBTTL  subtitle
	PAGE
ENDM

	INCLUDE SYSCALL.INC
.cref
.list
data	segment	public 'DATA'
data	ends

code    segment public 'CODE'
	assume  cs:code,ds:data

	PUBLIC  FormatAnother?,Yes?,REPORT,USER_STRING
	public	fdsksiz,badsiz,syssiz,datasiz,biosiz

	extrn   std_printf:near,crlf:near,PrintString:near

data segment
	extrn	driveLetter:byte

; In formes.asm
	extrn	msgInsertDisk:byte
	extrn	msgFormatAnother?:byte
	extrn	msgTotalDiskSpace:byte
	extrn	msgSystemSpace:byte
	extrn	msgBadSpace:byte
	extrn	msgDataSpace:byte
	extrn	yes_byte:byte
	extrn	no_byte:byte

	extrn   inbuff:byte

ptr_msgTotalDiskSpace	dw	offset msgTotalDiskSpace
fdsksiz			dd      0

ptr_msgSystemSpace	dw	offset msgSystemSpace
syssiz  		dd      0
biosiz  		dd      0

ptr_msgBadSpace		dw	offset msgBadSpace
badsiz  		dd      0

ptr_msgDataSpace	dw	offset msgDataSpace
datasiz			dd      0

ptr_msgInsertDisk	dw	offset msgInsertDisk
			dw	offset driveLetter
data ends

FormatAnother? proc near
; Wait for key. If yes return carry clear, else no. Insures
;   explicit Y or N answer.
	lea	dx, msgFormatAnother?
	call	PrintString
	CALL    Yes?
	JNC     WAIT20
	JZ      WAIT20
	CALL    CRLF
	JMP     SHORT FormatAnother?
FormatAnother? endp

Yes? proc near

; Wait for key. If YES return carry clear,else carry set.
;   If carry is set, Z is set if explicit NO, else key was not Yes or No.
	CALL    USER_STRING
	JNZ     GETBYT
	XOR     AL,AL                   ; So that CMP with [NO_BYTE] is NZ
	JMP     SHORT CHECK_NO

GETBYT:
	MOV     AL,BYTE PTR [INBUFF+2]
	OR      AL,20H                  ; Convert to lower case
	CMP     AL,[YES_BYTE]
	JZ      WAIT20                  ; Carry clear if jump
CHECK_NO:
	CMP     AL,[NO_BYTE]
	STC                             ; Set carry (wasn't Yes)
WAIT20: RET

Yes? endp

USER_STRING:
; Get a string from user. Z is set if user typed no chars (imm CR)
;  We need to flush a second time to get rid of incoming Kanji characters also.
	MOV     AX,(STD_CON_INPUT_FLUSH SHL 8) + 0      ; Clean out input
	INT     21H
	MOV     DX,OFFSET INBUFF
	MOV     AH,STD_CON_STRING_INPUT
	INT     21H
	MOV     AX,(STD_CON_INPUT_FLUSH SHL 8) + 0      ; Clean out input
	INT     21H
	CMP     BYTE PTR [INBUFF+1],0
	RET

;*********************************************
; Make a status report including the following information:
; Total disk capacity
; Total system area used
; Total bad space allocated
; Total data space available

REPORT:
	lea	dx, ptr_msgTotalDiskSpace
	call	std_printf
	cmp     WORD PTR SYSSIZ,0
	JNZ     SHOWSYS
	cmp     WORD PTR SYSSIZ+2,0
	JZ      CHKBAD
SHOWSYS:
	MOV     dx,OFFSET ptr_msgSystemSpace
	CALL    std_printf              ;Report space used by system
CHKBAD:
	cmp     WORD PTR BADSIZ,0
	JNZ     SHOWBAD
	cmp     WORD PTR BADSIZ+2,0
	JZ      SHOWDATA
SHOWBAD:
	lea	dx, ptr_msgBadSpace
	call	std_printf
SHOWDATA:
	MOV     CX,WORD PTR FDSKSIZ
	MOV     BX,WORD PTR FDSKSIZ+2
	SUB     CX,WORD PTR BADSIZ
	SBB     BX,WORD PTR BADSIZ+2
	SUB     CX,WORD PTR SYSSIZ
	SBB     BX,WORD PTR SYSSIZ+2
	MOV     word ptr datasiz,CX
	MOV     word ptr datasiz+2,BX
	lea	dx, ptr_msgDataSpace
	call	std_printf
	call	crlf
	RET

code    ends
	end
