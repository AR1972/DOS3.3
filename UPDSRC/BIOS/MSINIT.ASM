
;	modification history
;
;	3.21	sp added pushf-popf fix around NoParms to fix bug

;;Rev 3.30 Modification -----------------------------------------------
	test = 0
	include msgroup.inc	;define code segment
	include dskprm.inc
	include msequ.inc	
	include msmacro.inc	
	include msextrn.inc	
	include biostruc.inc	
	include cmosequ.inc	
				
	EXTRN	OLD13:DWORD	
				
; THE FOLLOWING LABEL DEFINES THE END OF THE AT ROM PATCH.  THIS IS USED
; AT CONFIGURATION TIME.				
; Warning!!! This code will be dynamically relocated by MSINIT.
								
	PUBLIC	ENDATROM		;NOT REFERENCES EXTERNALLY, BUT
					; JUST TO CAUSE ENTRY IN LINK MAP
ENDATROM LABEL	BYTE							
									
;CMOS Clock setting support routines used by MSCLOCK.		
;Warning!!! This code will be dynamically relocated by MSINIT.
	
	EXTRN	base_century:byte		
	EXTRN	base_year:byte			
	EXTRN	month_tab:byte			
						
	public	Daycnt_to_day	;for real time clock support
Daycnt_to_day	proc	near	;for real time clock support
;Entry: [DAYCNT] = number of days since 1-1-80
;Return: CH=centry in BCD, CL=year in BCD, DH=month in BCD, DL=day in BCD
									 
	push	[daycnt]		;save daycnt			 
	cmp	daycnt, (365*20+(20/4)) ;# days from 1-1-1980 to 1-1-2000
	jae	century20						 
	mov	base_century, 19					 
	mov	base_year, 80						 
	jmp	years							 
century20:				;20th century			 
	mov	base_century, 20					 
	mov	base_year, 0						 
	sub	daycnt, (365*20+(20/4)) ;adjust daycnt			 
years:									 
	xor	dx, dx							 
	mov	ax, daycnt						 
	mov	bx, (366+365*3) 	;# of days in a Leap year block  
	div	bx			;AX = # of leap block, DX=daycnt 
	mov	daycnt, dx		;save daycnt left		 
;	or	ah, ah			;ax should be less than 256	 
;	jz	OK1							 
;	 jmp	 Erroroccur						 
;OK1:									 
	mov	bl,4							 
	mul	bl			;AX=# of years. Less than 100	 
	add	base_year, al		;So, ah = 0. Adjust year	 
	inc	daycnt			;set daycnt to 1 base		 
	cmp	daycnt, 366		;daycnt=remainder of leap year bk
	jbe	Leapyear		;within 366+355+355+355 days.	 
	inc	base_year		;if daycnt <= 366, then leap year
	sub	daycnt, 366		;else daycnt--, base_year++;	 
					;And next three years are normal 
	mov	cx, 3							 
Regularyear:								 
	cmp	daycnt, 365		;for(i=1; i>3 or daycnt <=365;i++)
	jbe	YearDone		;{if (daycnt > 365)		
	inc	base_year		;  { daycnt -= 365		
	sub	daycnt, 365		;  }				
	loop	regularyear		;}				
;	 jmp	 Erroroccur		 ;cannot come to here		
Leapyear:								
	mov	byte ptr month_tab+1,29 ;leap year. change month table. 
Yeardone:								
	xor	bx,bx							
	xor	dx,dx							
	mov	ax, daycnt						
	mov	si, offset month_tab					
	mov	cx, 12							
Months: 								
	inc	bl			;				
	mov	dl, byte ptr ds:[si]	;cmp daycnt for each month til fit
	cmp	ax, dx			;dh=0.				 
	jbe	Month_done						 
	inc	si			;next month			 
	sub	ax, dx			;adjust daycnt			 
	loop	Months							 
;	 jmp	 Erroroccur						 
Month_done:								 
	mov	byte ptr month_tab+1, 28 ;restore month table value	 
	mov	dl, bl							 
	mov	dh, base_year						 
	mov	cl, base_century	;al=day,dl=month,dh=year,cl=cntry
	call	word ptr BinToBCD	;To save 15 bytes, Bin_To_BCD proc
					;was rel from Daycnt_to_Day proc. 
;	call Bin_to_bcd 		;convert "day" to bcd             
	xchg	dl, al			;dl = bcd day, al = month	  
	call	word ptr BinToBCD					  
;	call Bin_to_bcd 						  
	xchg	dh, al			;dh = bcd month, al = year	  
	call	word ptr BinToBCD					  
;	call Bin_to_bcd 						  
	xchg	cl, al			;cl = bcd year, al = century	 
	call	word ptr BinToBCD					 
;	call Bin_to_bcd 						 
	mov	ch, al			;ch = bcd century		 
	pop	[daycnt]		;restore original value 	 
	ret								 
Daycnt_to_day	endp							 
									 
	public	EndDaycntToDay						 
EndDaycntToDay label	byte						 
									 
	public	Bin_to_bcd						 
Bin_to_bcd	proc	near		; real time clock sup
;Convert a binary input in AL (less than 63h or 99 decimal)
;into a bcd value in AL.  AH destroyed. 			
	push	cx						
	xor	ah, ah						
	mov	cl, 10						
	div	cl		;al=high digit bcd, ah=low digit bcd
	mov	cl, 4						
	shl	al, cl		;mov the high digit to high nibble
	or	al, ah							
	pop	cx							
	ret								
Bin_to_bcd	endp							
									
	Public	EndCMOSClockset 	;End of routines for CMOS clock 
EndCMOSClockset label byte						
;									
									
	EXTRN  INT6C_RET_ADDR:DWORD	; RETURN ADDRESS FROM INT 6C	
	EXTRN  BIN_DATE_TIME:BYTE					
	EXTRN  MONTH_TABLE:WORD 					
	EXTRN  DAYCNT2:WORD						
	EXTRN  FEB29:BYTE						
	EXTRN  TimeToTicks:Word 	;indirect intra-segment call add
									
	EVENB								
;									
; THE K09 REQUIRES ROUTINES FOR READING THE CLOCK BECAUSE OF THE SUSPEND/
; RESUME FACILITY. THE SYSTEM CLOCK NEEDS TO BE RESET AFTER RESUME.	 
;									 
	ASSUME	ES:NOTHING						 
									 
; THE FOLLOWING ROUTINE IS EXECUTED AT RESUME TIME WHEN THE SYSTEM	 
; POWERED ON AFTER SUSPENSION. IT READS THE REAL TIME CLOCK AND 	 
; RESETS THE SYSTEM TIME AND DATE, AND THEN IRETS.			 
; Warning!!! This code will be dynamically relocated by MSINIT.
INT6C	PROC	FAR							 
	PUSH	CS							 
	POP	DS							 
									 
	ASSUME DS:CODE							 
									 
	POP	WORD PTR INT6C_RET_ADDR ; POP OFF RETURN ADDRESS	 
	POP	WORD PTR INT6C_RET_ADDR+2				 
	POPF								 
	CALL	READ_REAL_DATE		; GET THE DATE FROM THE CLOCK	 
	CLI								 
	MOV	DS:DAYCNT,SI	      ; UPDATE DOS COPY OF DATE 	 
	STI								 
	CALL	READ_REAL_TIME		; GET THE TIME FROM THE RTC	 
	CLI								 
	MOV	AH, 01h 		; COMMAND TO SET THE TIME
	INT	1Ah			; CALL ROM-BIOS TIME ROUTINE 
	STI								
	JMP	INT6C_RET_ADDR		; LONG JUMP			
									
INT6C	ENDP								
									
									
	INCLUDE READCLOCK.INC						
	INCLUDE CLOCKSUB.INC						
									
	PUBLIC	ENDK09			;NOT REFERENCES EXTERNALLY, BUT 
					; JUST TO CAUSE ENTRY IN LINK MAP
ENDK09	LABEL	BYTE							 
	ASSUME	DS:NOTHING,ES:NOTHING					 
;;End of Modification -----------------------------------------------

;------------------------------------------------------------------------
;									:
;	System initiailzation						:
;									:
;	The entry conditions are established by the bootstrap		:
;	loader and are considered unknown.  The following jobs		:
;	will be performed by this module:				:
;									:
;	1.	All device initialization is performed			:
;	2.	A local stack is set up and DS:SI are set		:
;		to point to an initialization table. Then		:
;		an inter-segment call is made to the first		:
;		byte of the dos 					:
;	3.	Once the dos returns from this call the ds		:
;		register has been set up to point to the start		:
;		of free memory. The initialization will then		:
;		load the command program into this area 		:
;		beginning at 100 hex and transfer control to		:
;		this program.						:
;									:
;------------------------------------------------------------------------

; DRVFAT must be the first location of freeable space!
	EVENB
DRVFAT	DW	0000			; Drive and FAT ID of DOS
BIOS$	DW	0000			; First sector of data
DOSCNT	DW	0000			; How many sectors to read
fBigFAT DB	0			; Flags for drive
FatLen	DW	?			; number of sectors in FAT.
FatLoc	DW	?			; seg addr of fat sector

;;Rev 3.30 Modification -----------------------------------------------
; THE FOLLOWING TWO BYTES ARE USED TO SAVE INFO RETURNED BY INT 13, AH=8
; CALL TO DETERMINE DRIVE PARAMETERS.					
NUM_HEADS DB	2			; NUMBER OF HEADS RETURNED BY ROM
SEC_TRK   DB	9			; SEC/TRK RETURNED BY ROM	 
NUM_CYLN  DB	40			; NUMBER OF CYLINDERS RET BY ROM 
									 
	public	Model_Byte						 
MODEL_BYTE DB	0FFH			; MODEL BYTE. SET UP AT INIT TIME.
					; FF - PC-1, EXPANSION, OLD PC-2 
					; FE - NEWER PC-2 (64/256K PLANAR)
					; FD - 
					; FC - 
	public	Secondary_Model_Byte					 
Secondary_Model_Byte db 0						 
;;End of Modification -----------------------------------------------
									 
BOOTBIAS =	200H							 
	EVENB								 
DiskTable   DW	512,	0100h,	64,	0
	    DW	2048,	0201h,	112,	0
	    DW	8192,	0402h,	256,	0
	    DW	32680,	0803h,	512,	0
	    DW	65535,	1004h,	1024,	0

DiskTable2  DW	32680,	0803h,	512,	0
	    DW	65535,	0402h,	512,	fBIG

;;Rev 3.30 Modification -----------------------------------------------
;*************************************************************************
;Variables for Mini disk initialization
;*************************************************************************
End_Of_BDSM	dw	?		;offset value of the ending add
					;of BDSM table. Needed to figure
					;the Final_DOS_Location.
numh		db	0		;number of hard files
mininum 	db	0		;logical drive num for mini disk 
num_mini_dsk	db	0		;# of mini disk installed	 
Rom_Minidsk_num db	80h		;physical mini disk number	 
Mini_HDLIM	dw	0						 
Mini_SECLIM	dw	0						 
Mini_BPB_ptr	dw	0		;temporary variable used to save 
					;Mini Disk BPB pt add in DskDrvs.
;;End of Modification -----------------------------------------------

Bios_Date   DB	'01/10/84',0

;
; The following are the recommended BPBs for the media that we know of so
; far.

; 48 tpi diskettes
	EVENB
BPB48T	DW	512
	DB	2
	DW	1
	DB	2
	DW	112
	DW	2*9*40
	DB	0FDH
	DW	2
	DW	9
	DW	2
	DD	0		;hidden sectors - sp
	DD	0		;big total sectors - sp
	DB	6 DUP(?)	;reserved

; 96tpi diskettes
	EVENB
BPB96T	DW	512
	DB	1
	DW	1
	DB	2
	DW	224
	DW	2*15*80
	DB	0f9H
	DW	7
	DW	15
	DW	2
	DD	0		;hidden sectors - sp
	DD	0		;big total sectors - sp
	DB	6 DUP(?)	;reserved

BPBSIZ	=	$-BPB96T

; 3 1/2 inch diskette BPB
	EVENB
BPB35	DW	512
	DB	2
	DW	1			; Double sided with 9 sec/trk
	DB	2
	DW	70h
	DW	2*9*80
	DB	0f9H
	DW	3
	DW	9
	DW	2
	DD	0		;hidden sectors - sp
	DD	0		;big total sectors - sp
	DB	6 DUP(?)	;reserved


	EVENB
