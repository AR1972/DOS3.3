;
; After the boot sector reads in msbio it jumps to this location.  Msbio
; immediately jumps to initialization code in msinit.
;

	EXTRN	INIT:NEAR

Public START$
START$:
	JMP	INIT			; START$ patch by init to point to
					; hdrive BPB


	PATHSTART 001,BIO


;----------------------------------------------------------------------------
;
;		Command Jump Tables
;
;     These tables hold the entry points for the various service routines
; for the different drivers.  The index in the table is the command code for
; that funcion plus two.  For example the command code for Read (input) is 4,
; The 6th (4 plus 2) entry in the table DSKTBL is DSK$READ - the command to
; read a disk.	Commands which do not exist for a device are filled with
; exit (e.g. MediaCheck for CONTBL).  The first entry in the table is the
; largest command code implemented for that device.  This value is used
; for error checking.  If new command codes are added then the first entry
; in the table must be incremented.
;
;	BEWARE - These tables overlap somewhat! -c.p.
;

;
; Disk:
;

	ODD
DSKTBL	LABEL	BYTE
	DB	24			; This is the size of the table YUK!!!!
	DW	DSK$INIT		; Code	0: INIT
	DW	MEDIA$CHK		; code	1: Media Check
	DW	GET$BPB 		; code	2: BUILD BPB
	DW	CMDERR			; code	3: IOCTL input
	DW	DSK$READ		; code	4: INPUT
	DW	BUS$EXIT		; code	5: NONDESTRUCITVE INPUT, NO WAIT
	DW	EXIT			; code	6: INPUT STATUS
	DW	EXIT			; code	7: INPUT FLUSH
	DW	DSK$WRIT		; code	8: OUTPUT
	DW	DSK$WRITV		; code	9: OUTPUT with verify
	DW	EXIT			; code 10: OUTPUT STATUS
	DW	EXIT			; code 11: OUTPUT FLUSH
	DW	CMDERR			; code 12: IOCTL output
Public TABLE_PATCH
TABLE_PATCH LABEL WORD			;ARR 2.42
	DW	DSK$OPEN		; code 13: DEVICE OPEN
	DW	DSK$CLOSE		; code 14: DEVICE CLOSE
	DW	DSK$REM 		; code 15: REMOVABLE MEDIA
	dw	exit
	dw	exit
	dw	exit
	DW	GENERIC$IOCTL
	dw	exit
	dw	exit
	dw	exit
	dw	IOCTL$GETOWN
	dw	IOCTL$SETOWN

;
; Console:
;

	ODD
CONTBL	LABEL	BYTE
	DB	10
	DW	EXIT
	DW	EXIT
	DW	EXIT
	DW	CMDERR
	DW	CON$READ
	DW	CON$RDND
	DW	EXIT
	DW	CON$FLSH
	DW	CON$WRIT
	DW	CON$WRIT
	DW	EXIT

;
; Auxilary:
;

	ODD
AUXTBL	LABEL	BYTE
	DB	10
	DW	EXIT
	DW	EXIT
	DW	EXIT
	DW	CMDERR
	DW	AUX$READ
	DW	AUX$RDND
	DW	EXIT
	DW	AUX$FLSH
	DW	AUX$WRIT
	DW	AUX$WRIT
	DW	AUX$WRST

;
; Clock:
;

	ODD
TIMTBL	LABEL	BYTE
	DB	9
	DW	EXIT
	DW	EXIT
	DW	EXIT
	DW	CMDERR
	DW	TIM$READ
	DW	BUS$EXIT
	DW	EXIT
	DW	EXIT
	DW	TIM$WRIT
	DW	TIM$WRIT

;
; Printer:
;

	ODD
PRNTBL	LABEL	BYTE
	DB	24
	DW	EXIT			;INIT
	DW	EXIT
	DW	EXIT
	DW	CMDERR
	DW	EXIT$ZER		;INDICATE ZERO CHARS READ
	DW	BUS$EXIT
	DW	EXIT
	DW	EXIT
	DW	PRN$WRIT
	DW	PRN$WRIT
	DW	PRN$STAT
	DW	EXIT
	DW	EXIT
	DW	EXIT
	DW	EXIT
	DW	EXIT
	DW	PRN$TilBusy
	DW	EXIT
	DW	EXIT
	DW	PRN$GenIOCTL
	dw	exit
	dw	exit
	dw	exit
	dw	CMDERR
	dw	CMDERR


	EVENB
