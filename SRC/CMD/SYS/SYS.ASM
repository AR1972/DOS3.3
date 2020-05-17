;	SCCSID = @(#)sys.asm	1.12 85/10/06
TITLE	MS-DOS SYS Program
; SYS - Copies system programs IBMBIO.COM/IO.SYS and IBMDOS.COM/MSDOS.SYS
;   1.6     05/21/82	Added rev number message
;   1.61    06/04/82	Allow SYS to blank disk TimP at SCP
;   1.70    06/30/82	NON contiguous DOS allowed on 2.00 IBM.  Allows SYS to
;			1.0 1.1 disks.
;   1.71    07/02/82	Put in CHDIRs to make sure everything done in root dir.
;   1.80    04/26/83	MZ make sys work in small machines; use full 2.0
;			system calls
;   1.81    07/22/83	ARR Added check in IBM version for valid FAT ID on
;			destination because of IBM problem with SYSing to
;			unformatted disks which are really formatted.  Prints
;			NoDest message for ridic IBM reasons, should have a
;			better message.
;   1.82    08/12/83	ARR ZIBOed again.  Mark fails to check for errors on
;			his file I/O.  Results in SYS saying system
;			transferred when it hasn't been.
;   1.83    09/08/83	EKE Added code to quit if sys called on a drive across
;			a net.
;   1.84    09/09/83	CHRISP grabbed against his will to make this stupid
;			program write out a boot sector
;   1.85    10/18/83	NP Printf to print messages and it's now an .EXE file
;   1.86    11/8/83	MZ fix hard file output of boot sector
;   1.87    5/1/84	MZ make sys prompt for system disk in default drive.
;   3.20    11/9/84	RS make sys write out a correct boot sector for the
;			version of DOS. It grabs the boot sector off the system
;			disk and inserts the correct BPB.
;			Uses IOCTL Get Device Parms to get BPB for a Hard drive.
;   3.20    08/5/85	RS Allow FAT ID byte of 0F0H for 'strange' media
;			layouts. These come about because of /T /N switches in
;			FORMAT.
;   3.20    09/16/85	Incorporate tables of filenames to allow system files
;			used by other OEMs to be SYSed onto disks formatted on
;			other MSDOS systems. Allows the flexibility to replace
;			system files for one OEM by system files for another.
;
;
;   3.30    06/04/86	MT removes initial check for IBMBIO and DOS - not needed
;			because of later search of dirs
;   3.30    06/16/86	MT only force part of IBMBIO contig - do this by assuming
;			contig part smaller than 1.10 BIOS
;   3.30    06/16/86	MT Check diks space for enough room to install BIO and DOS
.xlist
.xcref
	include version.inc
	INCLUDE DOSSYM.INC   ;also defines version of dos
	include ioctl.INC
.cref
.list

;IBMJAPVER    EQU	FALSE		; this and the following are mutually
;IBMVER	      EQU	TRUE		; exclusive
;IBMCOPYRIGHT EQU 	FALSE

printf_code segment public
	extrn	printf:far
printf_code ends

CODE	SEGMENT PARA PUBLIC
CODE	ENDS

CONST	SEGMENT BYTE PUBLIC
	EXTRN	BIOSNamesTable:byte, DOSNamesTable:byte
	EXTRN	SourceBIOSFile:byte, SourceDOSFile:byte
CONST	ENDS

cstack	segment stack
	db  278 + 80h dup (?)		; 278 == IBM's ROM requirements
cstack	ends

DATA	SEGMENT BYTE PUBLIC

DG	GROUP	CODE,DATA,CONST,cstack

	EXTRN	BADDRV_ptr:byte, BADPARM_ptr:byte, GETSYS_ptr:byte
	EXTRN	SYSDRV:byte, NODEST_ptr:byte, BADSIZ_ptr:byte, DONE_ptr:byte
	EXTRN	BADVER:byte, Crlf_ptr:byte, NoSYS_PTR:byte, GetTarg_ptr:byte
	EXTRN	TargDrv:byte

	EXTRN	NotNetM_ptr:byte


DEFALT	DB	0

	IF IBMCOPYRIGHT
BIOSName    DB	"A:\IBMBIO.COM",0
DOSName     DB	"A:\IBMDOS.COM",0

SourceBIOSName	  DB  "A:\IBMBIO.COM",0
SourceDOSName	  DB  "A:\IBMDOS.COM",0
	ELSE
BIOSName    DB	"A:\IO.SYS",0
DOSName     DB	"A:\MSDOS.SYS",0

SourceBIOSName	  DB  "A:\IO.SYS",0
SourceDOSName	  DB  "A:\MSDOS.SYS",0
	ENDIF

IBMBIO_LOW  DW	0			;length of IBMBIO on disk
IBMBIO_HIGH DW	0
IBMDOS_LOW  DW	0			;length of old IBMDOS on disk
IBMDOS_HIGH DW	0

SIZE_OLD_HIGH DW  0
SIZE_OLD_LOW  DW  0

NEWBIO_SIZE_LOW DW 0
NEWBIO_SIZE_HIGH DW 0
NEWDOS_SIZE_LOW DW 0
NEWDOS_SIZE_HIGH DW 0


Need_Clusters	dw	0
Bytes_Per_Cluster dw	0
Number_Free_Clusters dw 0


;*** WARNING ***
; KEEP THE FOLLOWING ITEMS IN THE EXACT ORDER BELOW!!!
DOSEntFree  DB	1
BIOSEntFree DB	1

BIOSInFH    DW	?			; file handle of source BIOS
BIOSLenLow  DW	2 DUP (?)		; 32-bit length of BIOS
BIOSLenHigh DW	2 DUP (?)		; 32-bit length of BIOS
BIOSTime    DW	2 DUP (?)		; place to store time of BIOS write
BIOSOutFH   DW	?			; fh of BIOS destination

DOSInFH     DW	?			; file handle of source DOS
DOSLenLow   DW	2 DUP (?)		; 32-bit length of DOS
DOSLenHigh  DW	2 DUP (?)		; 32-bit length of DOS
DOSTime     DW	2 DUP (?)		; place to store time of DOS write
DOSOutFH    DW	?			; fh of DOS destination


AllName     DB "A:\*.*",0

;******************************************
;FCB SNOT

fcb_copy	db	32 dup(?)

	IF IBMCOPYRIGHT
FCBDOS	DB  "IBMDOS  COM"
FCBBIO	DB  "IBMBIO  COM"
	ELSE
FCBDOS	DB  "MSDOS   SYS"
FCBBIO	DB  "IO      SYS"
	ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

DOSFile_Offset	dw	0		; Index for system file names in Tables

DirEnt	DB	80h DUP (?)
cbBuf	    DW	?			; number of bytes in buffer
pDOS	    DW	?			; offset of beginning of DOS in buffer
pDOSEnd     DW	?			; offset of end of DOS in buffer

BIOSEG	EQU	70H			; STARTING LOCATION OF BIOS
BPBLEN	EQU	19

BPB	LABEL	DWORD			; POINTER TO HARDFILE BPB
	DW	0000
	DW	BIOSEG

public boot
BOOT	DB	0,0,0			 ; SKIP THE THREE BYTE JUMP
	DB	"MSDOS3.3"
SECSIZ	DW	512			; SECTOR SIZE
SECALL	DB	1			; SECTOS PER ALLOCATION UNIT
RESNUM	DW	1			; RESERVED SECTORS
FATNUM	DB	2			; NUMBER OF FATS
DIRNUM	DW	64			; NUMBER OF DIRECTORY ENTRIES
SECNUM	DW	1*8*40			; NUMBER OF SECTORS
FATID	DB	0FEH
FATSIZE DW	1
SECLIM	DW	8
HDLIM	DW	1
HIDDEN	DW	0
PHYDRV	DB	0
	DB	510-($-boot) dup (?)
	DB	55H,0AAH		 ; MAGIC WORD
REORG	LABEL	BYTE
	ORG	BOOT
	INCLUDE ..\BOOT\BOOT.INC
	ORG	REORG
FATID_TABLE	LABEL	WORD
	DW	0			; F8	FIXED DISK
	DW	-2			; F9
	DW	-1			; FA
	DW	-1			; FB
	DW	OFFSET DG:BPB91 	; FC
	DW	OFFSET DG:BPB92 	; FD
	DW	OFFSET DG:BPB81 	; FE
	DW	OFFSET DG:BPB82 	; FF

; BIOS PARAMETER BLOCKS FOR THE VARIOUS MEDIA

BPB81	DB	1
	DW	1
	DB	2
	DW	64
	DW	1*8*40
	DB	0FEH
	DW	1
	DW	8
	DW	1
	DW	0
	DB	0

BPB82	DB	2
	DW	1
	DB	2
	DW	112
	DW	2*8*40
	DB	0FFH
	DW	1
	DW	8
	DW	2
	DW	0
	DB	0

BPB91	DB	1
	DW	1
	DB	2
	DW	64
	DW	1*9*40
	DB	0FCH
	DW	2
	DW	9
	DW	1
	DW	0
	DB	0

BPB92	DB	2
	DW	1
	DB	2
	DW	112
	DW	2*9*40
	DB	0FDH
	DW	2
	DW	9
	DW	2
	DW	0
	DB	0

BPB96T	DB	1			; mjb001
	DW	1
	DB	2
	DW	224
	DW	2*15*80
	DB	0f9H
	DW	7
	DW	15
	DW	2
	DW	0
	DB	0
BPBSIZ	=	$-BPB96T

BPB325	DB	2			; mjb001
	DW	1
	DB	2
	DW	70h
cSec325 DW	2*9*80
	DB	0f9H
	DW	3
	DW	9
	DW	2
	DW	0
	DB	0



;
; Following structure used by Generic IOCTL call Get Device Parameters to get
; the BPB of a hard disk. It 'overflows' into area of BUF.
;
DeviceParameters	a_DeviceParameters	<0,DEV_HARDDISK>

BUF	LABEL	BYTE			; beginning of area for file reads

DATA	ENDS

CODE	SEGMENT PUBLIC PARA

	ASSUME	CS:DG,DS:NOTHING,ES:NOTHING,SS:CSTACK

start:
	JMP	SHORT CheckVersion

	DW	OFFSET DG:BOOT

HEADER	DB	"SYS 3.30"

CheckVersion:
	PUSH	AX			; save drive letter validity
	MOV	AH,GET_VERSION
	INT	21H			; get dos version

    cmp ax,expected_version
    jne gotbaddos

;	XCHG	AH,AL			; Turn it around to AH.AL
;	CMP	AX,DOSVER_LOW		; is it too low?
;	JNE	GOTBADDOS		; yes, error

	pop	ax
ASSUME	DS:NOTHING,ES:NOTHING
	push	cs
	pop	es
ASSUME	ES:DG
	mov	si,5ch
	mov	di,offset dg:fcb_copy
	mov	cx,32
	rep	movsb
	push	cs
	pop	ds
ASSUME	DS:DG
	MOV	DX,OFFSET DG:DirEnt
	MOV	AH,SET_DMA
	INT	21h
	jmp	sys

GOTBADDOS:
	push	cs
	pop	ds
ASSUME	DS:DG
	MOV	DX,OFFSET DG:BADVER	; message to dump
	mov	ah,std_con_string_output
	int	21h
	push	es
	xor	ax,ax
	push	ax

foo	proc	far
	ret			    ; Must use this method, version may be < 2.00
foo	endp

ERR0:
ASSUME	DS:DG,ES:DG
	MOV	DX,OFFSET DG:BADPARM_ptr    ; no drive letter
	JMP	xerror

ERR1:
ASSUME	DS:DG,ES:DG
	MOV	DX,OFFSET DG:BADDRV_ptr     ; drive letter invalid
	JMP	xerror

;
; We do not have a disk that has an available system in the root.  See if the
; media is removable and if so, ask the user for a replacement.  If the media
; is not removable, then die gracefully.
;
ERR2:
ASSUME	DS:DG,ES:DG
	MOV	AH,GET_DEFAULT_DRIVE	;Will find out the default drive
	INT	21H			;Default now in AL
	MOV	BL,AL
	INC	BL			; A = 1
	Call	IsRemovable
	jnc	DoPrompt
	MOV	DX,OFFSET DG:NoSys_PTR
	PUSH	DX
	CALL	PRINTF
	MOV	AX,4C01h
	INT	21h
DoPrompt:
	MOV	AL,DEFALT		; get default drive number
	ADD	AL,'A'-1                ; turn into letter
	MOV	SYSDRV,AL
	MOV	DX,OFFSET DG:GETSYS_ptr
	push	dx
	call	printf
	CALL	GetKeystroke		; wait for him to type simething
	XOR	AL,AL			; valid drive spec now...
SYS:
ASSUME	DS:DG,ES:DG
	mov	DOSEntFree,1
	mov	BIOSEntFree,1
	CMP	BYTE PTR fcb_copy+1," " ; Was file specified?
	JNZ	ERR0			; yes, no files are allowed -> error
	CMP	AL,-1			; Invalid drive spec?
	JZ	ERR1			; yes, must have valid drive -> error
	CMP	BYTE PTR fcb_copy,0	; No drive specified?
	JZ	ERR1			; yes, cannot sys to default drive error
	MOV	AH,GET_DEFAULT_DRIVE	; Get default drive
	INT	21H
	INC	AL			; turn from phys drive to logical drive
	MOV	DEFALT,AL		; save it for possible printing
	CMP	BYTE PTR fcb_copy,AL	; did he specify the default drive?
	JZ	ERR1			; yes, default drive not allowed

;------Code to quit if sys called on a drive across a net-----------------------
CheckNet:
	MOV	BL,BYTE PTR fcb_copy	;   x = IOCTL (getdrive, Drive+1);
	MOV	AX,(IOCTL SHL 8) + 9
	INT	21H
	JC	NotNet
	TEST	DX,1200H		; if(x & 0x1000)(redirected or shared)
	JZ	NotNet
	MOV	DX,OFFSET DG:NotNetM_ptr    ;	    Fatal ("Can't do over net");
	JMP	xerror

;-------Load up BIOS and DOS at this point ---------------------------------
NotNet:
	MOV	AL,DEFALT
	ADD	AL,'A'-1                ; turn into letter
	MOV	SourceBIOSName,AL	; twiddle source name
	MOV	SourceDOSName,AL	; twiddle source name
	CLD
	MOV	DX,OFFSET DG:SourceBIOSName   ; source name
	MOV	CX,7
	MOV	AH,4Eh
	INT	21h
	JC	ERR2J
	MOV	AX,WORD PTR DG:DIRENt+26
	MOV	WORD PTR NEWBIO_SIZE_LOW,AX
	MOV	AX,WORD PTR DG:DIRENt+28
	MOV	WORD PTR NEWBIO_SIZE_HIGH,AX
	MOV	DX,OFFSET DG:SourceBIOSName   ; source name
	MOV	DI,OFFSET DG:BIOSInFH	; pointer to block of data
	CALL	OpenFile
	JNC	NotERR2
ERR2J:
	JMP	Err2			; not found, go and try again

NotERR2:
	MOV	DX,OFFSET DG:SourceDOSName   ; source name
	MOV	CX,7
	MOV	AH,4Eh
	INT	21h
	JC	ERR2J
	MOV	AX,WORD PTR DG:DIRENt+26
	MOV	WORD PTR NEWDOS_SIZE_LOW,AX
	MOV	AX,WORD PTR DG:DIRENt+28
	MOV	WORD PTR NEWDOS_SIZE_HIGH,AX
	MOV	DX,OFFSET DG:SourceDOSName    ; source of DOS
	MOV	DI,OFFSET DG:DOSInFH	; pointer to block of data
	CALL	OpenFile		; Look for DOS
	JC	ERR2J			; not there, go ask for a system disk
	MOV	CX,SP			; get lowest available spot
	SUB	CX,0200h+(OFFSET DG:BUF); leave room for all sorts of things
	MOV	cbBuf,CX		; store length away
	CALL	FillMem 		; load up memory with files
	JC	ERR2J			; Some kind of error reading system


CheckDest:
;------------Check for "valid" destination-----------------------------------
	MOV	AH,0Dh
	INT	21h
	MOV	AL,BYTE PTR fcb_copy
	DEC	AL
	MOV	BX,OFFSET DG:buf	; Temp space
	MOV	DX,1			; Sector 1 (first sec of FAT)
	MOV	CX,DX			; One sector
	INT	25H			; Read Fat sector
	POP	AX			; Flags
	JC	PromptDest		; Issue prompt to insert Destination
					;   disk
	CMP	BYTE PTR [BUF],0F8H
	JAE	OKFAT
;---------Treat 0F0H as a valid 'IBM' FAT ID byte--------------------------------
	cmp	BYTE PTR [BUF],0F0H
	je	OKFAT
	JMP	ERR3


PromptDest:
	push	ax

	mov	al,Byte ptr fcb_copy	   ; Get destination ID
	ADD	AL,'A'-1                ; turn into letter
	MOV	TargDrv,AL

	MOV	DX,OFFSET DG:GetTarg_ptr
	push	dx
	call	printf

	CALL	GetKeystroke		; wait for him to type simething

	pop	ax
	jmp	CheckDest

;-------The Fat appears to be OK... See if DOS/Bios there-----------------




OKFAT:
;
;Set up drive letter in destignation filespecs
;

	MOV	AL,BYTE PTR fcb_copy
	ADD	AL,'A'-1                ; convert to letter
	MOV	BIOSName,AL		; point names at destination drive
	MOV	DOSName,AL

;
; Read in first sector of directory
;
; The reason that we do the direct read of the directory is the find first/next
; or search first/next do an exclusive search for volume labels. By using these
; calls, there is no way to determine if a volume label occupies the first
; location in the directory. Hence we get sleazy and read the directory directly
; (no pun intended) to get this info. While its in there, go ahead and grab the file
; sizes. -MT
;
GetDir:
       MOV     DL,Byte PTR fcb_copy
       MOV     AH,Get_DPB
       PUSH    DS
       INT     21h

; DS:BX point to DPB

	MOV	DX,[BX.dpb_dir_sector]
	POP	DS
	MOV	AL,BYTE PTR fcb_copy
	DEC	AL
	MOV	BX,OFFSET DG:BUF	; Temp space
	MOV	CX,1			; Sector 1 (first sec of FAT)
	INT	25H			; Read Fat sector
	POP	AX			; Flags
	JNC	Skip

;
;NOTE!!!! This next jump is actually a bug left over from the MS days - if the
;dir is not read successfully then the SYS should be canned at that point -
;however, up thru 3.20 this would just jump to the actual sys. To make things
; a little better I jump to an error - this needs to be DCR'd for a real error
;

	JMP	Err3
Skip:

;
; Now see if the first two directory entries are available... First check
; for being free:
;
	MOV	SI,OFFSET DG:BUF
	CMP	BYTE PTR [SI],0 	; empty dir?
	JE	Get_Space		; yes, go check for conflicts
	CLD
	CMP	BYTE PTR [SI],0E5h
	JE	SecondFree
;
; The first entry is not free.	See if the BIOS is there
;
	MOV	DI,OFFSET DG:FCBBIO
	MOV	CX,11
	REP	CMPSB
	JNE	Err3jj			; not BIOS
	DEC	BIOSEntFree

; added by dcl 8/24/86 - most cases solution

	mov	ax,0002 		; is ibmbio allocated the 1st cluster?
	cmp	ax,word ptr DG:BUF+26	; that being cluster 2???
	JNE	Err3jj			; not cluster 2 - error; go display

; end added by dcl 8/24/86

;
; IBM change - MT 6/16/86
; Get the size of the file for IBMBIO
;
	MOV	ax,word ptr DG:BUF+28
	MOV	word ptr IBMBIO_Low,ax
	MOV	ax,word ptr DG:BUF+30
	MOV	word ptr IBMBIO_High,ax

; Check the second entry
;
 SecondFree:
	MOV	SI,OFFSET DG:BUF+32
	CMP	BYTE PTR [SI],0 	; empty dir?
	JE	Get_Space		; yes, go check for conflicts
	CMP	BYTE PTR [SI],0E5h    ; how about second?
	JE	Get_Space
;
; This entry is not free.  Check it for IBMDOS
;
	MOV	DI,OFFSET DG:FCBDOS
	MOV	CX,11
	REP	CMPSB
Err3jj: JNZ	Err3j1			; not DOS
	DEC	DOSEntFree
;
; IBM change - MT 6/16/86
; Get the file size for IBMDOS
;
	MOV	ax,word ptr DG:BUF+60
	MOV	word ptr IBMDOS_Low,ax
	MOV	ax,word ptr DG:BUF+62
	MOV	word ptr IBMDOS_High,ax

;
; We now have the following:
;   Whether or not there is a DOS/BIOS on the disk
;   Whether or not the appropriate entry is free
; We are guaranteed that if the entry is free, then it has the correct file in


;
;IBM CHANGE - MT 6/16/86
;
; Here we make some VERY IMPORTANT assumptions.
;
;1) If IBMBIO exists on the disk currently, we assume it is in the correct
;   place, i.e. at the front of the data area and contiguous.
;2) The stub loader portion of IBMBIO is less than 2048 bytes long. This
;   number comes about by assuming we will never overlay anything smaller
;   than 1920 bytes (DOS 1.10 IBMBIO size). This can be expanded to 2048 if
;   we also assume the smallest possible cluster length is 512 bytes.
;
; Therefore, if we have an empty disk or IBMBIO exists, then we have enough
; contiguous room to install the portion of IBMBIO that requires itself to
; be contiguous.