BPBTable    dw	    BPB48T		; 48tpi drives
	    dw	    BPB96T		; 96tpi drives
	    dw	    BPB35		; 3.5" drives
	    ;dw      BPB48T		 ; Not used - 8" drives
	    ;dw      BPB48T		 ; Not Used - 8" drives
	    ;dw      BPB48T		 ; Not Used - hard files
	    ;dw      BPB48T		 ; Not Used - tape drives
	    ;dw      BPB48T		 ; Not Used - Other

PatchTable  LABEL BYTE
	DW	10,media_patch
	DW	3,getbp1_patch
	DW	3,SET_PATCH
	DW	3,DiskIO_Patch
	DW	3,DSKErr
	DW	10,Changed_Patch
	DW	3,INIT_PATCH
	DW	0

	ASSUME	DS:NOTHING,ES:NOTHING

;
; Entry from boot sector.  The register contents are:
;   DL = INT 13 drive number we booted from
;   CH = media byte
;   BX = First data sector on disk (0-based)
;
Public INIT
INIT	PROC	NEAR
	MESSAGE FTESTINIT,<"MSBIO",CR,LF>                                 ;3.30
	CLI
	XOR	AX,AX
	MOV	DS,AX
;
; Preserve original int 13 vector
;   We need to save INT13 in two places in case we are running on an AT.
; On ATs we install the IBM supplied ROM_BIOS patch DISK.OBJ which hooks
; INT13 ahead of ORIG13.  Since INT19 must unhook INT13 to point to the
; ROM INT13 routine, we must have that ROM address also stored away.
;
	MOV	AX,DS:[13h*4]
	MOV	WORD PTR Old13,AX
	MOV	WORD PTR Orig13,AX
	MOV	AX,DS:[13h*4+2]
	MOV	WORD PTR Old13+2,AX
	MOV	WORD PTR Orig13+2,AX
;
; Set up INT 13 for new action
;
	MOV	WORD PTR DS:[13h*4],OFFSET Block13
	MOV	DS:[13h*4+2],CS
;
; Preserve original int 19 vector
;
	MOV	AX,DS:[19h*4]
	MOV	WORD PTR Orig19,AX
	MOV	AX,DS:[19h*4+2]
	MOV	WORD PTR Orig19+2,AX
;
; Set up INT 19 for new action
;
	MOV	WORD PTR DS:[19h*4],OFFSET int19
	MOV	DS:[19h*4+2],CS
	STI


	int	11h			; rom-bios equipment determination
	ROL	AL,1			;PUT BITS 6 & 7 INTO BITS 0 & 1
	ROL	AL,1
	AND	AX,3			;ONLY LOOK AT BITS 0 & 1
	JNZ	NOTSINGLE		;ZERO MEANS SINGLE DRIVE SYSTEM
	INC	AX			;PRETEND IT'S A TWO DRIVE SYSTEM
	INC	CS:SINGLE		;REMEMBER THIS
NOTSINGLE:
	INC	AX			;AX HAS NUMBER OF DRIVES, 2-4
					;IS ALSO 0 INDEXED BOOT DRIVE IF WE
					;  BOOTED OFF HARD FILE
	mov	CL, AL			; save number of diskette drives in CL
	test	DL, 80h 		; booted from hard disk ?
	jnz	GotHrd			; yes, jump down
	xor	AX, AX			; no - indicate boot from drive A
GotHrd:

		; At this point the registers contain these values:
		;   AX = 0-based drive we booted from
		;   BX = the logical number of the first data sector on the disk
		;   CL = number of floppies including logical one
		;   CH = media byte
		;

	Message fTestINIT,<"Init",CR,LF>

;
; set up local stack
;
	xor	DX,DX
	cli			; turn interrupts off while manupulating stack
	mov	SS,DX		; set stack segment register
	mov	SP,700h 	; set stack pointer
	sti			; turn interrupts on
ASSUME	SS:NOTHING

			; preserve some of the values in registers

	push	CX			; save number of floppies and media byte
	mov	BIOS$,BX	      ; save first data sector
	mov	AH,CH			; FAT ID to AH too
	push	AX			; save boot drive number, and media byte
;;Rev 3.30 Modification -----------------------------------------------
; Let Model_byte, Secondary_Model_Byte be set here!!!	
	mov	ah,0c0h 		; return system environment 
	int	15h			; call ROM-Bios routine     
	jc	No_Rom_System_Conf	; just use Model_Byte	
	cmp	ah, 0			; double check		
	jne	No_Rom_System_Conf				
	mov	al, ES:[BX.bios_SD_modelbyte] ;get the model byte
	mov	[Model_Byte], al					
	mov	al, ES:[BX.bios_SD_scnd_modelbyte] ;secondary model byte
	mov	[Secondary_Model_Byte], al				
	jmp	short Turn_Timer_On					
No_Rom_System_Conf:							
	MOV	SI,0FFFFH		;MJB001 			
	MOV	ES,SI			;MJB001 			
	MOV	AL,ES:[0EH]		; GET MODEL BYTE ARR 2.41	
	MOV	MODEL_BYTE,AL	      ; SAVE MODEL BYTE ARR 2.41	
;;End of Modification -----------------------------------------------
Turn_Timer_On:								
	mov	AL,EOI
	out	AKPORT,AL		; turn on the timer

	Message fTestINIT,<"COM devices",CR,LF>

;;Rev 3.30 Modification -----------------------------------------------
	mov	si,offset COM4DEV 
	call	AUX_INIT
	mov	si,offset COM3DEV
	call	AUX_INIT
;;End of Modification -----------------------------------------------
	mov	SI,OFFSET COM2DEV
	call	AUX_INIT		;INIT COM2
	mov	SI,OFFSET COM1DEV
	call	AUX_INIT		;INIT COM1

	Message fTestINIT,<"LPT devices",CR,LF>
	mov	SI,OFFSET LPT3DEV
	call	PRINT_INIT		;INIT LPT3
	mov	SI,OFFSET LPT2DEV
	call	PRINT_INIT		;INIT LPT2
	mov	SI,OFFSET LPT1DEV
	call	PRINT_INIT		;INIT LPT1

	xor	DX,DX
	mov	DS,DX			;TO INITIALIZE PRINT SCREEN VECTOR
	mov	ES,DX

	xor	AX,AX
	mov	DI,INITSPOT
	stosw				;INIT four bytes to 0
	stosw

	mov	AX,CS			;FETCH SEGMENT

	mov	DS:WORD PTR BRKADR,OFFSET CBREAK    ;BREAK ENTRY POINT
	mov	DS:BRKADR+2,AX		;VECTOR FOR BREAK

	mov	DS:WORD PTR CHROUT*4,OFFSET WORD PTR OUTCHR
	mov	DS:WORD PTR CHROUT*4+2,AX

	Message fTestINIT,<"Interrupt vectors",CR,LF>
	mov	DI,4
	mov	BX,OFFSET INTRET	;WILL INITIALIZE REST OF INTERRUPTS
	xchg	AX,BX
	stosw				;Location 4
	xchg	AX,BX
	stosw				;INT 1		;Location 6
	add	DI,4
	xchg	AX,BX
	stosw				;Location 12
	xchg	AX,BX
	stosw				;INT 3		;Location 14
	xchg	AX,BX
	stosw				;Location 16
	xchg	AX,BX
	stosw				;INT 4		;Location 18

	mov	DS:WORD PTR 500H,DX	;SET PRINT SCREEN & BREAK =0
	mov	DS:WORD PTR LSTDRV,DX	;clean out last drive spec

	Message fTestINIT,<"Disk parameter table",CR,LF>

	EXTRN	MotorStartup:byte
	EXTRN	SettleCurrent:byte

	mov	SI,WORD PTR DS:DSKADR	;			  ARR 2.41
	mov	DS,WORD PTR DS:DSKADR+2 ; DS:SI -> current table  ARR 2.41

	mov	DI,SEC9 		; ES:DI -> New Table	  ARR 2.41
	mov	CX,SIZE DISK_PARMS	;			  ARR 2.41
	rep	MOVSB			; Copy Table		  ARR 2.41
	push	ES			;			  ARR 2.41
	pop	DS			; DS = 0		  ARR 2.41

	mov	WORD PTR DS:DSKADR,SEC9 ;			  ARR 2.41
	mov	WORD PTR DS:DSKADR+2,DS ; Point disk parm vector to new table
					;			  ARR 2.41


;-----------------------------------------------
;
; THE FOLLOWING DEPEND ON THE TYPE OF MACHINE.
;
	CMP	MODEL_BYTE,0FDH       ; IS THIS AN OLD ROM?	ARR 2.41
	JB	NO_DIDDLE		; NO			ARR 2.41
	MOV	WORD PTR DS:(SEC9 + DISK_HEAD_STTL),0200H+NORMSETTLE
					; SET HEAD SETTLE AND MOTOR START
					; ON PC-1 PC-2 PC-XT HAL0 ARR 2.41
	MOV	DS:(SEC9 + DISK_SPECIFY_1),0DFH 
					; SET 1ST SPECIFY BYTE
					; ON PC-1 PC-2 PC-XT HAL0 ARR 2.41
NO_DIDDLE:				;			  ARR 2.41

;--------------------------------------------------------------bug330a08
;	sp - fix from IBM
;
	mov	al,byte ptr ds:(sec9+disk_motor_strt)
	mov	cs:MotorStartup,al

	mov	al,byte ptr ds:(sec9+disk_head_sttl)
	mov	cs:SettleCurrent,al

;--------------------------------------------------------------bug330a08

	int	12h			; call rom-bios for memory size
	mov	CL, 6			; get ready for shift
	shl	AX, CL			; change from K to 16 byte blocks
	pop	CX			; restore CX
	mov	DRVFAT, CX
	push	AX
	mov	dx,ds:(7C00h + 16h)	; number of sectors/fat from boot sec
	xor	dh,dh
	mov	FatLen,DX
;
; Convert sector count to paragraph count:512 bytes / sec / 16 bytes / para
; = 32 para /sector
;
;;Rev 3.30 Modification -----------------------------------------------
	SHL	DX,1
	SHL	DX,1
	SHL	DX,1
	SHL	DX,1
	SHL	DX,1
;;End of Modification -----------------------------------------------
	SUB	AX,dx			; room for FAT
	MOV	FatLoc,AX		; location to read fat
	POP	AX

	MOV	DX,SYSINITSEG
	MOV	DS,DX

	ASSUME	DS:SYSINITSEG

	MOV	WORD PTR DEVICE_LIST,OFFSET CONHeader
	MOV	WORD PTR DEVICE_LIST+2,CS

; Allocation of buffers has moved to SYSINIT - Aug 19/85 BAS

;DEF_BUFF:

	MOV	MEMORY_SIZE,AX
	INC	CL
	MOV	DEFAULT_DRIVE,CL	;SAVE DEFAULT DRIVE SPEC

;DOSSEG  = ((((OFFSET END$)-(OFFSET START$))+15)/16)+BIOSEG+SYSIZE

; BAS DEBUG
;MOV	 CURRENT_DOS_LOCATION,((((OFFSET END$)-(OFFSET START$))+15)/16)+SYSIZE
	MOV	AX, OFFSET END$
	SUB	AX, OFFSET START$
	ADD	AX, 15
	RCR	AX, 1			; DIVIDE BY 16
	SHR	AX, 1
	SHR	AX, 1
	SHR	AX, 1
	ADD	AX, SYSIZE
	ADD	AX, CODE
	MOV	Current_DOS_Location, AX
; BAS DEBUG
;	ADD	Current_DOS_Location,CODE

;
; IMPORTANT: Some old IBM hardware generates spurious INT F's due to bogus
; printer cards.  We initialize this value to point to an IRET ONLY IF
;
; 1) The original segment points to storage inside valid RAM.
;
; 2) The original segment is 0F000:xxxx
;
; Theses are capricious requests from our OEM for reasons behind them, read
; the DCR's for the IBM DOS 3.2 project.
;
	push	ax

ASSUME ES:SYSINITSEG, DS:NOTHING
	mov	ax,SYSINITSEG
	mov	es,ax
	xor	ax,ax
	mov	ds,ax

	mov	ax,word ptr ds:(0fH*4+2)	; segment for Int 15

	cmp	ax,es:MEMORY_SIZE	      ; Condition 1
	jna	ResetIntF

	cmp	ax, 0F000h			; Condition 2
	jne	KeepIntF

