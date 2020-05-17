TITLE	BIOS SYSTEM INITIALIZATION
TRUE	    EQU 0FFFFh
FALSE	    EQU 0

;IBMVER	   EQU	   TRUE
;IBM	   EQU	   IBMVER
STACKSW    EQU	   TRUE 		;Include Switchable Hardware Stks ;3.30
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
	include smdossym.inc	; Reduced version of DOSSYM.INC	  ;3.30
	INCLUDE devsym.inc
	include ioctl.inc
.list

	IF	NOT IBM
	IF	NOT IBMJAPVER
	EXTRN	RE_INIT:FAR
	ENDIF
	ENDIF

SYSINITSEG	SEGMENT PUBLIC 'SYSTEM_INIT' BYTE

ASSUME	CS:SYSINITSEG,DS:NOTHING,ES:NOTHING,SS:NOTHING

	EXTRN	BADOPM:BYTE,CRLFM:BYTE,BADCOM:BYTE,BADMEM:BYTE,BADBLOCK:BYTE
	EXTRN	BADSIZ_PRE:BYTE,BADLD_PRE:BYTE
	EXTRN	BADSIZ_POST:BYTE,BADLD_POST:BYTE
	EXTRN	SYSSIZE:BYTE,BADCOUNTRY:BYTE

	EXTRN  dosinfo:dword,entry_point:dword,
	EXTRN  MEMORY_SIZE:WORD,fcbs:byte,keep:byte
	EXTRN  DEFAULT_DRIVE:BYTE,confbot:word,alloclim:word
	EXTRN  BUFFERS:WORD,zero:byte,sepchr:byte
	EXTRN  FILES:BYTE,stall:near
	EXTRN  count:word,chrptr:word
	EXTRN  bufptr:byte,memlo:word,prmblk:byte,memhi:word
	EXTRN  ldoff:word,area:word,PACKET:BYTE,UNITCOUNT:BYTE,
	EXTRN  BREAK_ADDR:DWORD,BPB_ADDR:DWORD,drivenumber:byte

	PUBLIC Int24,Open_Dev,Organize,Mem_Err,Newline,CallDev,Badload
	PUBLIC PrnDev,AuxDev,Config,Commnd,Condev,GetNum,BadFil,PrnErr
	PUBLIC Round,Delim,Print,Set_Break
	PUBLIC SetParms, ParseLine, DiddleBack
	PUBLIC Skip_delim,SetDOSCountryInfo,Set_Country_Path,Move_Asciiz  ;3.30
	PUBLIC Cntry_Drv,Cntry_Root,Cntry_Path				  ;3.30
	PUBLIC Delim							  ;3.30

ASSUME DS:SYSINITSEG
;
; The following set of routines is used to parse the DRIVPARM = command in
; the CONFIG.SYS file to change the default drive parameters.
;
SetParms:
	push	ds
	push	ax
	push	bx
	push	cx
	push	dx
	xor	bx,bx
	mov	bl,byte ptr drive
	inc	bl		    ; get it correct for IOCTL call (1=A,2=B...)
	push	cs
	pop	ds
	mov	dx,offset DeviceParameters
	mov	ah, IOCTL
	mov	al, GENERIC_IOCTL
	mov	ch, RAWIO
	mov	cl, SET_DEVICE_PARAMETERS
	int	21H
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	pop	ds
	ret

;
; Replace default values for further DRIVPARM commands
;
DiddleBack:
	mov	word ptr DeviceParameters.DP_Cylinders,80
	mov	byte ptr DeviceParameters.DP_DeviceType, DEV_3INCH720KB
	mov	word ptr DeviceParameters.DP_DeviceAttributes,0
	mov	word ptr switches,0	    ; zero all switches
	ret

;
; Entry point is ParseLine. AL contains the first character in command line.
;
ParseLine:			    ; don't get character first time
	push	ds
	push	cs
	pop	ds
NextSwtch:
	cmp	al,13			; carriage return?
	jz	done_line
	cmp	al,10			; linefeed?
	jz	put_back		; put it back and done
; Anything less or equal to a space is ignored.
	cmp	al,' '                  ; space?
	jbe	get_next		; skip over space
	cmp	al,'/'
	jz	getparm
	stc			    ; mark error invalid-character-in-input
	jmp	short exitpl

getparm:
	call	Check_Switch
	mov	word ptr Switches,BX	     ; save switches read so far
	jc	swterr
get_next:
	invoke	getchr
	jc	done_line
	jmp	NextSwtch
swterr:
	jmp	exitpl		    ; exit if error

done_line:
	test	word ptr Switches,flagdrive  ; see if drive specified
	jnz	okay
	stc			    ; mark error no-drive-specified
	jmp	short exitpl

okay:
	mov	ax,word ptr switches
	and	ax,0003H	    ; get flag bits for changeline and non-rem
	mov	word ptr DeviceParameters.DP_DeviceAttributes,ax
	mov	word ptr DeviceParameters.DP_TrackTableEntries, 0
	clc			    ; everything is fine
	call	SetDeviceParameters
exitpl:
	pop	ds
	ret

put_back:
	inc	count			; one more char to scan
	dec	chrptr			; back up over linefeed
	jmp	short done_line
;
; Processes a switch in the input. It ensures that the switch is valid, and
; gets the number, if any required, following the switch. The switch and the
; number *must* be separated by a colon. Carry is set if there is any kind of
; error.
;
Check_Switch:
	invoke	getchr
	jc	err_check
	and	al,0DFH 	    ; convert it to upper case
	cmp	al,'A'
	jb	err_check
	cmp	al,'Z'
	ja	err_check
	push	es
	push	cs
	pop	es
	mov	cl,byte ptr switchlist	     ; get number of valid switches
	mov	ch,0
	mov	di,1+offset switchlist	; point to string of valid switches
	repne	scasb
	pop	es
	jnz	err_check
	mov	ax,1
	shl	ax,cl		; set bit to indicate switch
	mov	bx,word ptr switches	 ; get switches so far
	or	bx,ax		; save this with other switches
	mov	cx,ax
	test	ax,7cH		; test against switches that require number to follow
	jz	done_swtch
	invoke	getchr
	jc	err_Swtch
	cmp	al,':'
	jnz	err_swtch
	invoke	getchr
	push	bx			; preserve switches
	mov	byte ptr cs:sepchr,' '          ; allow space separators
	call	GetNum
	mov	byte ptr cs:sepchr,0
	pop	bx			; restore switches
