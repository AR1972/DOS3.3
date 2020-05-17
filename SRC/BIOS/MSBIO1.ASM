	TITLE	MSBIO	MS-DOS 3.30

;-------------------------------------------------------------------------------
;									       :
;			    Microsoft Bio				       :
;									       :
;  The file msbio.asm is the main file in the Mircosoft bio.  This file        :
; includes the other main files in the bio.  Most of the routines are	       :
; in these include files.  The main files included are: 		       :
;									       :
;	File		Contains					       :
;									       :
;	msdisk.inc	Disk device driver routines			       :
;	ms96tpi.inc	Routines for 96tpi drives			       :
;	msaux.inc	Device driver for the rs-232 serial ports	       :
;	msclock.inc	Device driver for "clock$" device                      :
;	mscon.inc	Device driver for "con"                                :
;	mslpt.inc	Device driver for the printers			       :
;									       :
;  Each of these files contain a header section documenting the code	       :
;  in that file.							       :
;    Msbio also includes several files for equ's, structure definition,        :
;  macro definitions, etc.  These are:					       :
;									       :
;	msbiomes.inc	 msmacro.inc	devsym.inc			       :
;		dskprm.inc	   error.inc				       :
;									       :
;  Each of these file contains explanitory notes.			       :
;									       :
;    The actual code in msbio can be broken down into several piece:	       :
;									       :
;	macro definitions	Several marco are defined in msbio.  They      :
;				are a few odds and end that did not fit        :
;				anywhere else.				       :
;									       :
;	Command Jump Table	List of entry points in the device drivers.    :
;				See notation below for full explination.       :
;									       :
;	Interrupt and Strategy						       :
;	  Entry points		Calls on the device driver first come to here. :
;				There is common code with pushes registers and :
;				the like before jumping to routines in the     :
;				driver files.  The common exit points are also :
;				in this file.				       :
;									       :
;	Miscellaneous Code	There are several routines and data structure  :
;				declarations.  See below for details.	       :
;									       :
;-------------------------------------------------------------------------------



;
; If the variable TEST is non-zero then code for debugging is included.
; The extra code will make the binary file nuch larger.
; The symbol is also defined in msequ.inc.  Both must be changed to
; turn debugging on or off.
;
; The level of the debugging is controled by the variable fTestBits in
; this file.  See the comment preceeding the variable for more information.
; The actual routines which print the messages are in msmacro.inc
; See the header comment in this file for more information.
;
;***For testing purposes, set the TEST flag to 1. Otherwise reset it.

TEST=0

PATHGEN =	1

.SALL
;
; This is a DOSMAC macro which is used in DEVSYM which is included later.
;

BREAK	MACRO	subtitle
	SUBTTL	subtitle
	PAGE
	ENDM

;
; Some old versions of the 80286 have a bug in the chip.  The popf
; instruction will enable interrupts.  Therefore in a section of code with
; interrupts disabled and you need a popf instruction use the 'popff'
; macro instead.
;

POPFF	macro
	jmp	$+3
	iret
	push	cs
	call	$-2
	endm

;;Rev 3.30 modification -----------------------------
	INCLUDE MSGROUP.INC	;DEFINE CODE SEGMENT

SYSINITSEG SEGMENT PUBLIC 'SYSTEM_INIT'
SYSINITSEG ENDS


	INCLUDE JUMPMAC.INC
PATHSTART MACRO INDEX,ABBR
	IFDEF	PATHGEN
	    PUBLIC  ABBR&INDEX&S,ABBR&INDEX&E
	    ABBR&INDEX&S LABEL	 BYTE
	ENDIF
	ENDM

PATHEND MACRO	INDEX,ABBR
	IFDEF	PATHGEN
	    ABBR&INDEX&E LABEL	 BYTE
	ENDIF
	ENDM

	INCLUDE PUSHPOP.INC
	INCLUDE DEVSYM.INC		;MJB001
;; End of Modification