ResetIntF:
	mov	word ptr ds:[0FH*4],offset INTRET
	mov	word ptr ds:[0FH*4+2],cs

KeepIntF:
	pop	ax
;
; END IMPORTANT
;

;**************************************************************
;	WILL INITIALIZE THE NUMBER OF DRIVES		
;	AFTER THE EQUIPMENT CALL (INT 11H) BITS 6&7 WILL TELL	
;	THE INDICATIONS ARE AS FOLLOWS: 		
;							
;	BITS	7	6	DRIVES			
;		0	0	1			
;		0	1	2			
;		1	0	3			
;		1	1	4			
;************************************************************** 
	PUSH	CS
	POP	DS
	PUSH	CS
	POP	ES

	ASSUME	DS:CODE,ES:CODE

	call	CMOS_Clock_Read  ;Before doing anything if CMOS clock,
				 ;then set the system time accordingly.
				 ;Also, reset the cmos clock rate.

	Message fTestINIT,<"Disk devices",CR,LF>

	XOR	SI,SI
	MOV	WORD PTR [SI],OFFSET HARDDRV ;set up pointer to hdrive

	POP	AX			;number of floppies and FAT ID
	XOR	AH,AH			; Chuck FAT ID byte
	MOV	HARDNUM,AL	      ;Remember which drive is hard disk
	MOV	DRVMAX,AL	      ;And set initial number of drives
	SHL	AX,1			;Two bytes per address
	MOV	DI,OFFSET DSKDRVS
	ADD	DI,AX			;Point to hardfile location
	MOV	SI,OFFSET HDSKTAB
	MOVSW				;Two addresses to move
	MOVSW
	MESSAGE FTESTINIT,<"BEFORE INT 13",CR,LF>         
	mov	DL, 80h      	; tell rom bios to look at hard drives
	mov	AH, 8h	     	; set command to get drive parameter
	int	13h	     	; call ROM-BIOS to get number of drives
	jc	ENDDRV			; old, rom therefore no hard disks
	mov	HNUM, DL	      ; save number of hard drives in HNUM

ENDDRV:
	Message fTestINIT,<"Setting up BDSs",CR,LF>