;
;IBM CHANGE - MT 6/16/86
;
;See if enough free space for IBMBIO and IBMDOS
;

GET_SPACE:
	MOV	AH,36H			;Get free space
	MOV	DL,byte ptr fcb_copy	;Get the drive letter
	INT	21h

;16 bit math okay here, no danger of overflow

	MUL	CX			;Get bytes/cluster
					;Result left in AX
	PUSH	AX			;Save it for later
	MOV	Bytes_Per_Cluster,AX
	MOV	Number_Free_Clusters,BX

;Low result in AX, High result in DX
;Get IBMBIO size

	MOV	AX,IBMBIO_Low
	MOV	DX,IBMBIO_High

	CALL	Get_Clusters
	ADD	Number_Free_Clusters,AX

;Low result in AX, High result in DX
;Get IBMDOS size

	MOV	AX,IBMDOS_Low
	MOV	DX,IBMDOS_High
	CALL	Get_Clusters
	ADD	Number_Free_Clusters,AX


;Find the total size of new DOS and BIOS

	MOV	AX,NEWBIO_Size_Low
	MOV	DX,NEWBIO_Size_High

	CALL	Get_Clusters

Got_NEW_BIO_Clusters:
	MOV	Need_Clusters,AX

	MOV	AX,NEWDOS_Size_Low
	MOV	DX,NEWDOS_Size_High
	CALL	Get_Clusters
	ADD	AX,Need_Clusters

