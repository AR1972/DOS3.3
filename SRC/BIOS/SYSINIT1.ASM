TITLE	BIOS SYSTEM INITIALIZATION

TRUE	    EQU 0FFFFh
FALSE	    EQU 0

;IBMVER	   EQU	   TRUE
;IBM	   EQU	   IBMVER
STACKSW    EQU	   TRUE 		;Include Switchable Hardware Stacks
;IBMJAPVER EQU	   FALSE		;If TRUE set KANJI true also
;MSVER	   EQU	   FALSE
;ALTVECT   EQU	   FALSE		;Switch to build ALTVECT version
;KANJI	   EQU	   FALSE

include version.inc

	IF	IBMJAPVER
NOEXEC	EQU	TRUE
	ELSE
NOEXEC	EQU	FALSE
	ENDIF

DOSSIZE EQU	0A000H

.xlist
	include smdossym.inc	; Reduced version of DOSSYM.INC   ;3.30
	INCLUDE devsym.inc
	include ioctl.inc
	include BIOSTRUC.INC						  ;3.30
.list

	IF	NOT IBMJAPVER
	EXTRN	RE_INIT:FAR
	ENDIF

;---------------------------------------				  ;3.30
;Equates for Main stack and stack Initialization program		  ;3.30
	IF	STACKSW 						  ;3.30
cr			equ	0dh					  ;3.30
lf			equ	0ah					  ;3.30
									  ;3.30
EntrySize		equ	8					  ;3.30
									  ;3.30
MinCount		equ	8					  ;3.30
DefaultCount		equ	9					  ;3.30
MaxCount		equ	64					  ;3.30
									  ;3.30
MinSize 		equ	32					  ;3.30
DefaultSize		equ	128					  ;3.30
MaxSize 		equ	512					  ;3.30
									  ;3.30
AllocByte		equ	es:byte ptr [bp+0]			  ;3.30
IntLevel		equ	es:byte ptr [bp+1]			  ;3.30
SavedSP 		equ	es:word ptr [bp+2]			  ;3.30
SavedSS 		equ	es:word ptr [bp+4]			  ;3.30
NewSP			equ	es:word ptr [bp+6]			  ;3.30
Free			equ	0					  ;3.30
allocated		equ	1					  ;3.30
overflowed		equ	2					  ;3.30
clobbered		equ	3					  ;3.30
									  ;3.30
									  ;3.30
;External variables in BIOS for INT19h handling rouitne.  10/23/86	  ;3.30
									  ;3.30
CODE segment public 'code'                                                ;3.30
	EXTRN	Int19sem:byte						  ;3.30
									  ;3.30
	IRP	AA,<02,08,09,0A,0B,0C,0D,0E,70,72,73,74,76,77>		  ;3.30
		EXTRN Int19OLD&AA:dword 				  ;3.30
	ENDM								  ;3.30
CODE ends								  ;3.30
	ENDIF								  ;3.30
;---------------------------------------				  ;3.30
									  ;3.30
									  ;3.30
SYSINITSEG	SEGMENT PUBLIC 'SYSTEM_INIT'

ASSUME	CS:SYSINITSEG,DS:NOTHING,ES:NOTHING,SS:NOTHING

									  ;3.30
	EXTRN	BADCOM:BYTE						  ;3.30
	EXTRN	SYSSIZE:BYTE						  ;3.30
	EXTRN	CONDEV:BYTE,AUXDEV:BYTE,PRNDEV:BYTE,COMMND:BYTE 	  ;3.30
	extrn	DeviceParameters:byte					  ;3.30
									  ;3.30
	EXTRN	INT24:NEAR,MEM_ERR:NEAR 				  ;3.30
	EXTRN	DOCONF:NEAR						  ;3.30

	PUBLIC	CURRENT_DOS_LOCATION
	PUBLIC	FINAL_DOS_LOCATION
	PUBLIC	DEVICE_LIST
	PUBLIC	SYSI_COUNTRY						  ;3.30
	PUBLIC	MEMORY_SIZE
	PUBLIC	DEFAULT_DRIVE
	PUBLIC	BUFFERS
	PUBLIC	FILES
	PUBLIC	NUM_CDS 						  ;3.30
	PUBLIC	SYSINIT
	PUBLIC	CNTRYFILEHANDLE 					  ;3.30
	PUBLIC	COMMAND_LINE						  ;3.30

	IF	STACKSW
; Internal Stack Information
	PUBLIC	STACK_COUNT
	PUBLIC	STACK_SIZE
	PUBLIC	STACK_ADDR
	ENDIF

	PUBLIC dosinfo,entry_point
	PUBLIC fcbs,keep
	PUBLIC confbot,alloclim
	PUBLIC zero,sepchr,STALL
	PUBLIC count,chrptr
	PUBLIC bufptr,memlo,prmblk,memhi
	PUBLIC ldoff,area,PACKET,UNITCOUNT
	PUBLIC BREAK_ADDR,BPB_ADDR,drivenumber

SYSINIT$:								  ;3.30
	IF	STACKSW 						  ;3.30
	  include MSSTACK.INC		;Main stack program and data defin;3.30 itions
	  include STKMES.INC		;Fatal stack error message	  ;3.30
	    public Endstackcode 					  ;3.30
Endstackcode	label byte						  ;3.30
	ENDIF								  ;3.30

;
SYSINIT:
	JMP	GOINIT

DOSINFO 		LABEL	DWORD
			DW	0000
CURRENT_DOS_LOCATION	DW	0000