Public Old13
OLD13	label	DWORD
	db	'5986'                  ;Code for 3.30


Public Orig13
ORIG13	label	DWORD
	db	'21',0,0                ;Code for 3.30


;
; PTRSAV - pointer save
;
;   This variable holds the pointer to the Request Header passed by a
; program wishing to use a device driver.  When the strategy routine is
; called it puts the address of the Request header in this variable and
; returns.
;

	EVENB
PUBLIC	PTRSAV
PTRSAV	DD	0


;
; Buffer for the AUX device driver
;

;;Rev 3.30 Modification
	PUBLIC	AUXBUF
AUXBUF	DB	0,0,0,0   ;SET OF 1 BYTE BUFFERS FOR COM 1,2,3, AND 4


	EVENB
	PUBLIC PREVOPER,NUMBER_OF_SEC
;;End of Modification
PrevOper	DW	?	; Holds ROM DISK INT request (i.e. Register AX).
Number_Of_Sec	DB	?	; Holds number of sectors to read on an ECC error


;;Rev 3.30 Modification
	IF	($-CODE) GT 100H
	    %OUT VDISK BUFFER NOT CORRECTLY LOCATED
	ELSE
	    ORG 100H
	ENDIF
	PUBLIC	VDISK_AREA
VDISK_AREA DB	108 DUP(0)		;FOR USE BY VDISK
;;End of Modification


;
; AUXNUM holds the number of the printer or AUX device requested.  For
; example if printer 2 was called (PRN2$IN) AUXNUM is set to be one; with
; line printer 3 AUXNUM is set to 2.  With this set the printer device driver
; can tell which printer to command applies to.
;
; WARNING!!!  These are addressed together in GETDX
;

	EVENB
AUXNUM	DB	0
	DB	0


;
; Device Header for the CON Device Driver
;

	EVENB
PUBLIC	CONHeader
CONHeader LABEL   WORD
	DD	AUXDEV2
	DW	1000000000010011B	; Con in and con out + special
	DW	STRATEGY		; Strategy entry point
	DW	CON$IN			; interrupt entry point
	DB	'CON     '              ; device name


;
; Device Header for device "AUX"
;

	EVENB
	PUBLIC	AUXDEV2
AUXDEV2  LABEL	 WORD			 ;HEADER FOR DEVICE "AUX"
	DD	PRNDEV2
	DW	1000000000000000B	; attribute word, character device
	DW	STRATEGY		; device strategy routine
	DW	AUX0$IN 		; device interrupt routine
	DB	'AUX     '              ; device name


;
; Device Header for device PRN
;

	EVENB
	PUBLIC	PRNDEV2
PRNDEV2  LABEL	 WORD			 ;HEADER FOR DEVICE "PRN"
	DD	TIMDEV
	DW	CharDev + OutTilBusy + Dev320
	DW	STRATEGY
	DW	PRN0$IN
	DB	'PRN     '


;
; Device Header for device CLOCK$
;

	EVENB
	PUBLIC TIMDEV
TIMDEV	LABEL	WORD
	DD	DSKDEV
	DW	1000000000001000B
	DW	STRATEGY
	DW	TIM$IN
	DB	'CLOCK$  '


;
; Device Header for disk devices
;
;	Device attribute bits:
;		Bit 6 - DOS 3.2 Bit
;

	EVENB
PUBLIC	DSKDEV
DSKDEV	LABEL	WORD
	DD	COM1DEV
	DW	0000100001000000B	; DOS 3.2
	DW	STRATEGY		; strategy routine
	DW	DSK$IN			; Interrupt entry point


;
; maximum number of drives
;

DRVMAX	DB	4
Public DRVMAX


;
; Last drive accessed
;

	PUBLIC STEP_DRV
STEP_DRV	DB     -2		; ARR 2.20 LAST DRIVE ACCESSED

Public Phys_Drv
Phys_Drv	DB	0		; Used by setdrvie for getting
					; BDS for logical drive, or physical
					; drive. 0 => use logical
					;	 1 => use physical

Public fHave96
fHave96 DB	0			; Flag to indicate presence of
					;   96tpi support

Public Single
Single		DB	0		; Used to detect single drive systems

Public fHaveK09
fHaveK09	DB	0		;Indicates if this is a K09 or not
					; used by console driver.
Public NEW_ROM
NEW_ROM 	DB	0		;Set to 1 if we have a ROM that can
					; handle strange media layouts.

	PUBLIC FSETOWNER
fSetOwner	db	?		;=1 if we are setting the owner of a
					;drive. (Examined by CheckSingle).
	public	Secrete_Code