;Now see if there is enough room for all of it on the disk

	CMP	AX,Number_Free_Clusters
	JBE	PUT_SYS

ERR3J1:
	JMP	ERR3

;Go do the sys
PUT_SYS:
	CMP	BIOSEntFree,0
	JNE	GetRidDOS
	MOV	DX,OFFSET DG:BIOSName	; who to change mode
	MOV	CX,0			; undo attributes
	MOV	AX,(ChMod SHL 8) + 1	; set the attributes
	INT	21h
	MOV	DX,OFFSET DG:BIOSName
	MOV	AX,(UNLINK SHL 8)
	INT	21H			; Delete BIOS file
GetRidDOS:
	CMP	DOSEntFree,0
	JNE	CreateBIOS
	MOV	DX,OFFSET DG:DOSName	; who to change mode
	MOV	CX,0			; undo attributes
	MOV	AX,(ChMod SHL 8) + 1	; set the attributes
	INT	21h
	MOV	DX,OFFSET DG:DOSName
	MOV	AX,(UNLINK SHL 8)
	INT	21H				; Delete DOS file
CreateBIOS:
	MOV	DX,OFFSET DG:BIOSName	  ; destination of BIOS
	MOV	CX,7				; fancy attributes
	MOV	AH,Creat			; make a new one
	INT	21h
	JC	err3j2
	MOV	BIOSOutFH,AX			; save handle
	MOV	DX,OFFSET DG:DOSName		; destination of DOS
	MOV	AH,Creat			; make a new one
	INT	21h
	JC	err3j2
	MOV	DOSOutFH,AX		; save handle
	PUSH	DS
	MOV	AH,GET_DPB
	MOV	DL,BYTE PTR fcb_copy	; Target drive
	INT	21H
	MOV	[BX.dpb_next_free],0	; Reset Allocation to start of disk
					;  so BIOS goes in right place!
	POP	DS