; Because GetNum does not consider carriage-return or line-feed as OK, we do
; not check for carry set here. If there is an error, it will be detected
; further on (hopefully).
	call	Process_Num

done_swtch:
	clc
	ret

err_swtch:
	xor	bx,cx			; remove this switch from the records
err_check:
	stc
	ret

;
; This routine takes the switch just input, and the number following (if any),
; and sets the value in the appropriate variable. If the number input is zero
; then it does nothing - it assumes the default value that is present in the
; variable at the beginning. Zero is OK for form factor and drive, however.
;
Process_Num:
	test	word ptr Switches,cx	 ; if this switch has been done before,
	jnz	done_ret	    ; ignore this one.
	test	cx,flagdrive
	jz	try_f
	mov	byte ptr drive,al
	jmp	short done_ret

try_f:
	test	cx,flagff
	jz	try_t
; Ensure that we do not get bogus form factors that are not supported
	;cmp	al,Max_Dev_Type
	;ja	done_ret
	mov	byte ptr DeviceParameters.DP_DeviceType,al
	jmp	short done_ret

try_t:
	or	ax,ax
	jz	done_ret	    ; if number entered was 0, assume default value
	test	cx,flagcyln
	jz	try_s
	mov	word ptr DeviceParameters.DP_Cylinders,ax
	jmp	short done_ret

try_s:
	test	cx,flagseclim
	jz	try_h
	mov	word ptr slim,ax
	jmp	short done_ret
;
; Must be for number of heads
try_h:
	mov	word ptr hlim,ax

done_ret:
	clc
	ret

;
; SetDeviceParameters sets up the recommended BPB in each BDS in the
; system based on the form factor. It is assumed that the BPBs for the
; various form factors are present in the BPBTable. For hard files,
; the Recommended BPB is the same as the BPB on the drive.
; No attempt is made to preserve registers since we are going to jump to
; SYSINIT straight after this routine.
;
SetDeviceParameters:
	push	es
	push	cs
	pop	es
ASSUME ES:SYSINITSEG
	xor	bx,bx
	mov	bl,byte ptr DeviceParameters.DP_DeviceType
	cmp	bl,DEV_5INCH
	jnz	Got_80
	mov	cx,40			; 48tpi has 40 cylinders
	mov	word ptr DeviceParameters.DP_Cylinders,cx
Got_80:
	shl	bx,1			; get index into BPB table
	mov	si,offset BPBTable
	mov	si,word ptr [si+bx]	; get address of BPB
Set_RecBPB:
	mov	di,offset DeviceParameters.DP_BPB	 ; es:di -> BPB
	mov	cx,size a_BPB
	cld
	repe	movsb
	pop	es
ASSUME ES:NOTHING
	test	word ptr switches,flagseclim
	jz	see_heads
	mov	ax,word ptr slim
	mov	word ptr DeviceParameters.DP_BPB.BPB_SectorsPerTrack,ax
see_heads:
	test	word ptr switches,flagheads
	jz	Set_All_Done
	mov	ax,word ptr hlim
	mov	word ptr DeviceParameters.DP_BPB.BPB_Heads,ax
;
; We need to set the media byte and the total number of sectors to reflect the
; number of heads. We do this by multiplying the number of heads by the number
; of 'sectors per head'. This is not a fool-proof scheme!!
;
	mov	cx,ax			; cx has number of heads
	dec	cl			; get it 0-based
	mov	ax,DeviceParameters.DP_BPB.BPB_TotalSectors	; this is OK for two heads
	sar	ax,1			; ax contains # of sectors/head
	sal	ax,cl
	jc	Set_All_Done		; We have too many sectors - overflow!!
	mov	DeviceParameters.DP_BPB.BPB_TotalSectors,ax
; Set up correct Media Descriptor Byte
	cmp	cl,1
	mov	bl,0F0H
	mov	al,2			; AL contains sectors/cluster
	ja	Got_Correct_Mediad
	mov	bl,byte ptr DeviceParameters.DP_BPB.BPB_MediaDescriptor
	je	Got_Correct_Mediad
; We have one head - OK for 48tpi medium
	mov	al,1			; AL contains sectors/cluster
	mov	ch,DeviceParameters.DP_DeviceType
	cmp	ch,DEV_5INCH
	jz	Dec_Mediad
	mov	bl,0F0H
	jmp	short Got_Correct_Mediad
Dec_Mediad:
	dec	bl			; adjust for one head
Got_Correct_Mediad:
	mov	byte ptr DeviceParameters.DP_BPB.BPB_MediaDescriptor,bl
	mov	byte ptr DeviceParameters.DP_BPB.BPB_SectorsPerCluster,al
	clc
Set_All_Done:
	RET

ASSUME DS:NOTHING, ES:NOTHING

NOCHAR1: STC
	 return

ORGANIZE:
	MOV	CX,[COUNT]
	JCXZ	NOCHAR1
	CALL	MAPCASE
	XOR	SI,SI
	MOV	DI,SI

ORG1:	CALL	GET			;SKIP LEADING CONTROL CHARACTERS
	CMP	AL,' '
	JB	ORG1

	PUSH	CX
	PUSH	SI
	PUSH	DI
	MOV	BP,SI
	DEC	BP
	MOV	SI,OFFSET COMTAB	;Prepare to search command table
	MOV	CH,0