;
; Revision History
;
;   REV 2.1	5/1/83 ARR added timer int handler and changed order of AUX
;		    PRN init for HAL0
;
;   REV 2.15	7/13/83 ARR Because of IBM design issues, and that BASCOM
;		    is ill behaved with respect to the 1CH timer interrupt,
;		    the timer handler has to be backed out! The intended
;		    code is commented out and has an ARR 2.15 annotation.
;		    This means the BIOS will go back to the multiple roll
;		    over bug.
;
;   REV 2.20	8/5/83 ARR IBM makes hardware change.  Now wants to use half
;		    height drives for HAL0, and back fit for PC/PC XT.	Problem
;		    with head settle time.  Previous drives got by on a 0
;		    settle time, 1/2 hight drives need 15 head settle when
;		    doing WRITEs (0 ok on READ) if the head is being stepped.
;		    This requires a last track value to be kept so that BIOS
;		    knows when head is being moved.  To help out
;		    programs that issue INT 13H directly, the head settle will
;		    normally be set to 15.  It will be changed to 0 on READs,
;		    or on WRITEs which do not require head step.
;
;   REV 2.21	8/11/83 MZ IBM wants write with verify to use head settle 0.
;		    Use same trick as above.
;
;   REV 2.25	6/20/83 mjb001 added support for 96tpi and salmon
;
;   REV 2.30	6/27/83 mjb002 added real-time clock
;
;   REV 2.40	7/8/83 mjb003 added volume-id checking and int 2f macro
;		    definitions push* and pop*
;
;   REV 2.41	7/12/83 ARR more 2.X enhancements.  Open/Close media change
;
;   REV 2.42	11/3/83 ARR more 2.X enhancements.  Disk OPEN/CLOSE, FORMAT
;		    code and other misc hooked out to shrink BIOS.  Code for
;		    Disk OPEN/CLOSE, FORMAT included only with 96tpi disks.
;
;   Rev   2.43	12/6/83 MZ Examine boot sectors on hard disks for 16-bit fat
;		    check.  Examine large fat bit in BPB for walk of media for
;		    DOS
;
;   Rev   2.44	12/9/83 ARR Change to error reporting on INT 17H
;
;   Rev   2.45	12/22/83 MZ Make head settle change only when disk parm is 0.
;
;   Rev   3.21	3/20/87 SP Changed OUTCHR routine to always output to page 0.

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;
;	IBM ADDRESSES FOR I/O
;
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

include dskprm.inc

	SYSIZE	= 100H			; number of paragraphs in sysinit module
	LF	= 10			; line feed
	CR	= 13			; carriage return
	BACKSP	= 8			; backspace
	BRKADR	= 1BH * 4		; 006C	1Bh break vector address
	TIMADR	= 1CH * 4		; 0070	1Ch timer interrupt
	DSKADR	= 1EH * 4		; address of ptr to disk parameters
	SEC9	= 522H			; address of disk parameters
	HEADSETTLE	= SEC9+9	; address of head settle time
	NORMSETTLE	= 15		; Normal head settle
	SPEEDSETTLE	= 0		; Speed up settle time
	INITSPOT	= 534H		; IBM wants 4 zeros here
	AKPORT	= 20H
	EOI	= 20H
	
;;Rev 3.30 modification -----------------------------
	ASSUME	CS:CODE,DS:NOTHING,ES:NOTHING
	
	EXTRN	MEDIA$CHK:NEAR
	EXTRN	GET$BPB:NEAR
	EXTRN	DSK$INIT:NEAR
	EXTRN	DSK$READ:NEAR
	EXTRN	DSK$WRIT:NEAR
	EXTRN	DSK$WRITV:NEAR
	EXTRN	DSK$OPEN:NEAR
	EXTRN	DSK$CLOSE:NEAR
	EXTRN	DSK$REM:NEAR
	EXTRN	GENERIC$IOCTL:NEAR
	EXTRN	IOCTL$GETOWN:NEAR
	EXTRN	IOCTL$SETOWN:NEAR
	EXTRN	CON$READ:NEAR
	EXTRN	CON$RDND:NEAR
	EXTRN	CON$FLSH:NEAR
	EXTRN	CON$WRIT:NEAR
