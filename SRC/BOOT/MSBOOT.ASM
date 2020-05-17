;	SCCSID = @(#)ibmboot.asm	1.1 85/05/13
TITLE BOOT	SECTOR 1 OF TRACK 0 - BOOT LOADER

;   Rev 1.0 ChrisP, AaronR and others.	2.0 format boot
;
;   Rev 3.0 MarkZ   Salmon enhancements
;		    2.50 in label
;   Rev 3.1 MarkZ   3.1 in label due to vagaries of SYSing to IBM drive D's
;		    This resulted in the BPB being off by 1.  So we now trust
;		    2.0 and 3.1 boot sectors and disbelieve 3.0.
;
;   Rev 3.2 LeeAc   Modify layout of extended BPB for >32M support
;		    Move PHYDRV to 3rd byte from end of sector
;		    so that it won't have to be moved again
;		    FORMAT and SYS count on PHYDRV being in a known location
;
;   Rev. 3.3 DCLove Changed Sec 9 EOT field from 15 to 18. May 29, 1986.
;
;   Rev 3.31 MarkT  The COUNT value has a bogus check (JBE????) to determine
;		    if we've loaded in all the sectors of IO.SYS. This will
;		    cause too big of a load if the sectors per track is high
;		    enough, causing either a stack overflow or the boot code
;		    to be overwritten.
;
;
; The ROM in the IBM PC starts the boot process by performing a hardware
; initialization and a verification of all external devices.  If all goes
; well, it will then load from the boot drive the sector from track 0, head 0,
; sector 1.  This sector is placed at physical address 07C00h.	The initial
; registers are set up as follows:  CS=DS=ES=SS=0.  IP=7C00h, SP=0400H.
;
; The code in this sector is responsible for locating the MSDOS device drivers
; (IO.SYS) and for placing the directory sector with this information at
; physical address 00500h.  After loading in this sector, it reads in the
; entirety of the BIOS at BIOSEG:0 and does a long jump to that point.
;
; If no BIOS/DOS pair is found an error message is displayed and the user is
; prompted to reinsert another disk.  If there is a disk error during the
; process, a message is displayed and things are halted.
;
; At the beginning of the boot sector, there is a table which describes the
; MSDOS structure of the media.  This is equivalent to the BPB with some
; additional information describing the physical layout of the driver (heads,
; tracks, sectors)
;

ORIGIN	    EQU 7C00H			; Origin of bootstrap LOADER
BIOSEG	    EQU 70H			; destingation segment of BIOS
BioOff	    EQU 700H			; offset of bios
cbSec	    EQU 512
cbDirEnt    EQU 32
DirOff	    EQU 500h

;
; Define the destination segment of the BIOS, including the initialization
; label
;
SEGBIOS SEGMENT AT BIOSEG
BIOS	LABEL	BYTE
SEGBIOS ENDS

CODE	SEGMENT
	ASSUME CS:CODE,DS:NOTHING,ES:NOTHING,SS:NOTHING
	ORG	DirOff + 1Ch
BiosFS	LABEL	WORD

	ORG	ORIGIN

DSKADR	=	1EH*4			;POINTER TO DRIVE PARAMETERS

Public $START
$START:
	JMP	START
;----------------------------------------------------------
;
;	THE FOLLOWING DATA CONFIGURES THE BOOT PROGRAM
;	FOR ANY TYPE OF DRIVE OR HARDFILE
;
	DB	"MSDOS"
	DB	"3.3"
ByteSec DW	cbSec			; SIZE OF A PHYSICAL SECTOR
	DB	8			; SECTORS PER ALLOCATION UNIT
cSecRes DW	1			; NUMBER OF RESERVED SECTORS
cFat	DB	2			; NUMBER OF FATS
DirNum	DW	512			; NUMBER OF DIREC ENTRIES
	DW	4*17*305-1		; NUMBER OF SECTORS - NUMBER OF HIDDEN SECTORS
MEDIA	DB	0F8H			; MEDIA BYTE
cSecFat DW	8			; NUMBER OF FAT SECTORS
SECLIM	DW	17			; SECTORS PER TRACK
HDLIM	DW	4			; NUMBER OF SURFACES
cSecHid DW	1			; NUMBER OF HIDDEN SECTORS
	dw	0			; high order word of Hiden Sectors
	dd	0			; 32 bit version of NUMBER OF SECTORS
					; (when 16 bit version is zero)
	db	6 dup(?)		; reserved for later expansion


CURHD	DB	?			; Unitialized

; this is an image of the disk parameter table.  Zero entries are copied
; from the rom table at boot.
;
SEC9	DB	0			;   DISK_SPECIFY_1
	DB	0			;   DISK_SPECIFY_2
	DB	0			;   DISK_MOTOR_WAIT
	DB	0			;   DISK_SECTOR_SIZ
	DB	12h			;   DISK_EOT
	DB	0			;   DISK_RW_GAP
	DB	0			;   DISK_DTL
	DB	0			;   DISK_FORMT_GAP
	DB	0			;   DISK_FILL
	DB	1			;   DISK_HEAD_STTL
	DB	0			;   DISK_MOTOR_STRT

Public UDATA
UDATA	LABEL	WORD
BIOS$	EQU	WORD PTR UDATA+1
CURTRK	EQU	WORD PTR UDATA+3
CURSEC	EQU	BYTE PTR UDATA+5
COUNT	EQU	BYTE PTR UDATA+6	; NUMBER OF BIOS SECTORS
BIOSAV	EQU	WORD PTR UDATA+7
DIR$	EQU	WORD PTR UDATA+9

START:

;
; First thing is to reset the stack to a better and more known place.  The ROM
; may change, but we'd like to get the stack in the correct place.
;
	CLI				;Stop interrupts till stack ok
	XOR	AX,AX
	MOV	SS,AX			;Work in stack just below this routine
	ASSUME	SS:CODE
	MOV	SP,ORIGIN
	PUSH	SS
	POP	ES
	ASSUME	ES:CODE
;
; We copy the disk parameter table into a local area.  We scan the table above
; for non-zero parameters.  Any we see get changed to their non-zero values.
;
	MOV	BX,DSKADR
	LDS	SI,DWORD PTR SS:[BX]	; get address of disk table
	PUSH	DS			; save original vector for possible
	PUSH	SI			; restore
	PUSH	SS
	PUSH	BX
	MOV	DI,OFFSET Sec9
	MOV	CX,11
	CLD
changeloop:
	LODSB
	CMP	BYTE PTR ES:[DI],0	; is the template zero?
	JZ	Store			; yes, store what we've got
	MOV	AL,ES:[DI]
Store:
	STOSB
	MOV	AL,AH
	LOOP	ChangeLoop
;
; Place in new disk parameter table.
;
	PUSH	ES
	POP	DS
	ASSUME	DS:CODE
	MOV	[BX+2],AX
	MOV	[BX],OFFSET SEC9
;
; We may now turn interrupts back on.  Before this, there is a small window
; when a reboot command may come in when the disk parameter table is garbage
;
	STI				;Interrupts OK now
;
; Reset the disk system just in case any thing funny has happened.
;
	INT	13H			;Reset the system
	JC	RERROR
;
; The system is now prepared for us to begin reading.  First, determine
; logical sector numbers of the start of the directory and the start of the
; data area.
;
	MOV	AL,cFat 	      ;Determine sector dir starts on
	CBW
	MUL	cSecFat
	ADD	AX,cSecHid
	ADD	AX,cSecRes
	MOV	[DIR$],AX		; AX = cFat*cSecFat + cSecRes + cSecHid
	MOV	[BIOS$],AX
;
; Take into account size of directory (only know number of directory entries)
;
	MOV	AX,cbDirEnt		; bytes per directory entry
	MUL	DirNum			; convert to bytes in directory
	MOV	BX,ByteSec		; add in sector size
	ADD	AX,BX
	DEC	AX			; decrement so that we round up
	DIV	BX			; convert to sector number
	ADD	[BIOS$],AX
;
; We load in the first directory sector and examine it to make sure the the
; BIOS and DOS are the first two directory entries.  If they are not found,
; the user is prompted to insert a new disk.  The directory sector is loaded
; into 00500h
;
	MOV	BX,DirOff		; sector to go in at 00500h
	MOV	AX,DIR$ 		; logical sector of directory
	CALL	DODIV			; convert to sector, track, head
	MOV	AX,0201H		; disk read 1 sector
	CALL	DOCALL			; do the disk read
	JB	CKERR			; if errors try to recover
;
; Now we scan for the presence of IO.SYS  and MSDOS.SYS. Check the
; first directory entry.
;
	MOV	DI,BX
	MOV	CX,11
	MOV	SI,OFFSET BIO		; point to "bios     com"
	REPZ	CMPSB			; see if the same
	JNZ	CKERR			; if not there advise the user
;
; Found the BIOS.  Check the second directory entry.
;
	LEA	DI,[BX+20h]
	MOV	SI,OFFSET DOS		; point to "86dos   com"
	MOV	CX,11
	REPZ	CMPSB
	JZ	DoLoad
;
; There has been some recoverable error.  Display a message and wait for a
; keystroke.
;
CKERR:	MOV	SI,OFFSET SYSMSG	; point to no system message
ErrOut: CALL	WRITE			; and write on the screen
	XOR	AH,AH			; wait for response
	INT	16H			; get character from keyboard
	POP	SI			; reset disk parameter table back to
	POP	DS			; rom
	POP	[SI]
	POP	[SI+2]
	INT	19h			; Continue in loop till good disk

RERROR: MOV	SI,OFFSET DMSSG 	; DISK ERROR MESSAGE
	JMP	ErrOut
;
; We now begin to load the BIOS in.  Compute the number of sectors needed
;
DoLoad:
	MOV	AX,BiosFS		; get file size
	XOR	DX,DX			; presume < 64K
	DIV	ByteSec 		; convert to sectors
	INC	AL			; reading in one more can't hurt
	MOV	COUNT,AL		; Store running count
	MOV	AX,BIOS$		; get logical sector of beginning of BIOS
	MOV	BIOSAV,AX		; store away for real bios later
	MOV	BX,BioOff		; Load address from BIOSSEG
;
; Main read-in loop.
;   ES:BX points to area to read.
;   Count is the number of sectors remaining.
;   BIOS$ is the next logical sector number to read
;
LOOPRD:
	MOV	AX,BIOS$		; Starting sector
	CALL	DODIV
;
; CurHD is the head for this next disk request
; CurTrk is the track for this next request
; CurSec is the beginning sector number for this request
;
; Compute the number of sectors that we may be able to read in a single ROM
; request.
;
	MOV	AX,SECLIM
	SUB	AL,CURSEC
	INC	AX
;
; AX is the number of sectors that we may read.
;

;
;New code for Rev 3.31
;*****************************************************************************

	CMP	COUNT,AL	  ;Is sectors we can read more than we need?
	JAE	GOT_SECTORS	  ;No, it is okay
	MOV	AL,COUNT	  ;Yes, only read in what is left

GOT_SECTORS:

;*****************************************************************************
;End of change
;


	PUSH	AX
	CALL	DOCALL
	POP	AX
	JB	RERROR			; If errors report and go to ROM BASIC
	SUB	COUNT,AL		; Are we finished?
;
;Old code replaced by Rev 3.3
;********************************************************************
;	JBE	DISKOK			; Yes -- transfer control to the DOS
;********************************************************************
;New code for Rev 3.3
;

	JZ	DISKOK			; Yes -- transfer control to the DOS

;********************************************************************
;End of change
;
	ADD	BIOS$,AX		; increment logical sector position
	MUL	ByteSec 		; determine next offset for read
	ADD	BX,AX			; (BX)=(BX)+(SI)*(Bytes per sector)
	JMP	LOOPRD			; Get next track
;
; IBMINIT requires the following input conditions:
;
;   DL = INT 13 drive number we booted from
;   CH = media byte
;   BX = First data sector on disk (0-based)
;
DISKOK:
	MOV	CH,Media
	MOV	DL,PhyDrv
	MOV	BX,[BIOSAV]		;Get bios sector in bx
	JMP	FAR PTR BIOS		;CRANK UP THE DOS

WRITE:	LODSB				;GET NEXT CHARACTER
	OR	AL,AL			;clear the high bit
	JZ	ENDWR			;ERROR MESSAGE UP, JUMP TO BASIC
	MOV	AH,14			;WILL WRITE CHARACTER & ATTRIBUTE
	MOV	BX,7			;ATTRIBUTE
	INT	10H			;PRINT THE CHARACTER
	JMP	WRITE
;
; convert a logical sector into Track/sector/head.  AX has the logical
; sector number
;
DODIV:
	XOR	DX,DX
	DIV	SECLIM
	INC	DL			; sector numbers are 1-based
	MOV	CURSEC,DL
	XOR	DX,DX
	DIV	HDLIM
	MOV	CURHD,DL
	MOV	CURTRK,AX
ENDWR:	RET
;
; Issue one read request.  ES:BX have the transfer address, AL is the number
; of sectors.
;
DOCALL: MOV	AH,2
	MOV	DX,CURTRK
	MOV	CL,6
	SHL	DH,CL
	OR	DH,CURSEC
	MOV	CX,DX
	XCHG	CH,CL
	MOV	DL, PHYDRV
	mov	dh, curhd
	INT	13H
	RET

	include messages.inc

BIO	DB	"IO      SYS"
DOS	DB	"MSDOS   SYS"

Free	EQU (cbSec - 3) - ($-$start)
if Free LT 0
    %out FATAL PROBLEM:boot sector is too large
endif

	org	origin + (cbSec - 3)

; FORMAT and SYS count on PHYDRV being right here
PHYDRV	db	0
; Boot sector signature
	db	55h,0aah

CODE	ENDS
	END