MSDOS			LABEL	DWORD
ENTRY_POINT		LABEL	DWORD
			DW	0000
FINAL_DOS_LOCATION	DW	0000
DEVICE_LIST		DD	00000000

SYSI_Country		LABEL	DWORD		; 5/29/86 Pointer to  ;3.30
			DW	0000		;country table in DOS	  ;3.30
			DW	0000					  ;3.30

	IF	STACKSW
;
; Internal Stack Parameters

STACK_COUNT		DW	DefaultCount
STACK_SIZE		DW	DefaultSize
STACK_ADDR		DD	00000000
	ENDIF

; various default values

MEMORY_SIZE		DW	0001
DEFAULT_DRIVE		DB	00
BUFFERS 		DW	-1	; initialized during buffer allocation
;BUFFERS		 DW	 2	 ; two buffers
FILES			DB	8	; enough files for pipe
FCBS			DB	4	; performance for recycling
Keep			DB	0	; keep original set
NUM_CDS 		DB	5	; 5 net drives
CONFBOT 		DW	?
ALLOCLIM		DW	?
FOOSTRNG		DB	"A:\",0
COMMAND_LINE		DB	2,0,"P" ;Default Command.com Args
			DB	29 DUP (0)
ZERO			DB	0
SepChr			DB	0

									  ;3.30
Sys_Model_Byte		db	0FFh	;model byte used in SYSINIT	  ;3.30
Sys_Scnd_Model_Byte	db	0	;secondary model byte used in SYSI;3.30 NIT
									  ;3.30
	IF	NOT NOEXEC
COMEXE	EXEC0 <0,COMMAND_LINE,DEFAULT_DRIVE,ZERO>
	ENDIF

COUNT	DW	0000
CHRPTR	DW	0000
CntryFilehandle DW 0000 						  ;3.30

BUFPTR	LABEL	DWORD			;LEAVE THIS STUFF IN ORDER!
MEMLO	DW	0
PRMBLK	LABEL	WORD
MEMHI	DW	0
LDOFF	DW	0
AREA	DW	0

PACKET			DB	22
			DB	0
			DB	0	;INITIALIZE CODE
			DW	0
			DB	8 DUP (?)
UNITCOUNT		DB	0
BREAK_ADDR		DD	0
BPB_ADDR		DD	0
DriveNumber		DB	0

TempStack		DB	80h DUP (?)

GOINIT:
; before doing anything else, let's set the model byte                ;3.30
	mov	ah,0c0h 		;get system configuration     ;3.30*
	int	15h			; *			      ;3.30*
	jc	No_ROM_Config						  ;3.30
	cmp	ah, 0			; double check			  ;3.30
	jne	No_ROM_Config						  ;3.30
	mov	al, ES:[BX.bios_SD_modelbyte]				  ;3.30
	mov	cs:[Sys_Model_Byte], al 				  ;3.30
	mov	al, ES:[BX.bios_SD_scnd_modelbyte]			  ;3.30
	mov	cs:[Sys_Scnd_Model_Byte], al				  ;3.30
	jmp	short Move_Myself					  ;3.30
No_ROM_Config:				; Old ROM			  ;3.30
	mov	ax, 0f000h						  ;3.30
	mov	ds, ax							  ;3.30
	mov	al, byte ptr ds:[0fffeh]				  ;3.30
	mov	cs:[Sys_Model_Byte], al ;set the model byte.		  ;3.30
									  ;3.30
Move_Myself:								  ;3.30
	CLD				; Set up move
	XOR	SI,SI
	MOV	DI,SI

	IF	MSVER
	MOV	CX,cs:[MEMORY_SIZE]					  ;3.30
	CMP	CX,1			; 1 means do scan
	JNZ	NOSCAN
	MOV	CX,2048 		;START SCANNING AT 32K BOUNDARY
	XOR	BX,BX

MEMSCAN:INC	CX
	JZ	SETEND
	MOV	DS,CX
	MOV	AL,[BX]
	NOT	AL
	MOV	[BX],AL
	CMP	AL,[BX]
	NOT	AL
	MOV	[BX],AL
	JZ	MEMSCAN
SETEND:
	MOV	cs:[MEMORY_SIZE],CX
	ENDIF

	IF	IBMVER OR IBMJAPVER
	MOV	CX,cs:[MEMORY_SIZE]
	ENDIF

NOSCAN: 				; CX is mem size in para
	MOV	AX,CS
	MOV	DS,AX
ASSUME	DS:SYSINITSEG

	MOV	AX,OFFSET SYSSIZE
	Call	ParaRound
	SUB	CX,AX			;Compute new sysinit location
	MOV	ES,CX
	MOV	CX,OFFSET SYSSIZE + 1
	SHR	CX,1			;Divide by 2 to get words
	REP	MOVSW			;RELOCATE SYSINIT

	ASSUME	ES:SYSINITSEG

	PUSH	ES
	MOV	AX,OFFSET SYSIN
	PUSH	AX

AAA_DUMMY	PROC	FAR						  ;3.30
	RET