;	EXTRN	CON$GENIOCTL:NEAR
	EXTRN	AUX$READ:NEAR
	EXTRN	AUX$WRIT:NEAR
	EXTRN	AUX$FLSH:NEAR
	EXTRN	AUX$RDND:NEAR
	EXTRN	AUX$WRST:NEAR
	EXTRN	TIM$READ:NEAR
	EXTRN	TIM$WRIT:NEAR
	EXTRN	PRN$WRIT:NEAR
	EXTRN	PRN$STAT:NEAR
	EXTRN	PRN$TILBUSY:NEAR
	EXTRN	PRN$GENIOCTL:NEAR
	EXTRN	WRMSG:NEAR
;DATA AREAS
	INCLUDE MSDATA.INC
;;End of modification -----------------------------

;
; The following variables and two routines (MSGOUT and MSGNUM) are used
; with the debug routines to print numbers and messages on the screen.
;
; The variable fTestBits controls the level of debugging in the system.
; See the comments and "equ's" in msmacro.inc for an explination of
; how to control the level of debugging.  In a nutshell, setting
; fTestBits to fTestALL prints all the debugging messages.  Setting
; it to fTestDisk prints all disk related messages, etc.
;

if test
Public MSGNUM
MSGNUM:
	pushf
	test	fTestBits,AX
	jz	MRet
	push	SI
	push	BX
	push	CX
	push	ES
	push	DI
	mov	DI,OFFSET NUMBUF
	push	CS
	pop	ES
	mov	CX,4
NUMLOOP:
	push	CX
	mov	CL,4
	rol	BX,CL
	pop	CX
	push	BX
	and	BX,0Fh
	mov	AL,Digits[BX]
	stosb
	pop	BX
	loop	NumLoop
	pop	DI
	pop	ES
	pop	CX
	pop	BX
	mov	SI,OFFSET NUMBUF
	call	MSGOUT
	pop	SI
	popf
	ret

Public MSGOUT
MSGOUT:
	pushf
	test	fTestBits,ax
	jz	MRet
	push	DS
	push	AX
	push	BX
	push	CS
	pop	DS
	call	WRMSG
	pop	BX
	pop	AX
	pop	DS
MRet:
	popf
	ret
;;Rev 3.30 modification -----------------------------
	    PUBLIC DUMPBYTES
;Dumpbytes will dump the bytes in memory in hex.  Space will be put in
;between the bytes and CR, LF will be put at the end. - J.K.
;Input: DS:SI -> buffer to dump in Hex.
;	CX -> # of bytes (Length of the buffer)
;
DUMPBYTES proc near
	pushf
	push	ax
dumploops:
	lodsb
	mov	ah, al
	shr	ah, 1
	shr	ah, 1
	shr	ah, 1
	shr	ah, 1
	call	hex_to_ascii
	push	ax
	mov	al, ah
	call	outchar
	pop	ax
	call	outchar
	mov	al, ' '
	call	outchar
	loop	dumploops

	mov	al, 0dh
	call	outchar
	mov	al, 0ah
	call	outchar

	pop	ax
	popf
	ret
DUMPBYTES	endp

	PUBLIC	Hex_to_ascii
Hex_to_ascii	proc	near
	and	ax, 0f0fh
	add	ah, 30h
	cmp	ah, 3ah
	jb	hta_$1
	add	ah, 7
hta_$1:
	add	al, 30h
	cmp	al, 3ah
	jb	hta_$2
	add	al, 7
hta_$2:
	ret
Hex_to_ascii	endp

	PUBLIC	outchar
Outchar proc	near
	PUSH	AX
	PUSH	SI
	PUSH	DI
	PUSH	BP
	PUSH	BX
	MOV	AH, 0Eh 		;SET COMMAND TO WRITE A CHAR
	MOV	BL, 7			;SET FOREGROUND COLOR
	mov	bh,0			;
	INT	10h			;CALL ROM-BIOS
	POP	BX
	POP	BP
	POP	DI
	POP	SI
	POP	AX
	RET
Outchar endp

	ENDIF
;;End of modification -----------------------------

;
; end of routines for debugging
;
	INCLUDE MSMACRO.INC



;
; The next nine equ's describe the offset into the request header for
; different information.  For example STATUS is in byte 3 of the request
; header (starting count at zero).
;

CMDLEN	=	0			; length of this command
UNIT	=	1			; sub unit specifier
CMD	=	2			; command code
STATUS	=	3			; status
MEDIA	=	13			; media descriptor
TRANS	=	14			; transfer address
COUNT	=	18			; count of blocks or characters
START	=	20			; first block to transfer
EXTRA	=	22			; Usually pointer to Vol Id for error 15