FINDCOM:
	MOV	DI,BP
	MOV	CL,[SI]
	INC	SI
	JCXZ	NOCOM
	REPE	CMPSB
	LAHF
	ADD	SI,CX			;Bump to next position without affecting flags
	SAHF
	LODSB				;Get indicator letter
	JNZ	FINDCOM
	POP	DI
	POP	SI
	POP	CX
	JMP	SHORT GOTCOM

NOCOM:
	POP	DI
	POP	SI
	POP	CX
	MOV	AL,'Z'
GOTCOM: STOSB				;SAVE INDICATOR CHAR IN BUFFER

ORG2:	CALL	GET2			;SKIP NAME UNTIL DELIMITER
	CALL	DELIM			;
	JNZ	ORG2

	CALL	GET			;GET CHARS TO RIGHT OF EQUALS SIGN
	STOSB

ORG4:	CALL	GET2
	call	delim			; 5/30/86. "device=filename/p..."  ;3.30
	jz	ORG_EXT 		; 5/30/86			       ;3.30
	STOSB
	CMP	AL,' '
	JA	ORG4
	CMP	AL,10
	JZ	ORG1

	MOV	BYTE PTR ES:[DI-1],0
ORG5:	CALL	GET2
	STOSB
	CMP	AL,10
	JNZ	ORG5
	JMP	ORG1

ORG_EXT:								  ;3.30
	mov	byte ptr es:[di], 0	;put 0 at DI to make it an ASCIIZ ;3.30
	inc	DI			;				  ;3.30
	stosb				;and copy the delimeter char.	  ;3.30
	jmp	short ORG5		;and continue as usual. 	  ;3.30

GET2:
	JCXZ	NOGET
	MOV	AL,ES:[SI]
	INC	SI
	DEC	CX
	return

GET:	JCXZ	NOGET
	MOV	AL,ES:[SI]
	INC	SI
	DEC	CX
	CALL	DELIM
	JZ	GET
	return


DELIM:	CMP	AL,' '
	retz
	CMP	AL,9
	retz
	CMP	AL,'='
	retz
	CMP	AL,','
	retz
	CMP	AL,';'
	retz			; 5/23/86				  ;3.30
	CMP	AL,'/'          ; 5/30/86. IBM will assume "/" delim  ;3.30
	retz								  ;3.30
	cmp	al, 0		; 5/23/86 Special case for sysinit!!! ;3.30
	return


NOGET:	POP	CX
	MOV	COUNT,DI
	XOR	SI,SI
	MOV	CHRPTR,SI
	return
;
;  NEWLINE RETURNS WITH FIRST CHARACTER OF NEXT LINE
;
NEWLINE:invoke	GETCHR			;SKIP NON-CONTROL CHARACTERS
	retc
	CMP	AL,10			;LOOK FOR LINE FEED
	JNZ	NEWLINE
	invoke	GETCHR
	return

MAPCASE:
	PUSH	CX
	PUSH	SI
	PUSH	DS
	PUSH	ES
	POP	DS
	XOR	SI,SI
CONVLOOP:
	LODSB

	IF	KANJI
	CALL	TESTKANJ
	JZ	NORMCONV
	INC	SI			;Skip next char
	DEC	CX
	JCXZ	CONVDONE		;Just ignore 1/2 kanji error
;Fall through, know AL is not in 'a'-'z' range
NORMCONV:
	ENDIF

	CMP	AL,'a'
	JB	NOCONV
	CMP	AL,'z'
	JA	NOCONV
	SUB	AL,20H
	MOV	[SI-1],AL
NOCONV:
	LOOP	CONVLOOP
CONVDONE:
	POP	DS
	POP	SI
	POP	CX
	return

	IF	KANJI
TESTKANJ:
	CMP	AL,81H
	JB	NOTLEAD
	CMP	AL,9FH
	JBE	ISLEAD
	CMP	AL,0E0H
	JB	NOTLEAD
	CMP	AL,0FCH
	JBE	ISLEAD
NOTLEAD:
	PUSH	AX
	XOR	AX,AX			;Set zero
	POP	AX
	return

ISLEAD:
	PUSH	AX
	XOR	AX,AX			;Set zero
	INC	AX			;Reset zero
	POP	AX
	return
	ENDIF

ASSUME DS:NOTHING

Yes_Break_Failed:			;dev drv Init failed and aborted. ;3.30
	stc								  ;3.30
	pop	ax							  ;3.30
	return								  ;3.30

SET_BREAK:
; 8/14/86  For DOS 3.3, this routine is modified to take care of the  ;3.30
;Device driver's initialization error and abort.                          ;3.30
;If [break_addr+2] == [memhi] && [break_addr] = 0 then assume		  ;3.30
;that the device driver's initialization has an error and wanted to       ;3.30
;abort the device driver.  In this case, this routine will set carry	  ;3.30
;and return to the caller.						  ;3.30
;									  ;3.30
	PUSH	AX
	MOV	AX,WORD PTR [BREAK_ADDR+2]  ;REMOVE THE INIT CODE
	cmp	ax, [MEMHI]						  ;3.30
	jne	Set_Break_Continue	    ;if not same, then O.K.	  ;3.30
									  ;3.30
	cmp	word ptr [BREAK_ADDR],0 				  ;3.30
	je	Yes_Break_failed	    ;[Break_addr+2]=[MEMHI] & [Break_addr]=0 ;3.30
									  ;3.30
Set_Break_Continue:							  ;3.30
	MOV	[MEMHI],AX
	MOV	AX,WORD PTR [BREAK_ADDR]
	MOV	[MEMLO],AX
	POP	AX			    ; NOTE FALL THROUGH

;
; Round the values in MEMLO and MEMHI to paragraph boundary.
; Perform bounds check.
;
ROUND:
	PUSH	AX
	MOV	AX,[MEMLO]

	invoke	ParaRound		; para round up

	ADD	[MEMHI],AX
	MOV	[MEMLO],0
	mov	ax,memhi		; ax = new memhi
	CMP	AX,[ALLOCLIM]		; if new memhi >= alloclim, error
	JAE	MEM_ERR
	POP	AX
	clc				;clear carry			  ;3.30
	return

