TITLE	BIOS SYSTEM INITIALIZATION
TRUE	    EQU 0FFFFh
FALSE	    EQU 0

;IBMVER	   EQU	   TRUE
;IBM	   EQU	   IBMVER
STACKSW   EQU	   TRUE 		;Include Switchable Hardware Stacks
;IBMJAPVER EQU	   FALSE		;If TRUE set KANJI true also
;MSVER	   EQU	   FALSE
;ALTVECT   EQU	   FALSE		;Switch to build ALTVECT version
;KANJI	   EQU	   FALSE

INCLUDE version.inc

	IF	IBMJAPVER
NOEXEC	EQU	TRUE
	ELSE
NOEXEC	EQU	FALSE
	ENDIF

DOSSIZE EQU	0A000H

.xlist
	include smdossym.inc	; Reduced version of DOSSYM.INC	  ;3.30
	INCLUDE devsym.inc
	include ioctl.inc
	include BIOSTRUC.INC						  ;3.30
.list

	IF	NOT IBMJAPVER
	EXTRN	RE_INIT:FAR
	ENDIF

SYSINITSEG	SEGMENT PUBLIC 'SYSTEM_INIT'

ASSUME	CS:SYSINITSEG,DS:NOTHING,ES:NOTHING,SS:NOTHING

	EXTRN	BADOPM:BYTE,CRLFM:BYTE,BADCOM:BYTE,BADMEM:BYTE,BADBLOCK:BYTE
	EXTRN	BADSIZ_PRE:BYTE,BADLD_PRE:BYTE
	EXTRN	BADSIZ_POST:BYTE,BADLD_POST:BYTE
	EXTRN	BADSTACK:BYTE,BADCOUNTRYCOM:BYTE			  ;3.30
	EXTRN	SYSSIZE:BYTE,BADCOUNTRY:BYTE,INSUFMEMORY:BYTE		  ;3.30
	EXTRN	CONDEV:BYTE,AUXDEV:BYTE,PRNDEV:BYTE,COMMND:BYTE,CONFIG:BYTE
	EXTRN	Cntry_Drv:BYTE,Cntry_Root:BYTE,Cntry_Path:BYTE		  ;3.30
	EXTRN	DeviceParameters:byte					  ;3.30
	EXTRN	MEMORY_SIZE:word					  ;3.30
	EXTRN	BUFFERS:word						  ;3.30
	EXTRN	FILES:byte,NUM_CDS:byte 				  ;3.30
	EXTRN	DOSINFO:dword,ENTRY_POINT:dword 			  ;3.30
	EXTRN	FCBS:byte,KEEP:byte					  ;3.30
	EXTRN	CONFBOT:word,ALLOCLIM:word,COMMAND_LINE:byte		  ;3.30
	EXTRN	ZERO:byte,SEPCHR:byte					  ;3.30
	EXTRN	COUNT:word,CHRPTR:word,CNTRYFILEHANDLE:word		  ;3.30
	EXTRN	MEMLO:word,MEMHI:word,PRMBLK:word,LDOFF:word		  ;3.30
	EXTRN	PACKET:byte,UNITCOUNT:byte,BREAK_ADDR:dword		  ;3.30
	EXTRN	BPB_ADDR:dword,DRIVENUMBER:byte,SYSI_COUNTRY:dword	  ;3.30
									  ;3.30
	EXTRN	MEM_ERR:NEAR,SetDOSCountryInfo:NEAR			  ;3.30
	EXTRN	PARAROUND:NEAR,TEMPCDS:NEAR				  ;3.30
	EXTRN	Set_Country_Path:NEAR,Move_ASCIIZ:NEAR,DELIM:NEAR	  ;3.30
	EXTRN	BADFIL:NEAR,ROUND:NEAR					  ;3.30

	IF	STACKSW
;
; Internal Stack Parameters
EntrySize		equ	8

MinCount		equ	8
DefaultCount		equ	9
MaxCount		equ	64

MinSize 		equ	32
DefaultSize		equ	128
MaxSize 		equ	512

	extrn  stack_count:word 					  ;3.30
	extrn  stack_size:word						  ;3.30
	extrn  stack_addr:dword 					  ;3.30

	ENDIF

	PUBLIC DOCONF							  ;3.30
	PUBLIC GETCHR							  ;3.30

;*************************************************************************;3.30
;Take care of Config.sys file.						  ;3.30

