	TITLE MSBIO2 - DOS 3.3

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

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;
;	IBM ADDRESSES FOR I/O
;
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

;Below was moved from sysinit1
ROMSEGMENT	EQU	0F000H
MODELBYTE	EQU	DS:BYTE PTR [0FFFEH]
MODELPCJR	EQU	0FDH

	test=0
;;Rev 3.30 modification ----------------------------
	INCLUDE MSGROUP.INC	;DEFINE CODE SEGMENT
	INCLUDE MSEQU.INC
	INCLUDE DEVSYM.INC
	INCLUDE PUSHPOP.INC
	INCLUDE MSMACRO.INC

	ASSUME	DS:NOTHING,ES:NOTHING

	EXTRN	DSK$IN:NEAR
	EXTRN	SETPTRSAV:NEAR
	EXTRN	OUTCHR:NEAR
	EXTRN	SETDRIVE:NEAR
	EXTRN	FLUSH:NEAR
	EXTRN	HARDERR:NEAR
	EXTRN	HARDERR2:NEAR
	EXTRN	MAPERROR:NEAR
	EXTRN	GETBP:NEAR
	EXTRN	CHECKSINGLE:NEAR
	EXTRN	CHECK_TIME_OF_ACCESS:NEAR
	EXTRN	EXIT:NEAR
	EXTRN	HAS1:NEAR
	EXTRN	HAS1_res:NEAR
	EXTRN	READ_SECTOR:NEAR
	EXTRN	INT_2F_13:FAR

	EXTRN	OLD13:DWORD

;DATA
	EXTRN	PTRSAV:DWORD
	EXTRN	START_BDS:WORD
	EXTRN	FDRIVE1:WORD
	EXTRN	FDRIVE2:WORD
	EXTRN	FDRIVE3:WORD
	EXTRN	FDRIVE4:WORD
	EXTRN	FLAGBITS:WORD
	EXTRN	TIM_DRV:BYTE
	EXTRN	MEDBYT:BYTE
	EXTRN	DRVMAX:BYTE

	PATHSTART 005,DISK
	EVENB
	PUBLIC	ORIG19
ORIG19	DD	?

	PUBLIC	INT19SEM
INT19SEM DB	0			; INDICATE THAT ALL INT 19
					; INITIALIZATION IS COMPLETE

	IRP	AA,<02,08,09,0A,0B,0C,0D,0E,70,72,73,74,76,77>
	public	Int19OLD&AA
Int19OLD&AA	dd	-1		;Orignal hw int. vec for INT 19h.
	ENDM

	EVENB
	PUBLIC	DSKDRVS
DSKDRVS DW	FDRIVE1
	DW	FDRIVE2
	DW	FDRIVE3
	DW	FDRIVE4
	PUBLIC	HDSKTAB
HDSKTAB DW	HDRIVE
	DW	DRIVEX
;* Next area is reseved for mini disk BPB pointers *** 4/7/86
;* Don't change this pos. Should be add. from DskDrvs *** 4/7/86
MINI_DISK_BPB_PTRS DB 40 dup (?)   ;4/7/86 - mem res for Mini disk.

	EVENB
	PUBLIC	INT_2F_NEXT
INT_2F_NEXT DD	   ?

RET_ADDR    DD	   ?

	PATHEND 005,DISK
;;End of modification ----------------------------

;  INT19
;
;	We "hook" the INT_REBOOT vector, because contrary to IBM documentation,
;  it does NOT "bootstrap" the machine.  It leaves memory almost untouched.
;  Since the BIOS_INIT code assumes that certain Interrupt Vectors point to
;  the ROM_BIOS  we must "unhook" them before issuing the actual INT_REBOOT.
;  Currently the following vectors need to be unhooked:
;		  02,08,09,0A,0B,0C,0D,0E,70,72,73,74,75,76,77
;

Public Int19
Int19	proc	FAR
	xor	AX,AX			; get data segment to
	mov	DS,AX			;   point to the vector table
	assume	ds:nothing
	assume	es:nothing
	les	DI,Old13		; get ES to point to this segment
	mov	DS:[13h*4],DI		; restore old int13 value
	mov	DS:[13h*4+2],ES

	cmp	Byte ptr Int19Sem, 0
	jnz	int19vecs
	jmp	doint19

;;Dos 3.30 Will not support the PC-Jr
;;Rev 3.30 modification ----------------------------
;	ON THE PCJR, DON'T REPLACE ANY VECTORS
;	MODEL BYTE DEFINITIONS FROM MSSTACK.ASM
;	MOV	AX,ROMSEGMENT
;	MOV	DS,AX
;	MOV	AL,MODELPCJR
;
;	CMP	AL,MODELBYTE
;	JNE	INT19VECS
;	JMP	DOINT19