Secrete_Code	dw	'jk'            ;Code for 3.30.


;
; Device Header for device "COM1"
;

	EVENB
Public COM1DEV
COM1DEV LABEL	WORD
	DD	LPT1DEV
	DW	1000000000000000B	; attribute word, character device
	DW	STRATEGY		; device strategy routine
	DW	AUX0$IN 		; device interrupt routine
	DB	'COM1    '              ; device name


;
; Device Header for device LPT1
;

	EVENB
Public LPT1DEV
LPT1DEV LABEL	WORD
	DD	LPT2DEV
	DW	CharDev + OutTilBusy + Dev320
	DW	STRATEGY
	DW	PRN1$IN
	DB	'LPT1    '


;
; Device Header for device LPT2
;

	EVENB
Public Lpt2Dev
LPT2DEV LABEL	WORD
	DD	LPT3DEV
	DW	CharDev + OutTilBusy + Dev320
	DW	STRATEGY
	DW	PRN2$IN
	DB	'LPT2    '

;
; Device Header for device LPT3
;

	EVENB
Public Lpt3Dev
LPT3DEV LABEL	WORD
	DD	COM2DEV
	DW	CharDev + OutTilBusy + Dev320
	DW	STRATEGY
	DW	PRN3$IN
	DB	'LPT3    '


;
; Device Header for device "COM2"
;

	EVENB
Public Com2Dev
COM2DEV LABEL	WORD
	dd	COM3DEV
	DW	1000000000000000B	; attribute word, character device
	DW	STRATEGY		; device strategy routine
	DW	AUX1$IN 		; device interrupt routine
	DB	'COM2    '              ; device name

;;Rev 3.30 Modification
;
; Device header for device "COM3"
;
	EVENB
	PUBLIC  COM3DEV
COM3DEV LABEL   WORD
	dd	COM4DEV
	dw	1000000000000000b	; character device attribute
	dw	STRATEGY
	dw	AUX2$IN			; com3 == aux2
	db	'COM3    '

;
; Device header for device "COM4"
;
	EVENB
	PUBLIC  COM4DEV
COM4DEV LABEL   WORD
	dw	-1,CODE
	dw	1000000000000000b	; character device attribute
	dw	STRATEGY
	dw	AUX3$IN			; com4 == aux3
	db	'COM4    '

;;End of Modification


; Hard-wire the link to the next Int2f handler.
;;Rev 3.30 Modification
		EVENB
PUBLIC	Next2f_13
NEXT2F_13	LABEL	WORD
	EXTRN INT2F_DISK:FAR		;MSBIO2
		DD	INT2F_DISK


;
; Start of linked list of BDS's
;

		EVENB
Public Start_BDS
START_BDS LABEL WORD
       DD      BDS1	       ;START OF BDS LINKED LIST.
;;End of Modification


;
; Some floppy drives do not have changeline support.  The result is a
; large amount of inefficiency in the code.  A media-check always returns
; "I don`t know".  This cause DOS to reread the FAT on every access and
; always discard any cached data.
;    We get around this inefficiency by implementing a "Logical Door Latch".
; The following three items are used to do this.  The logical door latch is
; based on the premise that it is not physically possible to change floppy
; disks in a drive in under two seconds (most people take about 10).  The
; logical door latch is implemented by saving the time of the last successful
; disk operation (in the value TIM_DRV).  When a new request is made the
; current time is compared to the saved time.  If less than two seconds have
; passed then the value "No Change" is returned.  If more than two seconds
; have passed the value "Don't Know" is returned.
;    There is one complecation to this algorithm.  Some programs change the
; value of the timer.  In this unfortunate case we have an invalid timer.
; This possiblity is detected by counting the number of disk operations
; which occur without any time passing.  If this count exceeds the value of
; "AccessMax" we assume the counter is invalid and always return "Don't
; Know".  The variable "AccessCount" is used to keep track of the number
; of disk operation which occur without the time changing.
;

	PUBLIC ACCESSCOUNT
AccessCount db	0			; number of times media check called

	PUBLIC TIM_DRV
TIM_DRV DB	-1			; time when last disk I/O was performed

	PUBLIC FLAGBITS
FlagBits	dw	0		; Bits to set in flag field when doing
					; a Set_Changed_DL

	PUBLIC	MEDBYT
MedByt		DB	?		; hold media byte from floppy

		EVENB
	PUBLIC WRTVERIFY