MEM_ERR:
	MOV	DX,OFFSET BADMEM
	PUSH	CS
	POP	DS
	CALL	PRINT
	JMP	STALL

CALLDEV:MOV	DS,WORD PTR CS:[ENTRY_POINT+2]
	ADD	BX,WORD PTR CS:[ENTRY_POINT]	;Do a little relocation
	MOV	AX,DS:[BX]
	PUSH	WORD PTR CS:[ENTRY_POINT]
	MOV	WORD PTR CS:[ENTRY_POINT],AX
	MOV	BX,OFFSET PACKET
	CALL	[ENTRY_POINT]
	POP	WORD PTR CS:[ENTRY_POINT]
	return

BADNUM:
	MOV	sepchr,0
	XOR	AX,AX		; Set Zero flag, and AX = 0
	pop	bx		; 					  ;3.30
	stc			; AND carry set
	return

ToDigit:
	SUB	AL,'0'
	JB	NotDig
	CMP	AL,9
	JA	NotDig
	CLC
	return
NotDig: STC
	return

; GetNum parses a decimal number.
; Returns it in AX, sets zero flag if AX = 0 (MAY BE considered an
; error), if number is BAD carry is set, zero is set, AX=0.
GETNUM: push	bx			; 				  ;3.30
	XOR	BX,BX			; running count is zero
B2:	CALL	ToDigit 		; do we have a digit
	JC	BadNum			; no, bomb
	XCHG	AX,BX			; put total in AX
	PUSH	BX			; save digit
	MOV	BX,10			; base of arithmetic
	MUL	BX			; shift by one decimal di...
	POP	BX			; get back digit
	ADD	AL,BL			; get total
	ADC	AH,0			; make that 16 bits
	JC	BADNUM			; too big a number
	XCHG	AX,BX			; stash total

	invoke	GETCHR			;GET NEXT DIGIT
	JC	B1			; no more characters
	cmp	al, ' '                 ; 5/23/86 space?              ;3.30
	jz	B15			; 5/23/86 then end of digits  ;3.30
	cmp	al, ','                 ; 5/23/86 ',' is a seperator! ;3.30
	jz	B15			; 5/23/86 then end of digits. ;3.30
	cmp	al, 9			; 5/23/86 TAB		  ;3.30
	jz	B15			;				  ;3.30
	CMP	AL,SepChr		; allow , separators
	JZ	b15
	cmp	al,SWTCHR		; See if another switch follows
	JZ	b15
	cmp	al,10			; Line-feed?
	jz	b15
	cmp	al,13			; Carriage return?
	jz	b15
	OR	AL,AL			; end of line separator?
	JNZ	B2			; no, try as a valid char...
b15:	INC	COUNT			; one more character to s...
	DEC	CHRPTR			; back up over separator
B1:	MOV	AX,BX			; get proper count
	OR	AX,AX			; Clears carry, sets Zero accordingly
	pop	bx							  ;3.30
	return

SKIP_DELIM	proc	near		;				       ;3.30
;Skip the delimeters pointed by CHRPTR.  AL will contain the first non delimete;3.30r
;character encountered and CHRPTR will point to the next character.	       ;3.30
;This rouitne will assume the second "," found as a non delimiter character. So;3.30
;in case if the string is " , , ", this routine will stop at the second ",". At;3.30
;this time, Zero flag is set.						       ;3.30
;If COUNT is exhausted, then carry will be set. 			       ;3.30
Skip_delim_char:							       ;3.30
	call	getchr							       ;3.30
	jc	Skip_delim_exit 					       ;3.30
	cmp	al, ','                 ;the first comma?                      ;3.30
	je	Skip_delim_next 					       ;3.30
	call	delim			;check the charater in AL.	       ;3.30
	jz	Skip_delim_char 					       ;3.30
	jmp	short Skip_delim_exit	;found a non delim char 	       ;3.30
Skip_delim_next:							       ;3.30
	call	getchr							       ;3.30
	jc	Skip_delim_exit 					       ;3.30
	cmp	al, ','                 ;the second comma?                     ;3.30
	je	Skip_delim_exit 	;done				       ;3.30
	call	delim							       ;3.30
	jz	Skip_delim_next 					       ;3.30
Skip_delim_exit:							       ;3.30
	return								       ;3.30
SKIP_DELIM	endp							       ;3.30
									       ;3.30