;
; Strategy is the strategy entry point for all default bio device drivers.
; All that is done is to save the pointer to the request header in the
; variable PtrSav.
;

PUBLIC	STRATEGY
STRATEGY PROC	FAR
	mov	word ptr CS:[PTRSAV],BX
	mov	word ptr CS:[PTRSAV+2],ES
	ret

STRATEGY ENDP


;------------------------------------------------------------------------------
;
;			Device entry point
;
; The following ten pieces of code are the interrupt entry points for the
; default device drivers.  These small pieces of code have two jobs.
;
;	1) Make SI point to the beginning of the proper command jump  table.
;	   SI must first be pushed to preserve original contents.
;	2) If the call is an AUX or a printer save the number of the
;	   request in AL.  AL is moved to AUXNUM below.
;

;
; Con device:
;

;;Rev 3.30 modification -----------------------------
	PUBLIC CON$IN
CON$IN	PROC	FAR
	PUSH	SI
	MOV	SI,OFFSET CONTBL
	JMP	SHORT ENTRY
CON$IN	ENDP

	PUBLIC	AUX0$IN
AUX0$IN PROC	FAR
	PUSH	SI
	PUSH	AX
	XOR	AL,AL
	JMP	SHORT AUXENT
AUX0$IN ENDP

	PUBLIC AUX1$IN
AUX1$IN PROC	FAR
	PUSH	SI
	PUSH	AX
	MOV	AL,1
	JMP	short AUXENT
AUX1$IN ENDP

	PUBLIC  AUX2$IN
AUX2$IN proc far
	push	si
	push	ax
	mov	al,2
	jmp	short AUXENT
AUX2$IN endp

	PUBLIC  AUX3$IN
AUX3$IN proc far
	push	si
	push	ax
	mov	al,3
	jmp	short AUXENT

AUXENT:
	MOV	SI,OFFSET AUXTBL
	JMP	SHORT ENTRY1
AUX3$IN ENDP

PRN0$IN PROC	FAR
	PUBLIC	PRN0$IN

	PUSH	SI
	PUSH	AX
	XOR	AX,AX
	JMP	SHORT PRNENT
PRN0$IN ENDP

	PUBLIC	PRN1$IN
PRN1$IN PROC	FAR
	PUSH	SI
	PUSH	AX
	XOR	AL,AL
	MOV	AH,1
	JMP	SHORT PRNENT
PRN1$IN ENDP

	PUBLIC PRN2$IN
PRN2$IN PROC	FAR
	PUSH	SI
	PUSH	AX
	MOV	AL,1
	MOV	AH,2
	JMP	SHORT PRNENT
PRN2$IN ENDP

	PUBLIC PRN3$IN
PRN3$IN PROC	FAR
	PUSH	SI
	PUSH	AX
	MOV	AL,2
	MOV	AH,3
PRNENT:
	MOV	SI,OFFSET PRNTBL
	MOV	CS:[PRINTDEV],AH	;SAVE INDEX TO ARRAY OF RETRY CNTS
	JMP	SHORT ENTRY1
PRN3$IN ENDP

	PUBLIC	TIM$IN
TIM$IN	PROC	FAR
	PUSH	SI
	MOV	SI,OFFSET TIMTBL
	JMP	SHORT ENTRY
TIM$IN	ENDP

	PUBLIC	DSK$IN
DSK$IN	PROC	FAR
	push	SI
	mov	SI,OFFSET DSKTBL
;;End of modification -----------------------------



;
;   This section is the prolog to all default device drivers.  All registers
; are saved, the registers are filled with information fromthe request header,
; and the routine from the jump table is called.  Error checking is done
; to assure command code is valid.  Before calling the routine in the
; jump table the register are:
;
;	AH = Media Descriptor
;	AL = Unit Code
;	BX = offset to PTRSAV (request header is therefore at DS:BX)
;	CX = count from request header
;	DX = start sector
;	ES:DI = tranfer address
;	SI = points to jump table
;	DS = points to this segment
;
; Once the routine finishes its job it jumps back to one of the eight
; pieces of code below labeled Exit Points.
;