;
; Scan the list of drives to determine their type.  We have three flavors of
; diskette drives:
;
;   48tpi drives    We do nothing special for them
;   96tpi drives    Mark the fact that they have changeline support.
;   3 1/4 drives    Mark changeline support and small.
;
; The following code uses registers for certain values:
;   DL - Physical Drive
;   DS:DI - points to current BDS
;   CX - Flag bits for BDS
;   DH - Form Factor for the drive (1 - 48tpi, 2 - 96tpi, 3 - 3.5" medium)
;
	XOR	DL,DL			; start out with drive 0.
	push	cs
	pop	ds
	ASSUME DS:CODE
	MOV	EOT,9
	mov	di,offset Start_BDS
loop_drive:
	cmp	dl,drvmax
	jb	got_more
	jmp	Done_Drives
got_more:
	xor	cx,cx			; zero all flags
	mov	di,word ptr [di].link	; get next BDS
	mov	dh,ff48tpi		; Set Form Factor to 48 tpi
	MOV	NUM_CYLN,40	      ; 40 TRACKS PER SIDE
								
	PUSH	DS						
	PUSH	DI						
	PUSH	DX						
	PUSH	CX						
	PUSH	ES						
								
	MOV	AH, 8h			;GET DRIVE PARAMETERS
	INT	13h			;CALL ROM-BIOS		
	JNC	PARMSFROMROM					
	JMP	NOPARMSFROMROM		; GOT AN OLD ROM	
PARMSFROMROM:							
;If CMOS is bad, it gives ES,AX,BX,CX,DH,DI=0. CY=0.	 
;In this case, we are going to put bogus informations to BDS table.
;We are going to set CH=39,CL=9,DH=1 to avoid divide overflow when	
;they are calculated at the later time.  This is just for the Diagnostic
;Diskette which need IO.SYS,MSDOS to boot up before it sets CMOS.	
;This should only happen with drive B.					
									
;;Rev 3.30 Modification -----------------------------------------------
	CMP	CH,0			; if ch=0, then cl,dh=0 too.	 
	JNE	PFR_OK							 
	MOV	CH,39			; ROM gave wrong info.		 
	MOV	CL,9			; Let's default to 360K.         
	MOV	DH,1							 
PFR_OK: 								 
	INC	DH			; MAKE NUMBER OF HEADS 1-BASED	 
	INC	CH			; MAKE NUMBER OF CYLINDERS 1-BASED
	MOV	NUM_HEADS,DH	      ; SAVE PARMS RETURNED BY ROM	 
	AND	CL,00111111B		; EXTRACT SECTORS/TRACK 	 
	MOV	SEC_TRK,CL						 
	MOV	NUM_CYLN,CH	      ; ASSUME LESS THAN 256 CYLINDERS!! 
; MAKE SURE THAT EOT CONTAINS THE MAX NUM OF SEC/TRK IN SYSTEM OF FLOPPIES
	CMP	CL,EOT			; MAY SET CARRY 		 
	JBE	EOT_OK							
	MOV	EOT,CL						
EOT_OK: 							
	POP	ES						
	POP	CX						
	POP	DX						
	POP	DI						
	POP	DS						

;
; Check for presence of changeline
;
	mov	AH, 15h      	; set command to get DASD type
	int	13h	     	; call ROM-BIOS
	JC	CHANGELINE_DONE 	
	CMP	AH,02			; CHECK FOR PRESENCE OF CHANGELINE
	JNE	CHANGELINE_DONE 					 
;;End of Modification -----------------------------------------------
;
; We have a drive with change line support.
;
	Message fTestINIT,<"96tpi devices",CR,LF>

	or	CL,fChangeLine		; signal type
	mov	fHave96,1		; Remember that we have 96tpi disks
;									  ;3.30
; WE NOW TRY TO SET UP THE FORM FACTOR FOR THE TYPES OF MEDIA THAT WE KNOW;3.30
; AND CAN RECOGNISE. FOR THE REST, WE SET THE FORM FACTOR AS "OTHER".     ;3.30
;									  ;3.30
CHANGELINE_DONE:							  ;3.30
; 40 CYLINDERS AND 9 OR LESS SEC/TRK, TREAT AS 48 TPI MEDIUM.		  ;3.30
	CMP	NUM_CYLN,40						  ;3.30
	JNZ	TRY_80							  ;3.30
	CMP	SEC_TRK,9						  ;3.30
	JBE	GOT_FF							  ;3.30
GOTOTHER:								  ;3.30
	MOV	DH,FFOTHER		; WE HAVE A "STRANGE" MEDIUM      ;3.30
	JMP	SHORT GOT_FF						  ;3.30
									  ;3.30
;									  ;3.30
; 80 CYLINDERS AND 9 SECTORS/TRACK => 720 KB DEVICE			  ;3.30
; 80 CYLINDERS AND 15 SEC/TRK => 96 TPI MEDIUM				  ;3.30
;									  ;3.30
TRY_80: 								  ;3.30
	CMP	NUM_CYLN,80						  ;3.30
	JNZ	GOTOTHER						  ;3.30
	CMP	SEC_TRK,15						  ;3.30
	JZ	GOT96							  ;3.30
	CMP	SEC_TRK,9						  ;3.30
	JNZ	GOTOTHER						  ;3.30
	MOV	DH,FFSMALL						  ;3.30
	JMP	SHORT GOT_FF						  ;3.30
									  ;3.30
GOT96:									  ;3.30
	MOV	DH,FF96TPI						  ;3.30
									  ;3.30
GOT_FF: 								  ;3.30
	JMP	SHORT NEXTDRIVE 					  ;3.30
									  ;3.30
; AN OLD ROM, SO WE EITHER HAVE A 48TPI OR 96TPI DRIVE. IF THE DRIVE	  ;3.30
; HAS CHANGELINE, WE ASSUME IT IS A 96TPI, OTHERWISE IT IS A 48TPI.	  ;3.30
									  ;3.30
NOPARMSFROMROM: 							  ;3.30
	POP	ES							  ;3.30
	POP	CX							  ;3.30
	POP	DX							  ;3.30
	POP	DI							  ;3.30
	POP	DS							  ;3.30
									  ;3.30
	MOV	AH, 15h 		; SET COMMAND TO GET DASD TYPE    ;3.30
	INT	13h			; CALL ROM-BIOS 	          ;3.30
	JC	NEXTDRIVE						  ;3.30
	CMP	AH,2			; IS THERE CHANGELINE?		  ;3.30
	JNZ	NEXTDRIVE						  ;3.30
	OR	CL,FCHANGELINE						  ;3.30
	MOV	FHAVE96,1		; REMEMBER WE HAVE 96TPI DRIVES   ;3.30
	MOV	NUM_CYLN,80						  ;3.30
	MOV	DH,FF96TPI						  ;3.30
	MOV	AL,15			; SET EOT IF NECESSARY		  ;3.30
	CMP	AL, EOT 						  ;3.30
	JBE	EOT_OK2 						  ;3.30
	MOV	EOT,AL							  ;3.30
EOT_OK2:								  ;3.30

NextDrive:
	or	cl,fI_Own_Physical	; set this true for all drives
	mov	bh,dl			;save Int13 drive number
;
; We need to do special things if we have a single drive system and are setting
; up a logical drive. It needs to have the same Int13 drive number as its
; counterpart, but the next drive letter. Also reset ownership flag.
; We detect the presence of this situation by examining the flag SINGLE for the
; value 2.
;
	cmp	single,2
	jnz	Not_Special
	dec	bh		     ; Int13 drive number same for logical drive
	xor	cl,fI_Own_Physical   ; reset ownership flag for logical drive
Not_Special:
; The values that we put in for RHdlim and RSeclim will only remain if the
; form factor is of type "ffOther".
	xor	ax,ax				; fill BDS for drive
	mov	al,num_heads
	mov	word ptr [di].RHdlim,ax
	mov	al,sec_trk
	mov	word ptr [di].RSeclim,ax
	mov	word ptr [di].flags,cx
	mov	byte ptr [di].FormFactor,dh
	mov	byte ptr [di].DriveLet,dl
	mov	byte ptr [di].DriveNum,bh
	MOV	BL,BYTE PTR NUM_CYLN					  ;3.30
	mov	byte ptr [di].cCyln,bl		; only the l.s. byte is set here
	cmp	single,1			; Special case for single drive system
	jnz	No_Single
	message fTestINIT,<"Single Drive System",CR,LF>
						; Don't forget we have
	mov	single,2			;   single drive system
	or	cx,fI_Am_Mult			; set that this is one of
						;   several drives
	or	word ptr [di].flags,cx		; save flags
	mov	di,word ptr [di].link		; move to next BDS in list
	inc	dl				; add a number
	jmp	short NextDrive 	   ; Use same info for BDS as previous



No_Single:
	inc	dl
	jmp	loop_drive

Done_Drives:
	mov	ax,-1				; Signify end of list by
	mov	word ptr [di].link,ax		;    setting pointer to -1
;
; Set up all the hard drives in the system
;
DoHard:
	MNUM	fTestINIT+fTestHARD,AX
	Message fTestINIT+fTestHARD,<" Hard disk(s) to initialize",CR,LF>
	Message fTestINIT+fTestHARD,<"Hard disk 1",CR,LF>

	CMP	HNUM,0			  ; IF (No_Hard_files)
	JLE	STATIC_CONFIGURE	    ;	THEN EXIT TO CONFIGURE	  ;3.30
	mov	DL, 80h 		    ; set first hard file number
	mov	di,offset BDSH		    ; Set up first hard file.
	mov	bl,HARDNUM
	call	SETHARD
	jnc	HardFile1_OK

	dec	HNUM			  ; First hard file is bad.
	cmp	HNUM,0			  ; IF (Second_Hard_File)
	jg	Second_Hard		    ;	THEN Set up second hard file
	JMP	SHORT STATIC_CONFIGURE					  ;3.30

HardFile1_OK:
	call	Install_BDS		    ; install BDS into linked list
	cmp	HNUM,2			  ; IF (Only_one_hardfile)
	jb	SetIt			    ;	THEN SetIt "in place"

	mov	bl,HARDNUM
	inc	BL			    ; next drive letter
	mov	di,offset BDSX

Second_Hard:				    ; SETUP Second Hard FILE

	Message fTestINIT+fTestHARD,<"Hard disk 2",CR,LF>
	mov	DL, 81h 		    ; set second hard file number
	call	SETHARD
	jnc	HardFile2_OK
	dec	HNUM
	jmp	short SetIt

HardFile2_OK:
	Call	Install_BDS

SETIT:
	mov	al,HNUM
	or	al,al
	JZ	STATIC_CONFIGURE					  ;3.30
	add	al,HARDNUM
	mov	DRVMAX,al

; End of physical drive initialization. 				  ;3.30
; *** Do not change the position of the following statement.
; *** DoMini routine will use [DRVMAX] value for the start of the logical ;3.30
; *** drive number of Mini disk(s).					  ;3.30
									  ;3.30
       call    DoMini		;For setting up mini disks, if found -;3.30

; End of drive initialization.

;9/24/86 We now decide, based on the configurations available so far,;3.30
;what code or data we need to keep as a stay resident code.  The following;3.30
;table shows the configurations under consideration.  They are listed in  ;3.30
;the order of their current position memory.				  ;3.30
;Configuration will be done in two ways:				  ;3.30
;First, we are going to set "Static configuration".  Static configuration ;3.30
;will consider from basic configuration to ENDOF96TPI configuration.	  ;3.30
;The result of static configuration will be the address the Dynamic	  ;3.30
;configuration will use to start with.					  ;3.30
;Secondly, "Dynamic cofiguration" will be performed. Dynamic configuration;3.30
;involves possible relocation of CODE/DATA. Dynamic configuration routine ;3.30
;will take care of BDSM tables and AT ROM Fix module thru K09 suspend/res ;3.30
;code individually. After these operation, FINAL_DOS_LOCATION will be set.;3.30
;This will be the place SYSINIT routine will relocate MSDOS module.	  ;3.30
;									  ;3.30
;   1.	 BASIC CONFIGURATION FOR MSBIO (EndFloppy, EndSwap)		  ;3.30
;   2.	 ENDONEHARD							  ;3.30
;   3.	 ENDTWOHARD							  ;3.30
;   4.	 END96TPI	;a system that supports "Change Line Error"       ;3.30
;   5.	 End of BDSM	;BDSM tables for mini disks.			  ;3.30
;   6.	 ENDATROM	;Some of AT ROM fix module.			  ;3.30
;   7.	 ENDCMOSCLOCKSET;Supporting program for CMOS clock write.	  ;3.30
;   8.	 ENDK09 	;K09 CMOS Clock module to handle SUSPEND/RESUME   ;3.30
;									  ;3.30
;9/24/86.								  ;3.30
									  ;3.30
; *** For mini disk configuration. 4/7/86	 			  ;3.30
; *** END_OF_BDSM will contain the ending address(off) of BDSM table for  ;3.30
; *** mini disks which is located right after the label END96TPI.	  ;3.30
; *** The variable NUM_MINI_DSK will indicate the existance. 4/7/86	  ;3.30
									  ;3.30
									  ;3.30
STATIC_CONFIGURE:							  ;3.30
									  ;3.30
									  ;3.30
	PUSH	AX							  ;3.30
	mov	ax, offset END96TPI	;let's start with the biggest one.;3.30
	cmp	fHave96, 0		;Is change line support there?	  ;3.30
	jnz	Config96		;Yes.				  ;3.30
									  ;3.30
	mov	ax, offset ENDTWOHARD					  ;3.30
	cmp	HNUM, 1 		;1 hard file?			  ;3.30
	jbe	No_Two_HRD						  ;3.30
	jmp	ConfigTwoHard						  ;3.30
No_Two_HRD:								  ;3.30
	mov	ax, offset ENDONEHARD					  ;3.30
	jnz	Basic_Floppy						  ;3.30
	jmp	ConfigOneHard						  ;3.30
Basic_Floppy:								  ;3.30
	mov	ax, offset ENDFLOPPY					  ;3.30
	jmp	Dynamic_Configure	;static configuration is done!	  ;3.30

;
; Keep the 96tpi code
;
Config96:
;
; Save old INT 13 vector
;
	PUSH	AX
	PUSH	DS
	XOR	AX,AX
	MOV	DS,AX
	ASSUME	DS:NOTHING						  ;3.30
	MOV	AX,DS:[4 * 13h]
	MOV	WORD PTR CS:Real13,AX
	MOV	AX,DS:[4 * 13h+2]
	MOV	WORD PTR CS:Real13+2,AX
;
; Insert new vector
;
	MOV	WORD PTR DS:[4 * 13h],OFFSET INT13
	MOV	DS:[4 * 13h + 2],CS
	POP	DS
	ASSUME DS:CODE							  ;3.30
	POP	AX
;
; Keep two hard disk BPBs
;
ConfigTwoHard:
;
; Keep one hard disk BPB
;
ConfigOneHard:
;
; Adjust the number of drives to include the hard disks.
;
	PUSH	AX
	MOV	AL,HardNum
	ADD	AL,HNum
	add	al, num_mini_dsk ;4/7/86 for mini disks installed	  ;3.30
				;if not installed, then num_mini_dsk = 0. ;3.30
	MOV	DrvMax,AL
	POP	AX

DYNAMIC_CONFIGURE:							  ;3.30
	call	Get_Para_Offset 	;For dynamic allocation, we are   ;3.30
					;going to use offset address that ;3.30
					;is in paragraph boundary.	  ;3.30
	push	cs							  ;3.30
	pop	es			;es -> code			  ;3.30
	assume	es:code 						  ;3.30
	cld				;clear direction		  ;3.30
									  ;3.30
	cmp	[num_mini_dsk], 0	;Mini disk(s) installed ?	  ;3.30
	jz	CheckATROM		;No.				  ;3.30
	mov	ax, End_Of_BDSM 	;set the new ending address	  ;3.30
	call	Get_Para_Offset 					  ;3.30
CheckATROM:								  ;3.30
	cmp	Model_Byte, 0FCh	;AT ?				  ;3.30
	jnz	CheckCMOSClock						  ;3.30
	cmp	HNUM, 0 		;No hard file?			  ;3.30
	jz	CheckCMOSClock						  ;3.30
	mov	si, 0F000h						  ;3.30
	mov	es, si			;ES -> BIOS segment		  ;3.30
	assume	es:nothing						  ;3.30
	mov	si, offset BIOS_DATE					  ;3.30
	mov	di, 0FFF5H		;ROM BIOS string is at F000:FFF5  ;3.30
Cmpbyte:				;Only patch ROM for bios 01/10/84 ;3.30
	cmpsb								  ;3.30
	jnz	CheckCMOSClock						  ;3.30
	cmp	byte ptr [si-1],0					  ;3.30
	jnz	Cmpbyte 						  ;3.30
									  ;3.30
SetRomCode:				;Now we have to install ROM fix   ;3.30
					;AX is the address to move.	  ;3.30
	push	cs							  ;3.30
	pop	es			;set ES to CODE seg		  ;3.30
	assume	es:code 						  ;3.30
	mov	word ptr ORIG13, ax					  ;3.30
	mov	word ptr ORIG13+2, cs	;set new ROM bios int 13 vector   ;3.30
	mov	cx, offset ENDATROM					  ;3.30
	mov	si, offset IBM_DISK_IO					  ;3.30
	sub	cx, si			;size of AT ROM FIX module	  ;3.30
	mov	di, ax			;destination			  ;3.30
	rep	movsb			;relocate it			  ;3.30
	mov	ax, di			;new ending address		  ;3.30
	call	Get_Para_Offset 	;in AX				  ;3.30
									  ;3.30
CheckCMOSClock: 							  ;3.30
	push	cs							  ;3.30
	pop	es			;set ES to CODE seg		  ;3.30
	assume	es:code 						  ;3.30
	cmp	HaveCMOSClock, 1	;CMOS Clock exists?		  ;3.30
	jne	CheckK09						  ;3.30
	mov	DaycntToDay, ax 	;set the address for MSCLOCK	  ;3.30
	mov	cx, offset EndDaycntToDay				  ;3.30
	mov	si, offset Daycnt_To_Day				  ;3.30
	sub	cx, si			;size of CMOS clock sup routine   ;3.30
	mov	di, ax							  ;3.30
	rep	movsb							  ;3.30
	mov	ax, di							  ;3.30
	call	Get_Para_Offset 					  ;3.30
	mov	BinToBCD, ax		;set the address for MSCLOCK	  ;3.30
	mov	cx, offset EndCMOSClockSet				  ;3.30
	mov	si, offset Bin_To_BCD					  ;3.30
	sub	cx, si							  ;3.30
	mov	di, ax							  ;3.30
	rep	movsb							  ;3.30
	mov	ax, di							  ;3.30
	call	Get_Para_Offset 					  ;3.30
									  ;3.30
CheckK09:								  ;3.30
	push	ax			;save ax	     		  ;3.30*
	mov	ax,4100h		;Q: is it a K09 	          ;3.30*
	mov	bl,0			;			          ;3.30*
	int	15h			;			          ;3.30*
	pop	ax							  ;3.30
	jc	CONFIGDONE						  ;3.30
									  ;3.30
	mov	si, offset INT6C					  ;3.30
	mov	cx, offset ENDK09					  ;3.30
	sub	cx, si			;size of K09 routine		  ;3.30
	mov	di, ax							  ;3.30
	push	di			;save destination		  ;3.30
	rep	movsb							  ;3.30
	mov	ax, di			;				  ;3.30
	call	Get_Para_Offset 	;AX = new ending address	  ;3.30
	pop	di							  ;3.30
									  ;3.30
	push	ax							  ;3.30
	push	ds							  ;3.30
	mov	fHaveK09, 1		;remember we have a K09 type	  ;3.30
	xor	ax,ax							  ;3.30
	mov	ds, ax							  ;3.30
	assume	ds:nothing						  ;3.30
									  ;3.30
	mov	word ptr ds:[4 * 6Ch], di ;new INT 6Ch handler		  ;3.30
	mov	ds:[4 * 6Ch +2], cs					  ;3.30
									  ;3.30
	pop	ds							  ;3.30
	assume	ds:code 						  ;3.30
	pop	ax			;restore the ending address	  ;3.30

;
; Set up config stuff for SYSINIT
;
ConfigDone:
	MOV	DX,SYSINITSEG
	MOV	DS,DX
	ASSUME	DS:SYSINITSEG
	SUB	AX,OFFSET START$					  ;3.30
	ADD	AX,15
	RCR	AX,1
	SHR	AX, 1
	SHR	AX, 1
	SHR	AX, 1
	MOV	FINAL_DOS_LOCATION, AX
	POP	AX

GOINIT:
	ADD	Final_DOS_Location,CODE
	Message fTestINIT,<"Final DOS location is ">
	MNUM	fTestINIT,Final_DOS_Location
	Message fTestINIT,<CR,LF>
	PUSH	CS
	POP	DS

	ASSUME	DS:CODE,ES:NOTHING

	CMP	BYTE PTR fHave96,0
	JNZ	ReadDos
	call	purge_96tpi		;mjb001 eliminate calls to 96tpi hoohah

ReadDos:
	Message fTestINIT,<"Load FAT",CR,LF>
	mov	ax,DRVFAT	      ; Get drive and FAT ID
	call	SetDrive		; Get BDS for drive
	call	GetBP			; Ensure valid BPB is present
	call	GETFAT			; Read in the FAT sector
	xor	DI,DI
	mov	AL,ES:[DI]		; Get fat id byte
	mov	BYTE PTR DRVFAT+1,AL	; Save FAT byte
	mov	AX,DRVFAT
	Message fTestINIT,<"FATID read ">
	mnum	ftestinit,ax
	message ftestinit,<cr,lf>
	call	SETDRIVE		; Get Correct BDS for this drive
	mov	BL,[DI].FatSiz		; get size of fat on media
	mov	fBigFat,BL
	mov	CL,[DI].SecPerClus	; get sectors/cluster
	mov	AX,[DI].HIDSEC		; get number of hidden sectors
	sub	BIOS$,AX	      ; subtract hidden sector offset
	xor	CH,CH			; CX = sectors/cluster
;
;	THE BOOT PROGRAM HAS LEFT THE DIRECTORY AT 0:500
;
	PUSH	DS
	XOR	DI,DI
	MOV	DS,DI			; ES:DI POINTS TO LOAD LOCATION
	MOV	BX,DS:WORD PTR [53AH]	;   clus=*53A;
	POP	DS			;
	Message fTestINIT,<"Load DOS",CR,LF>
; BAS DEBUG
;LOADIT: MOV	 AX,((((OFFSET END$)-(OFFSET START$))+15)/16)+SYSIZE
LOADIT:
	MOV	AX, OFFSET END$ 					  ;3.30
	SUB	AX, OFFSET START$					  ;3.30
	ADD	AX, 15
	RCR	AX, 1			; DIVIDE BY 16
	SHR	AX, 1
	SHR	AX, 1
	SHR	AX, 1
	ADD	AX, SYSIZE

	ADD	AX,CODE

	MOV	ES,AX			;
	CALL	GETCLUS 		;	clus = GetClus (clus);

IsEof:
	TEST	fBigFat,fBIG		;   if (fBigFAT)
	JNZ	EOFBig
	Message fTestINIT,<CR,LF,"Small FAT EOF check",CR,LF>
	CMP	BX,0FF7h		;	return (clus > 0ff7h);
	JMP SHORT ISEOFX						  ;3.30
EOFBig:
	Message fTestINIT,<CR,LF,"Big FAT EOF check",CR,LF>
	CMP	BX,0FFF7h		;   else
ISEOFX: 								  ;3.30
	JB	LOADIT			;   } WHILE (!ISEOF (CLUS));	  ;3.30
									  ;3.30
	CALL	SETDRVPARMS						  ;3.30
									  ;3.30
	MESSAGE FTESTINIT,<"SYSINIT",CR,LF>                               ;3.30
	ZWAIT								  ;3.30
	MESSAGE FTESTINIT,<"ON TO SYSINIT...",CR,LF>                      ;3.30
	JMP	SYSINIT 						  ;3.30
									  ;3.30