; 5/26/86 *****************************************************************;3.30
SetDOSCountryInfo	proc	near					       ;3.30
;Input: ES:DI -> pointer to DOS_COUNTRY_CDPG_INFO			       ;3.30
;	DS:0  -> buffer.						       ;3.30
;	SI = 0								       ;3.30
;	AX = country id 						       ;3.30
;	DX = code page id. (If 0, then use ccSysCodePage as a default.)        ;3.30
;	BX = file handle						       ;3.30
;	This routine can handle maxium 72 COUNTRY_DATA entries. 	       ;3.30
;Output: DOS_country_cdpg_info set.					       ;3.30
;	 Carry set if any file read failure or wrong information in the file.  ;3.30
;	 Carry set and CX = -1 if cannot find the matching COUNTRY_id, CODEPAGE;3.30
;	 _id in the file.						       ;3.30
									       ;3.30
	push	di							       ;3.30
	push	ax							       ;3.30
	push	dx							       ;3.30
									       ;3.30
	xor	cx,cx							       ;3.30
	xor	dx,dx							       ;3.30
	mov	ax, 512 		;read 512 bytes 		       ;3.30
	call	ReadInControlBuffer	;Read the file header		       ;3.30
	jc	SetDOSData_fail 					       ;3.30
	push	es							       ;3.30
	push	si							       ;3.30
	push	cs							       ;3.30
	pop	es							       ;3.30
	mov	di, offset COUNTRY_FILE_SIGNATURE			       ;3.30
	mov	cx, 8			;length of the signature	       ;3.30
	repz	cmpsb							       ;3.30
	pop	si							       ;3.30
	pop	es							       ;3.30
	jnz	SetDOSData_fail 	;signature mismatch		       ;3.30
									       ;3.30
	add	si, 18			;SI -> county info type 	       ;3.30
	cmp	byte ptr ds:[si], 1	;Only accept type 1 (Currently only 1 h;3.30eader type)
	jne	SetDOSData_fail 	;cannot proceed. error return	       ;3.30
	inc	si			;SI -> file offset		       ;3.30
	mov	dx, word ptr ds:[si]	;Get the INFO file offset.	       ;3.30
	mov	cx, word ptr ds:[si+2]					       ;3.30
	mov	ax, 1024		;read 1024 bytes.		       ;3.30
	call	ReadInControlBuffer	;Read INFO			       ;3.30
	jc	SetDOSData_fail 					       ;3.30
	mov	cx, word ptr ds:[si]	;get the # of country, codepage combina;3.30tion entries
	cmp	cx, 72			;cannot handle more than 72 entries.   ;3.30
	ja	SetDOSData_fail 					       ;3.30
	inc	si							       ;3.30
	inc	si			;SI -> entry information packet        ;3.30
	pop	dx			;restore code page id		       ;3.30
	pop	ax			;restore country id		       ;3.30
	pop	di							       ;3.30
									       ;3.30
SetDOSCntry_find:			;Search for desired country_id,codepage;3.30_id.
	cmp	ax, word ptr ds:[si+2]	;compare country_id		       ;3.30
	jne	SetDOSCntry_next					       ;3.30
	cmp	dx, 0			;No user specified code page ?	       ;3.30
	je	SetDOSCntry_any_codepage;then no need to match code page id.   ;3.30
	cmp	dx, word ptr ds:[si+4]	;compare code page id		       ;3.30
	je	SetDOSCntry_got_it					       ;3.30
SetDOSCntry_next:							       ;3.30
	add	si, word ptr ds:[si]	;next entry			       ;3.30
	inc	si							       ;3.30
	inc	si			;take a word for size of entry itself  ;3.30
	loop	SetDOSCntry_find					       ;3.30
	mov	cx, -1			;signals that bad country id entered.  ;3.30
SetDOSCntry_fail:							       ;3.30
	stc								       ;3.30
	ret								       ;3.30
									       ;3.30
SetDOSData_fail:							       ;3.30
	pop	si							       ;3.30
	pop	cx							       ;3.30
	pop	di							       ;3.30
	jmp	short	SetDOSCntry_fail				       ;3.30
									       ;3.30
SetDOSCntry_any_CodePage:		;use the code_page_id of the country_id;3.30 found.
	mov	dx, word ptr ds:[si+4]					       ;3.30
SetDOSCntry_got_it:			;found the matching entry	       ;3.30
	mov	cs:CntryCodePage_Id, dx ;save code page ID for this country.   ;3.30
	mov	dx, word ptr ds:[si+10] ;get the file offset of country data   ;3.30
	mov	cx, word ptr ds:[si+12] 				       ;3.30
	mov	ax, 512 		;read 512 bytes 		       ;3.30
	call	ReadInControlBuffer					       ;3.30
	jc	SetDOSCntry_fail					       ;3.30
	mov	cx, word ptr ds:[si]	;get the number of entries to handle.  ;3.30
	inc	si							       ;3.30
	inc	si			;SI -> first entry		       ;3.30
									       ;3.30
SetDOSCntry_data:							       ;3.30
	push	di			;ES:DI -> DOS_COUNTRY_CDPG_INFO        ;3.30
	push	cx			;save # of entry left		       ;3.30
	push	si			;si -> current entry in Control buffer ;3.30
									       ;3.30
	mov	al, byte ptr ds:[si+2]	;get data entry id		       ;3.30
	call	GetCountryDestination	;get the address of destination in ES:D;3.30I
	jc	SetDOSCntry_data_next	;No matching data entry id in DOS      ;3.30
									       ;3.30
									       ;3.30
	mov	dx, word ptr ds:[si+4]	;get offset of data		       ;3.30
	mov	cx, word ptr ds:[si+6]					       ;3.30
	mov	ax, 4200h						       ;3.30
	stc								       ;3.30
	int	21h			;move pointer			       ;3.30
	jc	SetDOSData_fail 					       ;3.30
	mov	dx, 512 		;start of data buffer		       ;3.30
	mov	cx, word ptr es:[di]	;length of the corresponding data in DO;3.30S.
	add	cx, 10			;Signature + A word for the length itse;3.30lf
	mov	ah, 3fh 						       ;3.30
	stc								       ;3.30
	int	21h			;read the country.sys data	       ;3.30
	jc	SetDOSData_fail 	;read failure			       ;3.30
	cmp	ax, cx							       ;3.30
	jne	SetDOSData_fail 					       ;3.30
									       ;3.30
	mov	al, byte ptr ds:[si+2]	;save Data id for future use.	       ;3.30
	mov	si, (512+8)		;SI-> data buffer + id tag field       ;3.30
	mov	cx, word ptr ds:[si]	;get the length of the file	       ;3.30
	inc	cx			;Take care of a word for lenght of tab ;3.30
	inc	cx			;itself.			       ;3.30
	cmp	cx, (2048 - 512 - 8)	;Fit into the buffer?		       ;3.30
	ja	SetDOSData_fail 					       ;3.30
	cmp	al, SetCountryInfo	;is the data for SetCountryInfo table? ;3.30
	jne	SetDOSCntry_Mov 	;no, don't worry                       ;3.30
	push	word ptr es:[di+24]	;Cannot destroy ccMono_ptr address. Sav;3.30e them.
	push	word ptr es:[di+26]					       ;3.30
	push	di			;save DI			       ;3.30
									       ;3.30
	push	ax							       ;3.30
	mov	ax,cs:CntryCodePage_Id	;Do not use the Code Page info in Count;3.30ry_Info
	mov	ds:[si+4], ax		;Use the saved one for this !!!!       ;3.30
	pop	ax							       ;3.30
									       ;3.30
