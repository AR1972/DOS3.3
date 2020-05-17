;	SCCSID = @(#)print_t.asm	4.5 85/09/10
	INCLUDE pridefs.inc

SaveReg MACRO	reglist 		;; push those registers
IRP reg,<reglist>
	PUSH	reg
ENDM
ENDM

RestoreReg  MACRO   reglist		;; pop those registers
IRP reg,<reglist>
	POP	reg
ENDM
ENDM

BREAK	<Transient Portion>

;
;	MSDOS V3.00 PRINT
;
;	Transient Portion
;


CodeR	Segment public para

if hardint
	extrn	SliceCnt:BYTE, BusyTick:BYTE, MaxTick:BYTE, TimeSlice:BYTE
endif
	extrn	EndRes:WORD, BlkSiz:WORD, QueueLen:BYTE, PChar:BYTE
	extrn	ListName:BYTE, FileQueue:BYTE, EndQueue:WORD, Buffer:WORD
	extrn	EndPtr:WORD, NxtChr:WORD, MoveTrans:FAR

CodeR	EndS


BREAK	<Transient Data>

;Transient data

DATA	SEGMENT public BYTE

	extrn	badver:byte,conflictmes_ptr:word,invparm_ptr:word,crlf_ptr:word
	extrn	fullmes_ptr:word,nofils_ptr:word,dispmes_ptr:word
	extrn	whichmes:word,fstmes:byte,secmes:byte,badnamemes_ptr:word
	extrn	namtmes_ptr:word,badcanmes_ptr:word,cntmes_ptr:word
	extrn	prompt_ptr:word,invdrvmes_ptr:word,AccDen_PTR:WORD

	public	namebuf,arg_buf

	ORG	0

Public PRNT001S, PRNT001E
PRNT001S	equ	$

SWITCHAR	DB	?
PathChar	db	"\"

SubPack 	db	0		; Level
		dd	?		; pointer to filename

;--- Ints used by print. These ints are loaded here before the
; resident is installed, just in case an error before print
; is installed cases it to be never installed and the ints
; have to be restored.

i28vec	dd	?			; SOFTINT
i2fvec	dd	?			; COMINT
	if	IBM
i05vec	dd	?
i13vec	dd	?
i14vec	dd	?
i15vec	dd	?
i17vec	dd	?
	endif
	if	HARDINT
i1cvec	dd	?			; INTLOC
	endif

;--- Temp stack for use durint int 23 and 24 processing
	db     278 + 80H dup (?)	; 278 == IBM's ROM requirements
intStk	dw     ?


;--- Print installed flag:
; 0 = Not installed yet: process only configuration parameters
;	during the command line parse
; 1 = Partially installed: process only print commands AND flag
;	configuration parameters as errors AND finish by executing
;	the keep process
; 2 = Already installed: process only print commands AND flag
;	configuration parameters as errors
PInst		db	0		; defaults to not installed
CanFlag 	db	0		; cancel mode flag (0= no cancel)
Ambig		db	?		; =1 if a filename is ambigous
DevSpec 	db	0		; =1 a device was specified with the
					;  /d option, do not prompt
QFullMes	db	0		; =1 queue full message issued already
HARDCH	DD	?			;Pointer to real INT 24 handler

TOKBUF		DB	64 DUP (?)	; token buffer for CPARSE
LastSI		dw	?		; pointer to last token for lok-ahead

NulPtr		dw	?		; pointer to the nul in NameBuf
FNamPtr 	dw	?		; pointer to name portion of file name
NameBuf 	db	(MaxFileLen+16) dup(?)	 ; full name buffer for file
						 ;  plus room for ambigous expansion
Arg_buf 	db	(MaxFileLen+16) dup (?)

SearchBuf	find_buf <>		; search buffer

PRNT001E	equ	$

DATA	ENDS



BREAK	<Transient Code>

Code	Segment public para
	extrn	std_printf:near,printf_crlf:near
Code	EndS

Code	Segment  public para
	public	TransRet,TransSize

ASSUME	CS:DG,DS:nothing,ES:nothing,SS:Stack

TRANSIENT:
;Install
	CLD

;Code to print header
;	MOV	DX,OFFSET DG:HEADER
;	MOV	AH,STD_CON_STRING_OUTPUT
;	INT	21H

	MOV	AH,GET_VERSION
	INT	21H

	CMP	AX,EXPECTED_VERSION
	JE	OKDOS

;	XCHG	AH,AL			;Turn it around to AH.AL
;	CMP	AX,DOSVER_LOW
;	JB	GOTBADDOS
;	CMP	AX,DOSVER_HIGH
;	JBE	OKDOS

GOTBADDOS:
	PUSH	CS
	POP	DS
assume	ds:dg
	MOV	DX,OFFSET DG:BADVER
	MOV	AH,STD_CON_STRING_OUTPUT
	INT	21H
	push	es
	xor	ax,ax
	push	ax

foo	proc	far
	ret				; Must use this method, version may be < 2.00
foo	endp


assume	ds:nothing
OKDOS:
	mov	ax,ds:[pdb_environ]
	or	ax,ax
	jz	nofree
	push	es
	mov	es,ax
	mov	ah,dealloc
	int	21h
	pop	es
nofree:
	push	cs
	pop	ds
	push	cs
	pop	es
assume	ds:dg,es:dg
	mov	ax,0100H		; Ask if already installed
	INT	ComInt
	OR	AL,AL
	jnz	badinstal

;--- save int vectors in case of error

	mov	ax,(get_interrupt_vector shl 8) or SOFTINT ; (SOFTINT)
	int	21h
assume	es:nothing
	mov	word ptr [i28vec+2],es
	mov	word ptr [i28vec],bx

	mov	ax,(get_interrupt_vector shl 8) or COMINT  ; (COMINT)
	int	21h
	mov	word ptr [i2fvec+2],es
	mov	word ptr [i2fvec],bx

	if	IBM

	mov	ax,(get_interrupt_vector shl 8) or 13h
	int	21h
	mov	word ptr [i13vec+2],es
	mov	word ptr [i13vec],bx

	mov	ax,(get_interrupt_vector shl 8) or 15h
	int	21h
	mov	word ptr [i15vec+2],es
	mov	word ptr [i15vec],bx

	mov	ax,(get_interrupt_vector shl 8) or 17h
	int	21h
	mov	word ptr [i17vec+2],es
	mov	word ptr [i17vec],bx

	mov	ax,(get_interrupt_vector shl 8) or 14h
	int	21h
	mov	word ptr [i14vec+2],es
	mov	word ptr [i14vec],bx

	mov	ax,(get_interrupt_vector shl 8) or 05h
	int	21h
	mov	word ptr [i05vec+2],es
	mov	word ptr [i05vec],bx

	endif

	if	HARDINT

	mov	ax,(get_interrupt_vector shl 8) or INTLOC  ; (INTLOC)
	int	21h
	mov	word ptr [i1cvec+2],es
	mov	word ptr [i1cvec],bx

	endif

	push	cs
	pop	es
assume	es:dg

	jmp	OKINST			; not installed yet...

BADINSTAL:
	CMP	AL,1
	JZ	PRINTCONFLICT
	mov	[PInst],2		; remember print already installed
					;  and that we only do one pass
	jmp	short okinst
ERREX:
	call	printf_crlf
ERREX2:
	MOV	AX,(EXIT SHL 8) OR 0FFH
	INT	21H

PRINTCONFLICT:
	MOV	DX,OFFSET DG:CONFLICTMES_ptr
	JMP	short ERREX

Busy:
	RestoreReg  <AX>
IntWhileBusy:
	SaveReg <AX>
	INT	ComInt
	JNC	NotBusy
	CMP	AX,error_busy
	JZ	Busy
	add	sp,2			; clear off AX
	stc
	ret
NotBusy:
	Add	sp,2			; clear off AX and clear carry
	ret

OKINST:
	call	GetHInt 		; save current int 24 vector
	call	SetInts 		; set int 23 and 24 vectors
	MOV	AX,CHAR_OPER SHL 8
	INT	21H
	MOV	[SWITCHAR],DL		; Get user switch character
	cmp	dl,"-"
	jne	RegPathChar
	mov	[PathChar],"/"          ; alternate path character
RegPathChar:
	MOV	SI,81H			; Command line
ParseAgn1:				; come here when DI is trashed...
	MOV	DI,OFFSET DG:TOKBUF
ParseAgn:
	CALL	CPARSE
	jc	setbufj
	jmp	MORESTUFF		; End of command line?
SETBUFJ:
	cmp	[PInst],0		; is print already installed?
	jne	setbufj2
	jmp	NotYet
;
; Grab the pointer to the queue and lock it down.  Remember that since there
; are threads in the background, we may get a busy return.  We sit here in a
; spin loop until we can actually lock the queue.
;
setbufj2:
	mov	ax,0104H		; get status
	call	IntWhileBusy		; on return DS:SI points to queue
assume	ds:nothing
;--- check for off-line
	cmp	dx,ErrCnt1		; check count
	jb	CntOK
	push	ds
	push	cs
	pop	ds
assume	ds:dg
	mov	dx,offset dg:CntMes_ptr     ; printer might be off-line
	call	printf_crlf
	pop	ds
assume	ds:nothing

;--- display current queue
CntOk:
	call	copy_to_arg_buf
	cmp	byte ptr ds:[si],0	; is the queue empty?
	je	QueueEmpty
	mov	di,offset dg:FstMes
	push	ds
	push	cs
	pop	ds
assume	ds:dg
	mov	dx,offset dg:crlf_ptr
	call	std_printf
AnotherFile:
	mov	dx,offset dg:dispmes_ptr
assume	ds:dg
	mov	whichmes,di		; print one of the two messages
	mov	di,offset dg:SecMes	; once 1st mes printed, always print second
	call	printf_crlf
	pop	ds
assume	ds:nothing
	add	si,MaxFileLen		; point to next entry in queue
	call	copy_to_arg_buf
	cmp	byte ptr ds:[si],0	; end of queue?
	push	ds
	push	cs
	pop	ds
assume	ds:dg
	jne	AnotherFile
	pop	ax			; flush stack
	jmp	short quit_trans	; all done

copy_to_arg_buf:
	push	di
	push	si
	mov	di,offset dg:arg_buf
copy_the_name:
	lodsb
	or	al,al
	jz	name_copied
	stosb
	jmp	short copy_the_name
name_copied:
	stosb
	pop	si
	pop	di
	ret

QueueEmpty:
assume	ds:nothing
	push	cs			; queue is empty, print message
	pop	ds
assume	ds:dg
	mov	dx,offset dg:NoFils_ptr
	call	printf_crlf

;--- exit transient
quit_trans:
	mov	ax,0105H		; unlock the print queue
	call	IntWhileBusy		; on return DS:SI points to queue
	cmp	[PInst],1
	jne	RegQuit 		; printer was installed when we arrived
	mov	ax,CodeR
	mov	ds,ax
assume	ds:CodeR
	XOR	BX,BX
	MOV	CX,5			; StdIN,StdOUT,StdERR,StdAUX,StdPRN
CLS_LP: 				; Close STD handles before
					; keep process
	MOV	AH,CLOSE
	INT	21H
	INC	BX
	LOOP	CLS_LP
	MOV	DX,[ENDRES]		; install print...
	MOV	AX,KEEP_PROCESS SHL 8	; Exit code 0
	INT	21H

assume	ds:dg
RegQuit:
	MOV	AX,(EXIT SHL 8) 	; quit with no error
	INT	21H
NotYet:
	JMP	SETBUF


;--- Return the size of a filename in the queue ---
; Entry:	DS:SI points to name
; Exit: 	CX = size of the name
GetNameSize:
	push	si
	xor	cx,cx
NSLoop:
	lodsb
	or	al,al
	jz	NSDone
	inc	cx
	jmp	short NSLoop
NSDone:
	pop	si
	ret



ARGDEVJ:
	JMP	ARGDEV
MORESTUFF:
	CMP	AX,1
	jnz	NotEOL
	jmp	SETBUF			; End of command line
NotEOL:
	CMP	AX,2
	jnz	NotAFile
	jmp	PaFile			; Must be a filename to print
NotAFile:
	CMP	AX,4
	JNZ	BADTOK			; Unknown return
;
; We have a switch.  Figure out what it is...
;
	OR	[TOKBUF],20H		; Convert to lower case
	CMP	[TOKBUF],"b"
	jnz	NotSetSiz
	jmp	SETSIZ			; Buffer size
NotSetSiz:
	CMP	[TOKBUF],"d"
	JZ	ARGDEVJ 		; Device

if hardint
	CMP	[TOKBUF],"u"
	jnz	NotBusyVal
	jmp	BusyVal 		; Set BUSYTICK
NotBusyVal:
	CMP	[TOKBUF],"m"
	jnz	NotMaxVal
	jmp	MAXVAL			; Set MAXTICK
NotMaxVal:
	CMP	[TOKBUF],"s"
	jnz	NotTimeVal
	jmp	TIMEVAL 		; Set TIMESLICE and SLICECNT
NotTimeVal:
endif
	cmp	[TokBuf],"q"
	jnz	NotQVal
	jmp	QVal			; Set queue size
NotQVal:
	cmp	[TokBuf],"p"
	jz	SetPrintMode		; turn off cancel mode
	cmp	[TokBuf],"c"
	jz	SetCancelMode		; turn on cancel mode
	cmp	[TokBuf],"t"
	jz	CancelAll		; cancel all files
BADTOK:
	MOV	DX,OFFSET DG:INVPARM_ptr
	call	printf_crlf
	cmp	[PInst],0		; print not installed?
	jne	OKParseAgn
	jmp	ERREX2


;--- Turn Cancel mode off ---
SetPrintMode:
	cmp	[PInst],0		; has print been installed?
	jne	OkSetPrintM
	jmp	SetBuf			; no, better do it now

OkSetPrintM:
	mov	[CanFlag],0

OKParseAgn:
	jmp	ParseAgn


;--- Turn Cancel mode on ---
SetCancelMode:
	cmp	[PInst],0		; has print been installed?
	jne	OkSetCancelM
	jmp	SetBuf			; no, better do it now

OkSetCancelM:
	mov	[CanFlag],1
	jmp	ParseAgn


;--- Cancel all files ---
CancelAll:
	cmp	[PInst],0		; has print been installed?
	jne	OkCancelAll
	jmp	SetBuf			; no, better do it now

OkCancelAll:
	push	si			; save parse pointer
	mov	ax,0103H		; cancel command
	call	IntWhileBusy
	pop	si			;restore parse pointer
	jmp	SetBufJ


if hardint
;--- Set value of BUSYTICK ---
BUSYVAL:
	CALL	CPARSE			; Get size
	Jc	BADTOK
	CMP	AX,2
	jnz	BADTOK
	cmp	[PInst],0
	jne	BadTok			; Allowed only before installing
	CALL	GETNUM			; Convert
	JC	BADTOK
	OR	AH,AH
	JNZ	BADTOK			; To big
	push	ds
	mov	dx,CodeR
	mov	ds,dx
assume	ds:CodeR
	MOV	[BUSYTICK],AL
	pop	ds
assume	ds:dg
	JMP	PARSEAGN


;--- Set value of MAXTICK ---
MAXVAL:
	CALL	CPARSE			; Get size
	JC	BADTOKJ2
	CMP	AX,2
	JNZ	BADTOKJ2
	cmp	[PInst],0
	jne	BadTokj2		; Allowed only before installing
	CALL	GETNUM			; Convert
	JC	BADTOKJ2
	OR	AH,AH
	JNZ	BADTOKJ2		; To big
	push	ds
	mov	dx,CodeR
	mov	ds,dx
assume	ds:CodeR
	MOV	[MAXTICK],AL
	pop	ds
assume	ds:dg
	JMP	PARSEAGN


BadTokJ2:
	jmp	BadTok

;--- Set value of Time parameters ---
TIMEVAL:
	CALL	CPARSE			; Get size
	JC	BADTOKJ2
	CMP	AX,2
	JNZ	BADTOKJ2
	cmp	[PInst],0
	jne	BadTokJ2		; Allowed only before installing
	CALL	GETNUM			; Convert
	JC	BADTOKJ2
	OR	AH,AH
	JNZ	BADTOKJ2		; To big
	push	ds
	mov	dx,CodeR
	mov	ds,dx
assume	ds:CodeR
	MOV	[TIMESLICE],AL
	MOV	[SLICECNT],AL
	pop	ds
assume	ds:dg
	JMP	PARSEAGN
endif

;--- Set Size of Buffer ---
SETSIZ:
	CALL	CPARSE			; Get size
	JC	BADTOKJ
	CMP	AX,2
	JNZ	BADTOKJ
	cmp	[PInst],0
	jne	BadTokJ 		; Allowed only before installing
	CALL	GETNUM			; Convert
	JC	BADTOKJ
	CMP	AX,512
	JB	BADTOKJ 		; To small
	CMP	AX,1024 * 16
	JA	BADTOKJ 		; To Big
	push	ds
	mov	dx,CodeR
	mov	ds,dx
assume	ds:CodeR
	MOV	[BLKSIZ],AX
	pop	ds
assume	ds:dg
	JMP	PARSEAGN


;--- set file queue size ---
QVal:
	CALL	CPARSE			; Get size
	JC	BADTOKJ
	CMP	AX,2
	JNZ	BADTOKJ
	cmp	[PInst],0
	jne	BadTokJ 		; Allowed only before installing
	CALL	GETNUM			; Convert
	JC	BADTOKJ
	CMP	AX,MinQueueLen
	JB	BADTOKJ 		; To small
	CMP	AX,MaxQueueLen
	JA	BADTOKJ 		; To Big
	push	ds
	mov	dx,CodeR
	mov	ds,dx
assume	ds:CodeR
	MOV	[QueueLen],Al
	pop	ds
assume	ds:dg
	JMP	PARSEAGN

BADTOKJ:
	JMP	BADTOK


;--- process a file name ---
PaFile:
	cmp	[PInst],0		; has print been installed?
	jne	OkPaFile
	jmp	SetBuf			; no, better do it now

OkPaFile:
	cld				; just in case...
	mov	[Ambig],0		; assume not an ambigous file

;--- Check for drive specifier
	push	si			; save parse pointer
	mov	si,di			; SI points to file token
	mov	di,offset dg:NameBuf	; buffer for full file name
	cmp	byte ptr [si+1],":"     ; check if there is a drive designator
	je	DrvFound		; yes, use it...
	mov	ah,Get_Default_Drive	; no, get it...
	int	21h
	mov	dl,al			; save for later (used in DoPath)
	inc	dl			; adjust to proper code (A=1,B=2,...)
	add	al,"A"                  ; conver to letter code
	stosb				; store letter code
	mov	al,":"
	stosb
	jmp	short DoPath

DrvFound:
	mov	al,byte ptr [si]	; get drive letter
	call	UpConvt 		; conver to upper case
	sub	al,"@"                  ; conver to proper code...
	jbe	BadDrvJ
	mov	dl,al			; save for later (used in DoPath)
	movsb				; move the drive letter
	movsb				; move the ":"

;--- Check for full path
DoPath:
	mov	al,[PathChar]
	cmp	byte ptr [si],al	; does it start from the root?
	je	DrvChk			; yes, check for valid drive
	stosb				; store path character
	push	si
	mov	si,di			; buffer for current directory
	mov	ah,Current_Dir		; get current directory
	int	21h
	jnc	FEndLop
	pop	si
BadDrvJ:
	jmp	bad_drive

FEndLop:				; find the terminating nul
	lodsb
	or	al,al
	jnz	FEndLop
	dec	si			; adjust to point to nul
	mov	ax,di			; save pointer to beg. of path
	mov	di,si			; here is were the file name goes
	pop	si			; points to file name
	cmp	ax,di			; if equal then file is in the root
	je	PathFound		; if so, do not add another path char
	mov	al,[PathChar]
	stosb				; put path separator before file name
	jmp	short PathFound

;--- Check for valid drive.
;    Done by getting current dir of the drive in question (already in
;	DL) into NameBuf. If no error the valid drive and we throw
;	away the current dir stuf by overwriting it with the filename.
;
DrvChk: 				; DL has drive number (from DrvFound)
	push	si
	mov	si,di			; buffer for current directory
	mov	ah,Current_Dir		; get current directory
	int	21h
	pop	si
	jnc	PathFound
	jmp	bad_drive

PathFound:
	mov	cx,MaxFileLen		; lets not overflow file name buffer
	mov	ax,di			; CX := MaxFileLen -
					;	long(&NameBuf - &PtrLastchar)
	sub	ax,offset dg:NameBuf	; size of the filename so far
	sub	cx,ax			; size left for the filename
	jnc	MovLop

	mov	cx,1			; Set cx to Fall through to FNTooLong


MovLop: 				; WHILE (Length(FileName) <= MaxFileLen)
					;	DO copy in the file name
	lodsb
	stosb
	cmp	al,"*"
	je	IsAmbig
	cmp	al,"?"
	jne	ContMov
IsAmbig:
	mov	[Ambig],1		;	ambigous filename found

ContMov:
	or	al,al			;	end of name?
	jz	MoveDone
	loop	MovLop			; END of Loop

	dec	di
	mov	[NulPtr],di
	jmp	FNTooLong		; if we got here the name was too long


MoveDone:				; we have the full absolute name...
	dec	di
	mov	[NulPtr],di		; save pointer to termanting nul

;--- check for an option following name
	pop	si			; restore pointer to parse line
	mov	di,offset dg:TokBuf	; get next token here
	call	CParse
	cmp	ax,4			; an option?
	jne	NoOption		; no, do it later...
	or	[TokBuf],20h		; conver to lower case
	cmp	[TokBuf],"c"            ; cancel option?
	jne	NotCancel
	mov	[CanFlag],1		; set cancel flag
	jmp	short SkipTok

NotCancel:
	cmp	[TokBuf],"p"
	jne	NoOption
	mov	[CanFlag],0		; reset cancel flag
	jmp	short SkipTok

NoOption:
	mov	si,[LastSI]		; whatever it is, lets do it later...

;--- chose action on filename
SkipTok:
	push	si			; save pointer to parse line
	cmp	[CanFlag],1		; are we in cancel mode
	jne	CheckName
	jmp	GoCancel		; yes, use name to cancel file

;--- check file exists
CheckName:
	cmp	[Ambig],1		; is this an ambigous name?
	jne	NotAmbig

AnotherAmbig:				; do another ambigous name
	call	GetAbsN 		; get abs name into NameBuf
	jnc	SubFile 		; send it to resident
	jmp	bad_file		; an error

NotAmbig:
	mov	dx,offset dg:NameBuf
	mov	ax,(open shl 8) 	; open for reading...
	int	21h
	jc	bad_file_open
	mov	bx,ax			; copy handle
	mov	ah,close
	int	21h
SubFile:
	mov	dx,offset dg:NameBuf
	mov	word ptr [SubPack+1],dx ; store pointer to name in
	mov	word ptr [SubPack+3],ds ;  submit packet
	mov	dx,offset dg:SubPack	; DS:DX address of packet
	mov	ax,0101H		; submit a file to resident
	call	IntWhileBusy
	jnc	Cont0			; successfull, queue not full now...
	cmp	ax,error_queue_full
	jne	other_errs
	cmp	[QFullMes],1		; Have wa already issued the message?
	je	Cont1			; yes, not again...
	mov	[QFullMes],1
	mov	dx,offset dg:FullMes_ptr
	call	printf_crlf
	jmp	short Cont1

other_errs:

;***** PROCESS OTHER SUBMIT ERRORS

Cont0:
	mov	[QFullMes],0		; queue is not full
Cont1:
	cmp	[Ambig],1		; are we processing an ambigous name?
	jne	Cont2
	call	GetAbsN2		; get another file name
	jnc	SubFile
Cont2:
	pop	si
	jmp	ParseAgn1


;--- process file name errors
bad_drive:
	mov	dx,offset dg:InvDrvMes_ptr
	jmp	short BadName

Bad_File_Open:
	mov	dx,offset dg:BadNameMes_ptr
	PUSHF
	SaveReg <BX,CX,SI,DI,BP,ES,DS,AX,DX>
	MOV	AH,GetExtendedError
	INT	21h
	RestoreReg  <CX,BX>		; restore original AX
	MOV	DX,OFFSET DG:AccDen_PTR
	CMP	AX,65			; network access denied?
	JZ	NoMove			; Yes, return it.
	MOV	AX,BX
	MOV	DX,CX
NoMove:
	RestoreReg  <DS,ES,BP,DI,SI,CX,BX>
	popf
	Jmp	short badname

bad_file:
	mov	dx,offset dg:BadNameMes_ptr
	jmp	short BadName

FNTooLong:
	mov	dx,offset dg:NamTMes_ptr

BadName:
	call	printf_crlf
	pop	si
	jmp	ParseAgn1


;--- Issue a cancel command ---
GoCancel:
	mov	dx,offset dg:NameBuf	; filename
	mov	ax,0102H
	call	IntWhileBusy
	jc	BadCancel
	pop	si
	jmp	ParseAgn1

BadCancel:
	cmp	ax,2
	je	BadCanName

;***** PROCESS CANCEL ERROR

BadCanName:
	mov	dx,offset dg:BadCanMes_ptr
	jmp	badname

;--- Calculate end of resident memory ---
SETBUF:
	mov	dl,[PathChar]
	mov	ax,CodeR
	mov	es,ax
assume	es:CodeR
	mov	[PChar],dl		; sneaky, uh?

;--- check device
	cmp	[DevSpec],1		; was it already specified?
	je	DoQSize
	mov	dx,offset dg:prompt_ptr
	call	std_printf
	mov	dx,offset dg:TokBuf
	mov	[TokBuf],9		; max of 9 chars
	mov	[TokBuf+1],0		; assume zero in
	mov	ah,std_con_string_input
	int	21h			; get dev name
	mov	dx,offset dg:crlf_ptr
	call	std_printf
	mov	cl,[TokBuf+1]		; check how many read in
	or	cl,cl
	jz	DoQSize 		; a CR was typed
	xor	ch,ch
	mov	si,offset dg:TokBuf+2
	mov	di,offset CodeR:ListName
	push	si
	add	si,cx
	dec	si
	cmp	byte ptr [si],':'
	jne	gdevn
	dec	cx			; get rid of trailing ':'
gdevn:
	pop	si
gdlop:
	lodsb				; copy name
	call	UpConvT
	stosb
	loop	gdlop

;--- queue size
DoQSize:
	push	es
	pop	ds
assume	ds:CodeR
	mov	ax,MaxFileLen		; maximum length of a file name
	mul	[QueueLen]		; AX = result
	add	ax,offset CodeR:FileQueue
	mov	[EndQueue],ax		; save pointer to last nul
	inc	ax
	mov	[buffer],ax		; beggining of buffer

;--- buffer size
	add	ax,[BlkSiz]
	mov	[ENDPTR],AX		; Set end of buffer pointer
	mov	[NXTCHR],AX		; Buffer empty
	add	ax,100h 		; allow for header
	ADD	AX,16			; Convert to para
	SHR	AX,1
	SHR	AX,1
	SHR	AX,1
	SHR	AX,1
	mov	[EndRes],ax		; Add size of buffer to term res size
	jmp	MoveTrans


assume	ds:dg,es:dg
TransRet:				; after moving the transient we come
					;  here. Isn't this fun, uh?
	sti				; Ints were off during initialization
;--- normalize int handlers for new location of dg
	MOV	AX,(SET_INTERRUPT_VECTOR SHL 8) OR 23H
	MOV	DX,OFFSET DG:INT_23
	INT	21H
	MOV	AX,(SET_INTERRUPT_VECTOR SHL 8) OR 24H
	MOV	DX,OFFSET DG:INT_24
	INT	21H

	mov	[PInst],1		; remember we just installed resident part
	mov	si,[LastSI]		; back up one token
	jmp	ParseAgn1		; restart parse


ARGDEV:
	push	ds
	mov	ax,CodeR
	sub	ax,10h			; AX points to the header
	mov	ds,ax
	LODSB				; mandatory colon before device
	POP	DS
	CMP	AL,':'
	JZ	DoCparse
	dec	si
	jmp	short xk00
DoCparse:
	CALL	CPARSE			; Get device name, CX is size of token
	jnc	xk01
xk00:
	jmp	BADTOK
xk01:
	cmp	[PInst],0
	jne	xk00
	CMP	AX,2
	jnz	xk00
	PUSH	SI
	PUSH	DI
	MOV	SI,DI
	mov	ax,CodeR
	mov	es,ax
assume	es:CodeR
	MOV	WORD PTR [LISTNAME],2020H	; Nul out default
	MOV	[LISTNAME+2]," "
	MOV	DI,OFFSET CodeR:LISTNAME
	ADD	SI,CX
	DEC	SI			;Point to last char of name
	CMP	BYTE PTR [SI],':'
	JNZ	GOODCNT
	DEC	CX			;Chuck the trailing ':'
GOODCNT:
	CMP	CX,8
	JBE	GOODCNT2
	MOV	CX,8			; Limit to 8 chars for device
GOODCNT2:
	POP	SI
	PUSH	SI
TRLOOP:
	LODSB
	CALL	UPCONVt
	STOSB
	LOOP	TRLOOP
	POP	DI
	POP	SI
	push	cs
	pop	es
assume	es:dg
	mov	[DevSpec],1		; remember that a device was specified
	JMP	PARSEAGN

;--- Uper case convertion ---
UPCONVt:
	CMP	AL,'a'
	JB	NOCONVt
	CMP	AL,'z'
	JA	NOCONVt
	SUB	AL,20H
NOCONVt:
	RET

GETNUM:
; Return binary number in AX of number in ES:DI. DI,SI preserved
	PUSH	SI
	PUSH	DI
	XOR	BX,BX
	MOV	SI,DI
	MOV	CX,10			; Base 10 multiplier
	LODSB
	CMP	AL,':'
	JNZ	BADRET			; Must have leading ':' on numbers
NLP:
	LODSB
	OR	AL,AL
	JZ	GOODRET
	CMP	AL,'0'
	JB	BADRET
	CMP	AL,'9'
	JA	BADRET
	SUB	AL,'0'
	XOR	AH,AH
	XCHG	AX,BX
	MUL	CX
	ADD	AX,BX
	XCHG	AX,BX
	JMP	NLP

GOODRET:
	CLC
MORERET:
	MOV	AX,BX
	POP	DI
	POP	SI
	RET

BADRET:
	STC
	JMP	MORERET



;-----------------------------------------------------------------------;
;	Return first absolute name from ambigous name
;
;	Entry:	NameBuf has the ambigous File Name
;
;	Exit:	Carry Set if no files match
;		else NameBuf has the absolute name
;
assume	ds:dg, es:dg

GetAbsN:
	mov	ah,Set_DMA		; buffer for ffirst / fnext
	mov	dx,offset dg:SearchBuf
	int	21h

;--- look for a match
	mov	dx,offset dg:NameBuf
	mov	cx,0			; no attributes
	mov	ah,Find_First
	int	21h
	jnc	FstFound
	ret				; return with carry set

;--- Place new name in NameBuf
FstFound:
	mov	si,[NulPtr]		; scan back
	std
FstLoop:
	lodsb
	cmp	al,PathChar
	jne	FstLoop
	cld				; just in case...
	inc	si
	inc	si
	mov	[FnamPtr],si
	call	CopyName
	clc
	ret



;-----------------------------------------------------------------------;
;	Return next absolute name from ambigous
;
GetAbsN2:
	mov	ah,Set_DMA		; buffer for ffirst / fnext
	mov	dx,offset dg:SearchBuf
	int	21h
	mov	ah,Find_Next
	int	21h
	jnc	NxtFound
	ret				; return with carry set

NxtFound:
	call	CopyName
	clc
	ret



;-----------------------------------------------------------------------;
;	Copy name from search buf to NameBuf
;
CopyName:
	mov	di,[FNamPtr]
	mov	si,offset dg:SearchBuf.find_buf_pname
	cld
CopyAgn:
	lodsb
	stosb
	or	al,al			; nul found?
	jne	CopyAgn
	ret



BREAK	<CPARSE>

;-----------------------------------------------------------------------;
; ENTRY:								;
;	(CodeR-10H):SI	Points to input buffer				;
;	ES:DI	Points to the token buffer				;
;									;
; EXIT: 								;
;	DS:SI	Points to next char in the input buffer 		;
;	ES:DI	Points to the token buffer				;
;	CX	Character count 					;
;	AX	Condition Code						;
;		=1 same as carry set					;
;		=2 normal token 					;
;		=4 switch character, char in token buffer		;
;	Carry Flag	Set if a CR was found, Reset otherwise		;
;									;
; MODIFIES:								;
;	CX, SI, AX and the Carry Flag					;
;									;
;-----------------------------------------------------------------------;

TAB	equ	09h
CR	equ	0dh

CPARSE:
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	pushf				; save flags
	mov	[LastSI],si		; remember last token in case of backup
	push	ds
	mov	ax,CodeR
	sub	ax,10h			; AX points to the header
	mov	ds,ax
	push	di			; save the token buffer addrss
	xor	cx,cx			; no chars in token buffer
	call	kill_bl

	cmp	al,CR			; a CR?
	jne	sj2			; no, skip
sj1:
	mov	ax,1			; condition code
	dec	si			; adjust the pointer
	pop	di			; retrive token buffer address
	pop	ds
	popf				;restore flags
	stc				;set the carry bit
	ret

sj2:
	mov	dl,[SWITCHAR]
	cmp	al,dl			;is the char the switch char?
	jne	anum_char		;no, process...
	call	kill_bl
	cmp	al,CR			;a CR?
	je	sj1			;yes, error exit
	call	move_char		;Put the switch char in the token buffer
	mov	ax,4			;Flag switch
	jmp	short x_done2

anum_char:
	call	move_char		;just an alphanum string
	lodsb
	cmp	al,' '
	je	x_done
	cmp	al,tab
	je	x_done
	cmp	al,CR
	je	x_done
	cmp	al,','
	je	x_done
	cmp	al,'='
	je	x_done
	cmp	al,dl			;Switch character
	jne	anum_char
x_done:
	dec	si			;adjust for next round
	mov	ax,2			;normal token
x_done2:
	push	ax			;save condition code
	mov	al,0
	stosb				;null at the end
	pop	ax
	pop	di			;restore token buffer pointer
	pop	ds
	popf
	clc				;clear carry flag
	ret


kill_bl proc	near
	lodsb
	cmp	al,' '
	je	kill_bl
	cmp	al,tab
	je	kill_bl
	cmp	al,','                  ;a comma?
	je	kill_bl
	cmp	al,'='
	je	kill_bl
	ret
kill_bl endp


move_char proc	near
	stosb				;store char in token buffer
	inc	cx			;increment char count
	ret
move_char endp


;-----------------------------------------------------------------------;
GetHInt:
assume	ds:dg,es:dg
	push	es
	MOV	AX,(GET_INTERRUPT_VECTOR SHL 8) OR 24H
	INT	21H
assume	es:nothing
	MOV	WORD PTR [HARDCH],BX
	MOV	WORD PTR [HARDCH+2],ES
	pop	es
assume	es:dg
	ret

;-----------------------------------------------------------------------;
SetInts proc	near
assume	ds:dg,es:dg

	MOV	AX,(SET_INTERRUPT_VECTOR SHL 8) OR 23H
	MOV	DX,OFFSET DG:INT_23
	INT	21H

	MOV	AX,(SET_INTERRUPT_VECTOR SHL 8) OR 24H
	MOV	DX,OFFSET DG:INT_24
	INT	21H

	ret
SetInts endp


;-----------------------------------------------------------------------;
Public PRNT002S, PRNT002E
PRNT002s:

INT_24_RETADDR	DW	OFFSET DG:INT_24_BACK
in_int_23 db	0			; reentrancy flag

PRNT002E:

INT_24	PROC	FAR
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	PUSHF
	PUSH	CS
	PUSH	[INT_24_RETADDR]
	PUSH	WORD PTR [HARDCH+2]
	PUSH	WORD PTR [HARDCH]
	RET
INT_24	ENDP

INT_24_BACK:
	CMP	AL,2			;Abort?
	JNZ	IRETI
	inc	[in_int_23]		; no int 23's allowed
	push	cs
	pop	ds
assume	ds:dg
	push	cs
	pop	ss
assume	ss:dg
	mov	sp, offset dg:intStk	; setup local int stack
	cmp	[PInst],2
	je	DoNotUndo
DoUndo:
	call	Restore_ints
DoNotUndo:
	MOV	AH,EXIT
	MOV	AL,0FFH
	INT	21H
IRETI:
	IRET

;-----------------------------------------------------------------------;

INT_23:
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	cmp	[in_int_23],0		; check for a re-entrant call
	je	do_int_23
	iret				; discard further int 23's

do_int_23:
	inc	[in_int_23]		; make sure no more int 23's
	push	cs
	pop	ds
assume	ds:dg
	push	cs
	pop	ss
assume	ss:dg
	mov	sp, offset dg:intStk	; setup local int stack
	cmp	[PInst],2
	jne	DoUndo
UnlockQueue:
	mov	ax,0105H
	call	IntWhileBusy		; unlock print queue (just in case)
	jmp	short DoNotUndo


;-----------------------------------------------------------------------;
;	Restore all ints used by print to original values

Restore_ints proc near

assume	ds:dg,es:nothing,ss:dg

	CLI
	mov	ax,(set_interrupt_vector shl 8) or SOFTINT  ; (SOFTINT)
	push	ds
	lds	dx,[i28vec]
	int	21h
	pop	ds

	mov	ax,(set_interrupt_vector shl 8) or COMINT  ; (COMINT)
	push	ds
	lds	dx,[i2fvec]
	int	21h
	pop	ds

	if	IBM

	mov	ax,(set_interrupt_vector shl 8) or 13h
	push	ds
	lds	dx,[i13vec]
	int	21h
	pop	ds

	mov	ax,(set_interrupt_vector shl 8) or 15h
	push	ds
	lds	dx,[i15vec]
	int	21h
	pop	ds

	mov	ax,(set_interrupt_vector shl 8) or 17h
	push	ds
	lds	dx,[i17vec]
	int	21h
	pop	ds

	mov	ax,(set_interrupt_vector shl 8) or 14h
	push	ds
	lds	dx,[i14vec]
	int	21h
	pop	ds

	mov	ax,(set_interrupt_vector shl 8) or 05h
	push	ds
	lds	dx,[i05vec]
	int	21h
	pop	ds

	endif

	if	HARDINT

	mov	ax,(set_interrupt_vector shl 8) or INTLOC  ; (INTLOC)
	push	ds
	lds	dx,[i1cvec]
	int	21h
	pop	ds

	endif
	STI
	ret

Restore_ints endp

CODE	ENDS


Stack	Segment Stack

Public PRNT003S, PRNT003E
PRNT003S:
	dw	100 dup(0)

TransSize	label	byte		; end of transient
					;  only because code is para algned
PRNT003E:

Stack	Ends

	END	Transient
