	TITLE MSDISK - DOS 3.3
;------------------------------------------------------------------------
;									:
;	       DISK INTERFACE ROUTINES					:
;									:
;									:
;   This file contains the Disk Device Driver.				:
;									:
;   The routines in this files are:					:
;									:
;	routine 		function				:
;	------- 		--------				:
;									:
;	MEDIA$CHK		Determine if media in drive has changed :
;									:
;	GET$BPB 		Build a valid BPB for drive		:
;									:
;	DSK$REM 		Determine if disk has removable media	:
;									:
;	DSK$WRTV		Disk write with verify			:
;									:
;	DSK$WRT 		Disk write				:
;									:
;	DSK$READ		Read disk				:
;									:
;									:
;  These routines are not called directly.  Call are made via		:
; the strategy and interrupt entry point (see Device Header).		:
;									:
;  Data structures:							:
;	There are two main types of data structures associated with	:
;  the disk drives.  The first is the BDS.  BDS is the Bios Data	:
;  structure.  There is one BDS for each logical drive in the system.	:
;  All the BDS's are linked together in a list with the pointer to the  :
;  first BDS being found in Start_BDS.	The BDS hold various values	:
;  important to the disk drive.  For example there is a field for last	:
;  time accesses.  As actions take place in the system the BDS are	:
;  update to reflect the actions.  For example if there is a read to	:
;  a disk the last access field for the BDS for that drive is updated	:
;  to the current time. 						:
;	 The second data structure associated with disk drives is the	:
;  BPB.  A BPB is a Bios Parameter Block.  The BPB contains information :
;  about the media inside a disk drive.  Some on the fields in the BPB	:
;  are Sectors per track, number of FATs, and number of tracks.  This	:
;  information is used to tell where sectors are on the disk.  For	:
;  example,  if we need to read logical sector 52:			:
;									:
;	Diskette			Track	Sector	Side		:
;    single density							:
;    eight sectors per track		  6	   5	  0		:
;									:
;    double density							:
;    nine sectors per track		  2	   7	  1		:
;									:
;  The BPB for the media in the drive is stored in the BDS for the	:
;  drive.  If the user changes the floppy in the drive a call is	:
;  made to GET$BPB to build a new BPB in the BDS.  See this routine	:
;  for the algorithm.							:
;									:
;									:
;------------------------------------------------------------------------
;;Rev 3.30 Modification
;for testing, set test to 1.  So as MSBIO1.ASM.
	test=0
	EXTRN NUMERR:ABS		;MSDATA

	INCLUDE MSGROUP.INC	;DEFINE CODE SEGMENT
	INCLUDE MSEQU.INC
	INCLUDE PUSHPOP.INC
	INCLUDE MSMACRO.INC
	INCLUDE DEVSYM.INC
	INCLUDE DSKPRM.INC

	EXTRN INT2F_DISK:FAR		;MSBIO2
	EXTRN MEDIACHECK:NEAR		;96TPI
	EXTRN HASCHANGE:NEAR		;96TPI
	EXTRN MEDIA_SET_VID:NEAR	;96TPI
	EXTRN HIDENSITY:NEAR		;96TPI
	EXTRN CHECKLATCHIO:NEAR 	;96TPI
	EXTRN CHECKIO:NEAR		;96TPI
	EXTRN SET_CHANGED_DL:NEAR	;96TPI
	EXTRN SET_VOLUME_ID:NEAR	;MSVOLID
	EXTRN SWPDSK:NEAR		;MSBIO2
	EXTRN CMDERR:NEAR		;MSBIO1
	EXTRN STRATEGY:NEAR		;MSBIO1
	EXTRN ERR$CNT:NEAR		;MSBIO1
	EXTRN DSK$IN:NEAR		;MSBIO1
	EXTRN EXIT:NEAR 		;MSBIO1
	EXTRN BUS$EXIT:NEAR		;MSBIO1
	EXTRN ERR$EXIT:NEAR		;MSBIO1

;DATA
	EXTRN OLD13:DWORD		;MSBIO2
	EXTRN PTRSAV:DWORD		;MSBIO1
	EXTRN COM1DEV:WORD		;MSAUX
	EXTRN DAYCNT:WORD		;MSCLOCK
	EXTRN TIM_DRV:BYTE		;MSDATA
	EXTRN ACCESSCOUNT:BYTE		;MSDATA
	EXTRN SM92:BYTE 		;MSDATA
	EXTRN DISKSECTOR:BYTE		;MSDATA
	EXTRN MEDIABYTE:BYTE		;MSDATA
	EXTRN SECPERCLUSINSECTOR:BYTE	;MSDATA
	EXTRN BPB_IN_SECTOR:WORD	;MSDATA
	EXTRN DISKSECTOR:BYTE		;MSDATA
	EXTRN STEP_DRV:BYTE		;MSDATA
	EXTRN START_BDS:WORD		;MSDATA
	EXTRN PHYS_DRV:BYTE		;MSDATA
	EXTRN WRTVERIFY:WORD		;MSDATA
	EXTRN FSETOWNER:BYTE		;MSDATA
	EXTRN SINGLE:BYTE		;MSDATA
	EXTRN RFLAG:BYTE		;MSDATA
	EXTRN MEDBYT:BYTE		;MSDATA
	EXTRN SPSAV:WORD		;MSDATA
	EXTRN SECCNT:WORD		;MSDATA
	EXTRN DPT:DWORD 		;MSDATA
	EXTRN CURSEC:BYTE,CURHD:BYTE	;MSDATA
	EXTRN CURTRK:WORD		;MSDATA
	EXTRN EOT:BYTE			;MSDATA
	EXTRN MOTORSTARTUP:BYTE,SETTLECURRENT:BYTE,SETTLESLOW:BYTE ;MSDATA
	EXTRN CURHD:BYTE		;MSDATA
	EXTRN LSTERR:BYTE		;MSDATA
	EXTRN ERRIN:BYTE,ERROUT:BYTE	;MSDATA
	EXTRN PREVOPER:WORD		;MSDATA
	EXTRN ORIG13:DWORD		;MSDATA
	EXTRN FLAGBITS:WORD		;MSDATA
	EXTRN NUMBER_OF_SEC:BYTE	;MSDATA
	EXTRN FHAVE96:BYTE		;MSDATA
	EXTRN NEW_ROM:BYTE		;MSDATA
	EXTRN FORMT_EOT:BYTE,HDNUM:BYTE,TRKNUM:WORD,GAP_PATCH:BYTE ;MSDATA
	EXTRN NEXT2F_13:WORD		;MSDATA
	extrn Save_head_sttl:byte	;MSdata
	extrn Secrete_Code:word 	;MSdata
;;Rev 3.30 Modification


;
; Maximum number of retries in case of error
;

MAXERR	=	5
LSTDRV	=	504H


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

AccessMax	=	5


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
;
; flags for size of FAT
;
fTOOBIG 	EQU	80h
fBIG		EQU	40h

error_unknown_media	equ	7	; for use in BUILD BPB call

BPB_TYPE STRUC
SECSIZE DW	?
SECALL	DB	?
RESNUM	DW	?
FATNUM	DB	?
DIRNUM	DW	?
SECNUM	DW	?
FATID	DB	?
FATSIZE DW	?
SLIM	DW	?
HLIM	DW	?
HIDDEN	DW	?
BPB_TYPE ENDS
;------------------------------------------------------------------------
;									:
; The next 100 or so lines of code do the Media Check.	Media Check	:
; determines if the diskette (media) in the drive has been changed.	:
;									:
;	SI is used to hold media check code:				:
;			-1	media changed				:
;			 0	Don't know                              :
;			 1	media has not been changed		:
;									:
; The algorithm used is a follows:					:
;	if (hard disk)							:
;	    if (changed by format)					:
;		   return (not changed) 				:
;	    if	not (changed by format) 				:
;		   return (changed)					:
;	else we have a floppy						:
;	    if floppy has change line support go ask the floppy 	:
;	    if floppy does not have change line do the following	:
;		read the time						:
;		if more than two second have passed return don't know   :
;		if no time has passed then might be unreliable		:
;		  counter (some program fool with the counter when	:
;		  they should not).  See note below for procedure with	:
;		  unreliable counter					:
;		if sometime has passed but not two second return	:
;		  media has not changed.  This is based on the		:
;		  assumption that it is not physically possilbe to	:
;		  change a disk in less the two seconds (most people	:
;		  take about 10 seconds).				:
;									:
;------------------------------------------------------------------------

       public media$chk
MEDIA$CHK PROC	NEAR
	Message ftestdisk,<"Disk Media Check ">
	MNUM	ftestdisk,AX
	Message ftestdisk,<CR,LF>
	Call	SetDrive		; point DS:DI to BDS for specified drive

	cmp	cs:Secrete_Code, 'jk'   ; Secrete code for
	jne	media$done		; DOS 3.3 MSBIO.
;
; For non-removable disks only return changed if changed by format,
; otherwise return 'not changed'.
;

	mov	si,1			; assume no change
	test	word ptr [di].flags,fChanged_By_Format
	jz	WeAreNotFakingIt
					; reset flag
	and	word ptr [di].flags,NOT fChanged_By_Format

;
; If media has been changed by format, must use the ROM.
; Cannot rely on the 2 second time check.
;
	mov	cs:[TIM_DRV],-1 	; Ensure that we ask the ROM if media
					; has changed
	test	word ptr [di].flags,fNon_Removable
	jz	WeHaveAFloppy
	mov	SI,-1			; Indicate media changed
	jmp	short Media$Done
;
; return 'not changed' if disk is a hard file.
;

WeAreNotFakingIt:
	test	word ptr [di].flags,fNon_Removable
	jnz	Media$Done

;
; If this code is reached disk is a diskette drive
;

WeHaveAFloppy:

	xor	si,si			; Presume "I don't know"

;
; If drive is a floppy with changeline support the rom is called to
; determine if the media has changed.  It is not necessary to do the 2
; second check on these drives.
;
;----------------------------------------|
; Warning: Do not change the following. ;|
;	   It gets patched in MSINIT	;|
	Public Media_Patch		;|
Media_Patch:				;|
	CALL	MediaCheck		;|
	jc	Err$Exitj		;|
	call	HasChange		;|
	jnz	Media$Done		;|