AAA_DUMMY	ENDP							  ;3.30
;
;	MOVE THE DOS TO ITS PROPER LOCATION
;
SYSIN:

	ASSUME	DS:NOTHING,ES:SYSINITSEG,SS:NOTHING

	MOV	AX,[CURRENT_DOS_LOCATION]   ; Where it is (set by BIOS)   ;3.30
	MOV	DS,AX
	MOV	AX,[FINAL_DOS_LOCATION]     ; Where it is going (set by BI;3.30 OS)
	MOV	ES,AX

	ASSUME	ES:NOTHING

	XOR	SI,SI
	MOV	DI,SI

	MOV	CX,DOSSIZE/2
	REP	MOVSW

	LDS	SI,[DEVICE_LIST]	; Set for call to DOSINIT
	MOV	DX,[MEMORY_SIZE]	; Set for call to DOSINIT

	CLI
	MOV	AX,CS
	MOV	SS,AX
	MOV	SP,OFFSET LOCSTACK	; Set stack

	ASSUME	SS:SYSINITSEG

	IF	NOT ALTVECT
	STI				; Leave INTs disabled for ALTVECT
	ENDIF
LOCSTACK LABEL BYTE

	CALL	MSDOS			; Call DOSINIT
	mov	ax, word ptr es:[di.SYSI_InitVars] ; 5/29/86	  ;3.30
	mov	word ptr [dosinfo], ax					  ;3.30
	mov	ax, word ptr es:[di.SYSI_InitVars+2]			  ;3.30
	mov	word ptr [dosinfo+2],ax ;set the sysvar pointer 	  ;3.30
									  ;3.30
	mov	ax, word ptr es:[di.SYSI_Country_Tab]			  ;3.30
	mov	word ptr [SYSI_Country],ax				  ;3.30
	mov	ax, word ptr es:[di.SYSI_Country_Tab+2] 		  ;3.30
	mov	word ptr [SYSI_Country+2],ax	;set the SYSI_Country poin;3.30 ter
									  ;3.30
	les	di, dosinfo		;es:di -> dosinfo		  ;3.30

	MOV	AL,ES:[DI.SYSI_NUMIO]
	MOV	DriveNumber,AL		; Save start of installable block drvs

	MOV	AX,CS
	SUB	AX,11H			; room for header we will copy shortly
	MOV	[CONFBOT],AX		; Temp "unsafe" location

	PUSH	DS			; Save as input to RE_INIT
	PUSH	CS
	POP	DS
ASSUME	DS:SYSINITSEG
	CALL	TEMPCDS 		; Set up CDSs so RE_INIT and SYSINIT
					;   can make DISK system calls

	POP	DS			; Recover DS input to RE_INIT
ASSUME	DS:NOTHING

	IF	NOT IBMJAPVER
	CALL	RE_INIT 		; Re-call the BIOS
	ENDIF

	STI				; INTs OK
	CLD				; MAKE SURE
; DOSINIT has set up a default "process" (PHP) at DS:0. We will move it out
; of the way by putting it just below SYSINIT at end of memory.
	MOV	BX,CS
	SUB	BX,10H
	MOV	ES,BX
	XOR	SI,SI
	MOV	DI,SI
	MOV	CX,80H
	REP	MOVSW
	MOV	WORD PTR ES:[PDB_JFN_Pointer + 2],ES	; Relocate
	MOV	AH,SET_CURRENT_PDB
	INT	21H			; Tell DOS we moved it
	PUSH	DS
	PUSH	CS
	POP	DS
ASSUME	DS:SYSINITSEG
	MOV	DX,OFFSET INT24 	;SET UP INT 24 HANDLER
	MOV	AX,(SET_INTERRUPT_VECTOR SHL 8) OR 24H
	INT	21H

	MOV	BX,0FFFFH
	MOV	AH,ALLOC
	INT	21H			;FIRST TIME FAILS
	MOV	AH,ALLOC
	INT	21H			;SECOND TIME GETS IT
	MOV	[AREA],AX
	MOV	[MEMHI],AX		; MEMHI:MEMLO now points to
					; start of free memory
	IF	ALTVECT
	MOV	DX,OFFSET BOOTMES
	invoke	PRINT			;Print message DOSINIT couldn't
	ENDIF

	POP	DS
ASSUME	DS:NOTHING

	MOV	DL,[DEFAULT_DRIVE]
	OR	DL,DL
	JZ	NODRVSET		; BIOS didn't say
	DEC	DL			;A = 0
	MOV	AH,SET_DEFAULT_DRIVE
	INT	21H			;SELECT THE DISK
NODRVSET:

	CALL	DOCONF			;DO THE CONFIG STUFF
	CALL	ENDFILE 		;Set the system according to Confi;3.30 g.sys file info.

	IF	NOEXEC
	MOV	BP,DS			;SAVE COMMAND.COM SEGMENT
	PUSH	DS
	POP	ES
	MOV	BX,CS
	SUB	BX,10H			; Point to current PHP
	MOV	DS,BX
	XOR	SI,SI
	MOV	DI,SI
	MOV	CX,80H
	REP	MOVSW			; Copy it to new location for shell
	MOV	WORD PTR ES:[PDB_JFN_Pointer + 2],ES	; Relocate
	MOV	BX,ES
	MOV	AH,SET_CURRENT_PDB
	INT	21H			; Tell DOS we moved it
	MOV	ES:[PDB_PARENT_PID],ES	;WE ARE THE ROOT
	ENDIF

; We must now close all handles and reopen STDIN,STDOUT,STDERR in order
; to get a possibly NEW device driver for CON. STDAUX and STDPRN must
; also be openned.
	PUSH	CS
	POP	DS
ASSUME	DS:SYSINITSEG
	MOV	AL,[FILES]
	XOR	AH,AH			; DO NOT USE CBW INSTRUCTION!!!!!
					;  IT DOES SIGN EXTEND.
	MOV	CX,AX
	XOR	BX,BX			;Close standard input
	MOV	AH,CLOSE
	INT	21H
	MOV	BX,2