DOCONF:
	PUSH	CS
	POP	DS

	ASSUME	DS:SYSINITSEG

	MOV	AX,(CHAR_OPER SHL 8)	;GET SWITCH CHARACTER
	INT	21H
	MOV	[COMMAND_LINE+1],DL	; Set in default command line

	MOV	DX,OFFSET CONFIG	;NOW POINTING TO FILE DESCRIPTION
	MOV	AX,OPEN SHL 8		;OPEN FILE "CONFIG.SYS"
	STC				;IN CASE OF INT 24
	INT	21H			;FUNCTION REQUEST
	JC	ENDCONF 		;Wasn't there, or couldn't open   ;3.30
	JMP	NOPROB			;PROBLEM WITH OPEN

ENDCONF:								  ;3.30
	return								  ;3.30


BADOP:	MOV	DX,OFFSET BADOPM	;WANT TO PRINT COMMAND ERROR
	invoke	PRINT
	JMP	COFF

NOPROB: 				;GET FILE SIZE (NOTE < 64K!!)
	MOV	BX,AX
	XOR	CX,CX
	XOR	DX,DX
	MOV	AX,(LSEEK SHL 8) OR 2
	INT	21H
	MOV	[COUNT],AX
	XOR	DX,DX
	MOV	AX,LSEEK SHL 8		;Reset pointer to beginning of file
	INT	21H
	MOV	DX,CS
	MOV	AX,[COUNT]
	call	ParaRound
	SUB	DX,AX
	SUB	DX,11H			;ROOM FOR HEADER
	MOV	[CONFBOT],DX		; Config starts here
	CALL	TEMPCDS 		; Finally get CDS to "safe" location
ASSUME	DS:NOTHING,ES:NOTHING

	MOV	DX,[CONFBOT]
	MOV	DS,DX
	MOV	ES,DX
	XOR	DX,DX
	MOV	CX,[COUNT]
	MOV	AH,READ
	STC				;IN CASE OF INT 24
	INT	21H			;Function request
	PUSHF
;
; Find the EOF mark in the file.  If present, then trim length.
;
	SaveReg <AX,DI,CX>
	MOV	AL,1Ah			; eof mark
	MOV	DI,DX			; point ro buffer
	JCXZ	PutEOL			; no chars
	REPNZ	SCASB			; find end
	JNZ	PutEOL			; none found and count exahusted
;
; We found a 1A.  Back up
;
	DEC	DI			; backup past 1A
;
;  Just for the halibut, stick in an extra EOL
;
PutEOL:
	MOV	AL,13
	STOSB				; CR
	MOV	AL,10
	STOSB				; LF
	SUB	DI,DX			; difference moved
	MOV	Count,DI		; new count
;
; Restore registers
;
	RestoreReg  <CX,DI,AX>

	PUSH	CS
	POP	DS
ASSUME	DS:SYSINITSEG
	PUSH	AX
	MOV	AH,CLOSE
	INT	21H
	POP	AX
	POPF
	JC	CONFERR 		;IF NOT WE'VE GOT A PROBLEM
	CMP	CX,AX
	JZ	GETCOM			;COULDN'T READ THE FILE
CONFERR:
	MOV	DX,OFFSET CONFIG	;WANT TO PRINT CONFIG ERROR
	CALL	BADFIL
ENDCONV:JMP	ENDCONF 						  ;3.30

GETCOM:
	invoke	ORGANIZE		;ORGANIZE THE FILE
	CALL	GETCHR

CONFLP: JC	ENDCONV 						  ;3.30
	MOV	AH,AL
	CALL	GETCHR
	JNC	TryB
	JMP	BADOP

COFF:	PUSH	CS
	POP	DS
	invoke	NEWLINE
	JMP	CONFLP

;------------------------------------------------------------------------------
; Buffer command
;------------------------------------------------------------------------------
TryB:	CMP	AH,'B'                  ;BUFFER COMMAND?
	JNZ	TRYC
	invoke	GETNUM
	JZ	TryBBad 		; Gotta have at least one
	CMP	AX,100			; check for max number
	JB	SaveBuf
TryBBad:JMP	BadOp
SaveBuf:
	MOV	[BUFFERS],AX
CoffJ1: JMP	COFF

;------------------------------------------------------------------------------
; Break command
;------------------------------------------------------------------------------
TryC:	CMP	AH,'C'
	JZ	GOTC
	JMP	TRYD
GOTC:
	CMP	AL,'O'                  ;FIRST LETTER OF "ON" or "OFF"
	JNZ	TryCBad
	CALL	GETCHR
	JC	TryCBad
	CMP	AL,'N'                  ;SECOND LETTER OF "ON"
	JNZ	TryCoff
	MOV	AH,SET_CTRL_C_TRAPPING	;TURN ON CONTROL-C CHECK
	MOV	AL,1
	MOV	DL,AL
	INT	21H