Copy:
	CALL	DumpMem 		; flush out memory
	JC	ERR3J2			; Disk full or some other error
	MOV	AX,DOSLenHigh		; more DOS?
	OR	AX,DOSLenLow		; more low dos
	OR	AX,BIOSLenHigh		; more high BIOS
	OR	AX,BIOSLenLow		; more low BIOS
	JZ	AllDone 		; nope, all done
	CALL	FillMem 		; reload world
	JNC	Copy
	JMP	ERR2			; Start over again

ERR3J2:
	JMP	ERR3

ERR4:
	MOV	DX,OFFSET DG:BADSIZ_ptr
	JMP	xerror

AllDone:
	MOV	CX,BIOSTime		; get time and date
	MOV	DX,BIOSTime+2
	MOV	BX,BIOSOutFH		; where to stuff the time
	MOV	AX,(File_Times SHL 8) + 1
	INT	21h
	MOV	AH,Close
	INT	21h
	MOV	CX,DOSTime		; get time and date
	MOV	DX,DOSTime+2
	MOV	BX,DOSOutFH		; where to stuff the time
	MOV	AX,(File_Times SHL 8) + 1
	INT	21h
	MOV	AH,Close
	INT	21h

	CALL	PUTBOOT 		; copy the boot sector also

	MOV	DX,OFFSET DG:DONE_ptr	; all finished message
	push	dx
	call	printf
	XOR	AL,AL			; ok error code
	jmp	short rexit