INIT	ENDP								  ;3.30
									  ;3.30
;****************************						  ;3.30
									  ;3.30
Get_Para_Offset proc	near						  ;3.30
;in:  AX - offset value 						  ;3.30
;out: AX - offset value adjusted for the next paragraph boundary.	  ;3.30
	add	ax, 15		;make a paragraph			  ;3.30
	rcr	ax, 1							  ;3.30
	shr	ax, 1							  ;3.30
	shr	ax, 1							  ;3.30
	shr	ax, 1							  ;3.30
	shl	ax, 1		;now, make it back to offset value	  ;3.30
	shl	ax, 1							  ;3.30
	shl	ax, 1							  ;3.30
	shl	ax, 1							  ;3.30
	ret								  ;3.30
Get_Para_Offset endp							  ;3.30

;
;	READ A FAT SECTOR INTO fat location
;
GETFAT	PROC	NEAR							  ;3.30
	XOR	DI,DI			; offset
	MOV	DX,1			; relative sector (1st sector of fat)
	MOV	CX,FatLen		; read entire fat.
	MOV	AX,FatLoc		;
	MOV	ES,AX			; location to read
	MOV	AX,DRVFAT	      ; AH FAT ID byte, AL drive
	JMP	DISKRD
GETFAT	ENDP								  ;3.30


;
;	READ A BOOT RECORD INTO 7C0:BootBias
;  GetBoot reads the boot record into 7C0:BootBias
;  On Entry:
;	DL contains ROM drive number (80 or 81)
;  On Exit:
;	if carry set error
;	if carry clear:
;	   ES:BX piont to boot sector
;	AX and CX are not preserved
;	BX and ES are used to return values
;
GETBOOT PROC	NEAR
	mov	AX, 07C0h     ; prepare to load ES
	mov	ES, AX	      ; load ES segment register
	mov	BX, BootBias  ; load BX,  ES:BX is where sector goes
	mov	AX, 0201h     ; command to read & num sec. to 1
	xor	DH, DH	      ; head number zero
	mov	CX, 0001h     ; cylinder zero and sector one
	int	13h	      ; call rom bios
	jc	ERRET
	cmp	WORD PTR ES:[BootBias+1FEH],0AA55H   ; DAVE LITTON MAGIC BYTE?
	jz	Norm_Ret
	message ftesthard,<"Signature AA55 not found",cr,lf>
ERRET:
	message ftesthard,<"Error in Getboot",cr,lf>
	STC
Norm_Ret:
	RET
GETBOOT ENDP								  ;3.30
;
;   SetHard - generate BPB for a variable sized hard file.  IBM has a
;   partitioned hard file; we must read physical sector 0 to determine where
;   our own logical sectors start.  We also read in our boot sector to
;   determine version number
;
;   Inputs:	DL is ROM drive number (80 OR 81)
;		DS:DI points to BDS
;   Outputs:	Carry clear -> BPB is filled in
;		Carry set   -> BPB is left uninitialized due to error
;

SETHARD PROC	NEAR							  ;3.30
	push	di
	push	bx
	push	ds
	mov	byte ptr [di].DriveLet,bl
	mov	byte ptr [di].DriveNum,dl
	xor	ax,ax
	or	al,fNon_Removable
	or	word ptr [di].flags,ax
	mov	byte ptr [di].FormFactor,ffHardFile
	MOV	fBigFat,0			; Assume 12 bit FAT
	PUSH	DX

	mov	AH, 8		 	; set command to get drive parameters
	int	13h		 	; call rom-bios disk routine

			; DH is number of heads-1
			; DL is number of hard disks attached
			; Low 6 bits of CL is sectors/track
			; High 2 bits of CL with CH are max # of cylinders
	INC	DH			; get number of heads
	MOV	BYTE PTR [DI].HDLIM,DH
	POP	DX
	JC	SETRET			; carry here means no hard disk
	AND	CL,3FH			; extract number of sectors/track
	MOV	BYTE PTR [DI].SECLIM,CL
	CALL	GETBOOT 		;   if (getBoot ())
	JC	SETRET			;	return -1;
	MOV	BX,1C2H+BootBias	;   p = &boot[0x1C2];
SET1:
	CMP	BYTE PTR ES:[BX],1	;   while (p->PartitionType != 1 &&
	JZ	SET2
	CMP	Byte Ptr ES:[BX],4	;	p->PartitionType != 4) {
	JZ	Set2
	ADD	BX,16			;	p += sizeof Partition;
	CMP	BX,202H+BootBias	;	if (p == &boot[0x202h])
	JNZ	SET1			;	    return -1;
SETRET:
	STC				;	}
	jmp	Ret_Hard

SET2:
	PUSH	DX
	MOV	AX,WORD PTR ES:[BX+4]
	MOV	DX,WORD PTR ES:[BX+6]

;Decrement the sector count by 1 to make it zero based. Exactly 64k	  ;3.30
;sectors should be allowed						  ;3.30
;									  ;3.30
	SUB	AX,1			; PTM 901    12/12/86 MT	  ;3.30
	SBB	DX,0			; PTM 901    12/12/86 MT	  ;3.30

	ADD	AX,WORD PTR ES:[BX+8]
	ADC	DX,WORD PTR ES:[BX+10]
	JZ	OKDrive
	Message fTestHard,<"Partition invalid",CR,LF>
	OR	fBigFat,fTOOBIG
OKDrive:
	POP	DX
	MOV	AX,WORD PTR ES:[BX+4]
	MOV	[DI].HIDSEC,AX		;   BPB->HidSecCt = p->PartitionBegin;
	MOV	AX,WORD PTR ES:[BX+8]
	CMP	AX,64			;   if (p->PartitionLength < 64)
	JB	SETRET			;	return -1;

	MOV	WORD PTR [DI].DRVLIM,AX ;   BPB->MaxSec = p->PartitionLength;
	PUSH	AX

	PUSH	DX
	MOV	AX,[DI].HidSec		; boot sector number
	XOR	DX,DX
	MOV	BH,DH
	MOV	BL,byte ptr [DI].SecLim
	DIV	BX
	MOV	CL,DL			; CL is sector number
	INC	CL			; sectors are 1 based
	CWD
	MOV	BL,byte ptr [DI].HdLim
	DIV	BX			; DL is head, AX is cylinder
;
; DL is head.
; AX is cylinder
; CL is sector number
; TOS is drive
;

;*** For Mini Disks ***  4/7/86					  ;3.30
	cmp	word ptr [di].IsMini, 1 ;check for mini disk - 4/7/86 ;3.30
	jnz	OKnotMini		;not mini disk. - 4/7/86	  ;3.30
	add	ax, [di].hidden_trks	;set phy track num - 4/7/86   ;3.30
OKnotMini:				; 4/7/86			  ;3.30
;*** End of added logic for mini disk					  ;3.30

	ROR	AH,1			; move high two bits of cyl to high
	ROR	AH,1			; two bits of upper byte
	AND	AH,0C0h 		; turn off remainder of bits
	OR	CL,AH			; move two bits to correct spot
	MOV	CH,AL			; CH is Cylinder
;
; CL is sector + 2 high bits of cylinder
; CH is low 8 bits of cylinder
; DL is head
; TOS is drive
;
	POP	AX			; AL is drive
	MOV	DH,DL			; DH is head
	MOV	DL,AL			; DL is drive
;
; CL is sector + 2 high bits of cylinder
; CH is low 8 bits of cylinder
; DH is head
; DL is drive
;
	xor	BX, BX			; clear BX -- ES:BX points to buffer
	mov	ax, 0201h		; set command to read one sector
	int	13h			; call rom-bios to read sector
	pop	AX

;
; ES:[0] points to the boot sector.  In theory, (ha ha) the BPB in this thing
; is correct.  We can, therefore, pull out all the relevant statistics on the
; media if we recognize the version number.
;
	CMP	WORD PTR ES:[3], "B" SHL 8 + "I"
	JNZ	Unknownj
	CMP	WORD PTR ES:[5], " " SHL 8 + "M"
	JNZ	Unknownj
	CMP	WORD PTR ES:[8], "." SHL 8 + "2"
	JNZ	Try5
	CMP	BYTE PTR ES:[10], "0"
	JNZ	Try5
	Message fTestHard,<"Version 2.0 media",CR,LF>
	JMP	SHORT CopyBPB
unknownj:
	jmp	unknown
Try5:
	CMP	WORD PTR ES:[8],"." SHL 8 + "3"
	JNZ	Unknownj
	cmp	byte ptr es:[10],"1" ;do not trust 3.0 boot record.  4/15/86;3.30
	jb	unknownj	    ;if version >= 3.1, then O.K.  4/15/86	;3.30
	Message ftestHard,<"VERSION 3.1 OR ABOVE MEDIA",CR,LF>

CopyBPB:
; We have a valid Boot sector. Use the BPB in it to build the
; BPB in BIOS. It is assumed that ONLY SecPerClus, cDIR, and
; cSecFat need to be set (all other values in already). fBigFat
; is also set.
	MOV	AX,WORD PTR ES:[11+DRVLIM-BytePerSec]	   ; Total sectors
	MNUM	fTestHard,AX
	Message fTestHard,<" Sec ">
	DEC	AX				; Subtract # reserved (always 1)
	MOV	DX,WORD PTR ES:[11+cSecFAT-BytePerSec]	   ; Sectors for 1 fat
	MNUM	fTestHard,DX
	Message fTestHard,<" Sec/Fat ">
	MOV	[DI+cSecFAT],DX 		; Set in BIOS BPB
	SHL	DX,1				; Always 2 FATs
	SUB	AX,DX				; Sub # FAT sectors
	MOV	DX,WORD PTR ES:[11+cDIR-BytePerSec]	   ; # root entries
	MOV	[DI+cDIR],DX			; Set in BIOS BPB
	MNUM	fTestHard,DX
	Message fTestHard,<" directory entries ">
	MOV	CL,4
	SHR	DX,CL				; Div by 16 ents/sector
	SUB	AX,DX				; Sub # dir sectors
	; AX now contains the # of data sectors.
	MOV	CL,BYTE PTR ES:[11+SecPerClus-BytePerSec]  ; Sectors per cluster
	MOV	[DI.SecPerClus],CL		; Set in BIOS BPB
	XOR	DX,DX
	MOV	CH,DH
	MNUM	fTestHard,CX
	Message fTestHard,<" SecPerClus",CR,LF>
	DIV	CX
	; AX now contains the # clusters.
	CMP	AX,4096-10		; is this 16-bit fat?
	JB	GoodRetj		; No
	OR	fBigFat,fBIG		; 16 bit FAT