SetDOSCntry_Mov:							       ;3.30
	rep	movsb			;copy the table into DOS	       ;3.30
	cmp	al, SetCountryInfo	;was the ccMono_ptr saved?	       ;3.30
	jne	SetDOSCntry_data_next					       ;3.30
	pop	di			;restore DI			       ;3.30
	pop	word ptr es:[di+26]	;restore ccMono_ptr in DOS.	       ;3.30
	pop	word ptr es:[di+24]					       ;3.30
									       ;3.30
SetDOSCntry_data_next:							       ;3.30
	pop	si			;restore control buffer pointer        ;3.30
	pop	cx			;restore # of entries left	       ;3.30
	pop	di			;restore pointer to DSO_COUNTRY_CDPG   ;3.30
	add	si, word ptr ds:[si]	;try to get the next entry	       ;3.30
	inc	si							       ;3.30
	inc	si			;take a word of entry length itself    ;3.30
	loop	SetDOSCntry_data					       ;3.30
	ret								       ;3.30
SetDOSCountryInfo	endp						       ;3.30
;									       ;3.30
									       ;3.30
GetCountryDestination	proc	near					       ;3.30
;Get the destination address in the DOS country info table.		       ;3.30
;Input: AL - Data ID							       ;3.30
;	ES:DI -> DOS_COUNTRY_CDPG_INFO					       ;3.30
;On return:								       ;3.30
;	ES:DI -> Destination address of the matching data id		       ;3.30
;	carry set if no matching data id found in DOS.			       ;3.30
									       ;3.30
	push	cx							       ;3.30
	add	di, ccNumber_of_entries ;skip the reserved area, syscodepage et;3.30c.
	mov	cx, word ptr es:[di]	;get the number of entries	       ;3.30
	inc	di							       ;3.30
	inc	di			;SI -> the first start entry id        ;3.30
GetCntryDest:								       ;3.30
	cmp	byte ptr es:[di], al					       ;3.30
	je	GetCntryDest_OK 					       ;3.30
	cmp	byte ptr es:[di], SetCountryInfo ;was it SetCountryInfo entry? ;3.30
	je	GetCntryDest_1						       ;3.30
	add	di, 5			;next data id			       ;3.30
	jmp	short GetCntryDest_loop 				       ;3.30
GetCntryDest_1: 							       ;3.30
	add	di, NEW_COUNTRY_SIZE + 3 ;next data id			       ;3.30
GetCntryDest_loop:							       ;3.30
	loop	GetCntryDest						       ;3.30
	stc								       ;3.30
	jmp	short	GetCntryDest_exit				       ;3.30
GetCntryDest_OK:							       ;3.30
	cmp	al, SetCountryInfo	;select country info?		       ;3.30
	jne	GetCntryDest_OK1					       ;3.30
	inc	di			;now DI -> ccCountryInfoLen	       ;3.30
	jmp	short	GetCntryDest_exit				       ;3.30
GetCntryDest_OK1:							       ;3.30
	les	di, dword ptr es:[di+1] ;get the destination in ES:DI	       ;3.30
GetCntryDest_Exit:							       ;3.30
	pop	cx							       ;3.30
	ret								       ;3.30
GetCountryDestination	endp						       ;3.30
									       ;3.30
;									       ;3.30
ReadInControlBuffer	proc	near					       ;3.30
;Move file pointer to CX:DX						       ;3.30
;Read AX bytes into the control buffer. (Should be less than 2 Kb)	       ;3.30
;SI will be set to 0 hence DS:SI points to the control buffer.		       ;3.30
;Entry:  CX,DX offset from the start of the file where the read/write pointer  ;3.30
;	 be moved.							       ;3.30
;	 AX - # of bytes to read					       ;3.30
;	 BX - file handle						       ;3.30
;	 DS - buffer seg.						       ;3.30
;Return: The control data information is read into DS:0 - DS:0200.	       ;3.30
;	 CX,DX value destroyed. 					       ;3.30
;	 Carry set if error in Reading file.				       ;3.30
;									       ;3.30
	push	ax			;# of bytes to read		       ;3.30
	mov	ax, 4200h						       ;3.30
	stc								       ;3.30
	int	21h			;move pointer			       ;3.30
	pop	cx			;# of bytes to read		       ;3.30
	jc	RICB_exit						       ;3.30
	xor	dx,dx			;ds:dx -> control buffer	       ;3.30
	xor	si,si							       ;3.30
	mov	ah,3fh			;read into the buffer		       ;3.30
	stc								       ;3.30
	int	21h			;should be less than 1024 bytes.       ;3.30
RICB_exit:								       ;3.30
	ret								       ;3.30
ReadInControlBuffer	endp						       ;3.30
									       ;3.30
;									       ;3.30
SET_COUNTRY_PATH	proc	near					       ;3.30
;In:  DS - SYSINITSEG, ES - CONFBOT, SI -> start of the asciiz path string     ;3.30
;     DOSINFO_EXT, CNTRY_DRV, CNTRY_ROOT, CNTRY_PATH			       ;3.30
;     Assumes current directory is the ROOT directory.			       ;3.30
;Out: DS:DI -> full path (CNTRY_DRV).					       ;3.30
;     Set the CNTRY_DRV string from the COUNTRY=,,path command. 	       ;3.30
;     DS, ES, SI value saved.						       ;3.30
									       ;3.30
	push	si							       ;3.30
	push	ds			;switch ds, es			       ;3.30
	push	es							       ;3.30
	pop	ds							       ;3.30
	pop	es			;now DS -> CONFBOT, ES -> SYSINITSEG   ;3.30
									       ;3.30
	call	chk_drive_letter	;current DS:[SI] is a drive letter?    ;3.30
	jc	SCP_Default_drv 	;no, use current default drive.        ;3.30
	mov	al, byte ptr DS:[SI]					       ;3.30
	inc	si							       ;3.30
	inc	si			;SI -> next char after ":"             ;3.30
	jmp	short SCP_SetDrv					       ;3.30