xerror:
	push	dx
	call	printf
	mov	dx,offset dg:crlf_ptr
	push	dx
	call	printf
	mov	al,0ffh
rexit:
	MOV	AH,EXIT 		; bye and return error code
	INT	21h

POPRET:
	POP	CX
SETERR:
	STC
	return


Get_Clusters:
;Round up to the next cluster size

	MOV	BX,Bytes_Per_Cluster	;Bytes/cluster
	DIV	BX			;If there is a remainder in DX, then
					;we have another cluster to round up
	CMP	DX,0
	JE	Got_CLUSTERS
	INC	AX			;Round up to next cluster
Got_Clusters:
	RET


FillMem:
	MOV	CX,cbBuf		; get length of buffer
	MOV	BX,BIOSInFH		; get bios source handle
	MOV	DX,OFFSET DG:BUF+512	; point to beginning of buffer
					; past area to read in boot rec
	PUSH	CX			; save away total length
	CMP	BIOSLenHigh,0		; > 64K to read?
	JA	UseCX			; use CX
	CMP	BIOSLenLow,CX		; more left to read?
	JA	UseCX			; use CX
	MOV	CX,BIOSLenLow		; move new
UseCX:
	MOV	AH,Read
	INT	21h			; read in what we can
	JC	POPRET			; Error
	CMP	AX,CX			; Did we get it all?
	JNZ	POPRET			; No, error
	ADD	DX,AX			; update pointer for DOS Read
	MOV	pDOS,DX 		; point to beginning of DOS
	SUB	BIOSLenLow,AX		; decrement remaining
	SBB	BIOSLenHigh,0		; do 32 bit
	POP	CX			; get original length
	SUB	CX,AX			; this much is left
	MOV	BX,DOSInFH		; get bios source handle
	CMP	DOSLenHigh,0		; > 64K to read?
	JA	UseCXDOS		; use CX
	CMP	DOSLenLow,CX		; more left to read?
	JA	UseCXDOS		; use CX
	MOV	CX,DOSLenLow		; move new