RCCLLOOP:				;Close everybody but standard output
	MOV	AH,CLOSE		; Need output so we can print message
	INT	21H			; in case we can't get new one open.
	INC	BX
	LOOP	RCCLLOOP

	MOV	DX,OFFSET CONDEV
	MOV	AL,2
	MOV	AH,OPEN 		;OPEN CON FOR READ/WRITE
	STC				; Set for possible INT 24
	INT	21H
	JNC	GOAUX
	INVOKE	BADFIL
	JMP	SHORT GOAUX2

GOAUX:	PUSH	AX
	MOV	BX,1			;close standard output
	MOV	AH,CLOSE
	INT	21H
	POP	AX

	MOV	BX,AX			;New device handle
	MOV	AH,XDUP
	INT	21H			;Dup to 1, STDOUT
	MOV	AH,XDUP
	INT	21H			;Dup to 2, STDERR

GOAUX2: MOV	DX,OFFSET AUXDEV
	MOV	AL,2			;READ/WRITE ACCESS
	INVOKE	OPEN_DEV

	MOV	DX,OFFSET PRNDEV
	MOV	AL,1			;WRITE ONLY
	INVOKE	OPEN_DEV

;Global Rearm command for Shared Interrupt devices attached in the system;
;Shared interrupt attachment has some problem when it issues interrupt
;during a warm reboot.	Once the interrupt is presented by the attachment,
;no further interrupts on that level will be presented until a global rearm
;is issued. BIOS will issue a global rearm after each device driver is loaded.
;To issue a global rearm:	;For PC1, XT, Palace
;			  OUT 02F2h, XX  ; Interrupt level 2
;			  OUT 02F3h, XX  ; Interrupt level 3
;			  OUT 02F4h, XX  ; Interrupt level 4
;			  OUT 02F5h, XX  ; Interrupt level 5
;			  OUT 02F6h, XX  ; Interrupt level 6
;			  OUT 02F7h, XX  ; Interrupt level 7
;
;				;For PC AT, in addition to the above commands,
;				;need to handle the secondary interrupt handler
;			  OUT 06F2h, XX  ; Interrupt level 10
;			  OUT 06F3h, XX  ; Interrupt level 11
;			  OUT 06F4h, XX  ; Interrupt level 12
;			  OUT 06F6h, XX  ; Interrupt level 14
;			  OUT 06F7h, XX  ; Interrupt level 15
;
;				;For All others machine
;			  None.
; where XX stands for any value.

	PUSH	AX			;Save register
	PUSH	BX			;Save register
	PUSH	DX			;Save register
	PUSH	ES			;Save register

	MOV	AL,0FFH 		;Set up registers for global rearm
	MOV	DX,02F2H		;
	OUT	DX,AL			;OUT 02F2H,0FFH
	INC	DX			;
	OUT	DX,AL			;OUT 02F3H,0FFH
	INC	DX			;
	OUT	DX,AL			;OUT 02F4H,0FFH
	INC	DX			;
	OUT	DX,AL			;OUT 02F5H,0FFH
	INC	DX			;
	OUT	DX,AL			;OUT 02F6H,0FFH
	INC	DX			;
	OUT	DX,AL			;OUT 02F7H,0FFH

	MOV	AX,0F000H		;Get machine type
	MOV	ES,AX			;
	CMP	BYTE PTR ES:[0FFFEH],0FCH ;Q: Is it an AT type machine?
	JNE	REARMDONE		;  N: Skip next rearm
	MOV	AH,0C0H 		;Get system configuration
	INT	15H			;Q: Is it an old ROM?
	JC	REARMDONE		;  Y: Skip next rearm
	TEST	ES:[BX.BIOS_SD_FEATUREBYTE1],SCNDINTCONTROLLER ; Q: Present?
	JE	REARMDONE		;  N: Skip next rearm

	MOV	AL,0FFH 		;Set up registers for global rearm
	MOV	DX,06F2H		;
	OUT	DX,AL			;OUT 06F2H,0FFH
	INC	DX			;
	OUT	DX,AL			;OUT 06F3H,0FFH
	INC	DX			;
	OUT	DX,AL			;OUT 06F4H,0FFH
	INC	DX			;
	INC	DX			;
	OUT	DX,AL			;OUT 02F6H,0FFH
	INC	DX			;
	OUT	DX,AL			;OUT 02F7H,0FFH

REARMDONE:
	POP	ES			;Restore register
	POP	DX			;Restore register
	POP	BX			;Restore register
	POP	AX			;Restore register

;Global Rearm end *******************

;
; SET UP THE PARAMETERS FOR COMMAND
;
GOSET:
	MOV	SI,OFFSET COMMAND_LINE+1

	IF	NOEXEC
	MOV	DI,81H
	ELSE
	PUSH	DS
	POP	ES
	MOV	DI,SI
	ENDIF

	MOV	CL,-1
