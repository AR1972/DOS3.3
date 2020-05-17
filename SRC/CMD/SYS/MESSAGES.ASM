;	SCCSID = @(#)sysmes.asm 1.4 85/10/03
   TITLE Message file for MS-DOS SYS Program

FALSE	EQU	0
TRUE	EQU	NOT FALSE

;IBMJAPVER    EQU	FALSE
;IBMVER	      EQU	TRUE
;MSVER	      EQU	FALSE
;IBMCOPYRIGHT EQU       FALSE

include version.inc

addr macro sym,name
     public name
     ifidn <name>,<>

	    dw offset dg:sym
     else

name	 dw  offset dg:sym
     endif
     endm

CODE	SEGMENT BYTE PUBLIC
CODE	ENDS

CONST	SEGMENT BYTE PUBLIC
CONST	ENDS

DATA	SEGMENT BYTE PUBLIC
DATA	ENDS

DG	GROUP	CODE,DATA,CONST


CONST	SEGMENT PUBLIC BYTE

	PUBLIC	BadVer, sysdrv, TargDrv, GetTarg_ptr

	PUBLIC	NotNetM_ptr

include messages.inc

	IF	IBMJAPVER
	Public	Baddisk_ptr
	ENDIF

;
; In order to allow SYS to work on disks that have been formatted on another
; MSDOS system, we use the following variables which can be set up accordingly
; before assembling and linking the variuos files for SYS.

;
; Name of system files to be written to the disk
; File names must be terminated with a NULL.
;
Public SourceBIOSFile,SourceDOSFile

IF IBMCOPYRIGHT
SourceBIOSFile	db	"IBMBIO.COM",0
SourceDOSFile	db	"IBMDOS.COM",0
ELSE
SourceBIOSFile	db	"IO.SYS",0
SourceDOSFile	db	"MSDOS.SYS",0
ENDIF

;
; Tables of files to search for on destination disk
; NOTES: Each entry MUST be exactly 12 bytes long, with extra fields filled with
;	 NULLs.
;	 The files should be in corresponding order in the two tables.
;	 The end-of-table is indicated by an entry of -1.
;
Public BIOSNamesTable,DOSNamesTable

IF IBMCOPYRIGHT
BIOSNamesTable	db	"IBMBIO.COM",0,0
		db	-1

DOSNamesTable	db	"IBMDOS.COM",0,0
		db	-1
ELSE
BIOSNamesTable	db	"IO.SYS",0,0,0,0,0,0
		db	-1

DOSNamesTable	db	"MSDOS.SYS",0,0,0
		db	-1
ENDIF


CONST	ENDS

	END