UseCXDOS:
	MOV	AH,Read
	INT	21h			; read in what we can
	retc				; error
	CMP	AX,CX
	JNZ	SETERR			; Didn't read it all
	ADD	DX,AX			; update pointer for DOS Read
	MOV	pDOSEnd,DX		; point to End of dos DOS
	SUB	DOSLenLow,AX		; decrement remaining
	SBB	DOSLenHigh,0		; do 32 bit arithmetic
	CLC
	return

OpenFile:
	MOV	AX,(OPEN SHL 8) + 0	; open for reading only
	INT	21H			; Look for BIOS
	retc				; not found, go and try again
	STOSW				; stash away handle
	MOV	BX,AX			; get ready for seeks
	MOV	AX,(LSeek SHL 8) + 2	; seek relative to eof
	XOR	CX,CX			; zero offset
	XOR	DX,DX			; zero offset
	INT	21h			; get offsets
	STOSW				; save low part of size
	STOSW				; save low part of size
	MOV	AX,DX
	STOSW				; save high part of size
	STOSW				; save high part of size
	XOR	DX,DX			; zero offset
	MOV	AX,(LSeek SHL 8) + 0	; seek relative to beginning
	INT	21h
	MOV	AX,(File_Times SHL 8) + 0
	INT	21h			; get last write times
	MOV	AX,CX
	STOSW				; save time
	MOV	AX,DX
	STOSW				; save date
	return