CoffJ2: JMP	Coff
TryCOff:CMP	AL,'F'
	JNZ	TryCBad 		; Check for "OFF"
	CALL	GetChr
	JC	TryCBad
	CMP	AL,'F'
	JZ	COffJ2
TryCBad:JMP	BadOp

;------------------------------------------------------------------------------
; Device command
;------------------------------------------------------------------------------
TRYD:	CMP	AH,'D'
	JZ	GOTD
	JMP	TRYQ
GOTD:	MOV	BX,CS
	MOV	DS,BX

	MOV	WORD PTR [BPB_ADDR],SI
	MOV	WORD PTR [BPB_ADDR+2],ES

	CALL	ROUND
	XOR	AX,AX
	MOV	WORD PTR [ENTRY_POINT],AX
	MOV	AX,[MEMHI]
	MOV	WORD PTR [ENTRY_POINT+2],AX ;SET ENTRY POINT

	IF	NOT NOEXEC
	MOV	[LDOFF],AX		;SET LOAD OFFSET
	ENDIF

	PUSH	ES
	POP	DS
ASSUME	DS:NOTHING
	MOV	DX,SI			;DS:DX POINTS TO FILE NAME

	IF	NOEXEC
	LES	BX,DWORD PTR CS:[MEMLO]
	CALL	LDFIL			;LOAD IN THE DEVICE DRIVER
	ELSE
; We are going to open the cdevice driver and size it as is done
;  in LDFIL. The reason we must do this is that EXEC does NO checking
;  for us. We must make sure there is room to load the device without
;  trashing SYSINIT. This code is not
;  perfect (for instance .EXE device drivers are possible) because
;  it does its sizing based on the assumption that the file being loaded
;  is a .COM file. It is close enough to correctness to be usable.
	MOV	ES,AX			;ES:0 is LOAD addr
	MOV	AX,OPEN SHL 8		;OPEN THE FILE
	STC				;IN CASE OF INT 24
	INT	21H
	JC	BADLDRESET
	MOV	BX,AX			;Handle in BX
	PUSH	DX			; Save pointer to name
	XOR	CX,CX
	XOR	DX,DX
	MOV	AX,(LSEEK SHL 8) OR 2
	STC				;IN CASE OF INT 24
	INT	21H			; Get file size in DX:AX
	JNC	GO_AHEAD_LOAD
	MOV	AH,CLOSE		; Close file
	INT	21H
	POP	DX			; Clean stack
	STC				; Close may clear carry
	JMP	SHORT BADLDRESET

GO_AHEAD_LOAD:
    ; Convert size in DX:AX to para in AX
	ADD	AX,15			; Round up size for conversion to para
	ADC	DX,0
	MOV	CL,4
	SHR	AX,CL
	MOV	CL,12
	SHL	DX,CL			; Low nibble of DX to high nibble
	OR	AX,DX			; AX is now # of para for file

	MOV	CX,ES			; CX:0 is xaddr
	ADD	CX,AX			; New device will take up to here
	JC	MEM_ERRJY		; WOW!!!!
	CMP	CX,CS:[ALLOCLIM]
	JB	OKLDX
MEM_ERRJY:
	JMP	MEM_ERR

OKLDX:
	POP	DX			; Recover name pointer
	MOV	AH,CLOSE		; Close file
	INT	21H
	MOV	BX,CS
	MOV	ES,BX
	MOV	BX,OFFSET PRMBLK	;ES:BX POINTS TO PARAMETERS
	MOV	AL,3
	MOV	AH,EXEC
	STC				;IN CASE OF INT 24
	INT	21H			;LOAD IN THE DEVICE DRIVER
	ENDIF

BADLDRESET:
	PUSH	DS
	POP	ES			;ES:SI BACK TO CONFIG.SYS
	PUSH	CS
	POP	DS			;DS BACK TO SYSINIT
ASSUME	DS:SYSINITSEG
	JNC	GOODLD
BADBRK:
	cmp	byte ptr es:[si], 13	;file name is CR?		  ;3.30
	jne	BADBRK_1		;(entered "device=" without filename);3.30                                            ;3.30
	jmp	BADOP			;"Unrecognized command in CONFIG.SYS";3.30
BADBRK_1:								  ;3.30
	invoke	BADLOAD
	JMP	COFF

GOODLD: SaveReg <ES,SI> 		;INITIALIZE THE DEVICE
Restore:MOV	BL,ES:[SI]		;   while ((c=*p) != 0)
	OR	BL,BL
	JZ	Got
	INC	SI			;	p++;
	JMP	Restore