;----------------------------------------|
;
; If this code is reached the drive is a floppy with no changeline support
;
	MOV	SI,1			; PRESUME NO CHANGE
	mov	al,cs:[TIM_DRV] 	; last drive accessed
					;is drive of last access the same?
	CMP	AL,byte ptr [di].DriveNum
	JNZ	Media$Unk		; no, then return don't know
;
; CHECK TO SEE IF THIS DRIVE HAS BEEN ACCESSED IN THE LAST 2 SECONDS.
;
	call	Check_Time_of_Access
	jmp	short Media$Done


Media$Unk:
	DEC	SI			; RETURN "I DON'T KNOW"

;
; SI now contains the correct value for media change.  Clean up the left overs
;
Media$Done:
	les	bx,cs:[ptrsav]		; get original packet
	mov	WORD PTR es:[BX].Trans,SI
	or	SI,SI
	js	Init_Patch
	jmp	EXIT

MEDIA$CHK ENDP

;----------------------------------------|
; Warning: Do not change the following. ;|
;	   It gets patched in msinit	;|
	Public Init_Patch		;|
INIT_PATCH PROC NEAR			;|
	CALL	Media_Set_VID		;|
;----------------------------------------|
	mov	cs:[Tim_Drv],-1 	; make sure we ask ROM for media check
VOLIDOK:
	jmp	EXIT
INIT_PATCH ENDP



ERR$EXITJ PROC NEAR

	MESSAGE FTESTCOM,<"ERR$EXITJ: ">
	MNUM	FTESTCOM,AX
	MESSAGE FTESTCOM,<" == ">
	CALL	MAPERROR
	MNUM	FTESTCOM,AX
	MESSAGE FTESTCOM,<CR,LF>
	JMP	ERR$EXIT
ERR$EXITJ ENDP

;
; PERFORM A CHECK ON THE TIME PASSED SINCE THE LAST ACCESS FOR THIS
; PHYSICAL DRIVE.
; WE ARE ACCESSING THE SAME DRIVE.  IF THE TIME OF LAST SUCCESSFUL ACCESS
; WAS LESS THAN 2 SECONDS AGO, THEN WE MAY PRESUME THAT THE DISK WAS NOT
; CHANGED
; RETURNS IN SI:
;	0 - IF TIME OF LAST ACCESS WAS >= 2 SECONDS
;	1 - IF TIME WAS < 2 SECONDS (I.E NO MEDIA CHANGE ASSUMED)
; REGISTERS AFFECTED AX,CX,DX, FLAGS.
;
CHECK_TIME_OF_ACCESS PROC NEAR
	PUBLIC CHECK_TIME_OF_ACCESS
	mov	si,1			; Presume no change
;;Rev 3.30 Modification
	xor	AH, AH			; set command to read time
	int	1Ah			; call rom-bios clock routine

;
; Once time is read, must make sure the date wrap is not lost.	The ROM will
; return the value only once, it must check for day wrap on each call.
;
	SHR	AL,1
	ADC	CS:[DAYCNT],0		; ADD IT TO OUR SAVED DAY COUNT
;
; Compute elapsed time
;
	MOV	AX,WORD PTR DS:[DI].TIM_LO   ; GET STORED TIME
	SUB	DX,AX
	MOV	AX,WORD PTR DS:[DI].TIM_HI
	SBB	CX,AX
;;End of Modification
;
; CX:DX is the elapsed time
;
	JNZ	TimeCheck_Unk		; CX <> 0 => > 1 hour
	OR	DX,DX			; did some time pass?
	JNZ	TimePassed		; yes, examine max value
;
; No noticeable time has passed.  There are two possiblities.  First there
; could be two driver calls with in one clock tick (55 milliseconds).  The
; second possiblity is the program has reprogramed the counter -- this is
; the unreliable counter case.	To distinguish between the case a count is
; kept of the number of calls that happen without a clock tick (the variable
; is AccessCount).  If this count exceeds a set limit (MaxAccess) it is
; assumed the counter is unreliable and the value don't know is returned.
; If AccessCount is less than MaxAccess we assume the time is valid and
; therefor the media has not changed.
;
	inc	byte ptr cs:AccessCount
					; Exceeded threshold for count?
	cmp	byte ptr cs:AccessCount,AccessMax
	jb	TimeCheck_Ret		; no, return media unchanged
	dec	byte ptr cs:AccessCount ; don't let the count wrap
	jmp	short TimeCheck_Unk	; "I don't know" if media changed


;
; If this code is reached some time has passed.  Need to determine if
; 2 seconds have passed.  Note: 18.2 ticks per second.
;
TimePassed:
	CMP	DX,18 * 2		; IF ( Time_passed <= 2secs )
	JBE	TimeCheck_Ret		;      presume no change


; Everything indicates that we do not know what has happened.
;
TimeCheck_Unk:
	DEC	SI			; Presume I don't know
TimeCheck_Ret:
	RET

CHECK_TIME_OF_ACCESS ENDP

ERR$EXITJ2: JMP ERR$EXITJ


;------------------------------------------------------------------------
;									:
;		Get Bios Parameter Block				:
;									:
; GET$BPB is called to build a valid BPB for the media in the disk	:
; drive.  A BPB (Bios Parameter Block) contains information about	:
; the media which is currently in the drive.  The values stored is	:
; information like number of fat sectors, size of drive, 8 or 9 sectors,:
; etc.									:
;									:
;	This routine is called by the device drive code.		:
;									:
;	On entry AL contains the logical drive number which needs	:
;	  the BPB built.						:
;	ES:[di] points to a buffer; the first byte of the buffer is a	:
;	   media decriptor byte.					:
;									:
;------------------------------------------------------------------------
;
; Build a valid BPB for the disk in the drive.
;

	public GET$BPB
GET$BPB PROC	NEAR
	Message fTestDisk,<"Disk Build BPB ">   ; print debug messages
	MNUM	fTestDisk,AX
	Message fTestDisk,<CR,LF>
	mov	AH,byte ptr ES:[DI]	; get FAT IB byte read by DOS
	call	SetDrive		; get the correct BDS for the drv
;;Rev 3.30 Modification
	TEST	WORD PTR [DI].FLAGS,FNON_REMOVABLE
	JNZ	ALREADY_GOTBPB		; NO NEED TO BUILD FOR FIXED DISKS
;;End of Modification
	call	GETBP			; build a BPB if necessary.
	jc	Err$exitj2		; if error exit
GET$BPB ENDP
;----------------------------------------|
; Warning: Do not change the following. ;|
;	   It gets patched in msinit	;|
	Public SET_PATCH		;|
SET_PATCH PROC	NEAR			;|
	CALL	set_volume_id		;|
;----------------------------------------|
					; print debug messages
	message ftestdisk,<"Set Volume ID">
	mnum	ftestdisk,di
	message ftestdisk,<"  ">
	mnum	ftestdisk,ds
	message ftestdisk,<cr,lf>
ALREADY_GOTBPB:
	add	di,BytePerSec		; return the BPB that is in the current BDS

	PUBLIC	SetPTRSAV
SetPTRSAV:				; return point for DSK$INIT
	les	BX,cs:[PTRSAV]
	mov	ES:[BX].MEDIA,AH
	mov	ES:[BX].COUNT,DI
	mov	ES:[BX].COUNT+2,DS
	jmp	EXIT
SET_PATCH ENDP




;
;
;      GETBP fills the BDS with the BPB for the media currently in the drive.
; The following steps are followed:
;	If the Return_Fake_BPB flag is set then the GETBP just returns.
;	If the BDS is for a hard disk (non-removable) then GETBP returns since
;   the BPB cannot change on a hard disk drive.
;	For all other cases GETBP reads the boot sector and looks for a BPB
;   in the boot sector. (All DOS 2.X and about disks should have a valid
;   BPB in the boot sector.)
;	If no valid BPB is found (DOS 1.X disk) then GETBP reads the FAT
;   sector and gets the FAT ID byte.  With this byte a valid BPB is build.
;
;	Inputs:
;		DS:DI points to correct BDS
;
;	Outputs:
;		Fills in BPB in current BDS if valid BPB or FAT ID on disk.
;		Carry set, and AL=7 if invalid disk.
;		Carry set and error code in AL if other error.
;

	Public GETBP
GETBP	PROC	NEAR
					; if non-removable or returning
					; fake BPB then return BPB as is.
	TEST	WORD PTR [DI].FLAGS,RETURN_FAKE_BPB OR FNON_REMOVABLE
	jz	GETBP1
	JMP	GETRET_EXIT


GETBP1:
	message ftestdisk,<"Building BPB from scratch",CR,LF>
	SaveReg <cx,dx,es,bx>
;
; Attempt to read in boot sector and determine BPB.
; We assume that the 2.x and greater DOS disks all have a valid boot sector.
;
Rdboot:
	call	ReadBootSec
	jnc	NoRdErr
	jmp	GetBP_Err_Ret		; Carry set if there was error.
NoRdErr:
	cmp	bx,0			; BX is 0 if boot sector is valid.
	jnz	DoFatBPB		; if not go read FAT

	call	MovBPB			; Move BPB into registers.
	jmp	Has1
	
;
; At this point the drive contains a 1.X diskette.  We read the FAT byte
; and fill in the BPB from there.
;

DoFatBPB:
        call    ReadFat                 ; puts media descriptor byte in AH
        jc      GetBP_Err_Ret           ; if carry set, there was error, get out

;----------------------------------------|
; Warning: Do not change the following. ;|
;          It gets patched in msinit    ;|
Public GETBP1_PATCH                     ;|
GETBP1_PATCH:                           ;|
        call    hidensity               ;|
;----------------------------------------|
; Test for a valid 3.5" medium
        cmp     [di].FormFactor, ffsmall
        jnz     Is_Floppy
        cmp     ah,0F9H                 ; is it a valid fat ID byte for 3.5" ?
        jnz     Got_Unknown_Medium
        mov     bx,offset sm92          ; pointer to correct BPB
        push    cs
        pop     es
ASSUME ES:CODE
        mov     al,[bx.spf]
        mov     cx,[bx.csec]
        mov     dx,word ptr [bx.spa]
        mov     bx,word ptr [bx.spt]
	jmp	short HAS1_res		; Need to load reserved sectors
;
; must be a 5.25" floppy if we come here
;
Is_Floppy:
        mov     CL,AH                   ; save media
        and     CL,0F8H                 ; normalize
        cmp     CL,0F8H                 ; cmopare with good media byte
        jnz     Got_Unknown_Medium