ERR3:
	MOV	DX,OFFSET DG:NODEST_ptr
	JMP	xerror

DumpMem:
	MOV	DX,OFFSET DG:BUF+512	; get offset of bios start
	MOV	CX,pDOS 		; beginning of next guy
	SUB	CX,DX			; difference is length
	JZ	DumpDos 		; no bios to move
	MOV	BX,BIOSOutFH		; where to output
	MOV	AH,Write
	INT	21h			; wham
	retc				; error
	CMP	AX,CX			; Did it work?
	JNZ	WRERR			; No
DumpDos:
	MOV	DX,pDOS 		; beginning of dos
	MOV	CX,pDOSEnd		; end of dos
	SUB	CX,DX			; difference is length
	retz				; if zero no write
	MOV	BX,DOSOutFH		; where to output
	MOV	AH,Write
	INT	21h			; wham
	retc				; error
	CMP	AX,CX			; Did it work?
	retz				; Yes, carry clear
WRERR:
	STC
	return



;
; Output a boot sector apporpriate to the supposed version of DOS.  We do this
; by reading in the boot sector for the drive and getting the BPB from there.
; This works fine until we get a 1.x diskette, when we have to grab the media
; descriptor byte and select the correct BPB using that.
;
public putboot
PUTBOOT:
	mov	ax,dg			  ; initialize DS.
	mov	ds,ax
	mov	al,byte ptr fcb_copy	  ; target drive 1-based
	dec	al			  ; convert to 0-based
	mov	dx,0000H		  ; get relative sector 0
	call	Read_Sec
	jc	Do_Media_Byte
	cmp	word ptr DG:[Buf+1FEH], 0AA55H	       ; Is it a 1.x disk?
	jnz	Do_Media_Byte
PB0:
	mov	si,(offset DG:Buf)+13	  ; Set up SI to point to 'SECALL' in
					  ; the BPB just read in.
	jmp	PB7
;
; We were unable to use the BPB in the boot sector, so we must now get a
; valid BPB by examining the media descriptor byte.
;
Do_Media_Byte:
	MOV	AH,GET_DPB
	MOV	DL,BYTE PTR fcb_copy	; Target drive
	INT	21H
	MOV	AL,[BX.dpb_media]	; Media byte
	PUSH	CS
	POP	DS
	SUB	AL,0F8H
	CBW
	MOV	BX,AX			; BX has offset into bpb table
	SHL	BX,1			; Word table, mult by 2
	MOV	SI,[BX+FATID_TABLE]	; get pointer to bpb
	OR	SI,SI			; hardfile?
	JNZ	PB3			; nope.

;
; We have a hard drive. We can use the IOCTL Get Device Parameters to get the
; BPB for the hard drive.
;
	mov	bl,byte ptr fcb_copy	; Drive number
	mov	dx,offset DeviceParameters
	mov	ah,IOCTL
	mov	al,GENERIC_IOCTL
	mov	ch,RAWIO
	mov	cl,Get_Device_Parameters
	int	21H
	mov	bx,dx			; ds:bx-> DeviceParameters
	lea	si,byte ptr [bx].DP_BPB ; SI -> BPB returned
	inc	si
	inc	si			; si-> secall in BPB

PB3:	CMP	SI,-1			; weird internal error?
	JZ	PB9
	CMP	SI,-2			; new multi-value FAT ID?
	JNZ	PB7			; nope.
;
; We may have a FAT ID of F9.  This may represent TWO different media in two
; incompatible drives.	We do a get free space to determine which.
;
	MOV	AH,Get_Drive_freespace
	MOV	DL,BYTE PTR FCB_copy
	INT	21h
	MOV	BX,DX
	MUL	BX			; compute total sectors
	CMP	AX,cSec325
	MOV	SI,OFFSET DG:BPB325
	JB	PB7
	MOV	SI,OFFSET DG:BPB96T

PB7:	PUSH	DS			; COPY IN THE NEW STUFF
	POP	ES
	MOV	DI,OFFSET DG:SECALL
	MOV	CX,BPBSIZ
	CLD
	REP	MOVSB

PB8:
	cmp	dg:FATID,0F8H			; Hard drive?
	jnz	not_hard