WRTVERIFY LABEL WORD

	PUBLIC RFLAG
RFLAG		DB	ROMRead 		;2 for read, 3 for write
VERIFY		DB	0			;1 if verify after write

	PUBLIC SECCNT
SECCNT		DW	0


Public HARDNUM
HARDNUM 	DB	99		;logical drive number of first hardfile

;
; Some of the older versions of the IBM rom-bios always assumed a seek would
; have to be made to read the diskette.  Consequently a large head settle
; time was always used in the I/O operations.  To get around this problem
; we need to continually adjust the head settle time.  The following
; algorithm is used:
;
;   Get the current head settle value.
;   If it is 1, then
;	set slow = 15
;   else
;	set slow = value
;   ...
;   if we are seeking and writing then
;	use slow
;   else
;	use fast
;   ...
;   restore current head settle value
;

	PUBLIC MOTORSTARTUP,SETTLECURRENT,SETTLESLOW
MotorStartup	db  ?			; value from table
SettleCurrent	db  ?			; value from table
SettleSlow	db  ?			; slow settle value

NextSpeed   DB	?			; value of speed to be used

	public	save_head_sttl
Save_head_sttl	db  ?		;used by READ_SECTOR routine


Public EOT
EOT	    DB	9

;
; pointer to Disk Parameter Table
;

		EVENB
	PUBLIC DPT
DPT	    DD	?

;
; The following two sets of variables are used to hold values for
; disk I/O operations
; Keep the next two items contiguous - see IOCTL_Block for reason

	PUBLIC CURSEC,CURHD,CURTRK,SPSAV
CURSEC	DB	0			; current sector
CURHD	DB	0			; current head
CURTRK	DW	0			; current track
SPSAV	DW	0			; save the stack pointer

;
; The following are used for IOCTL function calls
;

	PUBLIC FORMT_EOT,HDNUM,TRKNUM,GAP_PATCH 
FORMT_EOT	DB	8		    ; EOT used for format
HDNUM		DB	0		    ; Head number
TRKNUM		DW	0		    ; Track being manipulated
GAP_PATCH	DB	50h		    ; Format gap patched into DPT

;
; Disk errors returned from the IBM rom
;

Public ERRIN
ERRIN	LABEL	BYTE
	DB	80H			; no response
	DB	40H			; seek failure
	DB	10H			; bad CRC
	DB	8			; DMA overrun
	DB	6			; media change
	DB	4			; sector not found
	DB	3			; write attempt to write-protect disk
	PUBLIC LSTERR
LSTERR	DB	0			; all other errors

;
; returned error code corresponding to above errors
;

Public ERROUT
ERROUT	LABEL	BYTE
	DB	2			; no response
	DB	6			; seek failure
	DB	4			; bad CRC
	DB	4			; DMA overrun
	DB	15			; invalid media change
	DB	8			; sector not found
	DB	0			; write attempt on write-protect disk
	DB	12			; general error

	PUBLIC NUMERR
NUMERR	=	ERROUT-ERRIN


;-------------------------------------------------------------
;
; DiskSector is a 512 byte sector into which the boot sector
; is read.  It is also used as read sector for DMA check for
; hard disk.


Public DiskSector
DiskSector  db	11 dup(?)	   ; take care of 3 jump bytes plus OEM name.
	PUBLIC BPB_IN_SECTOR
BPB_In_Sector	dw  ?
	PUBLIC SECPERCLUSINSECTOR
SECPERCLUSINSECTOR	DB	?
	dw	?
	db	?
	dw	?
	dw	?
	PUBLIC MEDIABYTE
mediabyte   db	    ?
	dw	?
	dw	?
	dw	?
	dw	?
	db	?
	db	512-($-DiskSector) dup (?)

;---------------------------------------------------------------------
;
;	The "BDS"'s contain information for each drive in the system.
;  There is one BDS for each logical drvie in the system.  The BDS's
;  are all linked together in a chain.	The BDS contain various values
;  important to the disk drive. Various values are updated whenever actions
;  are performed.  For example if a drive is read from the last time
;  accessed fields are updated to the current time.
;	Initial values:
;    *	Sectors/Alloc. unit in BPB initially set to -1 to signify that
;	the BPB has not been filled.
;    *	Link is set to -1 to signify end of list.
;    *	number of cylinders in MaxParms initialized to -1 to indicate
;	that the parameters have not been set.
;
;  Start_BDS contains a pointer to the first BDS.  It is through this
;  pointer that routines find particular BDS (see SetDrive to see how
;  this is done).
;

	EVENB