GOODID: mov     AL,1                    ; set number of FAT sectors
        mov     BX,64*256+8             ; set dir entries and sector max
        mov     CX,40*8                 ; set size of drive
        mov     DX,01*256+1             ; set head limit and sec/all unit
        test    AH,00000010B            ; test for 8 or 9 sectors
        jnz     HAS8                    ; NZ = has 8 sectors
        inc     AL                      ; inc number of FAT sectors
        inc     BL                      ; inc sector max
        add     CX,40                   ; increase size
HAS8:   test    AH,00000001B            ; test for 1 or 2 heads
	jz	HAS1_res		; Z = 1 head
        add     CX,CX                   ; double size of disk
        mov     BH,112                  ; increase number of directory entries
        inc     DH                      ; inc sec/all unit
        inc     DL                      ; inc head limit

PUBLIC	HAS1_res
HAS1_res:
	mov	si,word ptr ds:[di].RESSEC
PUBLIC	HAS1                            ; save values in BDS
HAS1:   mov     byte ptr ds:[DI].SecPerClus,DH
        mov     byte ptr ds:[DI].cDir,BH
        mov     word ptr ds:[DI].Drvlim,CX
        mov     byte ptr ds:[DI].Mediad,AH
        mov     byte ptr ds:[DI].csecFat,AL
        mov     byte ptr ds:[DI].SecLim,BL
        mov     byte ptr ds:[DI].HdLim,DL
        mov     word ptr ds:[DI].RESSEC,SI
GETRET: pop     BX
        RestoreReg <es,dx,cx>
ASSUME ES:NOTHING
GETRET_Exit:
        RET

GetBP_Err_Ret:
	CALL	MapError
	JMP	SHORT GETRET

;
; We have a 3.5" diskette for which we cannot build a BPB. We do not assume any
; type of BPB for this medium.
;
Got_Unknown_Medium:
	mov	al,error_unknown_media
	stc
	jmp	short GETRET

GETBP	ENDP

bpbType struc
spf	db	?
spt	db	?
cdire	db	?
csec	dw	?
spa	db	?
chead	db	?
bpbType ends

;
; end of GET$BPB code
;-------------------------------------------------

;
; Read in the boot sector. Set carry if error in reading sector.
; BX is set to 1 if the boot sector is invalid, otherwise it is 0.
;
READBOOTSEC PROC NEAR
         mov     CX, 0001h               ; set track and sector number
         xor     DH, DH                  ; set head number for read_sector
	 call	 read_sector
	 jc	 Err_Ret		 ; error - get out
	 xor	 bx,bx			 ; assume valid boot sector.

				; at this point the boot sector has been
				; read in from the disk.  We now need to
				; determine if the boot sector contains
				; a valid BPB.	Currently there are only
				; a few simple checks.	Expanding the
				; number or types of checks would not be
				; a bad idea.
;*******************************************************************************
; Put a sanity check for the boot sector in here to detect boot sectors that
; do not have valid BPBs.
; We examine the first two bytes - they must contain a long jump or a short
; jump followed by a NOP.
; If this test is passed, we further check by examining the signature at
; the end of the boot sector for the word AA55H.
; If the signature is not present, we examine the media descriptor byte to
; see if it is valid.
;******************************************************************************
	 cmp	byte ptr cs:[DiskSector],069H	; Is it a direct jump?
	 JE	Check_bpb_MediaByte		; DON'T NEED TO FIND A NOP
	 cmp	byte ptr cs:[DiskSector],0E9H	; DOS 2.0 jump?
	 JE	Check_bpb_MediaByte		; NO NEED FOR NOP
	 cmp	byte ptr cs:[DiskSector],0EBH	; How about a short jump.
	 JNE	INVALIDBOOTSEC
	 cmp	byte ptr cs:[DiskSector]+2,090H ; Is next one a NOP?
	 JNE	INVALIDBOOTSEC


; Don't have to perform the following signature check since
; we need to check the media byte even with the good signatured diskette.
;CHECK_SIGNATURE:
;	  CMP	  WORD PTR CS:[DISKSECTOR+1FEH],0AA55H	 ; SEE IF NON-IBM
;						   ; DISK OR 1.X MEDIA.
;	  JZ	  CHECKSINGLESIDED	 ; GO SEE IF SINGLE SIDED MEDIUM.
;					 ; MAY NEED SOME SPECIAL HANDLING
;
; CHECK FOR NON-IBM DISKS WHICH DO NOT HAVE THE SIGNATURE AA55 AT THE
; END OF THE BOOT SECTOR, BUT STILL HAVE A VALID BOOT SECTOR. THIS IS DONE
; BY EXAMINING THE MEDIA DESCRIPTOR IN THE BOOT SECTOR.
;

;;Rev 3.30 Modification
Check_bpb_MediaByte:

	 MOV	 AL,BYTE PTR CS:MEDIABYTE
	 AND	 AL,0F0H
	 CMP	 AL,0F0H		; ALLOW FOR STRANGE MEDIA
	 JNZ	 INVALIDBOOTSEC 
;
; THERE WERE SOME (APPARENTLY A BUNCH) DISKETTES THAT HAD BEEN FORMATTED
; UNDER DOS 3.1 AND EARLIER VERSIONS WHICH HAVE INVALID BPBS IN THEIR BOOT
; SECTORS. THESE ARE SPECIFICALLY DISKETTES THAT WERE FORMATTED IN DRIVES
; WITH ONE HEAD, OR WHOSE SIDE 0 WAS BAD. THESE CONTAIN BPBS IN THE BOOT
; SECT THAT HAVE THE SEC/CLUS FIELD SET TO 2 INSTEAD OF 1, AS IS STANDARD
; IN DOS. TO SUPPORT THEM, WE HAVE TO INTRODUCE A "HACK" THAT WILL
; HELP OUR BUILD BPB ROUTINE TO RECOGNISE THESE SPECIFIC CASES, AND TO
; SET UP OUT COPY OF THE BPB ACCORDINGLY.
; WE DO THIS BY CHECKING TO SEE IF THE BOOT SECTOR IS OFF A DISKETTE THAT
; IS SINGLE-SIDED AND IS A PRE-DOS 3.20 DISKETTE. IF IT IS, WE SET THE
; SEC/CLUS FIELD TO 1. IF NOT, WE CARRY ON AS NORMAL.
CHECKSINGLESIDED:
	MOV	AL,BYTE PTR CS:MEDIABYTE
	TEST	AL,0001H	; IS LOW BIT SET? - INDICATES DOUBLE SIDED
	JNZ	GOODDSK
	CMP	WORD PTR CS:[DISKSECTOR+8],"." SHL 8 + "3"
	JNZ	MUSTBEEARLIER
	CMP	BYTE PTR CS:[DISKSECTOR+10],"2"
	JAE	GOODDSK

; WE MUST HAVE A PRE-3.20 DISKETTE. SET THE SEC/CLUS FIELD TO 1
MUSTBEEARLIER:
	MOV	BYTE PTR CS:[SECPERCLUSINSECTOR],1
	JMP	SHORT GOODDSK

INVALIDBOOTSEC:
	 INC	 BX			; SET THAT BOOT SECTOR INVALID
;;End of Modification

GoodDsk:				; carry already reset
	 clc
	 ret

Err_Ret:				; carry is already set on entry here
	 message ftestdisk,<"error in readboot",cr,lf>
	 ret

READBOOTSEC ENDP

;
; MovBPB moves the BPB read from the Boot sector into registers for use by
; GETBP routine at Has1
;
MOVBPB	PROC	NEAR
	SaveReg <ds,di>
	push	cs
	pop	ds
	mov	di,offset BPB_In_Sector
	mov	dh,Byte Ptr [di].secall     ;sectors per unit
	mov	bh,Byte Ptr [di].dirnum     ;number of directory entries
	mov	cx,Word Ptr [di].secnum     ;size of drive
	mov	ah,Byte Ptr [di].fatid	    ;media descriptor
	mov	al,Byte Ptr [di].fatsize    ;number of FAT sectors
	mov	bl,Byte Ptr [di].slim	    ;sectors per track
	mov	dl,Byte Ptr [di].hlim	    ;number of heads
	mov	si,word ptr [di].resnum	    ;reserved sectors
	RestoreReg <di,ds>
	ret
MOVBPB	ENDP



;
; Read in the FAT sector and get the Media Byte from it.
; Input : AL contains logical drive.
; Output:
;	  Carry set if an error occurs, AX contains error code.
;	  Otherwise, AH contains media byte on exit. AL is preserved.

READFAT PROC	NEAR
	push	ax			    ; preserve logical drive in AL
	MOV	DH,0			    ; HEAD 0
	mov	CX,0002 		    ; set track and sector number
	call	read_sector		    ; CS:BX points to fat sector
	jc	Bad_FAT_Ret		    ; error, get out
	pop	ax			    ; reset logical drive
	mov	ah,Byte Ptr CS:[BX]	    ; media byte
	ret

Bad_FAT_Ret:				     ; carry set on entry
	message ftestdisk,<"error in FAT read",cr,lf>
	pop	cx			     ; clear stack
	ret
READFAT ENDP



;
; Read_sector reads a single sector into the tempory buffer 'DiskSector'.
; Up to three retries are done in case of error.
;
;    Inputs:
;	DS:DI	points to BDS for drive
;	CH - track number
;	CL - sector number
;	DH - head number
;
;    Outputs:
;	If carry is clear -- successful read
;	   CS:BX points to buffer holding sector
;	   AX, BX are not preserved, CX, DX, BP, and ES are preserved
;
;	If carry is set -- error on read
;	   AX, BX, and DX are not preserved; CX, BP, and ES are preserved
;
;

READ_SECTOR PROC NEAR
	PUBLIC READ_SECTOR
	push	BP			; preserve BP register
	mov	BP,3			; BP is retry count, set to 3
	push	ES			; preserve ES also
	mov	DL, byte ptr [di].DriveNum
	mov	BX, offset DiskSector	; Get ES:BX to point to buffer
	push	CS			;    get the segment right
	pop	ES			; now ES:BX is correct

RD_RET:
					; set command to read (AH=2) and
	mov	AX, 0201h		; number of sectors to 1 (AL=1)
	int	13h			; call rom-bios disk routines

	jnc	OKRET2			; if no carry then no error - done
