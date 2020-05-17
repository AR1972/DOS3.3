
;------------------------------------------------------------------------
;									:
; File: ms96tpi.asm							:
;									:
; This file contains code to support the 96 tpi drives.  The code	:
; is included in the bio if the machine has at least one drive with	:
; changeline support.  If the machine has no changeline drives then	:
; the code is not kept in the bio at system initialization time.	:
;									:
;------------------------------------------------------------------------


;------------------------------------------------------------------------
;									:
;		DISK OPEN/CLOSE ROUTINES				:
;									:
;------------------------------------------------------------------------

DSK$OPEN:
	PUBLIC	DSK$OPEN
	Message fTestDisk,<"Disk Open ">        ; print debug messages
	MNUM	fTestDisk,AX
	Message fTestDisk,<CR,LF>
						; AL is logical drive
	call	SetDrive			; Get BDS for drive
	inc	WORD PTR ds:[di].opcnt
	jmp	EXIT

DSK$CLOSE:
	PUBLIC	DSK$CLOSE
	Message fTestDisk,<"Disk Close ">       ; print debug messages
	MNUM	fTestDisk,AX
	Message fTestDisk,<CR,LF>
						; AL is logical drive
	call	SetDrive			; Get BDS for drive
	cmp	WORD PTR ds:[di].opcnt,0
	jz	EXITJX				; Watch out for wrap
	dec	WORD PTR ds:[di].opcnt
EXITJX:
	jmp	EXIT

;
; ChkOpCnt checks the number of open files on drive.
;
; Input : DS:DI points to current BDS for drive.
;
; Return : zero set if no open files
;	   zero reset if open files
;

ChkOpCnt:
	Message fTest96,<"Check open count ">   ; print debug messages
	MNUM	fTest96,AX
	Message fTest96,<CR,LF>
	cmp	WORD PTR ds:[di].opcnt,0
	ret

;
; At media check time, we need to really get down and check what the change is.
; This is GUARANTEED to be expensive.
;
; On entry AL contains logical drive number
;

	public mediacheck
MediaCheck:
	call	CheckSingle		; make sure correct disk is in place
	xor	SI,SI
	call	HasChange
	jz	MediaRet
	call	CheckROMChange
	jnz	MediaDoVOLID
	push	AX
	push	DX
					; see if changeline has been triggered
;;Rev 3.30 Modification
	mov	DL, DS:[DI.drivenum]    ; set logical drive number	  
	mov	AH, 16h 	    ; get changeline status	  
	int	13h		    ; call rom diskette routine	  
;;End of Modification
	pop	DX
	pop	AX
	jc	MediaDoVolid		; if changeline was triggered jmp
	mov	SI,1			; else signal no change


; There are some drives with changeline that "lose" the changeline indication
; if a different drive is accessed after the current one. In order to avoid
; missing a media change, we return an "I don't know" to DOS if the changeline
; is not active AND we are accessing a different drive from the last one.
; If we are accessing the same drive, then we can safely rely on the changeline
; status.

	PUBLIC LOSECHNG
LOSECHNG:
	mov	bl,cs:[Tim_Drv] 	; get last drive accessed
	cmp	byte ptr [di].DriveNum,bl
	jz	MediaRet
; Do the 2 second twiddle. If time >= 2 seconds, do a volid check.
; Otherwise return "I don't know" (Strictly speaking, we should return a
; "Not Changed" here since the 2 second test said no change.) - RS.

	SaveReg <AX,CX,DX>
	call	Check_Time_Of_Access
	RestoreReg <DX,CX,AX>
	or	si,si
	jz	MediaDoVolid		; Check_Time says ">= 2 secs passed"
	xor	si,si			; return "I don't know"
	Public MediaRet
MediaRet:
	ret


;
; MediaDoVolid:  if this is called somehow the media was changed.  Look at
; VID to see. We do not look at FAT because this may be different since we
; only set MedByt when doing a READ or WRITE.
;