;Stacks code has changed these hardware interrupt vectors
;STKINIT in SYSINIT1 will initialzie Int19hOLDxx values.
int19vecs:

;
; we now need to unhook all the vector replace to prevent stack overflow
;

;;Rev 3.30 modification ----------------------------
	XOR	AX,AX
	MOV	DS,AX

	IRP	AA,<02,08,09,0A,0B,0C,0D,0E,70,72,73,74,76,77>

	LES	DI,Int19OLD&AA

	mov	ax,es		; Put segment where we can compare it
	cmp	ax,-1		; OPT 0ffffh is not likely
	je	skip_int&AA	; OPT could get away without checking
	cmp	di,-1		; OPT offset here.
	je	skip_int&AA

	MOV	DS:[AA&H*4],DI
	MOV	DS:[AA&H*4+2],ES
skip_int&AA:
	ENDM
;;End of modification ----------------------------

doint19:
	LES	DI,Orig19
	MOV	DS:[19h*4],DI
	MOV	DS:[19h*4+2],ES

	INT	19h
INT19	ENDP
ASSUME	DS:CODE

;*****************************************************************************
PUBLIC	DSK$INIT
DSK$INIT PROC	NEAR
	PUSH	CS
	POP	DS
	MOV	AH,BYTE PTR DRVMAX
	MOV	DI,OFFSET DskDrvs
	JMP	SetPTRSAV
DSK$INIT ENDP


;
; Int 2f handler for external block drivers to communicate with the internal
; block driver in msdisk. The multiplex number chosen is 8. The handler
; sets up the pointer to the request packet in [PTRSAV] and then jumps to
; DSK$IN, the entry point for all disk requests.
; On exit from this driver (at EXIT), we will return to the external driver
; that issued this Int 2F, and can then remove the flags from the stack.
; This scheme allows us to have a small external device driver, and makes
; the maintainance of the various drivers (DRIVER and msBIO) much easier,
; since we only need to make changes in one place (most of the time).
;
; AL contains the Int2F function:
;   0 - Check for installed handler - RESERVED
;   1 - Install the BDS into the linked list
;   2 - DOS request
;

MYNUM		EQU	8

Public Int2F_Disk
Int2F_Disk PROC FAR
	cmp	ah,MYNUM
	je	Mine
	jmp	cs:[Int_2F_Next]	; chain to next Int 2F handler
Mine:
	cmp	al,0F8H 		; IRET on reserved functions
	jb	Do_Func
	IRET
Do_Func:
	or	al,al			; A GET INSTALLED STATE request?
	jne	Disp_Func
	mov	al,0FFH
	IRET
Disp_Func:
	Message fTestInit,<"Int2F_disk",cr,lf>
	cmp	al,1			 ; Request for installing BDS?
	jne	Do_DOS_Req
	call	Install_BDS
	IRET

Do_DOS_Req:
; Set up pointer to request packet
	MOV	WORD PTR CS:[PTRSAV],BX
	MOV	WORD PTR CS:[PTRSAV+2],ES
	jmp	DSK$IN

Int2F_Disk ENDP

;
; Install_BDS installs a BDS a location DS:DI into the current linked list of
; BDS maintained by this device driver. It places the BDS at the END of the
; list.
Public Install_BDS
INSTALL_BDS PROC NEAR
	message ftestinit,<"Install BDS",cr,lf>
; ds:di point to BDS to be installed
	les	si,dword ptr cs:[Start_BDS] ; Start at beginning of list
	push	es			    ; Save pointer to current BDS
	push	si
; es:si now point to BDS in linked list
Loop_Next_BDS:
	cmp	si,-1			    ; got to end of linked list?
	jz	Install_Ret
; If we have several logical drives using the same physical drive, we must
; set the I_Am_Mult flag in each of the appropriate BDSs.
	mov	al,byte ptr ds:[di].DriveNum
	cmp	byte ptr es:[si].DriveNum,al
	jnz	Next_BDS
	message ftestinit,<"Logical Drives",cr,lf>
	xor	bx,bx
	mov	bl,fI_Am_Mult
	or	word ptr ds:[di].flags,bx    ; set flags in both BDSs concerned
	or	word ptr es:[si].flags,bx
	mov	bl,fI_Own_Physical
	xor	bx,-1
	and	word ptr ds:[di].flags,bx   ; reset that flag for 'new' BDS