BDS1	LABEL	WORD
	DD	BDS2			;LINK TO NEXT STRUCTURE
	DB	0			;ROM DISK INT Drive Number
	DB	0			;Logical Drive Letter
	PUBLIC	FDRIVE1 
FDRIVE1 DW	512			;Physical sector size in bytes
	DB	-1			;Sectors/allocation unit
	DW	1			;Reserved sectors for DOS
	DB	2			;No. allocation tables
	DW	64			;Number directory entries
	DW	9*40			;Number sectors (at 512 bytes ea.)
	DB	00000000B		;Media descriptor, initially 00H.
	DW	2			;Number of FAT sectors
	DW	9			;Sector limit
	DW	1			;Head limit
	DW	0			;Hidden sector count
	DB	0			; TRUE => Large fats
OPCNT1	DW	0			;Open Ref. Count
VOLID1	DB	"NO NAME    ",0         ;Volume ID for this disk
	DB	3			;Form Factor
FLAGS1	DW	0020H			;Various Flags
;	DB	9 dup (0)		;Reserved for future use
	dw	40			; number of cylinders
RecBPB1 DW	512			;Physical sector size in bytes
	DB	1			;Sectors/allocation unit
	DW	1			;Reserved sectors for DOS
	DB	2			;No. allocation tables
	DW	0E0H			;NUMBER DIRECTORY ENTRIES
	DW	9*40			;Number sectors (at 512 bytes ea.)
	DB	0F0h			;Media descriptor, initially 00H.
	DW	2			;Number of FAT sectors
	DW	9			;Sector limit
	DW	2			;HEAD LIMIT
	DW	0			;Hidden sector count
	DB	12 DUP (?)
TRACK1	DB	-1			;Last track accessed on this drive
TIM_LO1 DW	-1			;Keep these two contiguous (?)
TIM_HI1 DW	-1

	EVENB
BDS2	LABEL	WORD
	DD	BDS3			;LINK TO NEXT STRUCTURE
	DB	0			;INT 13 DRIVE NUMBER
	DB	0			;Logical Drive Letter
	PUBLIC	FDRIVE2 
FDRIVE2 DW	512			;Physical sector size in bytes
	DB	-1			;Sectors/allocation unit
	DW	1			;Reserved sectors for DOS
	DB	2			;No. allocation tables
	DW	64			;Number directory entries
	DW	9*40			;Number sectors (at 512 bytes ea.)
	DB	00000000B		;Media descriptor, initially 00H.
	DW	2			;Number of FAT sectors
	DW	9			;Sector limit
	DW	1			;Head limit
	DW	0			;Hidden sector count
	DB	0			; TRUE => Large fats
OPCNT2	DW	0			;Open Ref. Count
VOLID2	DB	"NO NAME    ",0         ;Volume ID for this disk
	DB	3			;Form Factor
FLAGS2	DW	0020H			;Various Flags
;	DB	9 dup (0)		;Reserved for future use
	dw	40			; number of cylinders
RecBPB2 DW	512			;Physical sector size in bytes
	DB	1			;Sectors/allocation unit
	DW	1			;Reserved sectors for DOS
	DB	2			;No. allocation tables
	DW	0E0H			;NUMBER DIRECTORY ENTRIES
	DW	9*40			;Number sectors (at 512 bytes ea.)
	DB	0F0h			;Media descriptor, initially 00H.
	DW	2			;Number of FAT sectors
	DW	9			;Sector limit
	DW	2			;HEAD LIMIT
	DW	0			;Hidden sector count
	DB	12 DUP (?)
TRACK2	DB	-1			;Last track accessed on this drive
TIM_LO2 DW	-1			;Keep these two contiguous (?)
TIM_HI2 DW	-1

	EVENB
BDS3	LABEL	WORD
	DD	BDS4			;LINK TO NEXT STRUCTURE
	DB	0			;INT 13 DRIVE NUMBER
	DB	0			;Logical Drive Letter
	PUBLIC	FDRIVE3
FDRIVE3 DW	512			;Physical sector size in bytes
	DB	-1			;Sectors/allocation unit
	DW	1			;Reserved sectors for DOS
	DB	2			;No. allocation tables
	DW	64			;Number directory entries
	DW	9*40			;Number sectors (at 512 bytes ea.)
	DB	00000000B		;Media descriptor, initially 00H.
	DW	2			;Number of FAT sectors
	DW	9			;Sector limit
	DW	1			;Head limit
	DW	0			;Hidden sector count
	DB	0			; TRUE => Large fats