MediaDoVolid:
	call	GETBP		       ; build a new BPB in current BDS
	jc	MediaRet
	call	Check_VID
	jnc	MediaRet
	call	MapError		; fix up AL for return to DOS
	ret

;
; Checklatchio:
;
; Simple, quick check of latched change.  If no indication, then return
; otherwise do expensive check.  If the expensive test fails, POP off the
; return and set AL = 15 (for invalid media change) which will be returned to
; DOS.
;
	public checklatchio
CheckLatchIO:
; If returning fake BPB then assume the disk has not changed
;	test	word ptr ds:[di].flags, RETURN_FAKE_BPB
;	jnz	CheckRet
;;Rev 3.30 Modification
	call	HasChange		;change line supported?
	jz	CheckRet		;No. Just return
;;End of Modification
	call	ChkOpCnt
	jnz	CheckROM
CheckRet:
	ret
;
; Check for past ROM indications.  If no ROM change indicated, then return OK.
;
	public checkrom
CheckROM:
	call	CheckROMChange
	jz	CheckRet		; no change
;
; We now see that a change line has been seen in the past.  Let's do the
; expensive verification.
;
	Message fTest96,<"CheckROMChange says yes...",CR,LF>
	call	GETBP			; build BPB in current BDS
	jc	Ret_No_Error_Map	; GETBP has already called MapError
	call	Check_VID
	jc	CheckLatchRet		; disk error trying to read in.
	or	SI,SI			; Is changed for sure?
	jns	CheckRet
	call	ReturnVid
CheckLatchRet:
	call	MapError		; fix up AL for return to DOS
Ret_No_Error_Map:
	stc				; indicate an error
	pop	si			; pop off return address
	ret



;
;  CheckFatVID:
;
; Check the FAT and the VID.  Return in DI -1 or 0.  Return with carry set
; ONLY if there was a disk error.  Return that error code in AX.
;
	public checkfatvid
CheckFATVID:
	Message fTest96,<"Check FAT",CR,LF>
	call	FAT_Check
	or	SI,SI
	js	Changed_Drv
;
; The fat was the same.  How about the volume ID?
;
Check_VID:
	Message fTest96,<"Check VID",CR,LF>
	call	Read_volume_ID
	jc	CheckFatRet
	call	Check_Volume_id
	or	SI,SI
	jnz	Changed_Drv
	Message fTest96,<"VID not changed",CR,LF>
	call	ResetChanged
CheckFatRet:
	ret
Changed_Drv:
	mov	cs:[Tim_Drv],-1 	; Ensure that we ask ROM for media
	ret				; check next time round




;
; CheckIO:  At I/O time the rom-bios returned an error.  We need to
; determine if the error is due to a media change.  If error code is not
; change-line error (06h) we just return.  We pop off the call and jmp to
; harderr if we see an error.
;
;   On entry:  AH contains error code returned from rom-bios.
;

	public checkio
CheckIO:
	cmp	AH,06			; change line error?
	jnz	CheckFatRet		; no - just return
	call	ChkOpCnt
	jz	CheckFATRet		; no open files
; If returning fake BPB then ignore disk changes
;	test	word ptr ds:[di].flags, RETURN_FAKE_BPB
;	jnz	IgnoreChange
	call	GETBP			; build up a new BPB in current BDS
	jc	No_Error_Map		; GETBP has already called MapError
	call	CheckFATVID
	jc	CheckIORet		; disk error trying to read in.
	or	SI,SI			; Is changed for sure?
	js	CheckIOErr		; yes changed
IgnoreChange:
	inc	BP			; allow a retry
	ret
CheckIOErr:
	call	ReturnVid
CheckIORet:
	stc				; make sure carry gets passed through
	jmp	HardErr

No_Error_Map:
	jmp	HardErr2




;
; Return VID sets up the VID for a return to DOS.
;

	Public ReturnVID