COMTRANLP:				;FIND LENGTH OF COMMAND LINE
	INC	CL
	LODSB
	STOSB				;COPY COMMAND LINE IN
	OR	AL,AL
	JNZ	COMTRANLP
	DEC	DI
	MOV	AL,0DH			; CR terminate
	STOSB

	IF	NOEXEC
	MOV	ES:[80H],CL		; Set up header
	MOV	AL,[DEFAULT_DRIVE]
	MOV	ES:[5CH],AL
	ELSE
	MOV	[COMMAND_LINE],CL	;Count
	ENDIF

	MOV	DX,OFFSET COMMND	;NOW POINTING TO FILE DESCRIPTION

	IF	NOEXEC
	MOV	ES,BP			;SET LOAD ADDRESS
	MOV	BX,100H
	CALL	LDFIL			;READ IN COMMAND
	JC	COMERR
	MOV	DS,BP
	MOV	DX,80H
	MOV	AH,SET_DMA		;SET DISK TRANFER ADDRESS
	INT	21H
	CLI
	MOV	SS,BP
	MOV	SP,DX
	STI
	XOR	AX,AX			;PUSH A WORD OF ZEROS
	PUSH	AX
	PUSH	BP			;SET HIGH PART OF JUMP ADDRESS
	MOV	AX,100H
	PUSH	AX			;SET LOW PART OF JUMP ADDRESS
CCC	PROC	FAR
	RET				;CRANK UP COMMAND!
CCC	ENDP

	ELSE
; We are going to open the command interpreter and size it as is done in
; LDFIL.  The reason we must do this is that SYSINIT is in free memory.  If
; there is not enough room for the command interpreter, EXEC will probably
; overlay our stack and code so when it returns with an error SYSINIT won't be
; here to catch it.  This code is not perfect (for instance .EXE command
; interpreters are possible) because it does its sizing based on the
; assumption that the file being loaded is a .COM file.  It is close enough to
; correctness to be usable.

	PUSH	DX			; Save pointer to name

; First, find out where the command interpreter is going to go.
	MOV	BX,0FFFFH
	MOV	AH,ALLOC
	INT	21H			;Get biggest piece
	MOV	AH,ALLOC
	INT	21H			;SECOND TIME GETS IT
	JC	MEMERRJX		; Oooops
	MOV	ES,AX
	MOV	AH,DEALLOC
	INT	21H			; Give it right back
	MOV	BP,BX
; ES:0 points to Block, and BP is the size of the block
;   in para.

; We will now adjust the size in BP DOWN by the size of SYSINIT. We
;   need to do this because EXEC might get upset if some of the EXEC
;   data in SYSINIT is overlayed during the EXEC.
	MOV	BX,[MEMORY_SIZE]
	MOV	AX,CS
	SUB	BX,AX			; BX is size of SYSINIT in Para
	ADD	BX,11H			; Add the SYSINIT PHP
	SUB	BP,BX			; BAIS down
	JC	MEMERRJX		; No Way.

	MOV	AX,(OPEN SHL 8) 	;OPEN THE FILE being EXECED
	STC				;IN CASE OF INT 24
	INT	21H
	JC	COMERR			; Ooops
	MOV	BX,AX			;Handle in BX
	XOR	CX,CX
	XOR	DX,DX
	MOV	AX,(LSEEK SHL 8) OR 2
	STC				;IN CASE OF INT 24
	INT	21H			; Get file size in DX:AX
	JC	COMERR
    ; Convert size in DX:AX to para in AX
	ADD	AX,15			; Round up size for conversion to para
	ADC	DX,0
	MOV	CL,4
	SHR	AX,CL
	MOV	CL,12
	SHL	DX,CL			; Low nibble of DX to high nibble
	OR	AX,DX			; AX is now # of para for file
	ADD	AX,10H			; 100H byte PHP
	CMP	AX,BP			; Will it fit?
	JB	OKLD			; Jump if yes.
MEMERRJX:
	JMP	MEM_ERR

OKLD:
	MOV	AH,CLOSE
	INT	21H			; Close file
	POP	DX			; Recover pointer to name
	PUSH	CS
	POP	ES
	ASSUME	ES:SYSINITSEG
	MOV	BX,OFFSET COMEXE	; Point to EXEC block
	MOV	WORD PTR [BX.EXEC0_COM_LINE+2],CS	; Set segments
	MOV	WORD PTR [BX.EXEC0_5C_FCB+2],CS
	MOV	WORD PTR [BX.EXEC0_6C_FCB+2],CS
	XOR	AX,AX			;Load and go
	MOV	AH,EXEC
	STC				;IN CASE OF INT 24
	INT	21H			;GO START UP COMMAND
	ENDIF
; NOTE FALL THROUGH IF EXEC RETURNS (an error)

COMERR:
	MOV	DX,OFFSET BADCOM	;WANT TO PRINT COMMAND ERROR
	INVOKE	BADFIL
STALL:	JMP	STALL

	PUBLIC	TEMPCDS 						  ;3.30
TEMPCDS:
ASSUME	DS:SYSINITSEG
	LES	DI,[DOSINFO]

	MOV	CL,BYTE PTR ES:[DI.SYSI_NUMIO]
	XOR	CH,CH
	MOV	ES:[DI.SYSI_NCDS],CL
	MOV	AL,CL
	MOV	AH,SIZE curdir_list
	MUL	AH
	call	ParaRound
	MOV	SI,[CONFBOT]
	SUB	SI,AX
	MOV	[ALLOCLIM],SI		; Can't alloc past here!
	MOV	WORD PTR ES:[DI.SYSI_CDS + 2],SI
	MOV	AX,SI
	MOV	WORD PTR ES:[DI.SYSI_CDS],0
	LDS	SI,ES:[DI.SYSI_DPB]
ASSUME	DS:NOTHING
	MOV	ES,AX
	XOR	DI,DI