; We must also set the fChangeline bit correctly.
	mov	bx,word ptr es:[si].flags   ; determine if changeline available
	and	bl,fChangeline
	xor	bh,bh
	or	word ptr ds:[di].flags,bx

Next_BDS:
; Before moving to next BDS, preserve pointer to current one. This is needed at
; the end when the new BDS is linked into the list.
	pop	bx			    ; discard previous pointer to BDS
	pop	bx
	push	es
	push	si
	mov	bx,word ptr es:[si].link + 2
	mov	si,word ptr es:[si].link
	mov	es,bx
	jmp	short Loop_Next_BDS

Install_Ret:
	pop	si				; Retrieve pointer to last BDS
	pop	es				; in linked list.
	mov	ax,ds
	mov	word ptr es:[si].link+2,ax	; install BDS
	mov	word ptr es:[si].link,di
	mov	word ptr ds:[di].link,-1	; set NEXT pointer to NULL
	RET
INSTALL_BDS ENDP

;
; RE_INIT installs the Int 2F vector that will handle communication between
; external block drivers and the internal driver. It also installs the
; Reset_Int_13 interface.  It is called by SYSYINIT
;
PUBLIC	RE_INIT
RE_INIT PROC FAR
	Message ftestinit,<"REINIT",CR,LF>
	PUSH	AX
	PUSH	DS
	PUSH	DI
	XOR	DI,DI
	MOV	DS,DI
	MOV	DI,2FH*4	    ; point it to Int 2F Vector
	MOV	AX,WORD PTR DS:[DI]
	MOV	WORD PTR CS:[INT_2F_NEXT],AX
	MOV	AX,WORD PTR DS:[DI+2]		   ; preserve old Int 2F vector
	MOV	WORD PTR CS:[INT_2F_NEXT+2],AX

; INSTALL the Reset_Int_13
; interface


	CLI
	MOV	Word Ptr DS:[DI],Offset Int_2f_13	  ; install new vectors
	MOV	Word Ptr DS:[DI+2],CS
	STI
	POP	DI
	POP	DS
	POP	AX
	RET

RE_INIT ENDP

;-------------------------------------------------
;
;  Ask to swap the disk in drive A:
; Using a different drive in a one drive system so
; request the user to change disks
;
Public SWPDSK
SWPDSK	PROC	NEAR
	mov	al,byte ptr ds:[di].drivelet	; get the drive letter
	add	al,"A"
	mov	cs:DRVLET,AL
	push	ds			; preserve segment register
	push	cs
	pop	ds
	mov	SI,OFFSET SNGMSG	; ds:si -> message
	push	BX
	call	WRMSG			;Print disk change message
	call	FLUSH
					; wait for a keyboard character
	xor	AH, AH			; set command to read character
	int	16h			; call rom-bios
	POP	BX
	pop	ds			; restore segment register
WRMRET:
	ret
SWPDSK	ENDP

;----------------------------------------------
;
;  WrMsg writes out message pointed to by [SI]
;
Public WrMsg
WRMSG	PROC	NEAR
	lodsb				; get the next character of the message
	or	AL,AL			; see fi end of message
	jz	WRMRET
	pushf
	push	CS
	call	OUTCHR
	jmp	SHORT WRMSG
WRMSG	ENDP

	INCLUDE BIOMES.INC

;
; End of support for multiple floppies with no logical drives
; This is not 'special' any more because we now have the capability of
; defining logical drives in CONFIG.SYS. We therefore keep the code for
; swapping resident ALL the time.
;

;;Rev 3.30 modification ----------------------------
;Variables for Dynamic Relocatable modules
;These should be stay resident.

	public	INT6C_RET_ADDR
INT6C_RET_ADDR	DD	?		;ret add from INT 6C for P12 mach

	PATHSTART 001,CLK
;
;   DATA STRUCTURES FOR REAL-TIME DATE AND TIME
;
	public	BIN_DATE_TIME
	public	MONTH_TABLE
	public	DAYCNT2
	public	FEB29
BIN_DATE_TIME:
	DB	0		; CENTURY (19 OR 20) OR HOURS (0-23)
	DB	0		; YEAR IN CENTURY (0-99) OR MINUTES (0-59)
	DB	0		; MONTH IN YEAR (1-12) OR SECONDS (0-59)
	DB	0		; DAY IN MONTH (1-31)
MONTH_TABLE:
	DW	0		;MJB002 JANUARY
	DW	31		;MJB002 FEBRUARY
	DW	59		;MJB002
	DW	90		;MJB002
	DW	120		;MJB002
	DW	151		;MJB002
	DW	181		;MJB002
	DW	212		;MJB002
	DW	243		;MJB002
	DW	273		;MJB002
	DW	304		;MJB002
	DW	334		;MJB002