GoodRetj:
	JMP	GoodRet

Unknown:
	Message fTestHard,<"Unknown hard media. Assuming 3.0.",CR,LF>
	MOV	SI,OFFSET DiskTable2
Scan:
	CMP	AX,[SI]
	JBE	GotParm
	ADD	SI,4 * 2
	JMP	Scan
GotParm:
	MOV	CL,BYTE PTR [SI+6]
	OR	fBigFat,CL
	MOV	CX,[SI+2]
	MOV	DX,[SI+4]
;
;	AX = number of sectors on disk drive
;	DX = number of dir entries,
;	CH = number of sectors per cluster
;	CL = log base 2 of ch
;
;	NOW CALCULATE SIZE OF FAT TABLE
;
	MNUM	fTestHard,AX
	Message fTestHard,<" sectors ">
	MNUM	fTestHard,DX
	Message fTestHard,<" directory entries ">
	MNUM	fTestHard,CX
	Message fTestHard,<" SecPerClus|ClusShift">
	MOV	WORD PTR cDir[DI],DX	;SAVE NUMBER OF DIR ENTRIES
	MOV	BYTE PTR SecPerClus[DI],CH  ;SAVE SECTORS PER CLUSTER
	TEST	fBigFAT,fBIG		;   if (fBigFat)
	JNZ	DoBig			;	goto DoBig;
	Message fTestHard,<" Small fat",CR,LF>
	XOR	BX,BX
	MOV	BL,CH
	DEC	BX
	ADD	BX,AX
	SHR	BX,CL			;   BX = 1+(BPB->MaxSec+SecPerClus-1)/
	INC	BX			;	    SecPerClus
	AND	BL,11111110B		;   BX &= ~1; (=number of clusters)
	MOV	SI,BX
	SHR	BX,1
	ADD	BX,SI
	ADD	BX,511			;   BX += 511 + BX/2
	SHR	BH,1			;   BH >>= 1; (=BX/512)
	MOV	BYTE PTR [DI].cSecFat,BH ;SAVE NUMBER OF FAT SECTORS
	JMP	SHORT GOODRET						  ;3.30
DoBig:
	Message fTestHard,<" Big fat",CR,LF>
	MOV	CL,4			; 16 (2^4) directory entries per sector
	SHR	DX,CL			; cSecDir = cDir / 16;
	SUB	AX,DX			; AX -= cSecDir; AX -= cSecReserved;
	DEC	AX			; ax = t - r - d
	MOV	BL,2
	MOV	BH,SecPerClus[DI]	; bx = 256 * secperclus + 2
	XOR	DX,DX
	ADD	AX,BX			; ax = t-r-d+256*spc+2
	ADC	DX,0
	SUB	AX,1			; ax = t-r-d+256*spc+1
	SBB	DX,0
	DIV	BX			; cSecFat = ceil((total-dir-res)/
					;		 (256*secperclus+2));
	MOV	WORD PTR [DI].cSecFat,AX ; number of fat sectors
GoodRet:
	MOV	BL,fBigFat
	MOV	[DI].FatSiz,BL		; set size of fat on media
	CLC
Ret_Hard:
	pop	ds
	pop	bx
	pop	di
	RET
SETHARD ENDP								  ;3.30


;
; SetDrvParms sets up the recommended BPB in each BDS in the system based on
; the form factor. It is assumed that the BPBs for the various form factors
; are present in the BPBTable. For hard files, the Recommended BPB is the same
; as the BPB on the drive.
; No attempt is made to preserve registers since we are going to jump to
; SYSINIT straight after this routine.
;
SETDRVPARMS PROC NEAR							  ;3.30
	message ftestinit,<"Setting Drive Parameters",cr,lf>
	xor	bx,bx
	les	di,dword ptr cs:[Start_BDS]  ; get first BDS in list
Next_BDS:
	cmp	di,-1
	jnz	Do_SetP
Done_SetParms:
	RET
Do_SetP:
	push	es
	push	di			; preserve pointer to BDS
	mov	bl,es:[di].FormFactor
	cmp	bl,ffHardFile
	jnz	NotHardFF
	mov	ax,es:[di].DrvLim
	push	ax
	mov	ax,word ptr es:[di].hdlim
	mul	word ptr es:[di].seclim
	mov	cx,ax			; cx has # sectors per cylinder
	pop	ax
	xor	dx,dx			; set up for div
	div	cx			; div #sec by sec/cyl to get # cyl
	or	dx,dx
	jz	No_Cyl_Rnd		; came out even
	inc	ax			; round up
No_Cyl_Rnd:
	mov	es:[di].cCyln,ax
	message ftestinit,<"Ccyln ">
	MNUM	ftestinit,AX
	message ftestinit,<cr,lf>
	push	es
	pop	ds
	lea	si,[di].BytePerSec	; ds:si -> BPB for hard file
	jmp	short Set_RecBPB
NotHardFF:
	push	cs
	pop	ds
	cmp	bl,ffOther		; Special case "other" type of medium
	JNZ	NOT_PROCESS_OTHER					  ;3.30
Process_Other:
	xor	dx,dx
	mov	ax,[di].cCyln
	mov	bx,[di].RHdlim
	mul	bx
	mov	bx,[di].RSeclim
	mul	bx
	mov	[di].RDrvlim,ax 	; Have the total number of sectors
	dec	ax

; New logic to get the sectors/fat area.				  ;3.30
					;Fat entry assumed to be 1.5 bytes;3.30
	mov	bx, 3							  ;3.30
	mul	bx							  ;3.30
	mov	bx,2							  ;3.30
	div	bx							  ;3.30
	xor	dx, dx							  ;3.30
	mov	bx, 512 						  ;3.30
	div	bx							  ;3.30
	inc	ax							  ;3.30

No_Round_Up:
	mov	[di].RcSecFat,ax
	jmp	short Go_To_Next_BDS

NOT_PROCESS_OTHER:							  ;3.30
	shl	bx,1			; bx is word index into table of BPBs
	mov	si,offset BPBTable
	mov	si,word ptr [si+bx]	; get address of BPB
Set_RecBPB:
	lea	di,[di].RBytePerSec	    ; es:di -> RecBPB
	mov	cx,BPBSIZ
	REP	MOVSB			; MOVE BPBSIZ BYTES		  ;3.30
Go_To_Next_BDS:
	pop	di
	pop	es			; restore pointer to BDS
	mov	bx,word ptr es:[di].link+2
	mov	di,word ptr es:[di].link
	mov	es,bx
	jmp	Next_BDS
SETDRVPARMS ENDP							  ;3.30


;
;  READ CLUSTER SPECIFIED IN BX
;  CX = SECTORS PER CLUSTER
;  DI = LOAD LOCATION
;
GETCLUS PROC	NEAR							  ;3.30
	PUSH	CX
	PUSH	DI
	MOV	DOSCNT,CX	      ;SAVE NUMBER OF SECTORS TO READ
	MOV	AX,BX
	DEC	AX
	DEC	AX
	MUL	CX			;CONVERT TO LOGICAL SECTOR
	ADD	AX,BIOS$	      ;ADD IN FIRST DATA SECTOR
	MOV	DX,AX			;DX = FIRST SECTOR TO READ

GETCL1:
	MNUM	fTestINIT
	Message fTestINIT,<" => ">
					;SI = BX, BX = NEXT ALLOCATION UNIT