FOOSET: 				; Init CDSs
	MOV	AX,WORD PTR [FOOSTRNG]
	STOSW
	MOV	AX,WORD PTR [FOOSTRNG + 2]
	STOSW
	INC	BYTE PTR [FOOSTRNG]
	XOR	AX,AX
	PUSH	CX
	MOV	CX,curdir_flags - 4
	REP	STOSB
	CMP	SI,-1
	JNZ	NORMCDS
	XOR	AX,AX
	MOV	CL,3
	REP	STOSW
	POP	CX
	JMP	SHORT FINCDS

NORMCDS:
	POP	CX
	MOV	AX,curdir_inuse
	STOSW				; curdir_flags
	MOV	AX,SI
	STOSW				; curdir_devptr
	MOV	AX,DS
	STOSW
	LDS	SI,[SI.dpb_next_dpb]
FINCDS:
	MOV	AX,-1
	STOSW				; curdir_ID
	STOSW				; curdir_ID
	STOSW				; curdir_user_word
	mov	ax,2
	stosw				; curdir_end
	LOOP	FOOSET
	MOV	BYTE PTR [FOOSTRNG],"A"
	return


;------------------------------------------------------------------------------
; Allocate FILEs
;------------------------------------------------------------------------------
ENDFILE:
; WE ARE NOW SETTING UP FINAL CDSs, BUFFERS, FILES, FCSs STRINGs etc.  We no
; longer need the space taken by The TEMP stuff below CONFBOT, so set ALLOCLIM
; to CONFBOT.
	MOV	AX,[CONFBOT]
	MOV	[ALLOCLIM],AX

	PUSH	CS
	POP	DS
	INVOKE	ROUND
	MOV	AL,[FILES]
	SUB	AL,5
	JBE	DOFCBS
	XOR	AH,AH			; DO NOT USE CBW INSTRUCTION!!!!!
					;  IT DOES SIGN EXTEND.
	MOV	BX,[MEMLO]
	MOV	DX,[MEMHI]
	LDS	DI,[DOSINFO]		;GET POINTER TO DOS DATA
	LDS	DI,[DI+SYSI_SFT]	;DS:BP POINTS TO SFT
	MOV	WORD PTR [DI+SFLINK],BX
	MOV	WORD PTR [DI+SFLINK+2],DX   ;SET POINTER TO NEW SFT
	PUSH	CS
	POP	DS
	LES	DI,DWORD PTR [MEMLO]	;POINT TO NEW SFT
	MOV	WORD PTR ES:[DI+SFLINK],-1
	MOV	ES:[DI+SFCOUNT],AX
	MOV	BL,SIZE SF_ENTRY
	MUL	BL			;AX = NUMBER OF BYTES TO CLEAR
	MOV	CX,AX
	ADD	[MEMLO],AX		;ALLOCATE MEMORY
	MOV	AX,6
	ADD	[MEMLO],AX		;REMEMBER THE HEADER TOO
	INVOKE	ROUND			; Check for mem error before the STOSB
	ADD	DI,AX
	XOR	AX,AX
	REP	STOSB			;CLEAN OUT THE STUFF

;------------------------------------------------------------------------------
; Allocate FCBs
;------------------------------------------------------------------------------
DOFCBS:
	PUSH	CS
	POP	DS
	INVOKE	ROUND
	MOV	AL,[FCBS]
	XOR	AH,AH			; DO NOT USE CBW INSTRUCTION!!!!!
					;  IT DOES SIGN EXTEND.
	MOV	BX,[MEMLO]
	MOV	DX,[MEMHI]
	LDS	DI,[DOSINFO]		;GET POINTER TO DOS DATA
	ASSUME	DS:NOTHING
	MOV	WORD PTR [DI+SYSI_FCB],BX
	MOV	WORD PTR [DI+SYSI_FCB+2],DX ;SET POINTER TO NEW Table
	MOV	BL,CS:Keep
	XOR	BH,BH
	MOV	[DI+SYSI_keep],BX
	PUSH	CS
	POP	DS
	ASSUME	DS:SYSINITSEG
	LES	DI,DWORD PTR [MEMLO]	;POINT TO NEW Table
	MOV	WORD PTR ES:[DI+SFLINK],-1
	MOV	ES:[DI+SFCOUNT],AX
	MOV	BL,SIZE SF_ENTRY
	MOV	CX,AX
	MUL	BL			;AX = NUMBER OF BYTES TO CLEAR
	ADD	[MEMLO],AX		;ALLOCATE MEMORY
	MOV	AX,size sf-2
	ADD	[MEMLO],AX		;REMEMBER THE HEADER TOO
	INVOKE	ROUND			; Check for mem error before the STOSB
	ADD	DI,AX			;Skip over header
	MOV	AL,"A"
FillLoop:
	PUSH	CX			; save count
	MOV	CX,SIZE sf_entry	; number of bytes to fill
	cld
	REP	STOSB			; filled
	MOV	WORD PTR ES:[DI-(SIZE sf_entry)+sf_ref_count],0
	MOV	WORD PTR ES:[DI-(SIZE sf_entry)+sf_position],0
	MOV	WORD PTR ES:[DI-(SIZE sf_entry)+sf_position+2],0
	POP	CX
	LOOP	FillLoop

;------------------------------------------------------------------------------
; Allocate Buffers
;------------------------------------------------------------------------------