DAYCNT2 DW	0000		;MJB002 TEMP FOR CNT OF DAYS SINCE 1-1-80
FEB29	DB	0		;MJB002 FEBRUARY 29 IN A LEAP YEAR FLAG
	PATHEND 001,CLK

;;End of modification modification ----------------------------

Public EndFloppy
EndFloppy Label Byte
;
; End of code for virtual floppy drives
;
Public EndSwap
EndSwap Label Byte

	PATHSTART 004,BIO

Public HNUM
HNUM	DB	0			; number of hardfile (hard drives)

Public HardDrv
HARDDRV DB	80H			;Physical drive number of first hardfile


;
;  "HDRIVE" is a hard disk with 512 byte sectors
;

	EVENB
Public BDSH
BDSH	DW	-1			; Link to next structure
	DW	Code
	DB	80h			; physical drive number
	DB	"C"                     ; Logical Drive Letter
Public HDRIVE
HDRIVE:
	DW	512
	DB	1			; Sectors/allocation unit
	DW	1			; Reserved sectors for DOS
	DB	2			; No. of allocation tables
	DW	16			; Number of directory entries
	DW	0000			; Number of sectors (at 512 bytes each)
	DB	11111000B		; Media descriptor
	DW	1			; Number of FAT sectors
	DW	00			; Sector limit
	DW	00			; Head limit
	DW	00			; Hidden sector count
	DB	0			; TRUE => bigfat
OPCNTH	DW	0			; Open Ref. Count
VOLIDH	DB	"NO NAME    ",0         ; Volume ID for this disk
	DB	3			; Form Factor
FLAGSH	DW	0020H			; Various Flags
	dw	40			; number of cylinders
RecBPBH db	31 dup (?)		; Recommended BPB for drive
TRACKH	DB	-1			; Last track accessed on this drive
TIM_LOH DW	-1			; Keep these two contiguous (?)
TIM_HIH DW	-1
;
; End of single hard disk section
;


Public EndOneHard
EndOneHard Label Byte




;
;"DRIVEX" is an extra type of drive usually reserved for an
; additional hard file
;

	EVENB
Public BDSX
BDSX	DW	-1			; Link to next structure
	DW	Code
	DB	81h			; physical drive number
	DB	"D"                     ; Logical Drive Letter
Public DRIVEX
DRIVEX:
	DW	512
	DB	00			; Sectors/allocation unit
	DW	1			; Reserved sectors for DOS
	DB	2			; No. of allocation tables
	DW	0000			; Number of directory entries
	DW	0000			; Number of sectors (at 512 bytes each)
	DB	11111000B		; Media descriptor
	DW	0000			; Number of FAT sectors
	DW	00			; Sector limit
	DW	00			; Head limit
	DW	00			; Hidden sector count
	DB	0			; TRUE => bigfat
OPCNTD	DW	0			; Open Ref. Count
VOLIDD	DB	"NO NAME    ",0         ; Volume ID for this disk
	DB	3			; Form Factor
FLAGSD	DW	0020H			; Various Flags
	dw	40			; number of cylinders
RecBPBD db	31 dup (?)		; Recommended BPB for drive
TRACKD	DB	-1			; Last track accessed on this drive
TIM_LOD DW	-1			; Keep these two contiguous
TIM_HID DW	-1

;
; End of section for two hard disks
Public EndTwoHard
EndTwoHard Label Byte

	PATHEND 004,BIO


Public TwoHard
TWOHARD LABEL BYTE

PAGE
include ms96tpi.inc

;;Rev 3.30 modification ----------------------------
;Memory allocation for BDSM table.
	PUBLIC BDSMs
BDSMs	BDSM_type Max_mini_dsk_num dup (<>)	;currently max. 23

;** End_of_BDSM defined in MSINIT.ASM will be used to set the appropriate
;** ending address of BDSM table.
;;End of modification ----------------------------

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;bug005sp
;
;;3.3 BUG FIX -SUNILP ------------------------------
;Paragraph buffer between the BDSMs and MSHARD
;
;The relocation code for MSHARD needs this. this cannot be used for 
;anything. nothing can come before this or after this.....IMPORTANT!!!!
;don't get too smart and using this buffer for anything!!!!!!
;
	db	16 dup(0)
;
;end of bug fix buffer
;;
;;3.3 BUG FIX -SUNILP------------------------------
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;bug005sp
CODE	ENDS
	END