ENTRY:
	push	AX
ENTRY1:
	push	CX			; save all registers
	push	DX
	push	DI
	push	BP
	push	DS
	push	ES
	push	BX

	mov	CS:[AUXNUM],AL		; save choice of AUX/PRN device

	lds	BX,CS:[PTRSAV]		; get pointer to I/O packet
	ASSUME	DS:NOTHING

	mov	AL,byte ptr DS:[BX].UNIT    ;AL = UNIT CODE
	mov	AH,byte ptr DS:[BX].MEDIA   ;AH = MEDIA DESCRIP
	mov	CX,word ptr DS:[BX].COUNT   ;CX = COUNT
	mov	DX,word ptr DS:[BX].START   ;DX = START SECTOR

	xchg	DI,AX
	mov	AL,BYTE PTR DS:[BX].CMD
	cmp	AL,CS:[SI]		; is command code a valid number?
	ja	CMDERR			; no, jump to handle error

	cbw				; note that AL <= 15 means OK
	shl	AX,1
	add	SI,AX			; get SI to point to address of routine
	xchg	AX,DI			; put proper value back into AX
					; get ES:DI to point to transfer address
	les	DI,DWORD PTR DS:[BX].TRANS
	push	CS			; get DS equal to CS
	pop	DS

	ASSUME	DS:CODE

	cld				; clear the direction flag
	jmp	WORD PTR [SI+1] 	; go to the command

DSK$IN	ENDP
PAGE
;=====================================================
;=
;=	SUBROUTINES SHARED BY MULTIPLE DEVICES
;=
;=====================================================



;----------------------------------------------------------
;
;		Exit  Points
;
; All device driver call return through one of these eight
; pieces of code.  The code set error and status conditions
; and then restores the registers.
;

PUBLIC BUS$EXIT 			; device busy exit
BUS$EXIT PROC	FAR
	ASSUME	DS:NOTHING
	mov	AH,00000011B		; set error code
	jmp	SHORT ERR1

PUBLIC CMDERR
CMDERR:
	mov	AL,3			; unknown command error

PUBLIC ERR$CNT
ERR$CNT:
	lds	BX,CS:[PTRSAV]
	ASSUME	DS:NOTHING
	sub	WORD PTR [BX].COUNT,CX	;# of successful I/O's

PUBLIC ERR$EXIT
ERR$EXIT:
	mov	AH,10000001B		; mark error and return
	jmp	SHORT ERR1

BUS$EXIT ENDP
EXITP	proc	FAR
	ASSUME	DS:CODE

EXIT$ZER:
	lds	BX,[PTRSAV]
	ASSUME	DS:NOTHING
	xor	AX,AX
	mov	WORD PTR [BX].COUNT,AX	; indicate no character read

Public EXIT
EXIT:
	ASSUME	DS:NOTHING
	mov	AH,00000001B
ERR1:
	ASSUME	DS:NOTHING
	lds	BX,CS:[PTRSAV]
	mov	WORD PTR [BX].STATUS,AX ; mark operation complete

	pop	BX		; restore register and return
	pop	ES
	pop	DS
	pop	BP
	pop	DI
	pop	DX
	pop	CX
	pop	AX
	pop	SI
	ret
EXITP	endp


;-------------------------------------------------------------
;
; Chrout - write out character in AL using current attribute
;
;   called via int 29h
;
	PUBLIC	CHROUT
CHROUT	=	29H

	Public	OUTCHR
OUTCHR	PROC	FAR
	push	AX			; preserve affect registers
	push	SI
	push	DI
	push	BP
	push	bx			;
	mov	AH, 0Eh 		; set command to write a character
	mov	bh,0			;
	mov	BL, 7			; set foreground color
	int	10h			; call rom-bios
	pop	bx			;
	pop	BP			; restore registers
	pop	DI
	pop	SI
	pop	AX
	iret
OUTCHR	ENDP


;----------------------------------------------
;
; Fill DX register with value in AUXNUM
;

	PUBLIC GETDX
GETDX	PROC	NEAR
	mov	DX,WORD PTR CS:[AUXNUM]
	ret
GETDX	ENDP
	page
CODE	ENDS
	END