ReturnVID:
	Message fTest96,<"Return VID",cr,lf>
	push	DS			; save pointer to current BDS
	push	di
	push	cx
	call	init_vid_loop		; Sets ES:DI -> vid
	lds	BX,cs:[PTRSAV]
	mov	[BX.EXTRA],DI
	mov	[BX.EXTRA+2],ES
	pop	cx
	pop	di			; restore current BDS
	pop	DS
;;	MOV	AH,6			; INVALID MEDIA CHANGE
	mov	AH, 0Fh 		; set error as 'invalid media change'
	stc				; indicate error by setting carry flag
	ret

;
; Media_Set_VID:
;
; Moves the pointer to the volid for the drive into the original request packet
; On entry, DS:BX points to the original packet.
; No attempt is made to preserve registers.
;

MEDIA_SET_VID:
	PUBLIC MEDIA_SET_VID						  ;;Rev 3.30 Modification
	call	init_vid_loop		; Sets ES:DI -> vid		  ;;End of Modification
	lds	bx,cs:[PtrSav]		; get pointer to packet
	mov	word ptr [BX.TRANS+1],DI
	mov	word ptr [BX.TRANS+3],ES
	ret


;
;   HiDensity - examine a drive/media descriptor to set the media type.  If
;   the media descriptor is NOT F9 (not 96tpi or 3 1/2), we return and let the
;   caller do the rest.  Otherwise, we pop off the return and jump to the tail
;   of GETBP. For 3.5" media, we just return.
;
;   Inputs:	DS:DI point to correct BDS for this drive
;		AH has media byte
;
;   Outputs:	Carry clear
;		    No registers modified
;		Carry set
;		    AL = sectors/fat
;		    BH = number of root directory entries
;		    BL = sectors per track
;		    CX = number of sectors
;		    DH = sectors per allocation unit
;		    DL = number of heads
;
hidensity:
	PUBLIC HIDENSITY						  ;;Rev 3.30 Modification
									  ;;End of Modification
; Check for correct drive
;
	test	word ptr ds:[di].flags,fChangeline	; is it special?
	jz	DoFloppy		; no, do normal floppy test
;
; We have a media byte that is pretty complex.	Examine drive information
; table to see what kind it is.
;
	cmp	byte ptr ds:[di].FormFactor,ffSmall;  Is it single-media?
	jz	DoFloppy		; yes, use fatid...
;
; 96 tpi drive
;
	cmp	AH,0F9h
	jnz	DoFloppy
	mov	al,7			; seven sectors / fat
	mov	bx,224*256+0fh		; 224 root dir entries & 0f sector max
	mov	cx,80*15*2		; 80 tracks, 15 sectors/track, 2 sides
	mov	dx,01*256+2		; sectors/allocation unit & head max
popr:
	add	SP,2			; pop off return address
	jmp	has1_res			; return to tail of GETBP


DoFloppy:
	ret

	PATHSTART 001,TPI96						  ;;Rev 3.30 Modification
									  ;;End of Modification
;
; Certain poorly designed programs avoid DOS altogether and use INT 13 directly.
; These programs even retry operations and, thus, will ignore the disk change
; logic.
;
; We hook INT 13 and note all errors.
;
	assume	ds:nothing,es:nothing,ss:nothing

	Public REAL13
Real13	dd  ?
OldInt	dd  ?
dmy	dw  ?

	PATHEND 001,TPI96						 ;;Rev 3.30 Modification
									 ;;End of Modification
	Public Int13
Int13	proc	FAR
	pop	word ptr OldInt
	pop	word ptr OldInt+2
	pop	DMY
	MESSAGE FTEST13,<"*">                                             ;;Rev 3.30 Modification
	pushf								  ;;End of Modification
	call	REAL13			; simulate another INT 13
	jc	Err13			; did an error occur?
	jmp	OldInt			; no, return and pop off flags