OPCNT3	DW	0			;Open Ref. Count
VOLID3	DB	"NO NAME    ",0         ;Volume ID for this disk
	DB	3			;Form Factor
FLAGS3	DW	0020H			;Various Flags
;	DB	9 dup (0)		;Reserved for future use
	dw	40			; number of cylinders
RecBPB3 DW	512			;Physical sector size in bytes
	DB	1			;Sectors/allocation unit
	DW	1			;Reserved sectors for DOS
	DB	2			;No. allocation tables
	DW	0E0H			;NUMBER DIRECTORY ENTRIES
	DW	9*40			;Number sectors (at 512 bytes ea.)
	DB	0F0h			;Media descriptor, initially 00H.
	DW	2			;Number of FAT sectors
	DW	9			;Sector limit
	DW	2			;HEAD LIMIT
	DW	0			;Hidden sector count
	DB	12 DUP (?)
TRACK3	DB	-1			;Last track accessed on this drive
TIM_LO3 DW	-1			;Keep these two contiguous (?)
TIM_HI3 DW	-1

	EVENB
BDS4	LABEL	WORD
	DW	-1			;Link to next structure
	DW	Code
	DB	0			;INT 13 DRIVE NUMBER
	DB	0			;Logical Drive Letter
	PUBLIC	FDRIVE4
FDRIVE4 DW	512			;Physical sector size in bytes
	DB	-1			;Sectors/allocation unit
	DW	1			;Reserved sectors for DOS
	DB	2			;No. allocation tables
	DW	64			;Number directory entries
	DW	9*40			;Number sectors (at 512 bytes ea.)
	DB	00000000B		;Media descriptor, initially 00H.
	DW	2			;Number of FAT sectors
	DW	9			;Sector limit
	DW	1			;Head limit
	DW	0			;Hidden sector count
	DB	0			; TRUE => Large fats
OPCNT4	DW	0			;Open Ref. Count
VOLID4	DB	"NO NAME    ",0         ;Volume ID for this disk
	DB	3			;Form Factor
FLAGS4	DW	0020H			;Various Flags
;	DB	9 dup (0)		;Reserved for future use
	dw	40			; number of cylinders
;;Rev 3.30 Modification
RECBPB4 DW	512			;BYTES PER SECTOR
	DB	1			;SECTORS/ALLOCATION UNIT
	DW	1			;RESERVED SECTORS FOR DOS
	DB	2			;NO. ALLOCATION TABLES
	DW	0E0H			;NUMBER DIRECTORY ENTRIES
	DW	9*40			;NUMBER SECTORS (AT 512 BYTES EA.)
	DB	0F0H			;MEDIA DESCRIPTOR, INITIALLY F0H.
	DW	2			;NUMBER OF FAT SECTORS
	DW	9			;SECTOR LIMIT
	DW	2			;HEAD LIMIT
	DW	0			;HIDDEN SECTOR COUNT
	DB	12 DUP (?)
;;End of Modification
TRACK4	DB	-1			;Last track accessed on this drive
TIM_LO4 DW	-1			;Keep these two contiguous (?)
TIM_HI4 DW	-1


bpbType struc
spf	db	?
spt	db	?
cdire	db	?
csec	dw	?
spa	db	?
chead	db	?
bpbType ends
	PUBLIC SM92
sm92	bpbType <3,9,70H,2*9*80,2,2>


;
; ALTAH is a single character buffer used to handle special keys.
;

	PUBLIC	ALTAH
ALTAH	DB	0			;Special key handling


;
; The following variable can be modified via IOCTL sub-function 16. In this
; way, the wait can be set to suit the speed of the particular printer being
; used. One for each printer device.
;

	PUBLIC PRINTDEV
PRINTDEV	DB	0		; Index into following array

		EVENB
	PUBLIC WAIT_COUNT
WAIT_COUNT	DW	4 dup (50h)	; Array of Retry counts for printer


;
; DAYCNT is the number of days since 1-1-80.
; Each time the clock is read it is necessary to check if another day has
; passed.  The ROM only returns the day rollover once so if it is missed
; the time will be off by a day.
;

		EVENB
Public DAYCNT
DAYCNT	DW	0


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
Public NumBuf
NumBuf	DB	5 dup (?)
Public Digits
Digits	DB	"0123456789ABCDEF"
Public fTestBits
FTESTBITS   DW	    fTestDISK
endif


	PATHEND 001,BIO