Rd_rty:
	call	Again			; reset disk and decrement BP
	jz	Err_RD_RET
	test	word ptr ds:[di].flags,fNon_Removable
	JNZ	RD_RET
;;Rev 3.30 Modification -----------------------------------------
	push	ds		; For retry, set head settle
	push	ax		; time to 0Fh.
	lds	si,cs:DPT
	mov	al, ds:[si].disk_head_sttl
	mov	cs:[save_head_sttl],al
	mov	byte ptr ds:[si].disk_head_sttl, NormSettle
	pop	ax
	pop	ds
					; SET CMD TO READ (AH=2) AND
	MOV	AX, 0201h		; NUM OF SECTORS TO 1 (AL=1)
	INT	13h			; CALL ROM-BIOS DISK ROUTINES
	push	ds
	push	ax
	lds	si,cs:DPT
	mov	al, cs:[save_head_sttl]
	mov	byte ptr ds:[si].disk_head_sttl, al
	pop	ax
	pop	ds
	jnc	OKRET2
	jmp	Rd_rty
ERR_RD_RET:
	MOV	DL,-1		; MAKE SURE WE ASK ROM IF MEDIA  CHANGED
	STC			; RETURN ERROR
;;End of Modification -----------------------------------------

			; Update information pertaining to last drive
			; accessed, time of access, last track accessed
			; in that drive.
OKRET2:
					; set up for head settle logic in DISK
	mov	CS:[STEP_DRV],DL	; save last drive accessed
	mov	CS:[TIM_DRV],DL 	; save the values
	mov	byte ptr [di].track,CH	;
	pushf				; save the flags
	call	SET_TIM
	popf				; restore flags
	pop	ES			; restore registers
	pop	BP
	ret

READ_SECTOR ENDP



;------------------------------------------------------------------------
;									:
;		Disk Removable Routine					:
;									:
;  This routine determines if a particular logical drive has		:
;  removable media.							:
;									:
;  Input								:
;     AL contains the logical drive number which the check is being	:
;  done.								:
;------------------------------------------------------------------------

DSK$REM PROC	NEAR			;ARR 2.41
	PUBLIC	DSK$REM
	Message fTestDisk,<"Disk Removable ">   ; print debug messages
	MNUM	fTestDisk,AX
	Message fTestDisk,<CR,LF>
					; AL is logical unit number
	call	SetDrive		; get BDS for this drive
	test	word ptr [di].flags,fNon_Removable
	jnz	NON_REM
	jmp	EXIT

NON_REM:				; if non removable set busy bit
	jmp	BUS$EXIT

DSK$REM ENDP



;
; SetDrive scans through the data structure of BDSs and returns a
; pointer to the BDS that belongs to the drive specified in AL.
; Carry is set if no BDS has a logical drive number which matches the
; value in AL.
;	Input:
;	  AL contains the logical drive number
;	Output:
;	  DS:DI points to correct BDS if Carry is clear.
;
;	 All register execpt DS and DI are preserved
;

	Public SetDrive
SETDRIVE PROC	NEAR
	message ftestdisk,<"SetDrive",cr,lf>    ; print debug messages
	push	bx
	push	cs
	pop	ds
					; assume first BDS is in this segment
	ASSUME DS:CODE
	mov	di,word ptr Start_BDS
Scan_Loop:
;;Rev 3.30 Modification -----------------------------------------
	CMP	BYTE PTR CS:[PHYS_DRV],1	; DOES AL HAVE PHYS DRV?
	JB	USE_LOGICAL_DRV
	CMP	BYTE PTR [DI].DRIVENUM,AL
	JE	SETDRV
	JMP	SHORT GET_NXT_BDS
USE_LOGICAL_DRV:
	CMP	BYTE PTR [DI].DRIVELET,AL
	JE	SETDRV
GET_NXT_BDS:
	MOV	BX,WORD PTR [DI].LINK+2   ; GO TO NEXT BDS
	MOV	DI,WORD PTR [DI].LINK
	mov	ds,bx
	ASSUME	DS:NOTHING
;;End of Modification -----------------------------------------

	cmp	di,-1				; at end of list?
	jnz	Scan_Loop			; no, keep looking
	stc					; yes, indicate error set carry
SetDrv:
	pop	bx				; restore bx
	ret					; return

SETDRIVE ENDP



;------------------------------------------------------------------------
;									:
;		DISK I/O ROUTINES					:
;									:
;  On entry the register contain the following values:			:
;									:
;	AH - Media Descriptor byte					:
;	AL - logical drive number					:
;	CX - count of sectors to be read or written			:
;	DX - start sector						:
;	DI - offset of destination buffer				:
;									:
;------------------------------------------------------------------------


;------------------------------------------------------------------------
;									:
;		Disk Write with Verify					:
;									:
;  Input								:
;	See about header for register contents on entry.		:
;									:
;------------------------------------------------------------------------


DSK$WRITV PROC	NEAR
	PUBLIC	DSK$WRITV
	Message fTestDisk,<"Disk Write with verify ">
	MNUM	fTestDisk,AX
	Message fTestDisk,<" ">
	MNUM	fTestDisk,DX
	Message fTestDisk,<" for ">
	MNUM	fTestDisk,CX
	Message fTestDisk,<CR,LF>
	MOV	CS:[WRTVERIFY],103H
	JMP	SHORT DSK$CL

;------------------------------------------------------------------------
;									:
;		       Disk Write					:
;									:
;  Input								:
;	See about header for register contents on entry.		:
;									:
;------------------------------------------------------------------------

DSK$WRIT:
	PUBLIC	DSK$WRIT
	Message fTestDisk,<"Disk Write ">
	MNUM	fTestDisk,AX
	Message fTestDisk,<" ">
	MNUM	fTestDisk,DX
	Message fTestDisk,<" for ">
	MNUM	fTestDisk,CX
	Message fTestDisk,<CR,LF>
	MOV	CS:[WRTVERIFY],ROMWrite

DSK$CL:
	CALL	DISKIO
DSK$IO:
	JC	DSKBad
	JMP	EXIT
DSKBad:
	JMP	ERR$CNT

DSK$WRITV ENDP


;------------------------------------------------------------------------
;									:
;			Disk Read					:
;									:
;  Input								:
;	See about header for register contents on entry.		:
;									:
;------------------------------------------------------------------------

DSK$READ PROC	NEAR
	PUBLIC	DSK$READ
	Message fTestDisk,<"Disk Read ">
	MNUM	fTestDisk,AX
	Message fTestDisk,<" ">
	MNUM	fTestDisk,DX
	Message fTestDisk,<" for ">
	MNUM	fTestDisk,CX
	Message fTestDisk,<CR,LF>
	CALL	DISKRD
	JMP	DSK$IO
DSK$READ ENDP
;
; Miscellaneous odd jump routines.  Moved out of mainline for speed.
;


;
; CheckSingle determines if the drive specified is a virtual drive (more
; than one logical drive associated with one physical drive).  If this
; is the case we need to prompt the user to place the correct disk in
; the drive.
;
;	Input:
;	   DS:DI pints to the BDS for the drive being checked.
;
;	If there is a error the carry flag is set on return
;
;  All registers are preserved.
;

CHECKSINGLE PROC NEAR
	PUBLIC CHECKSINGLE
	push	AX			; save affected registers
	push	BX
	mov	BX,word ptr ds:[di].flags
	TEST	BL,FNON_REMOVABLE OR FI_OWN_PHYSICAL ;Can't change disk
	jnz	SingleRet		;     on hard drive so return
					; is there a drive sharing this
	TEST	BL,FI_AM_MULT		;   physical drive?
	jz	SingleRet		; if not, then return

				; At this point there is more than one
				; logical drive mapped to this physical drive.
				; But the drive being accessed is not the
				; owner of the physical drive.	What needs to
				; be done is find the current owner BDS and
				; turn off the owner flag and then make current
				; BDS the owner of the drive.  Then prompt the
				; user to change disks.
	mov	al,ds:[di].DriveNum	; get physical drive number
	push	ds			; preserve pointer to current BDS
	push	di
	push	cs

	pop	ds			; Point to start of BDS linked list
	ASSUME	DS:CODE

	mov	di,offset Start_BDS

Scan_List:
	mov	bx,word ptr [di].link+2     ; go to next BDS
	mov	di,word ptr [di].link
	mov	ds,bx
	ASSUME	DS:NOTHING

	cmp	di,-1			; end of list?
	jz	single_err_ret		;  if so there must be an error
					; same physical drive?
	cmp	byte ptr [di].DriveNum,al
	jnz	Scan_List		; no, keep looking

Check_Own:				; yes, check to see if owner
	mov	bx,word ptr [di].flags
	test	bl,fI_Own_Physical
	jz	Scan_List		; not owner, keep looking
	xor	bl,fI_Own_Physical	; yes owner  reset ownership flag
	mov	word ptr ds:[di].flags,bx
	pop	di			; Restore pointer to current BDS
	pop	ds
	xor	bx,bx
	or	bl,fI_Own_Physical	; establish current BDS as owner
	or	word ptr [di].flags,bx


				;
				; We examine the fSetOwner flag. If it is
				; set, then we are using the code in
				; CheckSingle to just set the owner of
				; a drive. We must not issue the prompt
				; in this case.
				;

	cmp	byte ptr cs:[fSetOwner],1
	jz	SingleRet
				;
				; To support "backward" compatibility with
				; IBM's "single drive status byte" we now
				; check to see if we are in a single drive
				; system and the Application has "cleverly"
				; diddled the SDSB (Single Drive Status Byte)
				;

	cmp	cs:[single],2		; single drive system?
	jne	short Ignore_SDSB	; no, jump down

	SaveReg <ds,di,ax>		; yes...
	mov	al,ds:[di].DriveLet	    ;	  IF (Curr_drv == Req_drv)
	mov	ah,al
	xor	di,di
	mov	ds,di
	xchg	al,ds:byte ptr LSTDRV	    ;	     THEN swap(Curr_drv,Req_drv)
	cmp	ah,al			    ;	     ELSE
	RestoreReg <ax,di,ds>		    ;		  swap(Curr_drv,Req_drv)
	je	SingleRet		    ;		  Issue Swap_dsk_msg

Ignore_SDSB:
	call	SWPDSK			; ask user for correct disk

SingleRet:
	pop	BX			; restore registers
	pop	ax
	ret				; return

