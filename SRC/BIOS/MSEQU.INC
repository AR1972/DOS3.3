
; file: msequ.asm contains various equ's used in the bio.  The values
; are explained below.
;

;IBMCOPYRIGHT	EQU	0
fTOOBIG 	EQU	80h
fBIG		EQU	40h
ROMStatus	EQU	1
ROMRead 	EQU	2
ROMWrite	EQU	3
ROMVerify	EQU	4
ROMFormat	EQU	5
vid_size	EQU 12

include msbds.inc    ; various equates for bds
include version.inc


IF IBMCOPYRIGHT
SYSIZE=200H		      ;NUMBER OF PARAGRAPHS IN SYSINIT MODULE	  ;;Rev 3.30 Modification
ELSE
SYSIZE=203H
ENDIF
RSINIT=0A3H		      ; RS-232 initialization			  ;;End of Modification
LF=10			      ; line feed
CR=13			      ; carriage return
BACKSP=8		      ; backspace
BRKADR=1BH * 4		      ; 006C  1BH break vector address
TIMADR=1CH * 4		      ; 0070  1CH timer interrupt
DSKADR=1EH * 4		      ; address of ptr to disk parameters
SEC9=522H		      ; address of disk parameters
HEADSETTLE=SEC9+9	      ; address of head settle time
NORMSETTLE=15		      ; Normal head settle
SPEEDSETTLE=0		      ; Speed up settle time
INITSPOT=534H		      ; IBM wants 4 zeros here
AKPORT=20H
EOI=20H
CMDLEN	=	    0		; length of this command
UNIT	=	    1		; sub unit specifier
CMD	=	    2		; command code
STATUS	=	    3		; status
MEDIA	=	    13		; media descriptor
TRANS	=	    14		; transfer address
COUNT	=	    18		; count of blocks or characters
START	=	    20		; first block to transfer
EXTRA	=	    22		; usually a pointer to Vol Id for error 15
CHROUT	=	    29H
MAXERR	=	     5
LSTDRV	=	     504H

				; location of boot sector on startup
BootBias	=   200h

NotBusyStatus	=	10000000B	    ; not busy
AckStatus	=	01000000B	    ; acknowledge (for what?)
NoPaperStatus	=	00100000B	    ; No more paper
SelectedStatus	=	00010000B	    ; The printer said it was selected
IOErrStatus	=	00001000B	    ; Some kinda error
RESERVED	=	00000110B	    ; NOPs
TimeOutStatus	=	00000001B	    ; time out.

PATHGEN 	=	1