Got:	MOV	BYTE PTR ES:[SI],' '    ;   *p = ' ';
	SaveReg <ES,SI>
	PUSH	CS
	POP	ES
	MOV	BX,SDEVSTRAT
	invoke	CALLDEV 		;   CallDev (SDevStrat);
	MOV	BX,SDEVINT
	invoke	CALLDEV 		;   CallDev (SDevInt);
	RestoreReg  <SI,DS>
	MOV	BYTE PTR [SI],0 	;   *p = 0;

	PUSH	CS
	POP	DS
	MOV	AX,WORD PTR [BREAK_ADDR+2]
	CMP	AX,[MEMORY_SIZE]
	JB	BREAKOK
	POP	SI
	POP	ES
	JMP	BADBRK

BREAKOK:
	LDS	DX,[ENTRY_POINT]	;SET DS:DX TO HEADER
	MOV	SI,DX
	ADD	SI,SDEVATT		;DS:SI POINTS TO ATTRIBUTES
	LES	DI,CS:[DOSINFO] 	;ES:DI POINT TO DOS INFO
	MOV	AX,DS:[SI]		;GET ATTRIBUTES
	TEST	AX,DEVTYP		;TEST IF BLOCK DEV
	JZ	ISBLOCK
	invoke	SET_BREAK		; Go ahead and alloc mem for device
	jc	Erase_Dev		;dev driver's Init routine failed ;3.30
	TEST	AX,ISCIN		;IS IT A CONSOLE IN?
	JZ	TRYCLK
	MOV	WORD PTR ES:[DI.SYSI_CON],DX
	MOV	WORD PTR ES:[DI.SYSI_CON+2],DS

TRYCLK: TEST	AX,ISCLOCK		;IS IT A CLOCK DEVICE?
	JZ	GOLINK
	MOV	WORD PTR ES:[DI+SYSI_CLOCK],DX
	MOV	WORD PTR ES:[DI+SYSI_CLOCK+2],DS
GOLINK: JMP	LINKIT

ISBLOCK:
	MOV	AL,CS:[UNITCOUNT]	;IF NO UNITS FOUND, erase the device
	OR	AL,AL
	JNZ	PERDRV
ERASE_DEV:
	MOV	AX,-1			; No call to SET_BREAK yet, so no alloc
	JMP	ENDDEV

PERDRV:
	CBW				; WARNING NO DEVICE > 127 UNITS
	MOV	CX,AX
	MOV	DH,AH
	MOV	DL,ES:[DI.SYSI_NUMIO]	;GET NUMBER OF DEVICES
	MOV	AH,DL
	ADD	AH,AL			; Check for too many devices
	CMP	AH,26			; 'A' - 'Z' is 26 devices
	JBE	OK_BLOCK
	PUSH	CS
	POP	DS
	MOV	DX,OFFSET BADBLOCK
	invoke	PRINT
	JMP	ERASE_DEV

OK_BLOCK:
	invoke	SET_BREAK		; Alloc the device
	ADD	ES:[DI.SYSI_NUMIO],AL	;UPDATE THE AMOUNT
	ADD	CS:DriveNumber,AL	; remember amount for next device
	LDS	BX,CS:[BPB_ADDR]	;POINT TO BPB ARRAY
PERUNIT:
	LES	BP,CS:[DOSINFO]
	LES	BP,DWORD PTR ES:[BP.SYSI_DPB]	;GET FIRST DPB

SCANDPB:CMP	WORD PTR ES:[BP.DPB_NEXT_DPB],-1
	JZ	FOUNDPB
	LES	BP,ES:[BP.DPB_NEXT_DPB]
	JMP	SCANDPB
FOUNDPB:
	MOV	AX,CS:[MEMLO]
	MOV	WORD PTR ES:[BP.DPB_NEXT_DPB],AX
	MOV	AX,CS:[MEMHI]
	MOV	WORD PTR ES:[BP.DPB_NEXT_DPB+2],AX
	LES	BP,DWORD PTR CS:[MEMLO]
	ADD	WORD PTR CS:[MEMLO],DPBSIZ
	CALL	ROUND			;Check for alloc error
	MOV	WORD PTR ES:[BP.DPB_NEXT_DPB],-1
	MOV	ES:[BP.DPB_FIRST_ACCESS],-1

	MOV	SI,[BX] 		;DS:SI POINTS TO BPB
	INC	BX
	INC	BX			;POINT TO NEXT GUY
	MOV	WORD PTR ES:[BP.DPB_DRIVE],DX
	MOV	AH,SETDPB		;HIDDEN SYSTEM CALL
	INT	21H
	MOV	AX,ES:[BP.DPB_SECTOR_SIZE]				  ;3.30
	PUSH	ES							  ;3.30
	LES	DI,CS:[DOSINFO] 	;ES:DI POINT TO DOS INFO	  ;3.30
	CMP	AX,ES:[DI.SYSI_MAXSEC]					  ;3.30
	POP	ES							  ;3.30
	JBE	NOTMAX							  ;3.30
	POP	SI							  ;3.30
	POP	ES							  ;3.30
	MOV	DX,OFFSET BADSIZ_PRE					  ;3.30
	MOV	BX,OFFSET BADSIZ_POST					  ;3.30
	invoke	PRNERR							  ;3.30
	JMP	COFF							  ;3.30