Single_Err_Ret:
	stc				; set carry flage to indicate error
	pop	di			; restore current BDS
	pop	ds
	jmp	short SingleRet


;
; BadDrive is called when sector specified is greater than last
; sector on disk.
; or when BDS is not found for drive
;

BadDrive:
	mov	AL,8		; error code 'sector not found'
	stc			; indicate error
IORET:	ret			; return



BogusSettle:
	MOV	AL,NormSettle	     ; someone has diddled the settle
	JMP	GotSlowSettle

CHECKSINGLE ENDP




;------------------------------------------------------------
;
;	DISK I/O HANDLER
;
;   On entry:
;	AL = Drive Number (0-6)
;	AH = media Descriptor
;	CX = sector count
;	DX = first sector
;	DS = CS
;	ES:DI = transfer address
;	[RFLAG] = operation (2 for read, 3 for write)
;	[VERIFY] = 1 for verity after write
;
;   On exit:
;	if successful carry flag = 0
;	  else CF=1 and AL contains error code
;


	Public DISKRD
DISKRD	PROC	NEAR
	mov	CS:[RFLAG],ROMRead	; set command to read

DISKIO:
	mov	BX,DI			; ES:BX is transfer address
	Call	SetDrive		; map logical and physical
	jc	BadDrive		; carry means BDS not found
	mov	al,BYTE PTR DS:[DI].Mediad
	mov	cs:MedByt,al		; Preserve media byte for drive for use
					; in determining media change.
	jcxz	IORET
	mov	cs:[SPSAV],SP		; save the sp value
;
; Ensure that we are trying to access valid sectors on the drive
;
	mov	SI,DX			; start with first sector
	add	SI,CX			; add in sector count
	add	DX,WORD PTR [DI].HIDSEC ; add in the hidden sectors
	cmp	SI,WORD PTR [DI].DRVLIM ; compare against drive maximum
	ja	BADDRIVE		; if greater than max, error
	mov	cs:[SECCNT],CX		; save sector count
;;Rev 3.30 Modification -----------------------------------------
; SET UP POINTER TO DISK BASE TABLE IN [DPT]. WE CANNOT ASSUME THAT IOSETUP
; WILL DO IT BECAUSE WE WILL SKIP THE SET UP STUFF WITH HARD DISKS.
	PUSH	DS
	XOR	AX,AX
	MOV	DS,AX
	LDS	SI,DWORD PTR DS:[DSKADR]; CURRENT DISK PARM TABLE
	MOV	WORD PTR CS:DPT,SI
	MOV	WORD PTR CS:DPT+2,DS
	POP	DS
;;End of Modification -----------------------------------------
;
; For hard drives do not do media check or set DPT.
;
	test	word ptr [di].flags,fNon_Removable
	jnz	Skip_Setup
	CALL	CHECKSINGLE
;
; Check to see if we have previously noted a change line.  The routine
; returns if everything is OK.	Otherwise, it pops off the stack and returns
; the proper error code.
;
;----------------------------------------|
; Warning: Do not change the following. ;|
;	   It gets patched in msinit	;|
	Public DiskIO_Patch		;|
DiskIO_PATCH:				;|
	CALL	CheckLatchIO		;|
;----------------------------------------|
;
; Set up tables and variables for I/O
	call	IOSetUp
;
; Now the settle values are correct for the following code
;
Skip_Setup:
	mov	AX,DX			; setup locical sector for divide
	xor	DX,DX
	div	word ptr [DI].SECLIM	; divide by sectors per track
	inc	DL
	mov	cs:[CURSEC],DL		; save current sector
	mov	CX,word ptr [DI].HDLIM	; get number of heads
	xor	DX,DX			; divide tracks by heads per cylinder
	div	CX
	mov	cs:[CURHD],DL		; save current head
	mov	cs:[CURTRK],AX		; save current track
;
; We are now set up for the I/O.  Normally, we consider the DMA boundary
; violations here.  Not true.  We perform the operation as if everything is
; symmetric; let the DISK INT handler worry about the DMA violations.
;
	mov	AX, cs:[SECCNT]
	call	BLOCK
	call	DONE
	ret

DISKRD	ENDP



;
; IOSetUp:
;
; IOSetUp does the following functions:
;   *	Set the drive-last-accessed flag (for diskette only).  No need to
;	update these flags for hard disks becuase we know a hard disk will
;	not be removed.
;   *	Set the proper last sector number in the Disk Parameter Table (DPT)
;   *	Set the proper motor start up time in DPT
;   *	Set the proper head settle time in the DPT
;
; Input:
;	DS:DI -> current BDS.
; Output:
;	AX,CX,SI are destroyed.
;
	public IOSetUp
IOSETUP PROC	NEAR
	MOV	AL,[DI].DRIVENUM
	MOV	CS:[TIM_DRV],AL 	; SAVE DRIVE LETTER
;
; determine proper head settle values
;
	mov	CX,DS
	LDS	SI,DWORD PTR CS:[DPT]	; GET POINTER TO DISK BASE TABLE
	MOV	AL,CS:[EOT]
	mov	[SI].DISK_EOT,AL	; bump for us
	mov	AL,[si].DISK_Motor_Strt ; preserve old motor start time
	mov	cs:MotorStartup,AL
;
; For 3.5" drives, both external as well as on the K09, we need to set the
; Motor Start Time to 4. This checking for every I/O is going to affect
; performance across the board, but is necessary!!
;
	push	es
	mov	es,cx			; ES:DI -> to current BDS
	cmp	byte ptr es:[di].FormFactor,ffsmall
	jnz	Motor_Start_OK
	mov	AL,4
	xchg	AL,[si].DISK_MOTOR_STRT
Motor_Start_OK:
	pop	ES
;
; DS:SI now points to disk parameter table.  Get current settle and set fast
; settle
;

	XOR	AL,AL
	INC	AL			; IBM WANTS FAST SETTLE = 1 - RS
	xchg	AL,[SI].DISK_Head_Sttl	; get settle and set up for fast
	mov	cs:SettleCurrent,AL
	MOV	AL,NORMSETTLE		; SOMEONE HAS DIDDLED THE SETTLE
GotSlowSettle:
	mov	DS,CX
	mov	cs:SettleSlow,AL
	ret




;
; Set time of last access, and reset default values in the DPT.
;
DONE:
	test	word ptr [di].Flags,fNon_Removable
	jnz	RETZ			; Do not set for non-removable Media
	call	SET_TIM 		; set time of last access for drive
;
; Restore head settle and EOT values
;
DiddleBack:
	push	ax			; preserve AX
	mov	DX,DS			; save DS in DX
	mov	AL,cs:SettleCurrent	; get value in registers
	mov	AH,cs:MotorStartup
	lds	SI,cs:DPT		; get pointer to DPT
	mov	[SI].Disk_EOT,9 	; save values in DPT
	mov	[SI].Disk_Head_Sttl,AL
	mov	[si].Disk_Sector_Siz,2
	mov	[si].Disk_Motor_Strt,AH
	mov	DS,DX			; restore DS
	pop	ax			; restore AX
RETZ:
	ret





;
; Block reads or writes the number of sectors specified in AX
; handling track boundaries.  For example, on an 8 sector per track
; disk there might be a request to read 6 sectors starting at the 5th
; sector.  Block breaks this request into a read of sectors 5-8 on
; the first track and a read of sectors 1-2 on the next track.	Disk is
; called to do the actual read.
;
;   Inputs:
;	AX - number of sectors to be read
;	DS:DI points to BDS for disk drive
;	cs:CurSec - sector on track where read should start
;	cs:CurTrk - track where read should start
;	cs:CurHd - head for read
;	ES:BX - transfer address
; AX, CX, and BL are not preserved
;

BLOCK:
	or	AX,AX			; see if any sectors to read
	jz	RETZ			; if not, return
;;Rev 3.30 Modification -----------------------------------------
; Fixed disk will not be restricted to the trk-by-trk basis.
	test	word ptr [di].Flags, fNon_Removable
	jz	BLOCK_FLOPPY
	call	DISK
	xor	ax,ax
	RET
BLOCK_FLOPPY:
;;End of Modification -----------------------------------------
;
; READ AT MOST 1 TRACK WORTH.  PERFORM MINIMIZATION AT SECTOR / TRACK
;
	mov	CL,byte ptr [DI].SecLim ; get sectors per track
	inc	CL
	sub	CL,cs:CurSec	; set CX to number of sector after current
	xor	CH,CH		;    sector on the current track
	cmp	AX,CX		; is all of request on current track?
	jae	GotMin		; no, jump down
	mov	CX,AX		; yes, set number of sector on this track to AX
GotMin:
				; now
				; AX is the requested number of sectors to read
				; CX is the number that we can do on this track
	push	AX
	push	CX
	mov	AX,CX		; AL is number of sectors to read
	call	Disk
	pop	CX
	pop	AX

				; CX is the number of sectors just transferred
	sub	AX,CX		; reduce sectors-remaining by last I/O
	shl	CL,1
	add	BH,CL		; adjust transfer address
	jmp	Block		; jump to do any remaining sectors

IOSETUP ENDP





;
;  DISK:
; Disk is called to read or write one or more sectors on a track.
; Retries are make if an error occurs.
;
;    Input:
;	AL - number of sector to be read/written (they must all be on one track)
;	DS:DI points to BDS for the drive
;	ES:BX is transfer address (must not cross 64k physical boundry)
;	[RFLAG] is 2 for read and 3 for write
;	[VERIFY] is 0 for normal, 1 for verify after write
;	[CurTrk] is track (cylinder) to be read/written.
;	[CurHd] is head to be used in operation.
;	[CurSec] is sector to start read on.
;
; The following are overwritten: BP,
;   Output:
;	[SECCNT] is decrement by the number of sectors read or written


	public disk
DISK	PROC	NEAR
	mov	BP,MAXERR		; set up retry count
	MOV	AH,CS:RFLAG		;GET READ/WRITE INDICATOR

RETRY:
					; AX is overwritten in int 13 call, so
					; to do a retry we need to save the
					; value by pushing on the stack
	push	AX
				; the next five lines of code put the
				; sector number in bit 5-0 of CL and the
				; cylinder number in CH and bits 7-6 of
				; CL.  The register must be set up in this
				; way for the bios.
	mov	DX,cs:[CURTRK]	;Load current cylinder