SCP_Default_drv:							       ;3.30
	mov	ah, 19h 						       ;3.30
	int	21h							       ;3.30
	add	al, "A"                 ;convert it to a character.            ;3.30
SCP_SetDrv:								       ;3.30
	mov	cs:CNTRY_DRV, al	;set the drive letter.		       ;3.30
	mov	di, offset CNTRY_PATH					       ;3.30
	mov	al, byte ptr DS:[SI]					       ;3.30
	cmp	al, "\"                                                        ;3.30
	je	SCP_Root_Dir						       ;3.30
	cmp	al, cs:SWTCHR		;let's accept "/" as an directory delim;3.30
	je	SCP_Root_Dir						       ;3.30
	jmp	short SCP_Path						       ;3.30
SCP_Root_Dir:								       ;3.30
	dec	di			;DI -> CNTRY_ROOT		       ;3.30
SCP_Path:								       ;3.30
	call	MOVE_ASCIIZ		;copy it			       ;3.30
	mov	di, offset CNTRY_DRV					       ;3.30
SCPath_Exit:								       ;3.30
	push	ds			;switch ds, es			       ;3.30
	push	es							       ;3.30
	pop	ds							       ;3.30
	pop	es			;DS, ES value restored		       ;3.30
	pop	si							       ;3.30
	RET								       ;3.30
SET_COUNTRY_PATH	endp						       ;3.30
									       ;3.30
;									       ;3.30
CHK_DRIVE_LETTER	proc	near					       ;3.30
;Check if DS:[SI] is a drive letter followed by ":".                           ;3.30
;Assume that every alpha charater is already converted to UPPER CASE.	       ;3.30
;Carry set if not.							       ;3.30
;									       ;3.30
	push	ax							       ;3.30
	cmp	byte ptr ds:[si], "A"                                          ;3.30
	jb	CDLetter_NO						       ;3.30
	cmp	byte ptr ds:[si], "Z"                                          ;3.30
	ja	CDLetter_NO						       ;3.30
	cmp	byte ptr ds:[si+1], ":"                                        ;3.30
	jne	CDLetter_NO						       ;3.30
	jmp	short CDLetter_exit					       ;3.30
CDLetter_NO:								       ;3.30
	stc								       ;3.30
CDLetter_exit:								       ;3.30
	pop	ax							       ;3.30
	ret								       ;3.30
CHK_DRIVE_LETTER	endp						       ;3.30
									       ;3.30
;									       ;3.30
MOVE_ASCIIZ	proc	near						       ;3.30
;In: DS:SI -> source ES:DI -> target					       ;3.30
;Out: copy the string until 0.						       ;3.30
;Assumes there exists a 0.						       ;3.30
MASCIIZ_loop:								       ;3.30
	movsb								       ;3.30
	cmp	byte ptr DS:[SI-1], 0	;Was it 0?			       ;3.30
	jne	MASCIIZ_loop						       ;3.30
	ret								       ;3.30
MOVE_ASCIIZ	endp							       ;3.30

;
;	DS:DX POINTS TO STRING TO OUTPUT (ASCIZ)
;
;	PRINTS <BADLD_PRE> <STRING> <BADLD_POST>
;
;
;
BADFIL:
	PUSH	CS
	POP	ES
	MOV	SI,DX
BADLOAD:
	MOV	DX,OFFSET BADLD_PRE	;WANT TO PRINT CONFIG ERROR
	MOV	BX,OFFSET BADLD_POST
PRNERR:
	PUSH	CS
	POP	DS
	MOV	AH,STD_CON_STRING_OUTPUT
	INT	21H
PRN1:	MOV	DL,ES:[SI]
	OR	DL,DL
	JZ	PRN2
	MOV	AH,STD_CON_OUTPUT
	INT	21H
	INC	SI
	JMP	PRN1
PRN2:	MOV	DX,BX
PRINT:	MOV	AH,STD_CON_STRING_OUTPUT
	INT	21H
	return


	IF	NOEXEC
;
; LOAD NON EXE FILE CALLED [DS:DX] AT MEMORY LOCATION ES:BX
;
LDFIL:
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DS
	PUSH	BX
	XOR	AX,AX			;OPEN THE FILE
	MOV	AH,OPEN
	STC				;IN CASE OF INT 24
	INT	21H
	POP	DX			;Clean stack in case jump
	JC	LDRET
	PUSH	DX
	MOV	BX,AX			;Handle in BX
	XOR	CX,CX
	XOR	DX,DX
	MOV	AX,(LSEEK SHL 8) OR 2
	STC				;IN CASE OF INT 24
	INT	21H			; Get file size in DX:AX
	JC	LDCLSP
	OR	DX,DX
	JNZ	LDERRP			; File >64K
	POP	DX
	PUSH	DX
	MOV	CX,ES			; CX:DX is xaddr
	ADD	DX,AX			; Add file size to Xaddr
	JNC	DOSIZE
	ADD	CX,1000H		; ripple carry
DOSIZE:
	mov	ax,dx
	call	ParaRound
	mov	dx,ax

	ADD	CX,DX
	CMP	CX,[ALLOCLIM]
	JB	OKLD
	JMP	MEM_ERR