; Search through the list of media supported and allocate 3 buffers if the
; capacity of the drive is > 360KB

	CMP	[BUFFERS], -1			; Has buffers been already set?
	je	DoDefaultBuff						  ;3.30
	jmp	DOBUFF				; the user entered the buf;3.30 fers=.
									  ;3.30
DoDefaultBuff:								  ;3.30

	MOV	[BUFFERS], 2			; Default to 2 buffers
	PUSH	AX
	PUSH	DS
	LES	BP,CS:[DOSINFO] 		; Search through the DPB's
	LES	BP,DWORD PTR ES:[BP.SYSI_DPB]	; Get first DPB

ASSUME DS:SYSINITSEG
	PUSH	CS
	POP	DS

NEXTDPB:
	; Test if the drive supports removeable media
	MOV	BL, BYTE PTR ES:[BP.DPB_DRIVE]
	INC	BL
	MOV	AX, (IOCTL SHL 8) OR 8
	INT	21H

; Ignore fixed disks
	OR	AX, AX			; AX is nonzero if disk is nonremoveable
	JNZ	NOSETBUF

; Get parameters of drive
	XOR	BX, BX
	MOV	BL, BYTE PTR ES:[BP.DPB_DRIVE]
	INC	BL
	MOV	DX, OFFSET DeviceParameters
	MOV	AX, (IOCTL SHL 8) OR GENERIC_IOCTL
	MOV	CX, (RAWIO SHL 8) OR GET_DEVICE_PARAMETERS
	INT	21H
	JC	NOSETBUF		; Get next DPB if driver doesn't support
					; Generic IOCTL

; Determine capacity of drive
; Media Capacity = #Sectors * Bytes/Sector
	MOV	BX, WORD PTR DeviceParameters.DP_BPB.BPB_TotalSectors

; To keep the magnitude of the media capacity within a word,
; scale the sector size
; (ie. 1 -> 512 bytes, 2 -> 1024 bytes, ...)
	MOV	AX, WORD PTR DeviceParameters.DP_BPB.BPB_BytesPerSector
	XOR	DX, DX
	MOV	CX, 512
	DIV	CX				; Scale sector size in factor of
						; 512 bytes

	MUL	BX				; AX = #sectors * size factor
	OR	DX, DX				; Just in case of LARGE floppies
	JNZ	SETBUF
	CMP	AX, 720 			; 720 Sectors * size factor of 1
	JBE	NOSETBUF
SETBUF:
	MOV	[BUFFERS], 3
	jmp	Chk_Memsize_for_Buffers 	; Now check the memory siz;3.30 e for default buffer count
NOSETBUF:
	CMP	WORD PTR ES:[BP.DPB_NEXT_DPB],-1
	jz	Chk_Memsize_for_Buffers 				  ;3.30
	LES	BP,ES:[BP.DPB_NEXT_DPB]
	JMP	NEXTDPB

;From DOS 3.3, the default number of buffers will be changed according to ;3.30 the
;memory size too.							  ;3.30
; Default buffers = 2							  ;3.30
; If diskette Media > 360 kb, then default buffers = 3			  ;3.30
; If memory size > 128 kb (2000H para), then default buffers = 5	  ;3.30
; If memory size > 256 kb (4000H para), then default buffers = 10	  ;3.30
; If memory size > 512 kb (8000H para), then default buffers = 15.	  ;3.30
									  ;3.30
Chk_Memsize_for_Buffers:						  ;3.30
	cmp	[memory_size], 2000h					  ;3.30
	jbe	BufSet							  ;3.30
	mov	[buffers], 5						  ;3.30
	cmp	[memory_size], 4000h					  ;3.30
	jbe	BufSet							  ;3.30
	mov	[buffers], 10						  ;3.30
	cmp	[memory_size], 8000h					  ;3.30
	jbe	BufSet							  ;3.30
	mov	[buffers], 15						  ;3.30
									  ;3.30
BUFSET:
ASSUME	DS:NOTHING
	POP	DS
	POP	AX
DOBUFF:

	INVOKE	ROUND
	DEC	[BUFFERS]		; FIRST DEC acounts for buffer already
					;    in system.
	JZ	BUF1			; All done
	PUSH	DS
	LES	DI,BUFPTR
	LDS	BX,DOSINFO
	MOV	AX,WORD PTR [BX.SYSI_BUF]   ; Link in new buffer
	MOV	WORD PTR ES:[DI.buf_link],AX
	MOV	AX,WORD PTR [BX.SYSI_BUF+2]
	MOV	WORD PTR ES:[DI.buf_link+2],AX
	MOV	WORD PTR [BX.SYSI_BUF],DI
	MOV	WORD PTR [BX.SYSI_BUF+2],ES
	MOV	WORD PTR ES:[DI.buf_ID],00FFH	;NEW BUFFER FREE
	MOV	BX,[BX.SYSI_MAXSEC]
	POP	DS
	ADD	BX,BUFINSIZ
	ADD	[MEMLO],BX
	JMP	DOBUFF

;------------------------------------------------------------------------------
; Allocate CDSs
;------------------------------------------------------------------------------
BUF1:
	INVOKE	ROUND
	LES	DI,[DOSINFO]
	MOV	CL,BYTE PTR ES:[DI.SYSI_NUMIO]
	CMP	CL,[NUM_CDS]
	JAE	GOTNCDS 		; User setting must be at least NUMIO
	MOV	CL,[NUM_CDS]