NOTMAX: PUSH	DS
	PUSH	DX
	LDS	DX,CS:[ENTRY_POINT]
	MOV	WORD PTR ES:[BP.DPB_DRIVER_ADDR],DX
	MOV	WORD PTR ES:[BP.DPB_DRIVER_ADDR+2],DS
	POP	DX
	POP	DS
	INC	DX
	INC	DH
	LOOP	PERUNIT
	PUSH	CS
	POP	DS
	CALL	TEMPCDS 		; Set CDS for new drives

LINKIT:
	LES	DI,CS:[DOSINFO] 	;ES:DI = DOS TABLE
	MOV	CX,WORD PTR ES:[DI.SYSI_DEV]	;DX:CX = HEAD OF LIST
	MOV	DX,WORD PTR ES:[DI.SYSI_DEV+2]

	LDS	SI,CS:[ENTRY_POINT]	;DS:SI = DEVICE LOCATION
	MOV	WORD PTR ES:[DI.SYSI_DEV],SI	;SET HEAD OF LIST IN DOS
	MOV	WORD PTR ES:[DI.SYSI_DEV+2],DS
	MOV	AX,DS:[SI]		;GET POINTER TO NEXT DEVICE
	MOV	WORD PTR CS:[ENTRY_POINT],AX	;AND SAVE IT

	MOV	WORD PTR DS:[SI],CX	;LINK IN THE DRIVER
	MOV	WORD PTR DS:[SI+2],DX
ENDDEV:
	POP	SI
	POP	ES
	INC	AX			;AX = FFFF (no more devs if YES)?
	JZ	COFFJ3
	JMP	GOODLD			;OTHERWISE PRETEND WE LOADED IT IN
COFFJ3: JMP	COFF

;------------------------------------------------------------------------------
; Country command
;  The syntax is:							  ;3.30
;	COUNTRY=country id {,codepage {,path}}				  ;3.30
;	COUNTRY=country id {,,path}	:Default CODEPAGE ID in DOS	  ;3.30
;------------------------------------------------------------------------------
TRYQ:
	CMP	AH,'Q'                                                         ;3.30
	JZ	TRYQ_CONT						       ;3.30
	JMP	TRYF							       ;3.30
TRYQ_CONT:								       ;3.30
	invoke	GETNUM							       ;3.30
	JZ	TryQBad 		; 0 is never a valid code, or number is;3.30
					;   bad 			       ;3.30
	MOV	BX,AX			; Country code in BX		       ;3.30
									       ;3.30
					; 5/26/86			       ;3.30
	MOV	DX,0			; assume no code page id	       ;3.30
									       ;3.30
	invoke	skip_delim		;skip the delimeters after the first nu;3.30m
	jc	TryQ_Def_File		;no more characters left? then use defa;3.30ult file
	cmp	al, 13			;				       ;3.30
	je	TryQ_Def_File						       ;3.30
	cmp	al, 10							       ;3.30
	jne	TRYQ_YES_EXTENDED					       ;3.30
	inc	[COUNT] 		;This is for NEWLINE routine in COFF.  ;3.30
	dec	[CHRPTR]						       ;3.30
COFFJ41:								       ;3.30
	JMP	TryQ_Def_File		;O.K. no code page, no path specified. ;3.30Use default path.
									       ;3.30
TRYQ_YES_EXTENDED:							       ;3.30
	cmp	al, ','                 ;was the second comma?                 ;3.30
	jne	TryQ_GETNUM						       ;3.30
	invoke	skip_delim		;Yes, skip ',' and other possible delim;3.30
	jmp	short TRYQ_PATH 	;and No code page id entered.	       ;3.30
TRYQ_GETNUM:								       ;3.30
	invoke	GETNUM							       ;3.30
	jc	TryQBadCOM		;"Country=xxx,path" will not be accepte;3.30d.
;	jc	TRYQ_PATH		;Codepage is not specified. No code pag;3.30e.
;					;At this point, AL already contain the ;3.30
;					;first char of the PATH.	       ;3.30
	jz	TryQBad 		;codepage=0 entered. Error	       ;3.30
	mov	DX, AX			;save code page in DX		       ;3.30
	invoke	skip_delim		;move CHRPTR to the path string        ;3.30
	jc	TryQ_Def_File		;no more char? then use default filenam;3.30e
	cmp	al, 13							       ;3.30
	je	TryQ_Def_File						       ;3.30
	cmp	al, 10							       ;3.30
	jne	TryQ_PATH		;path entered.			       ;3.30
	inc	[COUNT] 						       ;3.30
	dec	[CHRPTR]						       ;3.30