; NOTE:
; The physical hard drive number is placed in the third byte from the end in the
; boot sector in DOS 3.2. This is a change from the previous DOS versions.
;
	mov	byte ptr dg:[boot+1FDH],80H	; set physical hard drive number
not_hard:
	MOV	AL,BYTE PTR fcb_copy
	DEC	AL
	MOV	BX,OFFSET DG:BOOT	; Boot sector
	XOR	DX,DX			; Sector 0
	MOV	CX,DX
	INC	CX			; One sector
	INT	26H			; Write out 8 sector boot sector
	jnc	pb9
PB9:	POP	AX			; Flags
	RET

;
; Read_Sec reads the sector and track specified in DX from the drive in AL.
; The sector is read into location Buf. Carry set if error.
;

READ_SEC:
	push	ax			; save registers
	mov	cx,0001H
	mov	bx,Offset DG:Buf	; temp. buffer
	int	25H
	pop	ax			; Pop flags pushed by Int 25
Read_Ret:
	pop	ax
	ret



GetKeystroke:
	MOV	AX,(Std_CON_Input_Flush SHL 8) + Std_CON_Input_No_Echo
	INT	21H
	MOV	AX,(Std_CON_Input_Flush SHL 8) + 0
	INT	21H
	mov	dx,offset dg:crlf_ptr
	push	dx
	call	printf
	return

;
; Determine if the drive indicated in BX is removable or not.
;
;   Inputs:	BX has drive (0=default, 1=A)
;   Outputs:	Carry clear => removable
;		Carry set   => non-removable
;
;   Registers modified: none
;
IsRemovable:
	SaveReg <AX>
	mov	AX,(IOCTL SHL 8) OR 8	    ; do a media check
	INT	21H
	jnc	CheckRemove
	MOV	AX,(IOCTL SHL 8) OR 9	    ; Is it a net drive
	INT	21H
	jc	NotRemove		    ; Yipe! Say non-removable
	TEST	DX,1000H
	jnz	NotRemove		    ; Is NET drive. Say non-removable.
	JMP	IsRemove
CheckRemove:
	TEST	ax,1
	jnz	NotRemove
IsRemove:
	CLC
	RestoreReg  <AX>
	return
NotRemove:
	STC
	RestoreReg  <AX>
	return

;
; Moves the name at the current locations in the system file name tables into
; the relevant system variables for later use.
; Preserves all registers (except flags).
;
MoveNames:
	push	bx
	push	cx
	push	di
	push	si
	cld
	mov	bx,word ptr DOSFile_Offset
	mov	si,offset DG:BIOSNamesTable
	add	si,bx
	mov	di,offset DG:BIOSName
	add	di,3			; skip over drive,colon,back-slash
	mov	cx,11
	repe	movsb
	mov	si,offset DG:DOSNamesTable
	add	si,bx
	mov	di,offset DG:DOSName
	add	di,3			; skip over drive,colon,back-slash
	mov	cx,11
	repe	movsb
	pop	si
	pop	di
	pop	cx
	pop	bx
	ret

;
; Set up filename in FCB variables for searching directory entries.
;
SetUpFCB:
	push	si
	push	di
	push	bx
	mov	si,offset DG:BIOSNamesTable
	mov	bx,word ptr DOSFile_Offset
	add	si,bx
	mov	di,offset DG:FCBBIO
	call	MoveToFCB
	mov	si,offset DG:DOSNamesTable
	mov	bx,word ptr DOSFile_Offset
	add	si,bx
	mov	di,offset DG:FCBDOS
	call	MoveToFCB
	pop	bx
	pop	di
	pop	si
	ret

;
; Move ASCIZ filename to FCB-type filename from [SI] to [DI].
;
MoveToFCB:
	xor	cx,cx
NextChar:
	lodsb
	cmp	al,'.'
	jz	Fill_Blanks
	stosb
	inc	cx
	jmp	short NextChar

Fill_Blanks:
	mov	al,' '
	cmp	cx,8
	jge	See_Ext
	stosb
	inc	cx
	jmp	short Fill_Blanks

See_Ext:
	mov	cx,3
Next_Ext:
	lodsb
	stosb
	dec	cx
	jnz	Next_Ext
	RET

;
; Gets source file names from SourceBIOSFile and SourceDOSFile and puts them
; into the ASCIZ strings SourceBIOSName and SourceDOSName.
;
GetSourceNames:
	push	si
	push	di
	push	cx
	mov	si,offset DG:SourceBIOSFile
	mov	di,offset DG:SourceBIOSName
	add	di,3			; skip over drive,colon,back-slash
	mov	cx,12
	repe	movsb
	mov	si,offset DG:SourceDOSFile
	mov	di,offset DG:SourceDOSName
	add	di,3			; skip over drive,colon,back-slash
	mov	cx,12
	repe	movsb
	pop	cx
	pop	di
	pop	si
	ret



CODE	ENDS
	END	START