OKLD:
	XOR	CX,CX
	XOR	DX,DX
	MOV	AX,LSEEK SHL 8		;Reset pointer to beginning of file
	STC				;IN CASE OF INT 24
	INT	21H
	JC	LDCLSP
	POP	DX
	PUSH	ES			;READ THE FILE IN
	POP	DS			;Trans addr is DS:DX
	MOV	CX,0FF00H		; .COM files arn't any bigger than
					; 64k-100H
	MOV	AH,READ
	STC				;IN CASE OF INT 24
	INT	21H
	JC	LDCLS
	MOV	SI,DX			;CHECK FOR EXE FILE
	CMP	WORD PTR [SI],"ZM"
	CLC				; Assume OK
	JNZ	LDCLS			; Only know how to do .COM files
	STC
	JMP	SHORT LDCLS

LDERRP:
	STC
LDCLSP:
	POP	DX			;Clean stack
LDCLS:
	PUSHF
	MOV	AH,CLOSE		;CLOSE THE FILE
	STC
	INT	21H
	POPF

LDRET:	POP	DS
	POP	SI
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	return
	ENDIF

;
;  OPEN DEVICE POINTED TO BY DX, AL HAS ACCESS CODE
;   IF UNABLE TO OPEN DO A DEVICE OPEN NULL DEVICE INSTEAD
;
OPEN_DEV:
	CALL	OPEN_FILE
	JNC	OPEN_DEV3
OPEN_DEV1:
	MOV	DX,OFFSET NULDEV
	CALL	OPEN_FILE
	return

OPEN_DEV3:
	MOV	BX,AX			; Handle from open to BX
	XOR	AX,AX			; GET DEVICE INFO
	MOV	AH,IOCTL
	INT	21H
	TEST	DL,10000000B
	retnz
	MOV	AH,CLOSE
	INT	21H
	JMP	OPEN_DEV1

OPEN_FILE:
	MOV	AH,OPEN
	STC
	INT	21H
	return

INT24:	ADD	SP,6			;RESTORE MACHINE STATE
	POP	AX
	POP	BX
	POP	CX
	POP	DX
	POP	SI
	POP	DI
	POP	BP
	POP	DS
	POP	ES
	PUSH	AX
	MOV	AH,GET_DEFAULT_DRIVE	;INITIALIZE DOS
	INT	21H
	POP	AX
	IRET				;BACK TO USER

	IF	ALTVECT
BOOTMES DB	13,10,"MS-DOS version "
	DB	MAJOR_VERSION + "0"
	DB	"."
	DB	(MINOR_VERSION / 10) + "0"
	DB	(MINOR_VERSION MOD 10) + "0"
	DB	13,10
	DB	"Copyright 1981,82 Microsoft Corp.",13,10,"$"
	ENDIF

NULDEV	DB	"NUL",0
CONDEV	DB	"CON",0
AUXDEV	DB	"AUX",0
PRNDEV	DB	"PRN",0

CONFIG	DB	"\CONFIG.SYS",0

CNTRY_DRV   DB	  "A:"                                                    ;3.30
CNTRY_ROOT  DB	  "\"                                                     ;3.30
CNTRY_PATH  DB	  "COUNTRY.SYS",0                                         ;3.30
	    DB	  52 DUP (0)						  ;3.30
									  ;3.30
COUNTRY_FILE_SIGNATURE db 0FFh,'COUNTRY'                                  ;3.30
									  ;3.30
CntryCodePage_Id DW ?							  ;3.30

COMMND	DB	"\COMMAND.COM",0
	DB	20 dup (0)						  ;3.30

COMTAB	LABEL	BYTE
;;;;	   DB	   8,"AVAILDEV",'A'     ; NO LONGER SUPPORTED
	DB	7,"BUFFERS",  'B'
	DB	5,"BREAK",    'C'
	DB	6,"DEVICE",   'D'
	DB	5,"FILES",    'F'
	DB	4,"FCBS",     'X'
	DB	9,"LASTDRIVE",'L'
	DB	8,"DRIVPARM", 'P'       ; RS for DOS 3.2
		IF     STACKSW						  ;3.30
	DB	6,"STACKS",   'K'       ; BAS for DOS 3.2                 ;3.30
		ENDIF							  ;3.30
	DB	7,"COUNTRY",  'Q'
	DB	5,"SHELL",    'S'
;;;;	   DB	   8,"SWITCHAR",'W'     ; NO LONGER SUPPORTED
	DB	0

public DeviceParameters
DeviceParameters a_DeviceParameters <0,DEV_3INCH720KB,0,80>

hlim	    dw	    2
slim	    dw	    9

public drive
drive	db	?

public switches
Switches    dw	?

;
; The following are the recommended BPBs for the media that we know of so
; far.

; 48 tpi diskettes

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
	Dd	0	;hidden sectors - sp
	Dd	0	;big total sectors - sp
	DB	6 DUP(?)	;reserved - sp

; 96tpi diskettes

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
	Dd	0	;hidden sectors - sp
	Dd	0	;big total sectors - sp
	DB	6 DUP(?)	;reserved - sp

; 3 1/2 inch diskette BPB

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
	Dd	0	;hidden sectors - sp
	Dd	0	;big total sectors - sp
	DB	6 DUP(?)	;reserved - sp


BPBTable    dw	    BPB48T		; 48tpi drives
	    dw	    BPB96T		; 96tpi drives
	    dw	    BPB35		; 3.5" drives
; The following are not supported, so default to 3.5" media layout
	    dw	    BPB35		; Not used - 8" drives
	    dw	    BPB35		; Not Used - 8" drives
	    dw	    BPB35		; Not Used - hard files
	    dw	    BPB35		; Not Used - tape drives
	    dw	    BPB35		; Not Used - Other

switchlist  db	7,"FHSTDCN"         ; Preserve the positions of N and C.

; The following depend on the positions of the various letters in SwitchList

flagdrive   equ     0004H
flagcyln    equ     0008H
flagseclim  equ     0010H
flagheads   equ     0020H
flagff	    equ     0040H

SWTCHR	    EQU     "/"             ; switch follows this character

SYSINITSEG	ENDS
	END