TryQ_Def_File:								       ;3.30
	push	dx			;save code page 		       ;3.30
	mov	cs:CNTRY_DRV, 0 	;flag that the default path has been us;3.30ed!!!
	mov	dx, offset CNTRY_ROOT	;the default path		       ;3.30
	jmp	TRYQ_OPEN						       ;3.30
									       ;3.30
TryQBad:				;"Invalid country code or code page"   ;3.30
	STC								       ;3.30
	MOV	DX,OFFSET BADCOUNTRY					       ;3.30
	jmp	TryQChkErr						       ;3.30
									       ;3.30
TryQBadCOM:				;Error in COUNTRY command	       ;3.30
	STC								       ;3.30
	MOV	DX,OFFSET BADCOUNTRYCOM 				       ;3.30
	jmp	TryQChkErr						       ;3.30
									       ;3.30
TRYQ_PATH:				;DS - sysinitseg, ES - CONFBOT,        ;3.30
	mov	CX, [COUNT]		;AL - the first char of path	       ;3.30
	inc	CX			;BX - country id, DX - codepage id, 0 =;3.30 No code page
	mov	DI, SI							       ;3.30
TRYQ_PATH_LOOP: 			;find the end of path to put 0 after th;3.30at.
	mov	AL, byte ptr ES:[DI]					       ;3.30
	call	delim							       ;3.30
	jz	TRYQ_PATH_END						       ;3.30
	cmp	al, 13							       ;3.30
	jz	TRYQ_PATH_END						       ;3.30
	inc	DI							       ;3.30
	jmp	short TRYQ_PATH_LOOP					       ;3.30
TryQBad_Brg:jmp short TryQBad						       ;3.30
TRYQ_PATH_END:								       ;3.30
	mov	es:byte ptr [di], 0	;make it a ASCIIZ string. (Organize did;3.30 not handle this string)
	push	ds			;switch ds,es			       ;3.30
	push	es							       ;3.30
	pop	ds							       ;3.30
	pop	es							       ;3.30
									       ;3.30
	mov	di, offset  CNTRY_DRV	;move the user specified path to CNTRY_;3.30DRV
	call	Move_ASCIIZ						       ;3.30
									       ;3.30
	push	ds			;restore ds,es			       ;3.30
	push	es							       ;3.30
	pop	ds							       ;3.30
	pop	es							       ;3.30
									       ;3.30
;	 call	 Set_Country_Path	 ;set CNTRY_DRV 		       ;3.30
									       ;3.30
	push	dx			;save DX			       ;3.30
	mov	dx, offset CNTRY_DRV	;Now DS:DX -> CNTRY_DRV 	       ;3.30
TRYQ_OPEN:								       ;3.30
	mov	ax, 3d00h		;open a file			       ;3.30
	stc								       ;3.30
	int	21h							       ;3.30
	pop	dx			;restore codepage id		       ;3.30
	jc	TryQFileBad		;open failure			       ;3.30
									       ;3.30
	mov	cs:CntryFileHandle, ax	;save file handle		       ;3.30
	xchg	ax, bx			;now, AX = country id, BX = file handle;3.30
	mov	cx, cs:[MEMHI]						       ;3.30
	add	cx, 128 		;I need 2K buffer to handle COUNTRY.SYS;3.30
	cmp	cx, cs:[ALLOCLIM]					       ;3.30
	ja	TryQMemory		;cannot allocate the buffer for country;3.30.sys
									       ;3.30
	mov	si, offset CNTRY_DRV	;DS:SI -> CNTRY_DRV		       ;3.30
	cmp	byte ptr [si],0 	;default path?			       ;3.30
	jne	TRYQ_Set_for_DOS					       ;3.30
	inc	si							       ;3.30
	inc	si			;DS:SI -> CNTRY_ROOT		       ;3.30
TRYQ_Set_for_DOS:							       ;3.30
	les	di, cs:SYSI_Country	;ES:DI -> country info tab in DOS      ;3.30
	push	di			;save di			       ;3.30
	add	di, ccPath_CountrySys					       ;3.30
	call	MOVE_ASCIIZ		;Set the path to COUNTRY.SYS in DOS.   ;3.30
	pop	di			;ES:DI -> country info tab again.      ;3.30
	mov	cx, cs:[MEMHI]						       ;3.30
	mov	ds, cx							       ;3.30
	xor	si, si			;DS:SI -> 2K buffer to be used.        ;3.30
	call	SetDOSCountryInfo	;now do the job!!!		       ;3.30
	jnc	TryQchkERR		;read error or could not find country,c;3.30ode page combination
	cmp	cx, -1			;Could not find matching country_id,cod;3.30e page?
	je	TryQBad_Brg		;then "Invalid country code or code pag;3.30e"