;;Rev 3.30 Modification -----------------------------------------
	test	word ptr [di].FLAGS, fNon_Removable ;Fixed disk
	jz	DISK_NOT_MINI		;no, skip this.
	cmp	[di].IsMini, 1		;Is this a mini disk?
	jnz	DISK_NOT_MINI		;No. continue to next.
	add	dx, [di].Hidden_Trks	;else add hidden trks.
DISK_NOT_MINI:
;;End of Modification -----------------------------------------
	ror	DH,1		; get high two bits of cylinder in correct place
	ror	DH,1

	or	DH,cs:[CURSEC]	; get sector value
	mov	CX,DX		; put cylinder/sector values in correct register
				; get head value
	xchg	CH,CL		; put bytes in correct place
	mov	DH,byte ptr cs:[CurHD]
				; get drive number
	mov	DL,byte ptr [DI].DriveNum

	CMP	BYTE PTR [DI].FORMFACTOR,FFHARDFILE
	JZ	DO_FAST 		; HARD FILES USE FAST SPEED
;
; The registers are now all set up for call on rom-bios.
; The next dozen or so line determines whether we call Do_Fast or Do_Norm
; for the actual I/O read.  Do_Fast calls FastSpeed for the actual I/O.
; Do_Norm calls NormSpeed.  NormSpeed changes the value for the head settle
; time in the disk parameter table to a larger value and then calls FastSpeed
; to do the I/O.  So Do_Fast just has a shorter head settle time.
;
	CMP	CS:[STEP_DRV],-1
	jz	Do_Writej

	cmp	AH,ROMRead		; For read...
	je	Do_Fast 		;   ... alway use fast

	cmp	AH, ROMVerify		; For verify...
	je	Do_Fast 		;   ... alway use fast

Do_Writej:
	jmp	DO_Write		; Jump down for write...


DO_Fast:
	CALL	FastSpeed		; do I/O carry set if error
TestErr:
	jc	DSKERR			; error -- get out
; SET DRIVE AND TRACK OF LAST ACCESS
	mov	cs:[STEP_DRV],DL	; save the last drive accessed
	mov	byte ptr [di].track,CH	; save in BDS

NO_SET:
	cmp	CS:WRTVERIFY,103H	; Check for write and verify
	jz	DoVerify		; yes -- go do verify
NOVERIFY:
	pop	AX			; pop command and num sec. from stack
	and	CL,03FH 		; Eliminate cylinder bits from sector
	xor	AH,AH
	sub	cs:[SECCNT],AX		; Reduce count of sectors to go
	add	CL,AL			; Next sector
	mov	cs:[CURSEC],CL
	cmp	CL,BYTE PTR [DI].SECLIM ; See if sector/track limit reached
	jbe	Disk_Ret		; yes, return
NextTrack:
	mov	cs:[CURSEC],1		; Start with first sector of next track
	mov	DH,CS:[CURHD]
	inc	DH			; go to next head
	cmp	DH,BYTE PTR [DI].HDLIM	; at head limit?
	jb	NOXOR			; no, jump down
	xor	DH,DH			; at head limit, reset to head zero ...
	inc	cs:[CURTRK]		;      and go to next head
NOXOR:
	mov	cs:[CURHD],DH		; save new head number
Disk_Ret:
	clc				; successful return so clear error flag
	ret				; all done
DISK	ENDP
;
; The request is for write.  Determine if we are talking about the same
; track and drive.  If so, use the fast speed.
;
DO_WRITE PROC	NEAR
	cmp	DL,cs:[STEP_DRV]	; same drive?
	jnz	DO_Norm 		; no, do normal speed
	cmp	CH,byte ptr [di].track	; same track on drive
	jz	DO_Fast 		; yes, do fast speed
DO_Norm:
	call	NormSpeed		; use larger head settle time
	jmp	SHORT TestErr		; test for error

DO_WRITE ENDP


;
; we have a verify request also.  Get state info and go verify
;

DOVERIFY PROC	NEAR
	pop	AX			; get number of sectors from stack
	push	AX			;    in non-detructive fashion
	MOV	AH,ROMVERIFY		; REQUEST VERIFY
	CALL	FastSpeed		; MZ  2.21 change settle mode
	JNC	NoVerify
DOVERIFY ENDP

;
; Need to special case the change-line error AH=06h.  If we get this, we
; need to return it.
;
;----------------------------------------|
; Warning: Do not change the following. ;|
;	   It gets patched in msinit	;|
	Public DSKERR			;|
DSKERR	PROC	NEAR			;|
	CALL	CheckIO 		;|
;---------------------------------------;|

	Call	AGAIN			; reset the disk and decrement retry cnt
	jz	HARDERR 		; if z flag set, did all retries-give up
	cmp	AH,80H			; timeout?
	jz	HARDERR 		; yes, jump to hard error
DSKERR1:
	pop	AX			; Restore sector count
	jmp	RETRY			;     and try again

HARDERR:
	PUBLIC	HARDERR
	CALL	MapError

HARDERR2:			; for routines that call MapError themselves
	PUBLIC	HARDERR2
	mov	cs:[Tim_Drv],-1 	;Force a media check through ROM
	mov	CX,cs:SECCNT		;Get count of sectors to go
	mov	SP,cs:[SPSAV]		;Recover entry stack pointer
;
; Since we are performing a non-local goto, restore the disk parameters
;
MedByt_OK:
	call	DiddleBack
	ret				;and return

DSKERR	ENDP


;
; change settle value from SettleCurrent to whatever is appropriate
;
NORMSPEED PROC	NEAR
	push	DS			; save two registers
	push	AX
	mov	AL,cs:SettleSlow	; change value in current disk parm tbl
	lds	SI,cs:DPT		; current disk parm table
	mov	[SI].Disk_Head_Sttl,AL
	pop	AX			; restore command and sector count
	pop	DS
	call	FastSpeed		; do I/0
	push	DS			; restore the value in disk parm table
	lds	SI,cs:DPT
	mov	[SI].Disk_Head_Sttl,1	; 1 is fast settle
	pop	DS
	ret

NORMSPEED ENDP