GOTNCDS:
	XOR	CH,CH
	MOV	ES:[DI.SYSI_NCDS],CL
	MOV	AX,[MEMHI]
	MOV	WORD PTR ES:[DI.SYSI_CDS + 2],AX
	MOV	AX,[MEMLO]
	MOV	WORD PTR ES:[DI.SYSI_CDS],AX
	MOV	AL,CL
	MOV	AH,SIZE curdir_list
	MUL	AH
	call	ParaRound
	ADD	[MEMHI],AX
	INVOKE	ROUND			; Check for mem error before initializing
	LDS	SI,ES:[DI.SYSI_DPB]
ASSUME	DS:NOTHING
	LES	DI,ES:[DI.SYSI_CDS]
	CALL	FOOSET

;------------------------------------------------------------------------------
; Allocate Space for Internal Stack
;------------------------------------------------------------------------------

	IF	STACKSW

	PUSH	CS							  ;3.30
	POP	DS							  ;3.30
	ASSUME	DS:SYSINITSEG						  ;3.30

	IF	IBM

;Don't install the system stack on the PCjr. Ignore STACKS=command too.   ;3.30
		CMP	[Sys_Model_Byte], 0FDh	     ; PCjr = 0FDh	  ;3.30
		JE	SkipStack					  ;3.30
	ENDIF								  ;3.30
									  ;3.30
;If the use does not entered STACKS= command, as a default, do not install;3.30
;sytem stacks for PC1, PC XT, PC Portable cases.			  ;3.30
;Otherwise, install it to the user specified value or to the default	  ;3.30
;value of 9, 128 for the rest of the system.				  ;3.30
									  ;3.30
	cmp	word ptr [stack_addr], -1	;Has the user entered "sta;3.30 cks=" command?
	je	DoInstallStack			;Then install as specified;3.30  by the user
	cmp	[Sys_Scnd_Model_Byte], 0	;PC1, XT has the secondary;3.30  model byte = 0
	jne	DoInstallStack			;Other model should have d;3.30 efault stack of 9, 128
	cmp	[Sys_Model_Byte], 0FFh		;PC1 ?			  ;3.30
	je	SkipStack						  ;3.30
	cmp	[Sys_Model_Byte], 0FEh		;PC/XT or PC Portable ?   ;3.30
	je	SkipStack						  ;3.30
									  ;3.30
DoInstallStack: 							  ;3.30
	mov	ax, [stack_count]		; Stack_count = 0?	  ;3.30
	cmp	ax, 0				;then, stack size must be ;3.30 0 too.
	jz	SkipStack			;Don't install stack.     ;3.30
; 10/21/86 Dynamic Relocation of Stack code.			  ;3.30
	call	Round				;[memhi] = Seg. for stack ;3.30 code
						;[memlo] = 0		  ;3.30
	mov	ax, [memhi]						  ;3.30
	mov	es, ax				;ES -> Seg. the stack code;3.30  is going to move.
	assume	es:nothing						  ;3.30
	push	cs							  ;3.30
	pop	ds							  ;3.30
	xor	si,si				;!!We know that Stack code;3.30  is at the beginning of SYSINIT.
	xor	di,di							  ;3.30
	mov	cx, offset Endstackcode 				  ;3.30
	mov	[memlo],cx						  ;3.30
	call	Round				;Have enough space for rel;3.30 ocation?
	rep	movsb							  ;3.30
									  ;3.30
	MOV	AX, [MEMLO]			; Set address of stacks
	MOV	word ptr [STACK_ADDR],AX
	MOV	AX, [MEMHI]
	MOV	word ptr [STACK_ADDR+2],AX

;	Space for Internal Stack = STACK_COUNT(ENTRYSIZE + STACK_SIZE)
	MOV	AX, EntrySize
	ADD	AX, [STACK_SIZE]
	MOV	CX, [STACK_COUNT]
	MUL	CX
	call	ParaRound		; Convert size to pargraphs
	ADD	[MEMHI], AX
	INVOKE	ROUND			; Check for memory error before
					; continuing
	CALL	StackInit		; Initialize hardware stack

SkipStack:
	ENDIF

	PUSH	CS
	POP	DS
	ASSUME	DS:SYSINITSEG
;------------------------------------------------------------------------------
; Allocate rest of memory to system
;------------------------------------------------------------------------------
	INVOKE	ROUND
	MOV	BX,[MEMHI]
	MOV	AX,[AREA]
	MOV	ES,AX			;CALC WHAT WE NEEDED
	SUB	BX,AX
	MOV	AH,SETBLOCK
	INT	21H			;GIVE THE REST BACK
	PUSH	ES
	MOV	AX,ES
	DEC	AX
	MOV	ES,AX			;Point to arena
	MOV	ES:[arena_owner],8	;Set impossible owner
	POP	ES

	IF	NOEXEC
	MOV	BX,0FFFFH		;ALLOCATE THE REST OF MEM FOR COMMAND
	MOV	AH,ALLOC
	INT	21H
	MOV	AH,ALLOC
	INT	21H
	MOV	DS,AX
	ENDIF

	return

Public	ParaRound
ParaRound:
	ADD	AX,15
	RCR	AX,1
	SHR	AX,1
	SHR	AX,1
	SHR	AX,1
	return

;-------------------------------------------------------------------------;3.30 -----
; 5/6/86. MSSTACK initialization routine.				  ;3.30
	IF	STACKSW 						  ;3.30
									  ;3.30
INCLUDE STKINIT.INC							  ;3.30
									  ;3.30
	ENDIF								  ;3.30
;-------------------------------------------------------------------------;3.30 -----

SYSINITSEG	ENDS
	END