TryQFileBad:								       ;3.30
	cmp	cs:CNTRY_DRV,0		;Is the default file used?	       ;3.30
	je	TryQDefBad						       ;3.30
	mov	si, cs:[CONFBOT]					       ;3.30
	mov	es, si							       ;3.30
	mov	si, cs:[CHRPTR] 					       ;3.30
	dec	si			;ES:SI -> path in CONFBOT	       ;3.30
	jmp	short TryQBADLOAD					       ;3.30
TryQDefBad:				;Default file has been used.	       ;3.30
	push	cs							       ;3.30
	pop	es							       ;3.30
	mov	si, offset CNTRY_ROOT	;ES:SI -> \COUNTRY.SYS in SYSINIT_SEG  ;3.30
TryQBADLOAD:								       ;3.30
	call	BADLOAD 		;DS will be restored to SYSINIT_SEG    ;3.30
	mov	cx, cs:[CONFBOT]					       ;3.30
	mov	es, cx			;Restore ES -> CONFBOT. 	       ;3.30
	jmp	short CoffJ4						       ;3.30
TryQMemory:								       ;3.30
	MOV	DX,OFFSET INSUFMEMORY					       ;3.30
TryQChkErr:								       ;3.30
	mov	cx, cs:[CONFBOT]					       ;3.30
	mov	es, cx			;restore ES -> CONFBOT seg	       ;3.30
	push	cs							       ;3.30
	pop	ds			;retore DS to SYSINIT_SEG	       ;3.30
	jnc	CoffJ4			;if no error, then exit 	       ;3.30
	invoke	PRINT			;else show error message	       ;3.30
CoffJ4: 								       ;3.30
	mov	bx, CntryFileHandle					       ;3.30
	mov	ah, 3eh 						       ;3.30
	int	21h			;close a file. Don't care even if it fa;3.30ils.
	JMP	COFF							       ;3.30

;------------------------------------------------------------------------------
; Files command
;------------------------------------------------------------------------------
TRYF:
	CMP	AH,'F'
	JNZ	TRYL
	invoke	GETNUM
	CMP	AX,5
	JB	TryFBad 		; Gotta have at least 5
	CMP	AX,256
	JAE	TryFBad 		; Has to be a byte
	MOV	[FILES],AL
CoffJ5: JMP	COFF
TryFBad:JMP	BadOp
;------------------------------------------------------------------------------
; LastDrive command
;------------------------------------------------------------------------------
TRYL:
	CMP	AH,'L'
	JNZ	TRYP
	OR	AL,020h
	SUB	AL,'a'
	JB	TryLBad
	INC	AL
	CMP	AL,26			; a-z are allowed
	JA	TryLBad
	MOV	[NUM_CDS],AL
CoffJ6: JMP	COFF
TryLBad:JMP	BadOp
;-------------------------------------------------------------------------------
; Setting Drive Parameters
;-------------------------------------------------------------------------------
TRYP:
	CMP	AH,'P'
	JNZ	TRYK
	invoke	PARSELINE
	JC	TryLBad
	invoke	SETPARMS
	INVOKE	DIDDLEBACK
	jc	TryLBad
	JMP	COFF
;-------------------------------------------------------------------------------
; Setting Internal Stack Parameters
; STACK=M,N where
;	M is the number of stacks (range 8 to 64, default 9)
;	N is the stack size (range 32 to 512 bytes, default 128)
;  5/5/86: STACKS=0,0 implies no stack installation.		  ;3.30
;	Any combinations that are not within the specified limits will	  ;3.30
;	result in "Unrecognized command" error.                           ;3.30
;-------------------------------------------------------------------------------
TRYK:
	CMP	AH,'K'
	JNZ	TRYW

		IF	STACKSW 					  ;3.30

	MOV	SepChr,','
	INVOKE	GetNum			; Get number of stacks
	MOV	SepChr,0
	cmp	ax, 0			; 5/5/86			  ;3.30
	je	TRYK_0			; Let's accept 0.             ;3.30
	CMP	AX, MinCount		; 8 <= Number of Stacks <= 64
	JB	TryKBad
	CMP	AX, MaxCount
	JA	TryKBad
TRYK_0: 								  ;3.30
	MOV	[STACK_COUNT], AX