FASTSPEED PROC	NEAR
;
; If the drive has been marked as too big (i.e. starting sector of the
; partition is > 16 bits, then ALWAYS return drive not ready.
;
	TEST	BYTE PTR [DI].FatSiz,fTOOBIG


 IF TEST
	JZ	Ready			; if debugging use jmp rather
	JMP	NotReady		; than local jnz
Ready:
 else
	JNZ	NotReady
 endif

	Message fTestINIT,<"<">         ; print debug messages
	MNUM	fTestINIT,AX
	Message fTestINIT,<",">
	MNUM	fTestINIT,ES
	Message fTestINIT,<":">
	MNUM	fTestINIT
	Message fTestINIT,<",">
	MNUM	fTestINIT,CX
	Message fTestINIT,<",">
	MNUM	fTestINIT,DX
	Message fTestINIT,<">">

	int	13h			; call rom-bios disk routines

Death:
	ret
NotReady:
	stc				; set carry to indicate error
	mov	AH,80h			; put error code in AH
	jmp	Death			; jump to ret

FASTSPEED ENDP


;
; Map error returned by ROM into corresponding code to be returned to
; DOS in AL.
;
MAPERROR PROC	NEAR
	PUBLIC	MAPERROR
	push	CX			; save cx
	push	CS
	pop	ES			; make ES the local segment
	mov	AL,AH			; move error code into AL
	mov	cs:[LSTERR],AL		; terminate list with error code
	mov	CX,NUMERR		; number of possible error conditions
	mov	DI,OFFSET ERRIN 	; point to error conditions
	repne	SCASB
	mov	AL,cs:[DI + NUMERR - 1]    ; get translation
	pop	cx			; restore cx
	stc				; flag error condition
	ret
MAPERROR ENDP

;
; Set the time of last access for this drive. This is done only for removable
; media.
;
	public SET_TIM
SET_TIM PROC	NEAR
	push	ax
	xor	AH, AH			; set command to get time
	int	1Ah			; call rom-bios timer function
	or	AL,AL			; is there 24 hour rollover?
	jz	NOROLL3 		; no, skip down
	inc	cs:[DayCnt]		; yes, then increment DayCnt
NOROLL3:
; We have the new time. If we see that the time has passed, then we reset
; the threshold counter...
	cmp	DX,word ptr [di].TIM_LO ; Did any time pass?
	jnz	SetAccess		; yes, update access time
	cmp	CX,word ptr [di].TIM_HI ; now look at the high bits
	jz	Done_Set		; if equal then no time passed
SetAccess:				; we get here if some time has passed
					; zero AccessCount to show time passage
	mov	byte ptr cs:[AccessCount],0
	MOV	WORD PTR DS:[DI].TIM_LO,DX ; save low time bits
	MOV	WORD PTR DS:[DI].TIM_HI,CX ; save high time bit
Done_Set:
	clc				; indicate no error
	pop	ax			; restore AX register
	ret

SET_TIM ENDP
	ASSUME	CS:CODE,DS:NOTHING,ES:NOTHING,SS:NOTHING

;
; This is the true DISK INT handler.  We parse the request to see if there is
; a DMA violation.  If so, depending on the function, we:
;   READ/WRITE	Break the request into three pieces and move the middle one
;	into our internal buffer.
;   FORMAT	Copy the format table into the buffer
;   VERIFY	Point the transfer address into the buffer
;
; This is the biggest bogosity of all.	The IBM controller does NOT handle
; operations that cross physical 64K boundaries.  In these cases, we copy
; the offending sector into the buffer below and do the I/O from there.
;

INT13FRAME  STRUC
oldbp	dw  ?
oldax	dw  ?
oldbx	dw  ?
oldcx	dw  ?
olddx	dw  ?
olddd	dd  ?
oldf	dw  ?
INT13FRAME  ENDS

;;Rev 3.30 Modification -----------------------------------------
;To handle the INT 13h, AH = 8 Problem.
;Save Registers here.
Save_AX   DW  ?
Save_BX   DW  ?
Save_CX   DW  ?
Save_DX   DW  ?
Save_DI   DW  ?
Save_SI   DW  ?
Save_BP   DW  ?
Save_DS   DW  ?
Save_ES   DW  ?
Prev_DX   DW  ?
Save_Flag DW  ?
;;End of Modification -----------------------------------------


;
; Block13:
;
;   Entry conditions:
;	AH = function
;	AL = number of sectors
;	ES:BX = DMA address
;	CX = packed track and sector
;	DX = head and drive
;   Output conditions:
;	NO DMA violation.
;
	Public Block13
Block13 PROC	FAR
;
; Let the opperation proceed.  If there is a DMA violation, then we do things.
;
	mov	cs:PrevOper,AX		; save request
	pushf				; preserve the flags
	cmp	AH,ROMFormat		; format request?
	jnz	Not_Format		;    no, skip down

; Set changed by format bit for all logical drives using this physical drive
;---------------------------------------------------------|
; Warning: Do Not Change the following. 		  |
; It gets patched in at INIT time			  |
	Public Changed_Patch
Changed_Patch:
	mov	word ptr cs:[FlagBits],fChanged_By_Format+fChanged
	call	Set_Changed_DL		; Indicate that media changed by format
;							  |
;---------------------------------------------------------|

Not_Format:
;;Rev 3.30 Modification -----------------------------------------
	cmp	ah, 8			; Read Driver Parm ?
	je	Bus_Problem
	cmp	ah, 15h
	je	Bus_Problem
	CALL	ORIG13			; SIMULATE INT 13
	JC	GOTERR13_br		; ERROR?
	RET	2			; NO, RETURN AND CLEAR FLAGS

GOTERR13_br: jmp Goterr13

;Some machines have a problem with Int 13h function=8
;This function does not reset the common buses after the execution.
;To solve this problem, when we detect AH=8h, then we will save the result
;and will issue AH=1 (Read Status) call to reset the buses.

Bus_Problem:
	mov	cs:Prev_DX, DX		;save orignal drive number
	call	Orig13			;Do "Read drive parm"

	mov	cs:Save_AX, AX		;Save registers,flag
	mov	cs:Save_BX, BX
	mov	cs:Save_CX, CX
	mov	cs:Save_DX, DX
	mov	cs:Save_DI, DI
	mov	cs:Save_SI, SI
	mov	cs:Save_BP, BP
	mov	cs:Save_DS, DS
	mov	cs:Save_ES, ES
	pushf
	pop	cs:Save_Flag

	mov	dx, cs:Prev_DX		;restore orignal drive
	pushf
	mov	ah, 1			;Read Status.
	call	Orig13			;Reset the bus as a side effect

	mov	AX, cs:Save_AX		;restore registers,flag
	mov	BX, cs:Save_BX
	mov	CX, cs:Save_CX
	mov	DX, cs:Save_DX
	mov	DI, cs:Save_DI
	mov	SI, cs:Save_SI
	mov	BP, cs:Save_BP
	mov	DS, cs:Save_DS
	mov	ES, cs:Save_ES
	push	cs:Save_Flag
	popf
	jc	GotErr13		;AH=8 had been an error?
	ret	2
;
; Some kind of error occurred.	See if it is DMA violation
;
GotErr13:
	pushf
	cmp	AH, 09h 		; is error DMA error code?
	JNZ	CHECK_ECC
	JMP	GOTDMAERR
CHECK_ECC:
	CMP	AH,11H
	JZ	OK11
	POPF
	RET	2
;
; We have an error status 11h.	This indicates an ECC-corrected error.	Note
; that this indicates that the data is PROBABLY correct but not CERTAINLY
; correct. The ROMs on PC-1s and PC_XTs have a 'bug' in that if an ECC error
; occurs for a multi-sector read, only the sectors up to the one where the
; error occurred are read in. We have no way of knowing how many were read in
; this case, so we redo the operation, reading one sector at a time. If we
; get an ECC error on reading one sector, we ignore the error because the
; sector has been read in.
;
	PUBLIC OK11
OK11:
;	popf				; restore flags
;;Rev 3.30 Modification -----------------------------------------
; Here, it is better reset the system. So, we are going to
; call Orig13 again
	mov	ah, 0
	call	Orig13			;reset. Don't care about result
;;End of Modification -----------------------------------------

	mov	ax,cs:[PrevOper]	; Retrieve request
;
; This will provide a termination point.
;
	cmp	AL,1			; If request for one sector, assume OK
	jnz	ECC_Err_Handle		; more than one sector -- jump down
	xor	AH,AH			; clear carry too!
	ret	2

	Public ECC_Err_Handle
ECC_Err_Handle:
	SAVEREG <BX,CX,DX>
	mov	cs:[Number_Of_Sec],AL
Loop_ECC:
	mov	AX,CS:[PrevOper]	; set command to previos command
	mov	AL,1			;    but request only one sector
;
; we do reads one sector at a time. this ensures that we will eventually
; finish the request since ecc errors on 1 sector do read in that sector.
;
; we need  some "intelligence" in the ecc handler to handle reads
; that attempt to read more sectors than are available on a particular
; track.
; we call check_wrap to set up the sector #, head # and cylinder # for
; this request.
; at this point, all registers are set up for the call to orig13, except
; that there maybe a starting sector number that is bigger than the number
; of sectors on a track.
;

	CALL	Check_Wrap		; see if wrapping around cylinder

	pushf				; save flags
	call	ORIG13			; call original rom-bios code
;;Rev 3.30 Modification ------------------------------------------------------
	JNC	OK11_OP
	CMP	AH,11H			; ONLY ALLOW ECC ERRORS
	JNZ	OK11_EXIT_err		; Other error?
	mov	ah, 0			; ECC error. Reset it again.
	pushf
	call	Orig13
OK11_Op:
	dec	cs:[Number_of_Sec]	; adjust number of sectors for one read
	jz	OK11_Exit		; all done?
	inc	CL			; advance sector number
	inc	BH			; add 200H to address
	inc	BH
	jmp	short Loop_ECC		; and around for reading another sector

OK11_EXIT_err:
	stc				; Set carry bit again.
;;End of Modification ------------------------------------------------------

OK11_Exit:
	RESTOREREG <DX,CX,BX>
	Ret	2



;
; we truly have a DMA violation.  Restore register AX and retry the
; operation as best we can.
;
GotDMAErr:
	pop	AX			; clean up stack
	mov	AX,cs:PrevOper		; restore command
	sti				; restore interrupts
	cmp	AH,ROMRead		; determine the command
	jb	IntDone
	cmp	AH,ROMVerify
	jz	IntVerify
	cmp	AH,ROMFormat
	jz	IntFormat
	ja	IntDone
;
; We are doing a read/write call.  Check for DMA problems
;
	SaveReg <DX,CX,BX,AX>		; save register we overwrite
	push	BP
	mov	BP,SP
	mov	DX,ES			; Check for 64k boundary error

	shl	DX,1
	shl	DX,1
	shl	DX,1
	shl	DX,1			; Segment converted to absolute address

	add	DX,BX			; Combine with offset
	add	DX,511			; simulate a transfer
;
; If carry is set, then we are within 512 bytes of the end of the segment.
; We skip the first transfer and perform the remaining buffering and transfer
;
	JNC	NO_SKIP_FIRST
	mov	DH,byte ptr [bp.olddx+1]	; set correct head number
	jmp	Buffer

NO_SKIP_FIRST:
;
; DX is the physical 16 bits of start of transfer.  Compute remaining
; sectors in segment.
;
	shr	DH,1			; DH = number of sectors before address
	mov	AH,128			; AH = max number of sectors in segment
	sub	AH,DH
;
; AH is now the number of sectors that we can successfully write in this
; segment.  If this number is above or equal to the requested number, then we
; continue the operation as normal.  Otherwise, we break it into pieces.
;
	cmp	AH,AL			; can we fit it in?
	jb	DoBlock 		; no, perform blocking.
;
; Yes, the request fits.  Let it happen
;
	MOV	DH,BYTE PTR [BP.OLDDX+1]	; SET UP HEAD NUMBER
	call	DoInt
	jmp	Bad13
;
; Verify the given sectors.  Place the buffer pointer into our space.
;
IntVerify:
	SaveReg <ES,BX>
	push	CS
	pop	ES
DoSimple:
	mov	BX,OFFSET DiskSector
	pushf
	call	Orig13
	RestoreReg  <BX,ES>
	ret	2

;
; Format operation.  Copy the parameter table into memory
;
IntFormat:
	SaveReg <ES,BX>
	SaveReg <SI,DI,DS>
	push	ES
	push	CS
	pop	ES
	pop	DS
	mov	SI,BX
	mov	DI,OFFSET DiskSector
	call	Move
	RestoreReg  <DS,DI,SI>
	jmp	DoSimple
;
; Inline continuation of operation
;
IntDone:
	jmp	Orig13
;
; We can't fit the request into the entire block.  Perform the operation on
; the first block.
;
;
; DoBlock is modified to correctly handle multi-sector disk I/O. 
; Old DoBlock had added the number of sectors I/Oed (Ah in Old DoBlock) after
; the DoInt call to CL.  Observing only the lower 6 bits of CL(=max. 64) can
; represent a starting sector, if AH was big, then CL would be clobbered.
; By the way, we still are going to use CL for this purpose since Checkwrap
; routine will use it as an input.  To prevent CL from being clobbered, a 
; safe number of sectors should be calculated like "63 - # of sectors/track".
; DoBlock will handle the first block of requested sectors within the
; boundary of this safe value.

;Try to get the # of sectors/track from BDS via Rom drive number.
;For any mini disks installed, here we have to pray that they have the
;same # of sector/track as the main DOS partition disk drive.

DoBlock:
;;Rev 3.30 Modification ------------------------------------------------------
	Message ftestDisk,<"!!!DMA DoBlock!!!">
						
	mov	dx, word ptr [bp.olddx] ;set head #
	push	di					
	push	ds					
	push	ax			;AH=# of sectors before DMA err
					;AL - User requeseted # of sectors
	mov	byte ptr CS:[phys_drv],1				
	mov	al, dl							
	call	SetDrive		;get BDS pointer for this DISK. 
	pop	ax							
	mov	byte ptr CS:[phys_drv],0				
	test	word ptr [DI].Flags, fNon_Removable ;don't have to worry
	jnz	DoBlockHard		;about floppies. They are track by
					;track operatiions	
	mov	al, ah			;set al = ah for floppies
	jmp	short DoBlockCont			
DoBlockHard:					
	push	cx				
	xor	cx, cx				
	mov	cx, [DI].SecLim 	;# of sectors/track
	mov	ch, 63						
	sub	ch, cl						
	mov	al, ch						
	xchg	ah, al			;now ah - safe # of sectors
					;al - # of sectors before DMA err
	pop	cx							
DoBlockCont:								
	pop	ds							
	pop	di							
DoBlockContinue:							
	Message ftestDisk,<"%%DMA DoBlock Loop%%">                     
	cmp	ah, al		;if safe_# >= #_of_sectors_to_go_before DMA,
	jae	DoBlocklast	;then #_of_sectors_to_go as it is for DoInt.
	push	ax		;save AH, AL				
	mov	al, ah		;Otherwise, set al to ah to operate.	
	jmp	short DoBlockDoInt   ;DoInt will set AH to a proper function in [BP.Oldax]
DoBlocklast:						
	mov	ah, al					
	push	ax			;save AH	
DoBlockDoInt:				;let AH=AL=# of sectors this shot
	CALL	DoInt							 
	JC	BAD13			;something happened, bye!	 
	pop	ax							 
	SUB	BYTE PTR [BP.oldax], AH ;decrement by the successful operation	
	ADD	CL,AH			;advance sector number. Safety gauranteed.	
	ADD	BH,AH			;advance DMA address			
	ADD	BH,AH			;twice for 512 byte sectors.	
	cmp	ah, al			;check the previous value	
	je	Buffer			;if #_of_sectors_to_go < safe_#, then we are done already. 
	sub	al, ah			;otherwise, #_sector_to_go = #_of_sector_to_go - safe_#  
	call	Check_Wrap		;get new CX, DH for the next operation. 		  
	jmp	short DoBlockContinue	;handles next sectors left.			
;;End of Modification ------------------------------------------------------
;
Buffer:
	push	BX
	mov	AH,BYTE PTR [BP.oldax+1]
	cmp	AH,ROMWrite
	jnz	DoRead
;
; Copy the offending sector into local buffer
;
	SaveReg <DS,ES,SI,DI>
	push	CS			; exchange segment registers
	push	ES
	pop	DS
	pop	ES
	mov	DI,OFFSET DiskSector	; where to move
	push	DI			; save it
	mov	SI,BX			; source
	call	Move
	pop	BX			; new transfer address
	RestoreReg  <DI,SI>
	mov	AL,1
	mov	DL,byte ptr [BP.olddx]	; set drive number
	call	Check_Wrap		; check for head or cylinder wrap

;
;   AH is function
;   AL is 1 for single sector transfer
;   ES:BX is local transfer addres
;   CX is track/sector number
;   DX is head/drive number
;   SI,DI unchanged
;
	CALL	DoInt
	RestoreReg  <ES,DS>
	jc	Bad13			; go clean up
	jmp	SHORT DoTail
;
; Reading a sector.  Do INT first, then move things around
;
DoRead:
	SaveReg <ES,BX>
	push	CS
	pop	ES
	mov	BX,OFFSET DiskSector
	mov	AL,1
	mov	DL,byte ptr [BP.olddx]	; set drive number
	call	Check_Wrap		; check for head or cylinder wrap

;
;   AH = function
;   AL = 1 for single sector
;   ES:BX points to local buffer
;   CX, DX are track/sector, head/drive
;
	CALL	DoInt
	RestoreReg  <BX,ES>
	jc	Bad13			; error => clean up
	SaveReg <DS,SI,DI>
	push	CS
	pop	DS
	mov	DI,BX
	mov	SI,OFFSET DiskSector
	call	Move
	RestoreReg  <DI,SI,DS>
;
; Note the fact that we've done 1 more sector
;
DoTail:
	pop	BX			; retrieve new DMA area
	add	BH,2			; advance over sector
	inc	CX
	mov	AL,BYTE PTR [BP.oldAX]
	clc
	dec	AL
	jz	Bad13			; no more I/O
	mov	DL,byte ptr [BP.olddx]	; set drive number
	call	Check_Wrap		; check for head or cylinder wrap
	call	DoInt
;
; We are done.	AX has the final code; we throw away what we got before
;
Bad13:
	mov	SP,BP
	RestoreReg  <BP,BX,BX,CX,DX>
	ret	2
Block13 ENDP




	PAGE

	include msioctl.inc

	PAGE
;
; Check_Wrap is a routine that adjusts the starting sector, starting head
; and starting cylinder for an Int 13 request that requests I/O of a lot
; of sectors. It only does this for fixed disks. It is used in the sections
; of code that handle ECC errors and DMA errors. It is necessary, because
; ordinarily the ROM would take care of wraps around heads and cylinders,
; but we break down a request when we get an ECC or DMA error into several
; I/O of one or more sectors. In this case, we may already be beyond the
; number of sectors on a track on the medium, and the request would fail.
;
; Input conditions:
;	ALL registers set up for an Int 13 request.
;
; Output:
;	 - contains starting head number for request
;	 - contains starting sector and cylinder numbers
;	(The above may or may not have been changed, and are 0-based)
;	All other registers preserved.
;
	public check_wrap
Check_Wrap:
	Message ftestDisk,<"Entering Check_Wrap...",cr,lf>
	SaveReg <AX,BX,DS,DI>
	mov	byte ptr cs:[Phys_drv],1;Use phys. drive in AL to get BDS
	mov	al,dl			; put drive number in AL for get BDS
	call	SetDrive		; Get pointer to BDS for drive.
	mov	byte ptr cs:[phys_drv],0; Restore flag to use Logical Drive
	jc	No_wrap 		; Do nothing if wrong phys. drive

	test	word ptr [di].Flags,fNon_Removable
	jz	No_wrap 		; No wrapping for removable media
	MOV	BX,[DI].SECLIM
	MOV	AX,CX
	AND	AX,003FH		; EXTRACT SECTOR NUMBER
	cmp	ax,bx			; If Wrap
	jbe	No_wrap

	div	bl			; AH=new sector#, AL = # of head wraps

; We need to be careful here.  If the new sector number == 0, then we are
; on the last sector on that track
	or	ah,ah
	jnz	Not_on_Bound

	mov	ah,bl			; set sector = SECLIM if on Bndry
	dec	al			; and decrement Num. head wraps

Not_on_Bound:
	and	CL,0C0H 		; zero out sector #

	or	CL,ah			; OR in new sector #
	xor	ah,ah			; AX = # of head wraps
	inc	ax
	add	al,DH			; add in starting head #
	adc	ah,0			; catch any carry
	CMP	AX,[DI].HDLIM		; are we going to wrap around a head?
	jbe	No_Wrap_Head		; Do not lose new head number!!

	push	DX			; preserve drive number and head number
	xor	dx,dx
	mov	bx,[DI].HDLIM
	div	bx			; DX=new head #, AX=# of cylinder wraps
; Careful here! If new head # is 0, then we are on the last head.
	or	dx,dx
	jnz	No_Head_Bound

	mov	dx,bx			; On boundary. Set to HDLIM
; If we had some cylinder wraps, we need to reduce them by one!!
	or	ax,ax
	jz	No_Head_Bound

	dec	ax			; Reduce number of cylinder wraps
No_Head_Bound:
	mov	bh,dl			; bh has new head number
	POP	DX			; restore drive number and head number

	dec	bh			; get it 0-based
	mov	DH,bh			; set up new head number in DH

	mov	bh,CL
	and	bh,3FH			; preserve sector number
	mov	bl,6
	xchg	cl,bl
	shr	bl,cl			; get ms cylinder bits to ls end

	ADD	CH,AL			; ADD IN CYLINDER WRAP
	adc	bl,ah			; add in high byte
	shl	bl,cl			; move up to ms end
	xchg	bl,cl			; restore cylinder bits into CL
	or	CL,bh			; OR in sector number

No_Wrap:
	clc				; reset carry
	RestoreReg <DI,DS,BX,AX>
	RET

No_Wrap_Head:
	mov	DH,al			; Do not lose new head number
	dec	DH			; get it 0-based
	jmp	short No_Wrap

;
; INT_2F_13:
;		This code is chained into the INT_2F interrupt during bios
;	initialization.  It allows the user to change the ORIG13 int_13 vector

; INT_2F_13:
;		This code is chained into the INT_2F interrupt during bios
;	initialization.  It allows the user to change the ORIG13 int_13 vector
;	after booting.	This allows testing and implementation of custom int_13
;	handlers, without giving up MS-DOS error recovery
;
;	Entry Conditions
;		AH	== RESET_Int_13  (13h)
;		DS:DX	== Address of New INT_13 Handler
;		ES:BX	== Address of New INT_13 vector used by WARM BOOT
;								(INT 19)
;
;	Exit Conditions
;		Orig13	== Address of new Int_13 Handler
;		DS:DX	== Old ORIG13 value
;		ES:BX	== Old OLD13  value

	ASSUME CS:CODE,DS:Nothing,ES:nothing,SS:NOTHING

	Public INT_2F_13
INT_2F_13	Proc	Far

	cmp	AH,13h			; IF (interrupt_value != Reset_Int_13)
	je	Chg_Orig13
	jmp	CS:[Next2f_13]		;	THEN Continue on Int_2F chain

Chg_Orig13:				;	ELSE
	push	word ptr cs:[Orig13]	;	   Save Old value of OLD13 and
	push	word ptr cs:[Orig13 + 2];	   ORIG13 so that we can

	Push	word ptr cs:[OLD13]	;	   Return them to caller
	Push	word ptr cs:[OLD13 + 2]

	mov	Word Ptr CS:[Orig13],DX ;	   Orig13 := Addr. Of New INT_13
					;				Vector
	mov	Word Ptr CS:[Orig13+2],DS

	mov	Word Ptr CS:[Old13],BX	;	    Old13 := Addr. Of New
					;			  Boot_13 vector
	mov	Word Ptr CS:[Old13+2],ES

	pop	ES			;	    ES:BX := Old OLD13 vector
	pop	BX

	pop	DS			;	    DS:DX := Old ORIG13 vector
	pop	DX

	iret				;	END else

Int_2F_13	ENDP






Move	Proc	Near
	push	CX
	mov	CX,512/2
	cld
	rep	MOVSW
	pop	CX
	ret
Move Endp




DoINT	proc	NEAR
	mov	DL,byte ptr [BP.olddx]
	xor	AH,AH
	or	AL,AL
	jz	DoIntDone
	mov	AH,BYTE PTR [BP.oldax+1]
	push	[BP.oldf]
	call	Orig13
	pushf
	pop	[BP.oldf]
DoIntDone:
	ret
DoInt	endp

CODE	ENDS
	END