Err13:
	MESSAGE FTEST13,<"INT 13 ERROR ">                                 ;;Rev 3.30 Modification
	MNUM	FTEST13,AX						  
	MESSAGE FTEST13,<CR,LF> 					  
	pushf				; save state
	cmp	AH,06h			; is error a 'change' error?
	jz	GOTERR			; yes, jump down
B:	popf				; no, some other error, ignore it ;;End of Modification
	jmp	OldInt			; return and pop off flags


GotErr: or	DL,DL			; is this for the hard disk?
	js	B			; yes, ignore
	mov	word ptr cs:[FlagBits],fChanged
	call	Set_Changed_DL
	jmp	B
INT13	endp



;
; Set_Changed_DL - Sets flag bits according to bits set in [FlagBits].
;		   Essentially used to indicate Changeline, or Format.
;
;   Inputs:	DL contains physical drive number
;		[FlagBits] contains bits to set in the flag field in the BDSs
;   Outputs:	None
;   Registers modified: Flags
;

Set_Changed_DL:
	PUBLIC SET_CHANGED_DL						  ;;Rev 3.30 Modification
	Message ftest96,<"Set Changed",cr,lf>				  ;;End of Modification
	push	BX
	push	DX
	mov	BL,DL
ALL_SET:
	mov	dx,cs:[FlagBits]	; get bits to set in flag field
	xor	BH,BH
;
; In the virtual drive system we *must* flag the other drives as being changed
;
; assume first BDS is in this segment
	push	ax
	push	ds		    ; save current BDS
	push	di
	lds	di,dword ptr cs:[Start_BDS]
Scan_BDS:
	cmp	di,-1
	jz	SkipSet
	cmp	byte ptr [di].DriveNum,bl
	jnz	Get_Next_BDS
;
; Someone may complain, but this *always* must be done when a disk change is
; noted.  There are *no* other compromising circumstances.
;
SetChanged:
	or	word ptr ds:[di].flags,dx	; signal change on other drive
Get_Next_BDS:
	mov	ax,word ptr [di].link+2   ; go to next BDS
	mov	di,word ptr [di].link
	mov	ds,ax
	jmp	short Scan_BDS
SkipSet:
	pop	di		    ; restore current BDS
	pop	ds
	pop	ax
	pop	DX
	pop	BX
	ret



;
; CheckROMChange - see if external program has diddled ROM change line.
;
;   Inputs:	DS:DI points to current BDS.
;   Outputs:	Zero set - no change
;		Zero reset - change
;   Registers modified: none

CheckROMChange:
	MESSAGE FTEST13,<"CHECKROM ">                                     ;;Rev 3.30 Modification
	MNUM	FTEST13 						  
	MESSAGE FTEST13,<CR,LF> 					  ;;End of Modification
	test	word ptr [di].flags,fChanged
	ret




;
; ResetChanged - restore value of change line
;
;   Inputs:	DS:DI points to current BDS
;   Outputs:	none
;   Registers modified: none

ResetChanged:
	MESSAGE FTEST13,<"RESETCHANGED ">                                 ;;Rev 3.30 Modification
	MNUM	FTEST13 	
	MESSAGE FTEST13,<CR,LF> 					  ;;End of Modification
	and	word ptr ds:[di].flags,NOT fChanged
	ret



;
; HasChange - see if drive can supply change line
;
;   Inputs:	DS:DI points to current BDS
;   Outputs:	Zero set - no change line available
;		Zero reset - change line available
;   Registers modified: none

	PUBLIC	HASCHANGE						  ;;Rev 3.30 Modification
HasChange:
	MESSAGE FTEST13,<"HASCHANGE ">                                    
	MNUM	FTEST13 						  
	MESSAGE FTEST13,<CR,LF> 					  ;;End of Modification
	test	word ptr [di].flags,fChangeline
	ret

	ASSUME	DS:CODE

	include msvolid.inc

	Public End96tpi
End96tpi Label Byte