;
; Skip delimiters after the ,
;
	invoke	Skip_delim		;				  ;3.30
	JC	TryKBad

	INVOKE	GetNum			; Get size of individual stack
	JC	TryKBad 		; Number bad

	cmp	ax, 0			; 5/5/86			  ;3.30
	je	TRYK_SIZE0		; 5/5/86. Accept 0		  ;3.30

	CMP	AX, MinSize		; 32 <= Stack Size <= 512
	JB	TryKBad
	CMP	AX, MaxSize
	JA	TryKBad
TRYK_SIZE0:								  ;3.30
	MOV	[STACK_SIZE], AX
	cmp	ax,0							  ;3.30
	je	TRYK_BOTH0						  ;3.30
TRYK_OK:								  ;3.30
	mov	word ptr [stack_addr], -1 ;set flag. user entered stacks= ;3.30
	JMP	COFF
TRYK_BOTH0:								  ;3.30
	cmp	[STACK_COUNT],0 	;stack_size=0. Stack_Count=0 too? ;3.30
	je	TRYK_OK 		;yes. accepted. 		  ;3.30
TryKBad:
	MOV	DX, OFFSET BADSTACK	; 5/26/86 "Invalid stack parameter";3.30
	invoke	PRINT							  ;3.30
	JMP	COFF							  ;3.30

		ENDIF							  ;3.30
;------------------------------------------------------------------------------
; Switch command
;------------------------------------------------------------------------------
TRYW:
	CMP	AH,'W'
	JNZ	TRYA
	JMP	BadOp			; no longer implemented
;	MOV	DL,AL
;	MOV	AX,(CHAR_OPER SHL 8) OR 1      ;SET SWITCH CHARACTER
;	MOV	[COMMAND_LINE+1],DL
;	INT	21H
;	JMP	COFF

;------------------------------------------------------------------------------
; Availdev command
;------------------------------------------------------------------------------
TRYA:
	CMP	AH,'A'
	JNZ	TRYS
	JMP	BadOp			; NO LONGER IMPLEMENTED
;	CMP	AL,'F'                  ;FIRST LETTER OF "FALSE"
;	JNZ	COFFJ7
;	MOV	AX,(CHAR_OPER SHL 8) OR 3 ;TURN ON "/DEV" PREFIX
;	XOR	DL,DL
;	INT	21H
;COFFJ7: JMP	 COFF

;------------------------------------------------------------------------------
; shell command
;------------------------------------------------------------------------------
TRYS:
	CMP	AH,'S'
	JNZ	TRYX
	MOV	[COMMAND_LINE+1],0
	MOV	DI,OFFSET COMMND + 1
	MOV	[DI-1],AL
STORESHELL:
	CALL	GETCHR
	OR	AL,AL
	JZ	GETSHPARMS
	CMP	AL," "
	JB	ENDSH
	MOV	[DI],AL
	INC	DI
	JMP	STORESHELL

ENDSH:
	MOV	BYTE PTR [DI],0
	CALL	GETCHR
	CMP	AL,10
	JNZ	CONV
	CALL	GETCHR
CONV:	JMP	CONFLP

;------------------------------------------------------------------------------
; FCBS Command
;------------------------------------------------------------------------------
TRYX:
	CMP	AH,'X'
	JNZ	TRYZ
	invoke	GETNUM
	JZ	TryXBad 		; gotta have at least one
	CMP	AX,256
	JAE	TryXBad 		; Can't be more than 8 bits worth
	MOV	[FCBS],AL
;
; Skip delimiters after the ,
;
	invoke	Skip_delim		;				  ;3.30
	jc	tryxbad
	invoke	GetNum
	JC	TryXBad 		; Number bad (Zero is OK here)
	CMP	AX,256
	JAE	TryXBad
	CMP	AL,FCBS
	JA	TryXBad
	MOV	Keep,AL
	JMP	COFF
TryXBad:JMP	BadOp

;------------------------------------------------------------------------------
; Bogus command
;------------------------------------------------------------------------------
TRYZ:
	JMP	BADOP

GETSHPARMS:
	MOV	BYTE PTR [DI],0
	MOV	DI,OFFSET COMMAND_LINE+1
PARMLOOP:
	CALL	GETCHR
	CMP	AL," "
	JB	ENDSH
	MOV	[DI],AL
	INC	DI
	JMP	PARMLOOP

GETCHR:
	PUSH	CX
	MOV	CX,COUNT
	JCXZ	NOCHAR
	MOV	SI,CHRPTR
	MOV	AL,ES:[SI]
	DEC	COUNT
	INC	CHRPTR
	CLC
GET_RET:
	POP	CX
	return
NOCHAR: STC
	JMP	SHORT GET_RET


SYSINITSEG	ENDS
	END
