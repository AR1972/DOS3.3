;	SCCSID = @(#)print_r.asm	4.7 85/09/13
	INCLUDE pridefs.inc


BREAK	<Resident Portion>

;
;	MSDOS V3.00 PRINT
;
;	Resident Portion
;

Code	Segment public para
	extrn	TransRet:WORD,TransSize:WORD
Code	EndS



BREAK	<Resident Data>

CodeR	Segment public para

	extrn	ERRMES:BYTE, ERRMEST:BYTE, BELMES:BYTE, ErrMesT2:BYTE
	extrn	CanMes:BYTE, CanFilNAm:BYTE, AllCan:BYTE, ERR0:BYTE
	extrn	ERR1:BYTE, ERR2:BYTE, ERR3:BYTE, ERR4:BYTE, ERR5:BYTE
	extrn	ERR6:BYTE, ERR7:BYTE, ERR8:BYTE, ERR9:BYTE, ERR10:BYTE
	extrn	ERR11:BYTE, ERR12:BYTE, FATMES:BYTE, BADDRVM:BYTE,
	extrn	BADMES:BYTE, badmeslen:WORD, GOODMES:BYTE, goodmeslen:WORD

if hardint
	public	SliceCnt, BusyTick, MaxTick, TimeSlice
endif

	public	EndRes, BlkSiz, QueueLen, PChar
	public	ListName, FileQueue, EndQueue, Buffer
	public	EndPtr, NxtChr, MoveTrans

assume	CS:CodeR

public PRNR001S,PRNR001E
PRNR001S:
	db	"*** Microsoft/V310 ***"

		DB	(362 - 80h) + 310 DUP (?)  ; (362 - 80h) is IBM's New
						   ; recommended Stack Size -
						   ; Old recommended Stack Size
						   ; == New stack growth
ISTACK		LABEL	WORD		;Stack starts here and grows down the

;Resident data

;
; Due to flagrant bogosity by file servers, BUSY is *ALWAYS* relevant.
;
BUSY		DB	0		;Internal ME flag

	IF	HARDINT
;
; WARNING!!! The *&^%(*&^ 286 chip hangs if you access a word that will wrap
; at the segment boundary.  Make the initial INDOS point somewhere reasonable.
;
INDOS		DD	TimeSlice	;DOS buisy flag
NEXTINT 	DD	?		;Chain for int
NEXT_REBOOT	DD	?		;Chain for ROM bootstrap

fFake		db	0		; TRUE => do not diddle I/O ports
SOFINT		DB	0		;Internal ME flag
TICKCNT 	DB	0		;Tick counter
TICKSUB 	DB	0		;Tick miss counter
SLICECNT	DB	8		;Time slice counter, init to same val
					; as TIMESLICE

TIMESLICE	DB	8	;The PRINT scheduling time slice. PRINT
				; lets this many "ticks" go by before
				; using a time slice to pump out characters.
				; Setting this to 3 for instance means PRINT
				; Will skip 3 slices, then take the fourth.
				; Thus using up 1/4 of the CPU. Setting it
				; to one gives PRINT 1/2 of the CPU.
				; The above examples assume MAXTICK is
				; 1. The actual PRINT CPU percentage is
				; (MAXTICK/(1+TIMESLICE))*100

MAXTICK 	DB	2	;The PRINT in timeslice. PRINT will pump
				; out characters for this many clock ticks
				; and then exit. The selection of a value
				; for this is dependent on the timer rate.

BUSYTICK	DB	1	;If PRINT sits in a wait loop waiting for
				; output device to come ready for this
				; many ticks, it gives up its time slice.
				; Setting it greater than or equal to
				; MAXTICK causes it to be ignored.

;User gets TIMESLICE ticks and then PRINT takes MAXTICK ticks unless BUSYTICK
;	ticks go by without getting a character out.
	ENDIF

QueueLen	db	DefQueueLen	; Actual length of print queue
    even
EndQueue	dw	?		; pointer to end of print queue
QueueTail	dw	offset CodeR:FileQueue	; pointer to next free entry
						;  in the print queue
buffer		dw	?		; pointer to data buffer

I24_ERR 	DW	?		;Save location for INT 24H error code
Ctrlc		DB	?		; saved ^C trapping state
SPNEXT		DD	?		;Chain location for INT 28
COMNEXT 	DD	?		;Chain location for INT 2F
SSsave		DW	?		;Stack save area for INT 24
SPsave		DW	?
HERRINT 	DD	?		;Place to save Hard error interrupt
LISTDEV 	DD	?		;Pointer to Device
COLPOS		DB	0		;Column position for TAB processing
CURRFIL 	DB	0
NXTCHR		DW	?
CURRHAND	DW	-1
PrinterNum	DW	-1		; index for printer
QueueLock	db	0		; queue lock, 0=unlocked


PChar		db	?		; path character
AmbCan		db	?		; = 1 ambigous cancel
CanFlg		db	?		; = 1 Current was already canceled
ACanOcrd	db	?		; = 1 a file was found during an
					;  ambigous cancel

;--- Warnning: this is a FCB!!
ACBuf		db	?
ACName		db	8 dup(?)
ACExt		db	3 dup(?)
		db	4 dup(?)	; how big is an unopened fcb???


CONTXTFLAG	DB	0		;0 means his context, NZ means me
HISPDB		DW	?
PABORT		DB	0		;Abort flag
BLKSIZ		DW	512		;Size of the PRINT I/O block in bytes
ENDPTR		DW	?

COMDISP 	LABEL	WORD		; Communications dispatch table
		DW	OFFSET CodeR:INST_REQ
		DW	OFFSET CodeR:ADDFIL
		DW	OFFSET CodeR:CANFIL
		DW	offset CodeR:CanAll
		DW	OFFSET CodeR:QSTAT
		DW	offset CodeR:EndStat
		DW	offset CodeR:QSTATDEV

;Resident messages

MESBAS		DW	OFFSET CodeR:ERR0
		DW	OFFSET CodeR:ERR1
		DW	OFFSET CodeR:ERR2
		DW	OFFSET CodeR:ERR3
		DW	OFFSET CodeR:ERR4
		DW	OFFSET CodeR:ERR5
		DW	OFFSET CodeR:ERR6
		DW	OFFSET CodeR:ERR7
		DW	OFFSET CodeR:ERR8
		DW	OFFSET CodeR:ERR9
		DW	OFFSET CodeR:ERR10
		DW	OFFSET CodeR:ERR11
		DW	OFFSET CodeR:ERR12
ENDRES		DW	?		; filled in at initialization time
PRNR001E:

CodeR	EndS



BREAK	<Resident Code>

CodeR	Segment public para

Break	<Server critical section routines>

TestSetServer:
IF  IBM
	CLC
	PUSH	AX
	MOV	AX,8700h		; Can I run?
	INT	2Ah
	POP	AX
ENDIF
	ret

LeaveServer:
IF  IBM
	PUSH	AX
	MOV	AX,8701h
	INT	2Ah
	POP	AX
ENDIF
	ret

;Interrupt routines
ASSUME	CS:CodeR,DS:NOTHING,ES:NOTHING,SS:NOTHING
;
; PRINT is stimulated by a hardware interrupt.
;
;
; The Server may also stimulate us during timer ticks (if we handled the
; ticks ourselves, it would be disasterous.  Therefore, we have a substitute
; entry here that simulates the timer stuff but does NOT muck with the ports.
;
	IF	HARDINT
FakeINT1C:
	MOV	fFake,-1
	JMP	SHORT InnerHardInt

HDSPINT:				;Hardware interrupt entry point
	mov	fFake,0
InnerHardInt:
	CALL	TestSetServer
	JNC	TickTime
	jmp	ChainInt
TickTime:
	INC	[TICKCNT]		;Tick
	INC	[TICKSUB]		;Tick
	CMP	[SLICECNT],0
	JZ	TIMENOW
	DEC	[SLICECNT]		;Count down
	JMP	SHORT HardIntDone	;Not time yet
TIMENOW:
	CMP	BUSY,0			;See if interrupting ourself
	JNZ	HardIntDone

	IF	IBM
	push	ax			; check for nested interrupts
	mov	al,00001011b		; select ISR in 8259
	out	20H,al
	JMP	x
x:
	in	al,20H			; get ISR register
	and	al,0FEH 		; mask timer int
	pop	ax
	jnz	HardIntDone		; there was another int in service...
	ENDIF

	PUSH	DS
	PUSH	SI
	LDS	SI,[INDOS]		;Check for making DOS calls
;
; WARNING!!! Due to INT 24 clearing the INDOS flag, we must test both INDOS
; and ERRORMODE at once!  These must be contiguous in MSDATA.
;
	CMP	WORD PTR [SI-1],0
	POP	SI
	POP	DS
	JNZ	HardIntDone		;DOS is Busy
	INC	[BUSY]			;Exclude furthur interrupts
	MOV	[TICKCNT],0		;Reset tick counter
	MOV	[TICKSUB],0		;Reset tick counter
	STI				;Keep things rolling

	IF	AINT
	TEST	fFake,-1
	JNZ	NoAck
	PUSH	AX
	MOV	AL,EOI			;Acknowledge interrupt
	OUT	AKPORT,AL
	POP	AX
NoAck:
	ENDIF

	CALL	DOINT
	CLI
	PUSH	AX
	MOV	AL,[TIMESLICE]
	MOV	[SLICECNT],AL		;Either soft or hard int resets time slice
	POP	AX
	DEC	Busy			;Done, let others in
HardIntDone:
	Call	LeaveServer
CHAININT:
	TEST	fFake,-1
	JNZ	DoIRET
	JMP	[NEXTINT]		;Chain to next clock routine
DoIRET:
	IRET
	ENDIF


;
; PRINT is stimulated by a spooler idle interrupt
;
SPINT:					;INT 28H entry point
	CALL	TestSetServer
	JC	NxtSp

	IF	HARDINT
	CMP	[BUSY],0
	JNZ	SpIntDone
	INC	[BUSY]			;Exclude hardware interrupt
	INC	[SOFINT]		;Indicate a software int in progress
	ENDIF

	STI				;Hardware interrupts ok on INT 28H entry
	CALL	DOINT

	IF	HARDINT
	CLI
	MOV	[SOFINT],0		;Indicate INT done
	PUSH	AX
	MOV	AL,[TIMESLICE]
	MOV	[SLICECNT],AL		;Either soft or hard int resets time slice
	POP	AX
	DEC	Busy
	ENDIF
SpIntDone:
	call	LeaveServer

NXTSP:	JMP	[SPNEXT]		;Chain to next INT 28

;
; Since we may be entering at arbitrary times, we need to get/set the extended
; error as we may end up blowing it away.  We do not do this on spooler ints.
;

public PRNR002S, PRNR002E
PRNR002S:

SaveState   DPL <>			; empty DPL

PRNR002E:

public enterprint
EnterPRINT:
	IF	HardInt
	TEST	SofInt,-1
	JNZ	EnterDone
	ENDIF
	MOV	AH,GetExtendedError
	CALL	DO_21
	MOV	SaveState.DPL_AX,AX
	MOV	SaveState.DPL_BX,BX
	MOV	SaveState.DPL_CX,CX
	MOV	SaveState.DPL_DX,DX
	MOV	SaveState.DPL_SI,SI
	MOV	SaveState.DPL_DI,DI
	MOV	SaveState.DPL_DS,DS
	MOV	SaveState.DPL_ES,ES
EnterDone:
	RET

public leaveprint
LeavePRINT:
	IF	HardInt
	TEST	SofInt,-1
	JNZ	LeaveDone
	ENDIF
	MOV	AX,(ServerCall SHL 8) + 10
	PUSH	CS
	POP	DS
	MOV	DX,OFFSET CodeR:SaveState
	CALL	Do_21
LeaveDone:
	RET

public doint
DOINT:
ASSUME	CS:CodeR,DS:NOTHING,ES:NOTHING,SS:NOTHING
	CMP	[CURRFIL],0
	JNZ	GOAHEAD
SPRET:
	ret				;Nothing to do

GOAHEAD:
	cmp	[QueueLock],1
	je	spret			; queue locked, do nothing...
	PUSH	AX			;Need a working register
	MOV	[SSsave],SS
	MOV	[SPsave],SP
	MOV	AX,CS
	CLI
;Go to internal stack to prevent INT 24 overflowing system stack
	MOV	SS,AX
	MOV	SP,OFFSET CodeR:ISTACK
	STI
	PUSH	ES
	PUSH	DS
	PUSH	BP
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DI
	PUSH	CS
	POP	DS
ASSUME	DS:CodeR

	Call	EnterPRINT

	MOV	BX,[NXTCHR]
	CMP	BX,[ENDPTR]
	JB	PLOOP
	JMP	READBUFF		;Buffer empty

DONEJMPJP:
	POPF
DONEJMPJ:
	JMP	DONEJMP

FILEOFJ:
ASSUME	DS:CodeR
	JMP	FILEOF

PLOOP:
	IF	HARDINT
	MOV	BX,[NXTCHR]
	CMP	BX,[ENDPTR]
	JAE	DONEJMPJ		;Buffer has become empty
	CMP	[SOFINT],0
	JNZ	STATCHK
	PUSH	AX
	MOV	AL,[MAXTICK]
	CMP	[TICKCNT],AL		;Check our time slice
	POP	AX
	JAE	DONEJMPJ
STATCHK:
	ENDIF

	CALL	PSTAT
	PUSHF
	CMP	[CURRFIL],0
	JZ	DONEJMPJP		;File got cancelled by error
	POPF

	IF	HARDINT
	JZ	DOCHAR			;Printer ready
	CMP	[SOFINT],0
	ENDIF

	JNZ	DONEJMP 		;If soft int give up

	IF	HARDINT
	PUSH	AX
	MOV	AL,[BUSYTICK]
	CMP	[TICKSUB],AL		;Check our busy timeout
	POP	AX
	JAE	DONEJMP
	JMP	PLOOP
	ENDIF

DOCHAR:
	MOV	AL,BYTE PTR [BX]
	CMP	AL,1AH			;^Z?
	JZ	FILEOFJ 		;CPM EOF
	CMP	AL,0DH			;CR?
	JNZ	NOTCR
	MOV	[COLPOS],0
NOTCR:
	CMP	AL,9			;TAB?
	JNZ	NOTABDO
	MOV	CL,[COLPOS]		;expand tab to # spaces
	OR	CL,0F8H
	NEG	CL
	XOR	CH,CH
	JCXZ	TABDONE 		;CX contains # spaces to print
TABLP:
	MOV	AL," "
	INC	[COLPOS]
	PUSH	CX
	CALL	POUT
	POP	CX
	DEC	CX			;G
	JZ	TABDONE 		;G We're done - get next char
	JMP	PLOOP			;G Keep processing tab

;G	LOOP	TABLP
;G	JMP	TABDONE

NOTABDO:
	CMP	AL,8			;Back space?
	JNZ	NOTBACK
	DEC	[COLPOS]
NOTBACK:
	CMP	AL,20H			;Non Printing char?
	JB	NOCHAR
	INC	[COLPOS]		;Printing char
NOCHAR:
	CALL	POUT			;Print it
TABDONE:
	INC	[NXTCHR]		;Next char

	IF	HARDINT
	MOV	[TICKSUB],0		;Got a character out, Reset counter
	CMP	[SOFINT],0		;Soft int does one char at a time
	JNZ	DONEJMP
	JMP	PLOOP
	ENDIF

DONEJMP:
	CALL	CONTEXT_BACK
	Call	LeavePRINT

	POP	DI
	POP	SI
	POP	DX
	POP	CX
	POP	BX
	POP	BP
	POP	DS
	POP	ES
ASSUME	DS:NOTHING,ES:NOTHING
	CLI
	MOV	SS,[SSsave]		;Restore Entry Stack
	MOV	SP,[SPsave]
	STI
	POP	AX
	RET

CONTEXT_BACK:
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	CMP	[CONTXTFLAG],0
	JZ	CONTOK
	SaveReg <AX,BX>
	MOV	BX,[HISPDB]
	MOV	AH,SET_CURRENT_PDB
	call	do_21
	RestoreReg  <BX,AX>
	MOV	[CONTXTFLAG],0
CONTOK:
	RET

CONTEXT_SWITCH:
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	CMP	[CONTXTFLAG],0
	JNZ	RET45
	SaveReg <BX,AX>
	MOV	AH,GET_CURRENT_PDB
	call	do_21
	MOV	[HISPDB],BX
	MOV	BX,CS
	sub	bx,10h			; The 2.5 print is an exe program
	MOV	AH,SET_CURRENT_PDB
	call	do_21
	RestoreReg  <AX,BX>
	MOV	[CONTXTFLAG],1
RET45:	RET


;--- Refill the print buffer ---
READBUFF:
ASSUME	DS:CodeR,ES:NOTHING,SS:NOTHING

	call	Set24			; switch Int24 vector
	MOV	[PABORT],0		;No abort
	MOV	BX,[CURRHAND]
	MOV	CX,[BLKSIZ]
	MOV	DX,[BUFFER]
	MOV	AH,READ
	call	My21
	PUSHF
	call	Res24			; reset Int 24 vector
	CMP	[PABORT],0
	JZ	NOHERR
	POP	AX			;Flags from read
	jmp	FilClose		;Barf on this file, got INT 24


NOHERR:
	POPF
	JC	FILEOF
	CMP	AX,0
	JZ	FILEOF			;Read EOF?
	MOV	BX,[BUFFER]		;Buffer full
	MOV	DI,BX
	ADD	DI,AX
	MOV	[NXTCHR],BX
	MOV	CX,[BLKSIZ]
	SUB	CX,AX
	JCXZ	DONEJ			; Buffer is completely full
	PUSH	CS
	POP	ES
	MOV	AL,1AH
	cld
	REP	STOSB			; ^Z pad the buffer
DONEJ:
	JMP	DONEJMP

FILEOF:
	MOV	AL,0CH			;Form feed
	CALL	POUT

;--- Close file
; note: we came here from an i24 then PAbort is already = 1
FilClose:
	call	Set24
	mov	pAbort,-1
	MOV	BX,[CURRHAND]
	MOV	AH,CLOSE
	call	My21
	call	Res24
	MOV	[CURRFIL],0		; No file
	MOV	[CURRHAND],-1		; Invalid handle
	MOV	AX,[ENDPTR]
	MOV	[NXTCHR],AX		; Buffer empty

;--- Send close on output device
	call	Close_Dev

;--- compact the print queue
CompQAgn:
	call	CompQ

;--- Check if there are any more files to print
	mov	si,offset CodeR:FileQueue
	cmp	byte ptr [si],0 	; no more left if name starts with nul
	je	NoFilesLeft
	call	Set24
	MOV	[PABORT],0		;No abort
	mov	dx,si			; DS:DX points to file name
	mov	ax,(open shl 8)
	call	My21			; try opening new file
	pushf
	call	Res24
	cmp	[PAbort],0
	je	NoI24a
	popf
	jmp	short CompQAgn		; try next file

NoI24a:
	popf
	jnc	GotNewFile
	call	PrtOpErr
	jmp	short CompQAgn

GotNewFile:				; buffer was already marked as empty
	mov	[CurrHand],ax
	mov	[CurrFil],1

;--- Send Open on output device
	call	Open_Dev

NoFilesLeft:
	JMP	DONEJMP


;--- Print open error ---
; preserves DS

PrtOpErr:
assume	ds:CodeR,es:Nothing

; This stuff constitutes a "file" so it is bracketed by an open/close
; on the output device.

;--- Send Open on output device
	call	Open_Dev

	push	cs
	pop	es
assume	es:CodeR
	mov	si,offset CodeR:ErrMes
	call	ListMes
	mov	si,offset CodeR:ErrMesT2
	call	ListMes
	mov	si,offset CodeR:FileQueue
	call	ListMes2
	mov	si,offset CodeR:BelMes
	call	ListMes

;--- Send close on output device
	call	Close_Dev

	ret


;--- Compact File Queue ---
; modifies: AX,CX,SI,DI,ES

CompQ:
assume	ds:CodeR,es:nothing,ss:nothing
	push	cs
	pop	es
assume	es:CodeR
	mov	di,offset CodeR:FileQueue  ; ES:DI points to top of queue
	mov	si,(offset CodeR:FileQueue + MaxFileLen)  ; DS:SI points to next entry
	mov	cx,[EndQueue]
	sub	cx,si			; length in bytes of the queue
	cld
	rep	movsb			; compact the queue
	mov	ax,[QueueTail]		; normalize tail pointer as we
	sub	ax,MaxFileLen		;  know have a new "next empty slot"
	mov	[QueueTail],ax
	mov	si,ax
	mov	byte ptr [si],0 	; nul first byte of last entry
	ret


BREAK	<Resident Code: DSKERR>

;--- Set Local Int 24 vector ---
; modifies: AX,DX

Set24:
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	push	es
	push	bx
	push	dx
	MOV	AL,24H
	MOV	AH,GET_INTERRUPT_VECTOR
	call	do_21
	MOV	WORD PTR [HERRINT+2],ES ; Save current vector
	MOV	WORD PTR [HERRINT],BX
	MOV	DX,OFFSET CodeR:DSKERR
	MOV	AL,24H
	MOV	AH,SET_INTERRUPT_VECTOR ; Install our own
	call	do_21			; Spooler must catch its errors
	pop	dx
	pop	bx
	pop	es
	ret


;--- Reset Old Int 24 vector ---
; modifies: none

Res24:
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	push	ds
	PUSH	AX
	push	dx
	LDS	DX,[HERRINT]
ASSUME	DS:NOTHING
	MOV	AL,24H
	MOV	AH,SET_INTERRUPT_VECTOR
	call	do_21			;Restore Error INT
	pop	dx
	POP	AX
	pop	ds
	ret


;--- INT 24 handler ---
DSKERR:
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	CMP	[PABORT],0
	JNZ	IGNRET
	STI
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	DI
	PUSH	SI
	PUSH	BP
	PUSH	ES
	PUSH	DS
	PUSH	CS
	POP	DS
	PUSH	CS
	POP	ES
ASSUME	DS:CodeR,ES:CodeR
	ADD	[BADDRVM],AL		;Set correct drive letter
	MOV	SI,OFFSET CodeR:ERRMES
	CALL	LISTMES
	TEST	AH,080H
	JNZ	FATERR
	AND	DI,0FFH
	CMP	DI,12
	JBE	HAVCOD
	MOV	DI,12
HAVCOD:
	MOV	[I24_ERR],DI
	SHL	DI,1
	MOV	DI,WORD PTR [DI+MESBAS] ; Get pointer to error message
	MOV	SI,DI
	CALL	LISTMES 		; Print error type
	MOV	SI,OFFSET CodeR:ERRMEST
	CALL	LISTMES
	mov	si,offset CodeR:FileQueue  ; print filename
	call	ListMes2		; print name
	mov	si,offset CodeR:BelMes
	call	ListMes
SETABORT:
	INC	[PABORT]		;Indicate abort
	POP	DS
	POP	ES
	POP	BP
	POP	SI
	POP	DI
	POP	DX
	POP	CX
	POP	BX
IGNRET:
	XOR	AL,AL			;Ignore
	IRET

FATERR:
	MOV	[I24_ERR],0FFH
	MOV	SI,OFFSET CodeR:FATMES
	CALL	LISTMES
	JMP	SHORT SETABORT


BREAK	<Resident Code: SPCOMINT>

;--- Communications interrupt ---
SPCOMINT proc	far
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	CMP	AH,1
	JBE	MINE
	JMP	[COMNEXT]

MINE:
	CMP	AL,0F8H
	JAE	RESERVED_RET
IF  HardInt
	CMP	AX,0080h
	JNZ	CheckPSP
	JMP	FakeINT1C
ENDIF
CheckPSP:
	OR	AH,AH
	JNE	PSPDO
	MOV	AL,1			; Tell PSPRINT to go away (AH = 1)
RESERVED_RET:
	IRET

PSPDO:
	OR	AL,AL
	JNE	PSPDISP
INST_REQ:
	MOV	AL,0FFH
	IRET

PSPDISP:
	CMP	[BUSY],0
	JZ	SETCBUSY
ErrBusy:
	MOV	AX,error_busy
setcret:
	push	bp
	mov	bp,sp
	or	word ptr [bp+6],f_Carry
	pop	bp
	iret

SETCBUSY:
	XOR	AH,AH
	CMP	AX,6			; check function within valid range
	Jbe	GoForIt
	mov	ax,error_invalid_function
	jmp	setcret
GoForIt:
	INC	[BUSY]			;Exclude
	STI				;Turn ints back on
	PUSH	DI			;G
	PUSH	ES
	PUSH	DS
	PUSH	CS
	POP	DS
ASSUME	DS:CodeR
	mov	[QueueLock],0		; unlock the print queue
	SHL	AX,1			;Turn into word index
	mov	di,ax
	call	ComDisp[DI]
	assume	ds:nothing
	jc	ErrRet
ASSUME	DS:CodeR,ES:NOTHING
	push	ds
	push	cs
	pop	ds
ASSUME	DS:CodeR,ES:NOTHING
	CALL	PSTAT			; Tweek error counter
	pop	ds
	assume	ds:nothing
ErrRet:
	pushf
	call	Context_Back
	popf
	CLI
	DEC	BUSY			; leaves carry alone!
	POP	DS
ASSUME	DS:NOTHING
	POP	ES
	POP	DI			;G
	jc	setcret
	push	bp
	mov	bp,sp
	and	word ptr [bp+6],NOT f_Carry
	pop	bp
	iret
SpComInt    Endp

BREAK	<Get queue status>

;--- Return pointer to file queue ---
QSTAT:
ASSUME	DS:CodeR,ES:NOTHING

	mov	[QueueLock],1		; lock the print queue
	CALL	PSTAT			; Tweek error counter
	push	bp
	mov	bp,sp			;  0	2    4
	MOV	[bp+ 2 + 2],cs		; <BP> <RET> <DS>
	POP	BP
	mov	si,offset CodeR:FileQueue
	mov	dx,[ErrCnt]		; return error count
	clc
	ret

;--- Return pointer to device driver if active ---
QSTATDEV:
ASSUME	DS:CodeR,ES:NOTHING

	xor	ax,ax			;g assume not busy
	mov	[QueueLock],1		;g lock the print queue
	CALL	PSTAT			;g Tweek error counter
	cmp	byte ptr FileQueue,0	;g is there anything in the queue?
	clc				;g
	jz	qstatdev_end		;g no - just exit
	mov	ax,error_queue_full	;g yes - set error queue full
	mov	si,word ptr [listdev+2] ;g get segment of list device
	push	bp			;g
	mov	bp,sp			;g  0	 2   4
	MOV	[bp+2+2],si		;g <BP><RET><DS> seg of device to DS
	pop	bp			;g
	mov	si,word ptr [listdev]	;g offset of device to SI
	stc				;g

qstatdev_end:				;g
	mov	[QueueLock],0		;g unlock the print queue
	ret				;g

BREAK	<Resident Code: EndStat>

;--- Unlock the print queue ---
EndStat:
assume	ds:CodeR,es:nothing
	mov	[QueueLock],0
	clc
	ret

BREAK	<Cancel all available files in the queue>

;
; Note that we need to spin until the background is free
;
CanAll:
assume	ds:CodeR,es:nothing

	cmp	[CurrFil],0		; are we currently printing?
	jnz	DoCanAll		; yes, go and cancel
	ret				; carry is clear

DoCanAll:

;--- Cancel active file
	mov	bx,[CurrHand]		; close the current file
	call	Set24
	mov	[PAbort],1		; no Int24's
	mov	ah,Close
	call	My21
	call	Res24
	mov	[CurrFil],0		; no files to print
	mov	[CurrHand],-1		; invalidate handle
	mov	ax,[EndPtr]		; buffer empty
	mov	[NxtChr],ax

;--- Cancel rest of files
	mov	si,offset CodeR:FileQueue
	mov	[QueueTail],si		; next free entry is the first
	mov	byte ptr [si],0 	; nul first byte of firts entry
	mov	si,offset CodeR:AllCan
	call	ListMes 		; print cancelation message
	mov	si,offset CodeR:BelMes
	call	ListMes 		; ring!!

;--- Send close on output device
	call	Close_Dev
	clc
	ret

BREAK	<Cancel a file in progress>

CANFIL:
ASSUME	DS:CodeR,ES:NOTHING

	CMP	[CURRFIL],0
	JNZ	DOCAN
	ret				;  carry is clear

DOCAN:

;--- find which file to cancel
	push	bp
	mov	bp,sp			;  0	2    4
	MOV	ds,[bp+ 2 + 2]		; <BP> <RET> <DS>
	POP	BP

assume	ds:nothing
	push	cs
	pop	es
assume	es:CodeR
	mov	CS:[CanFlg],0		; reset message flag
	mov	CS:[ACanOcrd],0 	; no cancelation has ocured yet
	mov	bx,offset CodeR:FileQueue  ; ES:BX points to 1st entry in queue
	call	AmbChk

AnotherTry:
	mov	di,bx			; ES:DI points to 1st entry in queue
	mov	si,dx			; DS:SI points to filename to cancel
MatchLoop:
	lodsb
	cmp	al,byte ptr es:[di]	; names in queue are all in upper case
	je	CharMatch
	call	UpConv			; did not match, try upper case
	cmp	al,byte ptr es:[di]
	jne	AnotherName		; a mismatch, try another name
CharMatch:
	cmp	es:byte ptr es:[di],0	; was this the terminating nul?
	je	NameFound		; yes we got our file...
	inc	di
	jmp	MatchLoop

AnotherName:
	cmp	CS:[AmbCan],1		; ambigous file name specified?
	jne	AnName			; if not then no more work to do
	cmp	al,"?"
	jne	AnName
	cmp	byte ptr es:[di],"."
	je	FindPeriod
	cmp	byte ptr es:[di],0	; if nul then file names match
	jne	CharMatch		;  only if only ?'s are left...
FindNul:
	lodsb
	cmp	al,"?"
	je	FindNul
	cmp	al,"."
	je	FindNul
	or	al,al
	jne	AnName			; found something else, no match
	jmp	short NameFound

FindPeriod:				; ambigous files always have 8 chars
	lodsb				;  in name so we can not look for the
	or	al,al			;  period twice (smart uh?)
	je	AnName			; no period found, files do not match
	cmp	al,"."
	jne	FindPeriod
	jmp	short CharMatch

AnName:
	add	bx,MaxFileLen
	cmp	byte ptr es:[bx],0	; end of queue?
	jne	AnotherTry		; no, continue...
	cmp	CS:[ACanOcrd],1 	; yes, was there a file found?
	jne	sk2
	push	cs
	pop	ds
assume	ds:CodeR			; StartAnFil likes it this way...
	jmp	StartAnFil		; restart printing

sk2:
assume	ds:nothing

	mov	ax,error_file_not_found
	stc
	ret


;--- Name found, check if current file
NameFound:
	push	cs
	pop	ds
assume	ds:CodeR
	mov	[ACanOcrd],1		; remember we found a file
	cmp	bx,offset CodeR:FileQueue  ; is the file being printed?
	jne	NotCurrent		; no, just compact the queue
	cmp	[CanFlg],0
	jne	NotCurrent		; only cance current once

;--- Cancel current file
	mov	[CanFlg],1		; remeber we already canceled current
	push	bx
	mov	bx,[CurrHand]		; close the current file
	call	Set24
	mov	[PAbort],1		; no Int24's
	mov	ah,Close
	call	My21
	call	Res24
	mov	[CurrFil],0		; no files to print
	mov	[CurrHand],-1		; invalidate handle
	mov	ax,[EndPtr]		; buffer empty
	mov	[NxtChr],ax
	pop	bx

;--- print cancelation message
	push	bx
	mov	si,offset CodeR:CanMes
	call	ListMes 		; print cancelation message
	mov	si,bx			; points to filename
	call	ListMes2		; print filename
	mov	si,offset CodeR:CanFilNam
	call	ListMes
	mov	si,offset CodeR:BelMes
	call	ListMes 		; ring!!
	pop	bx

;--- Send close on output device
	call	Close_Dev

NotCurrent:
	mov	di,bx			; DI points to entry to cancel
	mov	si,bx
	add	si,MaxFileLen		; SI points to next entry
	cmp	si,[QueueTail]		; is the entry being canceled the last?
	jne	DoCompact		; no, do compaction
	mov	byte ptr [di],0 	; yes, just nul the first byte
	jmp	short CompactDone
DoCompact:
	mov	cx,[EndQueue]		; CX points to the end of the queue
	sub	cx,si			; length of the remainning of the queue
	cld
	rep	movsb			; compact the queue
CompactDone:
	mov	ax,[QueueTail]		; remember new end of queue
	sub	ax,MaxFileLen
	mov	[QueueTail],ax
	mov	si,ax
	mov	byte ptr [si],0 	; nul first byte of last entry

	cmp	byte ptr [bx],0 	; is there another file to consider?
	je	StartAnFil
	push	bp
	mov	bp,sp			;  0	2    4
	MOV	ds,[bp+ 2 + 2]		; <BP> <RET> <DS>
	POP	BP
assume	ds:nothing
	jmp	AnotherTry		; yes do it again...


;--- Start new file...
StartAnFil:
assume	ds:CodeR
	cmp	[CurrHand],-1		; was the canceled name the current?
	jne	NoneLeft		; no, just quit
StartAnFil2:
	mov	si,offset CodeR:FileQueue  ; points to new current file
	cmp	byte ptr[si],0		; is there one there?
	je	NoneLeft		; no, we canceled current and are none left
	call	Set24
	mov	[PAbort],0
	mov	dx,si
	mov	ax,(open shl 8)
	call	My21
	pushf
	call	Res24
	cmp	[PAbort],0
	je	NoI24b
	popf
	call	CompQ			; compact file queue
	jmp	short StartAnFil2

NoI24b:
	popf
	jnc	GoodNewCurr
	call	PrtOpErr		; print open error
	call	CompQ			; compact file queue
	jmp	short StartAnFil2

GoodNewCurr:
	mov	[CurrHand],ax		; save handle
	mov	[CurrFil],1		; signal active (buffer is already empty)

;--- Send Open on output device
	call	Open_Dev
NoneLeft:
	clc
	ret

;--- Upper case conversion ---
UpConv:
	CMP	AL,'a'
	JB	NOCONV
	CMP	AL,'z'
	JA	NOCONV
	SUB	AL,20H
NOCONV:
	RET


;--- Ambigous file name check ---
; entry:     ds:dx points to filename
;	preserves ds:dx and es
;
assume	ds:nothing,es:CodeR
AmbChk:
	mov	CS:[AmbCan],0		; assume not ambigous
	mov	si,dx
	cld
AmbLoop:
	lodsb
	or	al,al			; the nul?
	jne	AmbLoop
	dec	si			; points to nul
	std				; scan backwards
ScanBack:
	lodsb
	cmp	al,"*"
	jne	NotAStar
	mov	CS:[AmbCan],1
NotAStar:
	cmp	al,"?"
	jne	NotAQues
	mov	CS:[AmbCan],1
NotAQues:
	cmp	al,CS:[PChar]
	jne	ScanBack
	cld				; be safe
	cmp	CS:[AmbCan],1		; an ambigous cancel?
	je	AmbCanFnd		; no, just proceed
	ret

;--- transform * to ?'s
AmbCanFnd:
	inc	si
	inc	si			; points to actual name (past path char)
	mov	di,offset CodeR:ACBuf
	push	di
	mov	cx,12
	mov	al,20h
	cld
	rep	stosb			; fill fcb with blanks
	pop	di
	push	si
	mov	ax,(Parse_file_descriptor shl 8) and 0FF00h
	call	My21
	pop	si

;--- Copy name to expanded name
	push	ds
	pop	es
assume	ds:nothing
	push	cs
	pop	ds
assume	ds:CodeR
	push	es
	mov	di,si
	mov	si,offset CodeR:ACName
	mov	cx,8
ACMovNam:
	lodsb				; move name
	cmp	al,20h
	je	ACMovDn1
	stosb
	loop	ACMovNam

ACMovDn1:
	mov	si,offset CodeR:ACExt
	cmp	byte ptr [si],20h	; if extension starts with blank
	je	ACMovDn2		;  then do not put period
	mov	al,"."
	stosb
	mov	cx,3

ACMovExt:
	lodsb				; move name
	cmp	al,20h
	je	ACMovDn2
	stosb
	loop	ACMovExt

ACMovDn2:
	mov	byte ptr es:[di],0	; nul terminate
	pop	ds
assume ds:nothing
	push	cs
	pop	es
assume	es:CodeR
	ret



BREAK	<Add a file to the queue>

ADDFIL:
ASSUME	DS:CodeR,ES:NOTHING

;--- Check that queue is not full
	mov	di,[QueueTail]		; load pointer to next empty entry
	cmp	di,[EndQueue]		; queue full?
	jb	OkToQueue		; no, place in queue...
	mov	ax,error_queue_full
	stc
	ret

;--- Copy name to empty slot in queue
OkToQueue:
;
; Retrieve old DS
;
	push	bp
	mov	bp,sp			;  0	2    4
	MOV	ds,[bp+ 2 + 2]		; <BP> <RET> <DS>
	POP	BP

assume	ds:nothing
	push	cs
	pop	es			; ES:DI points to empty slot
assume	es:CodeR
	mov	si,dx			; DS:SI points to submit packet
	cmp	byte ptr ds:[si],0
	jnz	IncorrectLevel
	lds	si,dword ptr ds:[si+1]	; DS:SI points to filename
	mov	cx,MaxFileLen		; maximum length of file name
CopyLop:
	lodsb
	call	UpConv			; convert to upper case
	stosb
	or	al,al			; nul?
	je	CopyDone		; yes, done with move...
	loop	CopyLop
	push	cs
	pop	ds
assume	ds:CodeR
	mov	ax,error_name_too_long	; if normal exit from the loop then
	stc
	ret

IncorrectLevel:
	mov	ax,error_invalid_function
	stc
	ret

assume	ds:nothing,es:nothing		; es:nothing = not true but lets
CopyDone:				;   avoid possible problems...
	push	cs
	pop	ds
assume	ds:CodeR

;--- advance queue pointer
	mov	si,[QueueTail]		; pointer to slot just used
	push	si			; save for test open later
	add	si,MaxFileLen
	mov	[QueueTail],si		; store for next round
	mov	byte ptr [si],0 	; nul next entry (maybe the EndQueue)

;--- Check that file exists
	call	Set24
	mov	[PAbort],0
	pop	dx			; get pointer to filename
	MOV	AX,(OPEN SHL 8)
	call	My21
	pushf
	PUSH	DX
	call	Res24
	POP	DX
	popf
	JNC	GOTFIL
;
; See if brain damaged user entered an invalid drive
;
	PUSH	AX
	MOV	SI,DX
	CMP	BYTE PTR CS:[SI+1],':'
	JZ	GotDrive
	POP	AX
	JMP	SHORT	i24bf
GotDrive:
	MOV	AH,Get_default_drive	; get current
	CALL	My21
	PUSH	AX
	MOV	DL,CS:[SI]		   ; get drive letter to test
	OR	DL,20h
	SUB	DL,'a'
	MOV	AH,Set_Default_Drive	; set it
	CALL	My21
	MOV	AH,Get_default_drive	; get it back
	CALL	My21
	CMP	AL,DL			; same?
	JNZ	BadDrive		; no, bad drive
	POP	DX			; get original back
	MOV	AH,Set_Default_Drive	; set original
	CALL	My21
	POP	AX
	MOV	DX,SI
	JMP	SHORT i24bf
BadDrive:
	POP	DX			; get original back
	MOV	AH,Set_Default_Drive	; set original
	CALL	My21
	POP	AX
	MOV	AX,error_invalid_drive
	MOV	DX,SI
I24BF:
	mov	si,[QueueTail]		; take bad name out of queue
	sub	si,MaxFileLen		; SI points to the slot with bad name
	mov	[QueueTail],si
	mov	byte ptr [si],0 	; nul the first byte
	stc
	ret


;--- Check if print currently busy
GotFil:
	CMP	[CURRFIL],0		; currently printing?
	JZ	OKAFIL			; no, start new print
	mov	bx,ax			; busy, close handle
	call	Set24
	mov	[PAbort],1		; no Int24's
	mov	ah,Close
	call	My21
	call	Res24
	clc
	ret

;--- Save file data
OKAFIL:
	MOV	[CURRHAND],AX		; Valid handle
	MOV	AX,[ENDPTR]
	MOV	[NXTCHR],AX		; Buffer empty
	MOV	[CURRFIL],1

;--- Send Open on output device
	call	Open_Dev
	clc
	ret

BREAK	<Fake int 21H>

;
; perform a  system call as myself
;
My21:
	call	Context_switch
	call	Do_21
	ret

Public do_21
DO_21:
ASSUME	DS:NOTHING,ES:NOTHING
	IF	IBM
	CMP	BYTE PTR CS:[INT15FLAG],0
	JZ	REAL_21
	PUSH	DS
	PUSH	BX
	LDS	BX,CS:[INT15PTR]
	INC	BYTE PTR [BX]
	POP	BX
	POP	DS
	CALL	OffSave
	INT	21H
	Call	OnSave
	PUSH	DS
	PUSH	BX
	PUSHF				; Flags from system call
	LDS	BX,CS:[INT15PTR]
	DEC	BYTE PTR [BX]
	POPF
	POP	BX
	POP	DS
	RET
	ENDIF

REAL_21:
	Call	OffSave
	INT	21H
	CALL	OnSave
	RET

OffSave:
	ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	PUSH	AX
	PUSH	DX
	MOV	AX,Set_CTRL_C_Trapping SHL 8 + 2
	XOR	DL,DL
	INT	21h
	MOV	CtrlC,DL
	POP	DX
	POP	AX
	ret

OnSave:
	ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	PUSH	AX
	PUSH	DX
	MOV	AX,Set_CTRL_C_Trapping SHL 8 + 2
	MOV	DL,CtrlC
	INT	21h
	POP	DX
	POP	AX
	ret

BREAK	<Priter Support>

ListMes2:
ASSUME	DS:CodeR,ES:NOTHING
	LODSB
	cmp	al,0
	jz	LMesDone
	CALL	LOUT
	JMP	short LISTMES2


LISTMES:
ASSUME	DS:CodeR,ES:NOTHING
	LODSB
	CMP	AL,"$"
	JZ	LMESDONE
	CALL	LOUT
	JMP	short LISTMES

LMESDONE:
	RET

LOUT:
	PUSH	BX
LWAIT:
	CALL	PSTAT
	JZ	PREADY
	CMP	[ERRCNT],ERRCNT2
	JA	POPRET			;Don't get stuck
	JMP	SHORT LWAIT
PREADY:
	CALL	POUT
POPRET:
	POP	BX
	RET

;Stuff for BIOS interface
IOBUSY	EQU	0200H
IOERROR EQU	8000H

public PRNR003S, PRNR003E
PRNR003S:

BYTEBUF DB	?

CALLAD	DD	?

IOCALL	DB	22
	DB	0
IOREQ	DB	?
IOSTAT	DW	0
	DB	8 DUP(?)
	DB	0
	DW	OFFSET CodeR:BYTEBUF
INTSEG	DW	?
IOCNT	DW	1
	DW	0

PRNR003E:

; Following two routines perform device open and close on output device.
; NO REGISTERS (including flags) are modified. No errors generated.

public open_dev
Open_Dev:
ASSUME	DS:NOTHING,ES:NOTHING
;
; We are now going to use the printer... We must lock down the printer so
; that the network does not intersperse output on us...
; We must also signal the REDIRector for stream open.
; We must ask DOS to set the Printer Flag to busy
;
	PUSH	BX
	PUSHF
	PUSH	AX
	PUSH	DX
	MOV	DX,PrinterNum
	CMP	DX,-1
	JZ	NoORop
	MOV	AX,0203h		; redirector lock
	INT	2FH
	MOV	AX,0201H		; Redirector OPEN
	INT	2FH
NoORop:
	mov	ax,(SET_PRINTER_FLAG SHL 8) + 01
	int	21H
	POP	DX
	POP	AX
	MOV	BL,DEVOPN		; Device OPEN
	CALL	OP_CL_OP
	POPF
	POP	BX
	RET

OP_CL_OP:
	PUSH	DS
	PUSH	SI
	LDS	SI,[LISTDEV]
ASSUME	DS:NOTHING
	TEST	[SI.SDEVATT],DEVOPCL
	JZ	NO_OP_CL
	PUSH	CS
	POP	DS
ASSUME	DS:CodeR
	MOV	[IOCALL],DOPCLHL
	CALL	DOCALL
NO_OP_CL:
	POP	SI
	POP	DS
ASSUME	DS:NOTHING
	Ret


public close_dev
Close_Dev:
ASSUME	DS:NOTHING,ES:NOTHING
;
; At this point, we release the ownership of the printer...
;  and do a redirector CLOSE.
; Also tell DOS to reset the Printer Flag
;
	PUSH	BX
	PUSHF
	MOV	BL,DEVCLS
	CALL	OP_CL_OP		; Device CLOSE
	PUSH	AX
	PUSH	DX
	MOV	DX,PrinterNum
	CMP	DX,-1
	JZ	NoCRop
	MOV	AX,0202H		; redirector CLOSE
	INT	2FH
	MOV	AX,0204h		; redirector clear
	INT	2FH
NoCRop:
	MOV	AX,(SET_PRINTER_FLAG SHL 8) +00
	INT	21H
	POP	DX
	POP	AX
	POPF
	POP	BX
	RET

PSTAT:
ASSUME	DS:CodeR
	PUSH	BX
	INC	[ERRCNT]
	MOV	BL,DEVOST
	MOV	[IOCALL],DSTATHL
	CALL	DOCALL
	TEST	[IOSTAT],IOERROR
	JZ	NOSTATERR
	OR	[IOSTAT],IOBUSY 	;If error, show buisy
NOSTATERR:
	TEST	[IOSTAT],IOBUSY
	JNZ	RET13P			;Shows buisy
	MOV	[ERRCNT],0
RET13P:
	POP	BX
	RET

POUT:
ASSUME	DS:CodeR
	MOV	[BYTEBUF],AL
	MOV	BL,DEVWRT
	MOV	[IOCALL],DRDWRHL
DOCALL:
	PUSH	ES
	MOV	[IOREQ],BL
	MOV	BX,CS
	MOV	ES,BX
	MOV	[IOSTAT],0
	MOV	[IOCNT],1
	PUSH	DS
	PUSH	SI
	PUSH	AX
	call	Context_Switch
	MOV	BX,OFFSET CodeR:IOCALL
	LDS	SI,[LISTDEV]
ASSUME	DS:NOTHING
	MOV	AX,[SI+SDEVSTRAT]
	MOV	WORD PTR [CALLAD],AX
	CALL	[CALLAD]
	MOV	AX,[SI+SDEVINT]
	MOV	WORD PTR [CALLAD],AX
	CALL	[CALLAD]
	POP	AX
	POP	SI
	POP	DS
ASSUME	DS:CodeR
	POP	ES
	RET

	IF	IBM
Public PRNR004S, PRNR004E
PRNR004S:

REAL_INT_13 DD	?
INT_13_RETADDR DW OFFSET CodeR:INT_13_BACK

PRNR004E:

INT_13	PROC	FAR
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	PUSHF
	INC	[BUSY]			;Exclude if dumb program call ROM
	PUSH	CS
	PUSH	[INT_13_RETADDR]
	PUSH	WORD PTR [REAL_INT_13+2]
	PUSH	WORD PTR [REAL_INT_13]
	RET
INT_13	ENDP

INT_13_BACK	PROC	FAR
	PUSHF
	DEC	[BUSY]
	POPF
	RET	2			;Chuck saved flags
INT_13_BACK	ENDP
	ENDIF


	IF	IBM

Public PRNR005S, PRNR005E
PRNR005S:

REAL_INT_15 DD	?
INT15FLAG   DB	0			; Init to off
INT15PTR    DD	?

PRNR005E:

INT_15	PROC	FAR
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	CMP	AH,20H
	JNZ	REAL_15 		; Not my function
	CMP	AL,1
	JA	REAL_15 		; I only know 0 and 1
	JE	FUNC1
	INC	[INT15FLAG]		; Turn ON
	MOV	WORD PTR [INT15PTR],BX	; Save counter loc
	MOV	WORD PTR [INT15PTR+2],ES
	IRET

FUNC1:
	MOV	[INT15FLAG],0		; Turn OFF
	IRET

REAL_15:
	JMP	[REAL_INT_15]

INT_15	ENDP


Public PRNR006S, PRNR006E
PRNR006S:

FLAG17_14 DB	0			; Flags state of AUX/PRN redir
REAL_INT_5  DD	?
REAL_INT_17 DD	?
INT_17_NUM  DW	0

PRNR006E:

INT_17:
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	CMP	[FLAG17_14],1
	JNZ	DO_INT_17		;The PRN device is not used
	CMP	[CURRFIL],0
	JZ	DO_INT_17		;Nothing pending, so OK
	CMP	DX,[INT_17_NUM]
	JNZ	DO_INT_17		;Not my unit
	CMP	[BUSY],0
	JNZ	DO_INT_17		;You are me
	STI
	MOV	AH,0A1H 		;You are bad, get time out
	IRET

DO_INT_17:
	JMP	[REAL_INT_17]		;Do a 17

Public PRNR007S, PRNR007E
PRNR007S:
REAL_INT_14 DD	?
INT_14_NUM  DW	0

PRNR007E:

INT_14:
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	CMP	[FLAG17_14],2
	JNZ	DO_INT_14		;The AUX device is not used
	CMP	[CURRFIL],0
	JZ	DO_INT_14		;Nothing pending, so OK
	CMP	DX,[INT_14_NUM]
	JNZ	DO_INT_14		;Not my unit
	CMP	[BUSY],0
	JNZ	DO_INT_14		;You are me
	STI
	OR	AH,AH
	JZ	SET14_AX
	CMP	AH,2
	JBE	SET14_AH
SET14_AX:
	MOV	AL,0
SET14_AH:
	MOV	AH,80H			;Time out
	IRET

DO_INT_14:
	JMP	[REAL_INT_14]		;Do a 14

INT_5:
ASSUME	DS:NOTHING,ES:NOTHING,SS:NOTHING
	CMP	[FLAG17_14],1
	JNZ	DO_INT_5		;The PRN device is not used
	CMP	[CURRFIL],0
	JZ	DO_INT_5		;Nothing pending, so OK
	CMP	[INT_17_NUM],0
	JNZ	DO_INT_5		;Only care about unit 0
	IRET				;Pretend it worked

DO_INT_5:
	JMP	[REAL_INT_5]		;Do a 5
	ENDIF

Public PRNR008S, PRNR008E
PRNR008S:

ERRCNT	DW	0

	IF	IBM
;Reserved names for parallel card
INT_17_HITLIST LABEL BYTE
	DB	8,"PRN     ",0
	DB	8,"LPT1    ",0
	DB	8,"LPT2    ",1
	DB	8,"LPT3    ",2
	DB	0
;Reserved names for Async adaptor
INT_14_HITLIST	LABEL BYTE
	DB	8,"AUX     ",0
	DB	8,"COM1    ",0
	DB	8,"COM2    ",1
;--------------------------------------------------------------bug330a09
	DB	8,"COM3    ",2
	DB	8,"COM4    ",3
;--------------------------------------------------------------bug330a09
	DB	0
	ENDIF

LISTNAME DB	 "PRN     "             ;Device name

PRNR008E:

SETDEV:
ASSUME	CS:CodeR,DS:CodeR,ES:NOTHING,SS:NOTHING
; LISTNAME has the 8 char device name IN UPPER CASE
; CARRY set if bad device
; DS preserved, others destroyed.

	MOV	AH,GET_IN_VARS
	call	My21
	PUSH	ES
	POP	DS
	LEA	SI,ES:[BX.SYSI_DEV]
ASSUME	DS:NOTHING
	PUSH	CS
	POP	ES
ASSUME	ES:CodeR
	MOV	DI,OFFSET CodeR:LISTNAME
LOOKDEV:
	TEST	[SI.SDEVATT],DEVTYP
	JZ	NEXTDEV 		; Skip Block devs
	PUSH	SI
	PUSH	DI
	ADD	SI,SDEVNAME		; Point at name
	MOV	CX,8
	REPE	CMPSB
	POP	DI
	POP	SI
	JE	GOTDEV
NEXTDEV:
	LDS	SI,[SI.SDEVNEXT]
	CMP	SI,-1
	JNZ	LOOKDEV
	PUSH	CS
	POP	DS
	STC
	RET

GOTDEV:
	MOV	WORD PTR CS:[CALLAD+2],DS  ;Get I/O routines
	MOV	WORD PTR CS:[LISTDEV+2],DS ;Get I/O routines
	MOV	WORD PTR CS:[LISTDEV],SI
	PUSH	CS
	POP	DS
ASSUME	DS:CodeR

	IF	IBM
	MOV	PrinterNum,-1		   ; Assume not an INT 17 device
	PUSH	CS
	POP	ES
ASSUME	ES:CodeR
	MOV	BP,OFFSET CodeR:LISTNAME
	MOV	SI,BP
	MOV	DI,OFFSET CodeR:INT_17_HITLIST
CHKHIT:
	MOV	SI,BP
	MOV	CL,[DI]
	INC	DI
	JCXZ	NOTONHITLIST
	REPE	CMPSB
	LAHF
	ADD	DI,CX		;Bump to next position without affecting flags
	MOV	BL,[DI] 	;Get device number
	INC	DI
	SAHF
	JNZ	CHKHIT
	XOR	BH,BH
	MOV	[INT_17_NUM],BX
	MOV	PrinterNum,BX	; Set this as well to the INT 17 device
	MOV	[FLAG17_14],1
	JMP	SHORT ALLSET

NOTONHITLIST:
	MOV	DI,OFFSET CodeR:INT_14_HITLIST
CHKHIT2:
	MOV	SI,BP
	MOV	CL,[DI]
	INC	DI
	JCXZ	NOTONHITLIST2
	REPE	CMPSB
	LAHF
	ADD	DI,CX		;Bump to next position without affecting flags
	MOV	BL,[DI] 	;Get device number
	INC	DI
	SAHF
	JNZ	CHKHIT2
	XOR	BH,BH
	MOV	[INT_14_NUM],BX
	MOV	[FLAG17_14],2
	JMP	SHORT ALLSET

NOTONHITLIST2:
	MOV	[FLAG17_14],0
ALLSET:
	ENDIF
	CLC
	RET


		IF	HARDINT

BREAK	<Bootstrap Cleanup Code>

ReBtINT:
ASSUME	CS:CodeR,DS:NOTHING,ES:NOTHING,SS:Nothing

	CLI
	push	cs
	pop	ds

IntWhileBusy:
	INT	ComInt
	JNC	NotBusy
	JMP	IntWhileBusy
	ret
NotBusy:

	INC	[BUSY]			; Exclude hardware interrupts
	INC	[SOFINT]		; Exclude software interrupts

	call	CanAll			; Purge the Queue

	LDS	DX,CodeR:COMNEXT
	mov	ax,(set_interrupt_vector shl 8) or comint
	INT	21H			;Set int 2f vector

	LDS	DX,CodeR:NEXTINT
	mov	ax,(set_interrupt_vector shl 8) or intloc
	INT	21H			;Set hardware interrupt

	mov	ax,(set_interrupt_vector shl 8) or 15h
	lds	dx,CodeR:Real_Int_15	; Reset the wait on event on ATs
	int	21h

	mov	ax,(set_interrupt_vector shl 8) or 17h
	LDS	DX,CodeR:Real_Int_17
	INT	21H			;Set printer   interrupt

	mov	ax,(set_interrupt_vector shl 8) or 5h
	LDS	DX,CodeR:Real_Int_5
	INT	21H			;Set print screen   interrupt

	mov	ax,(set_interrupt_vector shl 8) or 14h
	LDS	DX,CodeR:Real_Int_14
	INT	21H			;Set printer   interrupt

	mov	ax,(set_interrupt_vector shl 8) or 24h
	LDS	DX,CodeR:HERRINT
	INT	21H			;Set printer   interrupt

	LDS	DX,CodeR:NEXT_REBOOT
	mov	ax,(set_interrupt_vector shl 8) or reboot
	INT	21H			;Set bootstrap interrupt

	STI
	INT	19H

		ENDIF		; HARDINT




;----- File name Queue and data buffer goes here
Public PRNR009S
PRNR009S:
FileQueue	Label	byte
	db	0			; the file queue starts empty


BREAK	<Initialization Code>

BADSPOOL:
ASSUME	CS:CodeR,DS:CodeR,ES:NOTHING,SS:Nothing
	MOV	DX,OFFSET CODER:BADMES
	mov	cx,badmeslen
	mov	bx,stdout
	mov	ah,write
	INT	21H
;*********************************************************************
	MOV	AX,(SET_PRINTER_FLAG SHL 8)	    ; Set flag to Idle
	int	21H
;*********************************************************************
	MOV	AX,(EXIT SHL 8) OR 0FFH
	INT	21H

;--- move transient out of the way
ContTrans	dd	?		; transient continuation address after move

MoveTrans label far
ASSUME	CS:CodeR,DS:CodeR,ES:CodeR,SS:Nothing
	cli
	CLD
	MOV	[INTSEG],CS
	CALL	SETDEV
ASSUME	ES:NOTHING
	JC	BADSPOOL
	MOV	DX,OFFSET CodeR:SPINT
	MOV	AL,SOFTINT
	MOV	AH,GET_INTERRUPT_VECTOR
	INT	21H			;Get soft vector
	MOV	WORD PTR [SPNEXT+2],ES
	MOV	WORD PTR [SPNEXT],BX
	MOV	AL,SOFTINT
	MOV	AH,SET_INTERRUPT_VECTOR
	INT	21H			;Set soft vector
	MOV	DX,OFFSET CodeR:SPCOMINT
	MOV	AL,ComInt
	MOV	AH,GET_INTERRUPT_VECTOR
	INT	21H			;Get communication vector
	MOV	WORD PTR [COMNEXT+2],ES
	MOV	WORD PTR [COMNEXT],BX
	MOV	AL,ComInt
	MOV	AH,SET_INTERRUPT_VECTOR ;Set communication vector
	INT	21H

	IF	IBM
	MOV	AL,13H
	MOV	AH,GET_INTERRUPT_VECTOR
	INT	21H
	MOV	WORD PTR [REAL_INT_13+2],ES
	MOV	WORD PTR [REAL_INT_13],BX
	MOV	DX,OFFSET CodeR:INT_13
	MOV	AL,13H
	MOV	AH,SET_INTERRUPT_VECTOR
	INT	21H			;Set diskI/O interrupt

	MOV	AL,15H
	MOV	AH,GET_INTERRUPT_VECTOR
	INT	21H
	MOV	WORD PTR [REAL_INT_15+2],ES
	MOV	WORD PTR [REAL_INT_15],BX
	MOV	DX,OFFSET CodeR:INT_15
	MOV	AL,15H
	MOV	AH,SET_INTERRUPT_VECTOR
	INT	21H			;Set INT 15 vector

	MOV	AL,17H
	MOV	AH,GET_INTERRUPT_VECTOR
	INT	21H
	MOV	WORD PTR [REAL_INT_17+2],ES
	MOV	WORD PTR [REAL_INT_17],BX
	MOV	DX,OFFSET CodeR:INT_17
	MOV	AL,17H
	MOV	AH,SET_INTERRUPT_VECTOR
	INT	21H			;Set printer interrupt
	MOV	AL,14H
	MOV	AH,GET_INTERRUPT_VECTOR
	INT	21H
	MOV	WORD PTR [REAL_INT_14+2],ES
	MOV	WORD PTR [REAL_INT_14],BX
	MOV	DX,OFFSET CodeR:INT_14
	MOV	AL,14H
	MOV	AH,SET_INTERRUPT_VECTOR
	INT	21H			;Set RS232 port interrupt
	MOV	AL,5H
	MOV	AH,GET_INTERRUPT_VECTOR
	INT	21H
	MOV	WORD PTR [REAL_INT_5+2],ES
	MOV	WORD PTR [REAL_INT_5],BX
	MOV	DX,OFFSET CodeR:INT_5
	MOV	AL,5H
	MOV	AH,SET_INTERRUPT_VECTOR
	INT	21H			;Set print screen interrupt
	ENDIF

	IF	HARDINT
	MOV	AH,GET_INDOS_FLAG
	INT	21H
ASSUME	ES:NOTHING
	MOV	WORD PTR [INDOS+2],ES	;Get indos flag location
	MOV	WORD PTR [INDOS],BX
	MOV	AL,INTLOC
	MOV	AH,GET_INTERRUPT_VECTOR
	INT	21H
	MOV	WORD PTR [NEXTINT+2],ES
	MOV	WORD PTR [NEXTINT],BX

	MOV	AL,REBOOT			; We also need to chain
	MOV	AH,GET_INTERRUPT_VECTOR 	; Into the INT 19 sequence
	INT	21H				; To properly "unhook"
	MOV	WORD PTR [NEXT_REBOOT+2],ES	; ourselves from the TimerTick
	MOV	WORD PTR [NEXT_REBOOT],BX	; sequence

	IF	IBM
	MOV	AX,0B800H
	INT	2FH
	CMP	AL,0
	JE	SET_HDSPINT		; No NETWORK, set hardware int
	TEST	BX,0000000011000100B
	JNZ	NO_HDSPINT		; DO NOT set HDSPINT if RCV|MSG|SRV
	ENDIF

SET_HDSPINT:
	MOV	DX,OFFSET CodeR:HDSPINT
	MOV	AL,INTLOC
	MOV	AH,SET_INTERRUPT_VECTOR
	INT	21H			;Set hardware interrupt

	MOV	DX,OFFSET CodeR:ReBtINT
	MOV	AL,REBOOT
	MOV	AH,SET_INTERRUPT_VECTOR
	INT	21H			;Set bootstrap interrupt

NO_HDSPINT:
	ENDIF
	MOV	DX,OFFSET CODER:GOODMES
	mov	cx,goodmeslen
	mov	bx,stdout
	mov	ah,write
	int	21h

;--- Move transient
; Note: do not use stack, it may get trashed in move!
public RealMove
RealMove:

	mov	ax,offset dg:TransRet
	mov	word ptr [ContTrans],ax ; store return offset
	mov	ax,CodeR
	add	ax,[endres]		; get start of moved transient, actually
					;  this is 100 bytes more than need be
					;  because of lack of pdb, but who cares?
	mov	word ptr [ContTrans+2],ax	; return segment
	mov	es,ax			; new location for dg group
assume	es:nothing
	mov	ax,dg
	mov	ds,ax
assume	ds:nothing
	mov	cx,offset dg:TransSize
	mov	si,cx			; start from the bottom and move up
	mov	di,cx
	std
	rep	movsb			; move all code, data and stack
	cld				; restore to expected setting...

;--- normalize transient segment regs
	mov	ax,es
	mov	ds,ax
	sub	ax,dg			; displacement
	mov	dx,ss
	add	dx,ax			; displace stack segemnt
	mov	ss,dx

assume	ds:nothing,es:nothing,ss:nothing
	jmp	ContTrans		; back to the transient...

PRNR009E:

CodeR	EndS

	End