;
;	GET THE FAT ENTRY AT BX, WHEN FINISHED SI=ENTRY BX
;
UNPACK:
	PUSH	DS
	PUSH	BX
	MOV	SI,FatLoc
	TEST	fBigFat,fBIG		;   if (!fBigFat) {
	JNZ	Unpack16
	MOV	DS,SI
	MOV	SI,BX
	SHR	SI,1
	MOV	BX,[SI+BX]		;	p = fat[clus+clus/2];
	JNC	HAVCLUS 		;	if (clus&1)
	SHR	BX,1			;	    p >>= 4;
	SHR	BX,1
	SHR	BX,1
	SHR	BX,1
HAVCLUS:
	AND	BX,0FFFH		;	oldclus=clus; clus = p & 0xFFF;
	JMP	SHORT UNPACKX						  ;3.30
Unpack16:				;   else {
	MOV	DS,SI
	SHL	BX,1			;	oldclus = clus;
	MOV	BX,[BX] 		;	clus = fat[2*clus];
UNPACKX:								  ;3.30
	POP	SI			;	return;
	POP	DS
					;	}
	MNUM	fTestINIT
	Message fTestINIT,<"    ">
	SUB	SI,BX
	CMP	SI,-1			;one apart?
	JNZ	GETCL2
	ADD	DOSCNT,CX
	JMP	GETCL1

GETCL2:
	PUSH	BX
	MOV	AX,DRVFAT	      ;GET DRIVE AND FAT SPEC
	MOV	CX,DOSCNT
	CALL	DISKRD			;READ THE CLUSTERS
	POP	BX
	POP	DI
	MOV	AX,DOSCNT	      ;GET NUMBER OF SECTORS READ
	XCHG	AH,AL			;MULTIPLY BY 256
	SHL	AX,1			;TIMES 2 EQUAL 512
	ADD	DI,AX			;UPDATE LOAD LOCATION
	POP	CX			;RESTORE SECTORS/CLUSTER
	RET
GETCLUS ENDP				;   RETURN;			  ;3.30

;
; SI POINTS TO DEVICE HEADER
;
;  4/22/86 - print_init, aux_init is modified to eliminate the	  ;3.30
;  self-modifying code.						  ;3.30
									  ;3.30
PRINT_INIT:								  ;3.30
	call	Get_device_number					  ;3.30
	mov	ah,1			;initalize printer port        ;3.30
	int	17h			;call ROM-Bios routine	       ;3.30
	ret								  ;3.30
									  ;3.30
AUX_INIT:								  ;3.30
	call	Get_device_number					  ;3.30
	mov	al,RSINIT		;2400,N,1,8 (MSEQU.INC)       ;3.30*
	mov	ah,0			;initalize AUX port	      ;3.30*
	int	14h			;call ROM-Bios routine	      ;3.30*
	ret								  ;3.30
									  ;3.30
GET_DEVICE_NUMBER:							  ;3.30
;SI -> device header							  ;3.30
	MOV	AL,CS:[SI+13]		;GET DEVICE NUMBER FROM THE NAME  ;3.30
	SUB	AL,"1"                                                    ;3.30
	CBW								  ;3.30
	MOV	DX,AX							  ;3.30
	RET								  ;3.30

;
;   purge_96tpi NOP's calls to 96tpi support.
;
PURGE_96TPI PROC NEAR			;MJB001 			  ;3.30
	PUSH	DS
	PUSH	ES

	push	cs			;mjb001
	pop	es			;mjb001
	push	cs			;mjb001
	pop	ds			;mjb001
	ASSUME	DS:CODE,ES:CODE 					  ;3.30
	MOV	SI,OFFSET PatchTable
PatchLoop:
	LODSW
	MOV	CX,AX
	JCXZ	PatchDone
	LODSW
	MOV	DI,AX
	MOV	AL,90h
	REP	STOSB
	JMP	PatchLoop

PatchDone:
	mov	di,offset TABLE_PATCH	    ; ARR 2.42
	MOV	AX,OFFSET EXIT
	STOSW
	STOSW

	POP	ES
	POP	DS
	ret				;mjb001
PURGE_96TPI ENDP							  ;3.30

;Mini disk initialization routine. Called right after DoHard -  4/7/86;3.30
; DoMini **************************************************************** ;3.30
; **CS=DS=ES=code							  ;3.30
; **DoMini will search for every extended partition in the system, and	  ;3.30
;   initialize it.							  ;3.30
; **BDSM stands for BDS table for Mini disk and located right after the   ;3.30
;   label End96Tpi.  End_Of_BDSM will have the offset value of the ending ;3.30
;   address of BDSM table.						  ;3.30
; **BDSM is the same as usual BDS except that TIM_LO, TIM_HI entries are  ;3.30
;   overlapped and used to id mini disk and the number of Hidden_trks.	  ;3.30
;   Right now, they are called as IsMini, Hidden_Trks respectively.	  ;3.30
; **DoMini will use the same routine in SETHARD routine after label SET1  ;3.30
;   to save coding.							  ;3.30
; **DRVMAX determined in DoHard routine will be used for the next	  ;3.30
;   available logical mini disk drive number.				  ;3.30
;									  ;3.30
; Input: DRVMAX, DSKDRVS						  ;3.30
;									  ;3.30
; Output: MiniDisk installed. BDSM table established and installed to BDS.;3.30
;	  num_mini_dsk -  number of mini disks installed in the system.   ;3.30
;	  End_Of_BDSM - ending offset address of BDSM.			  ;3.30
;									  ;3.30
;									  ;3.30
; Called modules:							  ;3.30
;		  GetBoot, WRMSG, int 13h (AH=8, Rom)			  ;3.30
;		  FIND_MINI_PARTITION (new), Install_BDSM (new),	  ;3.30
;		  SetMini (new, it will use SET1 routine)		  ;3.30
; Variables used: End_Of_BDSM, numh, mininum, num_mini_dsk,		  ;3.30
;		  Rom_Minidsk_num, Mini_HDLIM, Mini_SECLIM		  ;3.30
;		  BDSMs, BDSM_type (struc), Start_BDS			  ;3.30
;************************************************************************ ;3.30
;									  ;3.30
									  ;3.30
DoMini: 								  ;3.30
	Message fTestHard,<"Start of DoMini...",cr,lf>                    ;3.30
									  ;3.30
	push	ax			;Do I need to do this?		  ;3.30
									  ;3.30
	mov	di, offset BDSMs	;from now on, DI points to BDSM   ;3.30
	mov	dl, 80h 		;look at first hard drive     ;3.30*
	mov	ah, 8h			;get drive parameters	      ;3.30*
	int	13h			;call ROM-Bios		      ;3.30*
	cmp	dl, 0							  ;3.30
	jz	DoMiniRet		;no hard file? Then exit.	  ;3.30
	mov	numh, dl		;save the number of hard files.   ;3.30
	xor	ax,ax							  ;3.30
	mov	al, drvmax						  ;3.30
	mov	mininum, al		;this will be logical drive letter;3.30
					;for mini disk to start with.	  ;3.30
									  ;3.30
	shl	ax, 1			;ax=number of devices. word bndry ;3.30
	push	bx							  ;3.30
	mov	bx, offset DSKDRVS					  ;3.30
	add	bx, ax							  ;3.30
	mov	Mini_BPB_ptr, BX	;Mini_BPB_ptr points to first avlb;3.30
					;spot in DskDrvs for Mini disk	  ;3.30
					;which points to BPB area of BDSM.;3.30
	pop	bx							  ;3.30
									  ;3.30
	mov	Rom_Minidsk_num, 80h					  ;3.30
DoMiniBegin:								  ;3.30
	inc	dh			;Get # of heads (conv to 1 based) ;3.30
	xor	ax, ax							  ;3.30
	mov	al, dh							  ;3.30
	mov	Mini_HDLIM, ax		;save it.			  ;3.30
	xor	ax, ax							  ;3.30
	and	cl, 3fh 		;Get # of sectors/track 	  ;3.30
	mov	al, cl							  ;3.30
	mov	Mini_SECLIM, ax 	;and save it.			  ;3.30
									  ;3.30
	mov	dl, Rom_Minidsk_num	;drive number <DL>		  ;3.30
	call	GETBOOT 		;rd master boot rec 7c0:BootBias  ;3.30
	jc	DoMiniNext						  ;3.30
	call	FIND_MINI_PARTITION					  ;3.30
DoMiniNext:								  ;3.30
	dec	numh							  ;3.30
	jz	DoMiniRet						  ;3.30
	inc	Rom_MiniDsk_Num 	;Next hard file 		  ;3.30
	mov	dl, Rom_MiniDsk_Num	;look at next hard drive      ;3.30*
	mov	ah, 8h			;get drive parameters	      ;3.30*
	int	13h			;call ROM-Bios		      ;3.30*
	jmp	DoMiniBegin						  ;3.30
									  ;3.30
DoMiniRet:								  ;3.30
	pop	ax							  ;3.30
	ret								  ;3.30
									  ;3.30
									  ;3.30
;Find_Mini_Partition tries to find every Extended partition on a disk.	  ;3.30
;At entry:	DI -> BDSM entry					  ;3.30
;		ES:BX -> 07c0:BootBias - Master Boot Record		  ;3.30
;		Rom_MiniDsk_Num  - ROM drive number			  ;3.30
;		MiniNum - Logical drive number				  ;3.30
;		Mini_HDLIM, Mini_SECLIM 				  ;3.30
;									  ;3.30
;Called routine: SETMINI which uses SET1 (in SETHARD routine)		  ;3.30
;Variables & equates used from orig BIOS - flags, fNon_Removable, fBigfat ;3.30
;									  ;3.30
;									  ;3.30
FIND_MINI_PARTITION:							  ;3.30
									  ;3.30
	add	bx, 1C2h		;BX -> system id.		  ;3.30
									  ;3.30
FmpNext:								  ;3.30
	cmp	byte ptr ES:[BX], 5	; 5 = extended partition ID.	  ;3.30
	jz	FmpGot							  ;3.30
	add	bx, 16			; for next entry		  ;3.30
	cmp	bx, 202h+BootBias					  ;3.30
	jnz	FmpNext 						  ;3.30
	jmp	FmpRet			;not found extended partition	  ;3.30
									  ;3.30
FmpGot: 				;found my partition.		  ;3.30
	Message ftestHard,<"Found my partition...",cr,lf>                 ;3.30
	xor	ax,ax							  ;3.30
	or	al, fNon_Removable					  ;3.30
	or	word ptr [DI].Flags, ax 				  ;3.30
	mov	byte ptr [DI].FormFactor, ffHardFile			  ;3.30
	mov	fBigFat, 0		;assume 12 bit Fat.		  ;3.30
	mov	ax, Mini_HDLIM						  ;3.30
	mov	[DI].HDLIM, ax						  ;3.30
	mov	ax, Mini_SECLIM 					  ;3.30
	mov	[DI].SECLIM, ax 					  ;3.30
	mov	al, Rom_MiniDsk_Num					  ;3.30
	mov	[DI].DriveNum, al	;set physical number		  ;3.30
	mov	al, Mininum						  ;3.30
	mov	[DI].DriveLet, al	;set logical number		  ;3.30
									  ;3.30
	cmp	word ptr ES:[BX+8], 64	;**With current BPB, only lower word					  ;3.30
					; is meaningful.							  ;3.30
	je	FmpRet			;should be bigger than 64 sectors at least				  ;3.30
	sub	bx, 4			;let BX point to the start of the entry 				  ;3.30
	mov	dh, byte ptr ES:[BX+2]										  ;3.30
	and	dh, 11000000b		;get higher bits of cyl 						  ;3.30
	rol	dh, 1												  ;3.30
	rol	dh, 1												  ;3.30
	mov	dl, byte ptr ES:[BX+3]	;cyl byte								  ;3.30
	mov	[DI].Hidden_Trks, dx	;set hidden trks							  ;3.30
;** Now, read the volume boot record into BootBias.								  ;3.30
	mov	cx,ES:[BX+2]		;cylinder,cylinder/sector     ;3.30*
	mov	dh,ES:[BX+1]		;head			      ;3.30*
	mov	dl,Rom_MiniDsk_Num	;drive			      ;3.30*
	mov	ax,7c0h 		;			      ;3.30*
	mov	es,ax			;buffer segment 	      ;3.30*
	mov	bx,BOOTBIAS		;buffer offset		      ;3.30*
	mov	ax,0201h		;read,1 sector		      ;3.30*
	int	13h			;call ROM-Bios routine	      ;3.30*
	jc	FmpRet			;cannot continue.							  ;3.30
	mov	bx, 1c2h+BootBias										  ;3.30
														  ;3.30
	call	SetMini 		;install a mini disk. BX value saved.					  ;3.30
	jc	FmpnextChain											  ;3.30
														  ;3.30
	call	Install_BDSM		;install the BDSM into the BDS table					  ;3.30
;	 call	 Show_Installed_Mini	 ;show the installed message. 3/35/86 - Don't show messages.          ;3.30
	inc	mininum 		;increase the logical drive number for next				  ;3.30
	inc	num_mini_dsk		;increase the number of mini disk installed.				  ;3.30
														  ;3.30
	push	bx			;now, set the DskDrvs pointer to BPB info.				  ;3.30
	mov	bx, Mini_BPB_ptr										  ;3.30
	lea	si, [di].BytePerSec	;points to BPB of BDSM							  ;3.30
	mov	[bx], si											  ;3.30
	inc	Mini_BPB_ptr		;advance to the next address						  ;3.30
	inc	Mini_BPB_ptr											  ;3.30
	pop	bx												  ;3.30
														  ;3.30
	add	DI, type BDSM_type	;adjust to the next BDSM table entry.					  ;3.30
	mov	End_OF_BDSM, DI 	;set the ending address of BDSM table to this.				  ;3.30
;	 Message fTestHard,<"Mini disk installed.",cr,lf>                                                         ;3.30
FmpnextChain: jmp FmpNext		;let's find out if we have any chained partition                          ;3.30
FmpRet: 													  ;3.30
	ret													  ;3.30
														  ;3.30
SetMini:													  ;3.30
	push	di												  ;3.30
	push	bx												  ;3.30
	push	ds												  ;3.30
	jmp	SET1			;will be returned to Find mini partition routine.			  ;3.30
					;Some logic has been added to SET1 to					  ;3.30
					;deal with Mini disks.							  ;3.30
														  ;3.30
;														  ;3.30
;Install BDSM installs a BDSM (pointed by DS:DI) into the end of the current					  ;3.30
;linked list of BDS.												  ;3.30
;Also, set the current BDSM pointer segment to DS.								  ;3.30
;At entry: DS:DI -> BDSM											  ;3.30
;														  ;3.30
Install_BDSM:													  ;3.30
														  ;3.30
	push	ax												  ;3.30
	push	si												  ;3.30
	push	es												  ;3.30
														  ;3.30
	les	si, dword ptr cs:Start_BDS	;start of the beginning of list 				  ;3.30
I_BDSM_Next:													  ;3.30
	cmp	word ptr es:[si], -1		;end of the list?						  ;3.30
	jz	I_BDSM_New											  ;3.30
	mov	si, word ptr es:[si].link									  ;3.30
	mov	ax, word ptr es:[si].link+2	;next pointer							  ;3.30
	mov	es, ax												  ;3.30
	jmp	short I_BDSM_Next										  ;3.30
I_BDSM_New:													  ;3.30
	mov	ax, ds												  ;3.30
	mov	word ptr ds:[di].link+2, ax	;BDSM segment had not been initialized. 			  ;3.30
	mov	word ptr es:[si].link+2, ax									  ;3.30
	mov	word ptr es:[si].link, di									  ;3.30
	mov	word ptr ds:[di].link, -1	;make sure it is a null ptr.					  ;3.30
														  ;3.30
I_BDSM_ret:													  ;3.30
	pop	es												  ;3.30
	pop	si												  ;3.30
	pop	ax												  ;3.30
	ret													  ;3.30
														  ;3.30
;***The following code is not needed any more.	Don't show any                                                    ;3.30
;***messages to be compatible with the behavior of IO.SYS.							  ;3.30
;;Show the message "Mini disk installed ..."                                                                      ;3.30
;;This routine uses WRMSG procedure which will call OUTCHR.							  ;3.30
;Show_Installed_Mini:												  ;3.30
;	 push	 ax												  ;3.30
;	 push	 bx												  ;3.30
;	 push	 ds												  ;3.30
;														  ;3.30
;	 mov	 al, Mininum		 ;logical drive number							  ;3.30
;	 add	 al, Drv_Letter_Base	 ;='A'                                                                    ;3.30
;	 mov	 Mini_Drv_Let, al										  ;3.30
;	 mov	 si, offset Installed_Mini									  ;3.30
;	 call	 WRMSG												  ;3.30
;														  ;3.30
;	 pop	 ds												  ;3.30
;	 pop	 bx												  ;3.30
;	 pop	 ax												  ;3.30
;	 ret													  ;3.30
;**End of mini disk initialization**	; 4/7/86								  ;3.30
														  ;3.30
														  ;3.30
CMOS_Clock_Read proc	near											  ;3.30
														  ;3.30
; IN ORDER TO DETERMINE IF THERE IS A CLOCK PRESENT IN THE SYSTEM, THE FOLLOWING				  ;3.30
; NEEDS TO BE DONE.												  ;3.30
	PUSH	AX												  ;3.30
	PUSH	CX												  ;3.30
	PUSH	DX												  ;3.30
	PUSH	BP												  ;3.30
														  ;3.30
	XOR	BP,BP												  ;3.30
LOOP_CLOCK:													  ;3.30
	XOR	CX,CX												  ;3.30
	XOR	DX,DX												  ;3.30
	MOV	AH,2			;READ REAL TIME CLOCK	      ;3.30
	INT	1Ah			;CALL ROM-BIOS ROUTINE	      ;3.30
	CMP	CX,0												  ;3.30
	JNZ	CLOCK_PRESENT											  ;3.30
														  ;3.30
	CMP	DX,0												  ;3.30
	JNZ	CLOCK_PRESENT											  ;3.30
														  ;3.30
	CMP	BP,1			; READ AGAIN AFTER A SLIGHT DELAY, IN CASE CLOCK			  ;3.30
	JZ	NO_READDATE		; WAS AT ZERO SETTING.							  ;3.30
														  ;3.30
	INC	BP			; ONLY PERFORM DELAY ONCE.						  ;3.30
	MOV	CX,4000H											  ;3.30
DELAY:														  ;3.30
	LOOP	DELAY												  ;3.30
	JMP	LOOP_CLOCK											  ;3.30
														  ;3.30
CLOCK_PRESENT:													  ;3.30
	mov	cs:HaveCMOSClock, 1	; Set the flag for cmos clock					  ;3.30
														  ;3.30
	call	CMOSCK			; Reset CMOS clock rate that may be 				  ;3.30
					;possibly destroyed by CP DOS and POST routine did not			  ;3.30
					;restore that.								  ;3.30
														  ;3.30
	PUSH	SI												  ;3.30
	MESSAGE FTESTINIT,<"CLOCK DEVICE",CR,LF>                                                                  ;3.30
	CALL	READ_REAL_DATE		;MJB002 READ REAL-TIME CLOCK FOR DATE					  ;3.30
														  ;3.30
	CLI				;MJB002 								  ;3.30
	MOV	DAYCNT,SI	      ;MJB002 SET SYSTEM DATE							  ;3.30
	STI				;MJB002 								  ;3.30
	POP	SI			;MJB002 								  ;3.30
NO_READDATE:													  ;3.30
	POP	BP												  ;3.30
	POP	DX												  ;3.30
	POP	CX												  ;3.30
	POP	AX												  ;3.30
	RET													  ;3.30
														  ;3.30
CMOS_Clock_Read endp												  ;3.30
;														  ;3.30
; 10/28/86													  ;3.30
; THE FOLLOWING CODE IS WRITTEN BY JACK GULLEY IN ENGINEERING GROUP.					  ;3.30
; CP DOS IS CHANGING CMOS CLOCK RATE FOR ITS OWN PURPOSES AND IF THE					  ;3.30
; USE COLD BOOT THE SYSTEM TO USE PC DOS WHILE RUNNING CP DOS, THE CMOS					  ;3.30
; CLOCK RATE ARE STILL SLOW WHICH SLOW DOWN DISK OPERATIONS OF PC DOS					  ;3.30
; WHICH USES CMOS CLOCK.  PC DOS IS PUT THIS CODE IN MSINIT TO FIX THIS					  ;3.30
; PROBLEM AT THE REQUEST OF CP DOS. 									  ;3.30
; THE PROGRAM IS MODIFIED TO BE RUN ON MSINIT. Equates are defined in CMOSEQU.INC.				  ;3.30
; This program will be called by CMOS_Clock_Read procedure. 						  ;3.30
;														  ;3.30
;  The following code CMOSCK is used to insure that the CMOS has not						  ;3.30
;	had its rate controls left in an invalid state on older AT's.                                             ;3.30
;														  ;3.30
;	It checks for an AT model byte "FC" with a submodel type of                                               ;3.30
;	00, 01, 02, 03 or 06 and resets the periodic interrupt rate						  ;3.30
;	bits incase POST has not done it.  This initilization routine						  ;3.30
;	is only needed once when DOS loads.  It should be ran as soon						  ;3.30
;	as possible to prevent slow diskette access.								  ;3.30
;														  ;3.30
;	This code exposes one to DOS clearing CMOS setup done by a						  ;3.30
;	resident program that hides and re-boots the system.							  ;3.30
;														  ;3.30
CMOSCK	PROC	NEAR			;	CHECK AND RESET RTC RATE BITS					  ;3.30
														  ;3.30
;Model byte and Submodel byte were already determined in MSINIT.						  ;3.30
	push	ax												  ;3.30
	cmp	cs:Model_byte, 0FCh	;check for PC-AT model byte						  ;3.30
					 ;	 EXIT IF NOT "FC" FOR A PC-AT                                     ;3.30
	JNE	CMOSCK9 		; Exit if not an AT model						  ;3.30
														  ;3.30
	CMP	cs:Secondary_Model_Byte,06H  ; Is it 06 for the industral AT					  ;3.30
	JE	CMOSCK4 		; Go reset CMOS periodic rate if 06					  ;3.30
	CMP	cs:Secondary_Model_Byte,04H  ; Is it 00, 01, 02, or 03						  ;3.30
	JNB	CMOSCK9 		; EXIT if problem fixed by POST 					  ;3.30
					; Also,Secondary_model_byte = 0 when AH=0c0h, int 15h failed.	  ;3.30
CMOSCK4:				;	RESET THE CMOS PERIODIC RATE					  ;3.30
					;  Model=FC submodel=00,01,02,03 or 06					  ;3.30

	mov	al,CMOS_REG_A or NMI	;NMI disabled on return
	mov	ah,00100110b		;Set divider & rate selection
	call	CMOS_WRITE


	mov	al,CMOS_REG_B or NMI	;NMI disabled on return
	call	CMOS_READ
	and	al,00000111b		;clear SET,PIE,AIE,UIE,SQWE
	mov	ah,al
	mov	al,CMOS_REG_B		;NMI enabled on return
	call	CMOS_WRITE

CMOSCK9:				;	EXIT ROUTINE							  ;3.30
	pop	ax												  ;3.30
	RET				; RETurn to caller							  ;3.30
					;  Flags modifyied							  ;3.30
CMOSCK	ENDP													  ;3.30
PAGE														  ;3.30
;--- CMOS_READ -----------------------------------------------------------------				  ;3.30
;		READ BYTE FROM CMOS SYSTEM CLOCK CONFIGURATION TABLE	       :				  ;3.30
;									       :				  ;3.30
; INPUT: (AL)=	CMOS TABLE ADDRESS TO BE READ				       :				  ;3.30
;		BIT    7 = 0 FOR NMI ENABLED AND 1 FOR NMI DISABLED ON EXIT    :				  ;3.30
;		BITS 6-0 = ADDRESS OF TABLE LOCATION TO READ		       :				  ;3.30
;									       :				  ;3.30
; OUTPUT: (AL)	VALUE AT LOCATION (AL) MOVED INTO (AL).  IF BIT 7 OF (AL) WAS  :				  ;3.30
;		ON THEN NMI LEFT DISABLED.  DURING THE CMOS READ BOTH NMI AND  :				  ;3.30
;		NORMAL INTERRUPTS ARE DISABLED TO PROTECT CMOS DATA INTEGRITY. :				  ;3.30
;		THE CMOS ADDRESS REGISTER IS POINTED TO A DEFAULT VALUE AND    :				  ;3.30
;		THE INTERRUPT FLAG RESTORED TO THE ENTRY STATE ON RETURN.      :				  ;3.30
;		ONLY THE (AL) REGISTER AND THE NMI STATE IS CHANGED.	       :				  ;3.30
;-------------------------------------------------------------------------------				  ;3.30
														  ;3.30
CMOS_READ	PROC	NEAR		;	READ LOCATION (AL) INTO (AL)					  ;3.30
	PUSHF				; SAVE INTERRUPT ENABLE STATUS AND FLAGS				  ;3.30

	cli
	push	bx
	push	ax			;save user NMI state
	or	al,NMI			;disable NMI for us
	out	CMOS_PORT,al
	nop				;undocumented delay needed
	in	al,CMOS_DATA		;get data value

	 ;set NMI state to user specified 
	mov	bx,ax			;save data value
	pop	ax			;get user NMI
	and	al,NMI
	or	al,CMOS_SHUT_DOWN
	out	CMOS_PORT,al
	nop
	in	al,CMOS_DATA

	mov	ax,bx			;data value
	pop	bx

	PUSH	CS			; *PLACE CODE SEGMENT IN STACK AND					  ;3.30
	CALL	CMOS_POPF		; *HANDLE POPF FOR B- LEVEL 80286					  ;3.30
	RET				; RETURN WITH FLAGS RESTORED						  ;3.30
														  ;3.30
CMOS_READ	ENDP												  ;3.30
														  ;3.30
CMOS_POPF	PROC	NEAR		;	POPF FOR LEVEL B- PARTS 					  ;3.30
	IRET				; RETURN FAR AND RESTORE FLAGS						  ;3.30
														  ;3.30
CMOS_POPF	ENDP												  ;3.30
														  ;3.30
;--- CMOS_WRITE ----------------------------------------------------------------				  ;3.30
;		WRITE BYTE TO CMOS SYSTEM CLOCK CONFIGURATION TABLE	       :				  ;3.30
;									       :				  ;3.30
; INPUT: (AL)=	CMOS TABLE ADDRESS TO BE WRITTEN TO			       :				  ;3.30
;		BIT    7 = 0 FOR NMI ENABLED AND 1 FOR NMI DISABLED ON EXIT    :				  ;3.30
;		BITS 6-0 = ADDRESS OF TABLE LOCATION TO WRITE		       :				  ;3.30
;	 (AH)=	NEW VALUE TO BE PLACED IN THE ADDRESSED TABLE LOCATION	       :				  ;3.30
;									       :				  ;3.30
; OUTPUT:	VALUE IN (AH) PLACED IN LOCATION (AL) WITH NMI LEFT DISABLED   :				  ;3.30
;		IF BIT 7 OF (AL) IS ON.  DURING THE CMOS UPDATE BOTH NMI AND   :				  ;3.30
;		NORMAL INTERRUPTS ARE DISABLED TO PROTECT CMOS DATA INTEGRITY. :				  ;3.30
;		THE CMOS ADDRESS REGISTER IS POINTED TO A DEFAULT VALUE AND    :				  ;3.30
;		THE INTERRUPT FLAG RESTORED TO THE ENTRY STATE ON RETURN.      :				  ;3.30
;		ONLY THE CMOS LOCATION AND THE NMI STATE IS CHANGED.	       :				  ;3.30
;-------------------------------------------------------------------------------				  ;3.30
														  ;3.30
CMOS_WRITE	PROC	NEAR		;	WRITE (AH) TO LOCATION (AL)					  ;3.30
	PUSHF				; SAVE INTERRUPT ENABLE STATUS AND FLAGS				  ;3.30
	PUSH	AX			; SAVE WORK REGISTER VALUES						  ;3.30

	cli
	push	ax			;save user NMI state
	or	al,NMI			;disable NMI for us
	out	CMOS_PORT,al
	nop
	mov	al,ah
	out	CMOS_DATA,al		;write data

	 ;set NMI state to user specified 
	pop	ax 			;get user NMI
	and	al,NMI
	or	al,CMOS_SHUT_DOWN
	out	CMOS_PORT,al
	nop
	in	al,CMOS_DATA

	POP	AX			; RESTORE WORK REGISTERS						  ;3.30
	PUSH	CS			; *PLACE CODE SEGMENT IN STACK AND					  ;3.30
	CALL	CMOS_POPF		; *HANDLE POPF FOR B- LEVEL 80286					  ;3.30
	RET													  ;3.30
														  ;3.30
CMOS_WRITE	ENDP												  ;3.30
;														  ;3.30

END$:
code	ends
end
