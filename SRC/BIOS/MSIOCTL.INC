	include ioctl.inc

;
; Generic IOCTL dispatch tables
;
IOReadJumpTable db	2
		dw	offset GetDeviceParameters
		dw	offset ReadTrack
		dw	offset VerifyTrack

IOWriteJumpTable db	2
		dw	offset SetDeviceParameters
		dw	offset WriteTrack
		dw	offset FormatTrack

MAX_SECTORS_CURR_SUP	EQU	63	; CURRENT MAXIMUM SEC/TRK THAT	  ;3.30
					; WE SUPPORT (Was 40 in DOS 3.2)  ;3.30
;
; TrackTable is an area for saving information passwd by the set device
; parameter function for laster use my Read/Write/Format/Verify.
;
; Entries are 4-Tuples (C,H,R,N) where:
;   C = Cylinder, H = Head, R = Sector, N = Bytes/Sector
;
; fixed for bug0016 - initialised table with values - sp
TrackTable      db      0,0,1,2
                db      0,0,1,2
                db      0,0,3,2
                db      0,0,4,2
                db      0,0,5,2
                db      0,0,6,2
                db      0,0,7,2
                db      0,0,8,2
                db      0,0,9,2
                db      0,0,10,2
                db      0,0,11,2
                db      0,0,12,2
                db      0,0,13,2
                db      0,0,14,2
                db      0,0,15,2
                db      MAX_SECTORS_CURR_SUP * size a_SectorTable - ($-tracktable) dup (0)

sectorsPerTrack dw      15


; This is a real ugly place to put this
; it should really go in the BDS
mediaType	db	0

Media_Set_For_Format	db	0	; 1 if we have done an Int 13 Set Media
					; Type for Format call
; Rev 3.30 *****************************************************************
Had_Format_Error	db	0	; 1 if the previous format operation
					; failed.
Dsk_time_out_Err	equ	80h	; Time out error (No media present).
Dsk_change_line_Err	equ	6h	; Change line error
Dsk_illegal_combination equ	0Ch	; Return code of ah=18h function.
; Rev 3.30 *****************************************************************

;
; TempDPT is a temporary place to hold a pointer to the original
; Disk Parameter Table while DPT is made to point to a table returned
; by a BIOS call.  A value of -1 indicateds no value has been saved.
;

TempDPT 	DD	-1

;
; Generic$IOCTL:
;    Perform Generic IOCTL request
;    Input:
;	al	- unit number
;    Output:
;	if carry set then al contains error code
;
	Public Generic$IOCTL
Generic$IOCTL:
	Message ftestdisk,<"Generic IOCTL",cr,lf>
	les	bx,cs:[PTRSAV]		; es:bx points to request header.
	call	SetDrive		; ds:di points to BDS for drive.
;
; At this point:
;    es:bx - points to the Request Header
;    ds:di points to the BDS for the drive
;
	cmp	es:[bx].MajorFunction, RAWIO
	jne	IOCTL_Func_Err
	mov	al, es:[bx].MinorFunction
	mov	si, offset IOReadJumpTable
	test	al, GEN_IOCTL_FN_TST			; Test of req. function
	jnz	NotGenericIoctlWrite			;   function is a Read.
	mov	si, offset IOWriteJumpTable
NotGenericIoctlWrite:
	and	al, 0fH
	cmp	al, cs:[si]
	ja	IOCTL_Func_Err
	cbw
	shl	ax, 1
	inc	si
	add	si,ax
	les	bx, es:[bx].GenericIOCTL_Packet
	call	cs:[si]
	jc	FailGeneric$IOCTL
	jmp	exit

FailGeneric$IOCTL:
	jmp	err$exit

IOCTL_Func_Err:
	jmp	CMDERR





;
; GetDeviceParameters:
;
; Input: DS:DI points to BDS for drive
;	 ES:BX points to device parameter packet
;

	 PUBLIC GETDEVICEPARAMETERS					  ;3.30
GetDeviceParameters proc near
; Copy info from BDS to the device parameters packet
	mov	al, byte ptr ds:[di].FormFactor
	mov	byte ptr es:[bx].DP_DeviceType, al
	mov	ax, word ptr ds:[di].Flags
	and	ax,fNon_Removable+fChangeline	; mask off other bits
	mov	word ptr es:[bx].DP_DeviceAttributes, ax
	mov	ax, word ptr ds:[di].cCyln
	mov	word ptr es:[bx].DP_Cylinders, ax

; Set media type to default
	xor	al, al
	mov	byte ptr es:[bx].DP_MediaType, al

; Copy recommended BPB
	lea	si, byte ptr [di].RBytePerSec
	test	byte ptr es:[bx].DP_SpecialFunctions, BUILD_DEVICE_BPB
	jz	use_BPB_present
; Get the correct disk in the drive
	call	CheckSingle
; Build the BPB from scratch
	call	GETBP
	jc	Get_Parm_Ret
	lea	si,byte ptr [di].BytePerSec
use_BPB_present:
	lea	di, byte ptr [bx].DP_BPB
	mov	cx, size BPB_Type		; for now use 'small' BPB
	rep	movsb
	clc
Get_Parm_Ret:
	ret
GetDeviceParameters endp





;
; SetDeviceParameters:
;
; Input: DS:DI points to BDS for drive
;	 ES:BX points to device parameter packet
;

	 PUBLIC SETDEVICEPARAMETERS					  ;3.30
SetDeviceParameters proc near

; Make sure the fChanged_By_Format flag gets set to kick DOS into looking at
; the BPB
	or	word ptr ds:[di].Flags, fChanged_By_Format or fChanged
	test	byte ptr es:[bx].DP_SpecialFunctions, ONLY_SET_TRACKLAYOUT
	jz	short SetDevParm_1
	jmp	SetTrackTable			; Originally TrackLayout

SetDevParm_1:
; Copy info from the device parameters packet to BDS
	mov	al, byte ptr es:[bx].DP_DeviceType
	mov	byte ptr ds:[di].FormFactor, al

	mov	ax, word ptr es:[bx].DP_Cylinders
	mov	word ptr ds:[di].cCyln, ax

; If change line is not loaded then ignore changeling flag
	mov	ax, word ptr es:[bx].DP_DeviceAttributes
	cmp	cs:[fHave96],0
	jnz	Have_Change
	and	ax,not fChangeline
Have_Change:
; ignore all bits except Non_removable and Changeline
	and	ax,fNon_Removable or fChangeline
	mov	cx, word ptr ds:[di].Flags
	and	cx, not (fNon_Removable or fChangeline or GOOD_TRACKLAYOUT)
	or	ax, cx
	mov	word ptr ds:[di].Flags, ax

; Set media type
	mov	al, byte ptr es:[bx].DP_MediaType
	mov	cs:mediaType, al
; the media changed (maybe) so we will have to do a SetDASD the next time
; we format a track
	or	word ptr ds:[di].Flags, SET_DASD_true

	SaveReg <ds,di,es,bx>
; Figure out what we are supposed to do with the BPB

; Were we asked to install a fake BPB?
	test	byte ptr es:[bx].DP_SpecialFunctions, INSTALL_FAKE_BPB
	jnz	short InstallFakeBPB

; Were we returning a fake BPB when asked to build a BPB?
	test	word ptr ds:[di].Flags, RETURN_FAKE_BPB
	jz	short InstallRecommendedBPB

; We were returning a fake BPB but we can stop now
	and	word ptr ds:[di].Flags, not RETURN_FAKE_BPB
	jmp	DoneWithBPBstuff

InstallRecommendedBPB:
	mov	cx, size a_BPB
	lea	di, byte ptr [di].RBytePerSec
	jmp	short CopyTheBPB

InstallFakeBPB:
	mov	cx, size BPB_Type    ; move 'smaller' BPB
	lea	di, byte ptr [di].BytePerSec
CopyTheBPB:
	lea	si, byte ptr [bx].DP_BPB
; exchange es and ds
	push	es
	push	ds
	pop	es
	pop	ds

	rep	movsb

DoneWithBPBstuff:
	Call	RestoreOldDPT
	RestoreReg <bx,es,di,ds>

; Set up track table (if neccessary)
SetTrackTable:
	mov	cx, word ptr es:[bx].DP_TrackTableEntries
	mov	cs:sectorsPerTrack, cx
	and	word ptr ds:[di].Flags, not GOOD_TRACKLAYOUT
	test	byte ptr es:[bx].DP_SpecialFunctions, TRACKLAYOUT_IS_GOOD
	jz	UglyTrackLayout
	or	word ptr ds:[di].Flags, GOOD_TRACKLAYOUT

UglyTrackLayout:
	cmp	cx, MAX_SECTORS_IN_TRACK
	ja	TooManySectorsPerTrack
	jcxz	SectorInfoSaved 		; if no value don't copy table
					; save information in the track table

        push    BX                              ; get ES:BX to point to sector
        add     BX, DP_SectorTable              ;  table in Device param. struct

        push    DI
        mov     DI, offset TrackTable + 2       ; CS:DI now points to sector id
                                                ; of the first track table entry
        push    AX                              ; preserve AX value

                                                ; For MAX_SECTORS_IN_TRACK
TrackLoop:                                      ;   DO:
        mov     AX, word ptr ES:[BX]            ;   get sector number
        mov     byte ptr CS:[DI], AL            ;   save in track table

        mov     AX, word ptr ES:[BX]+2          ;   get sector size
        call    SectorSizeToSectorIndex         ;   convert size to index number
        mov     byte ptr CS:[DI]+1, AL          ;   save size in track table

        add     BX, size a_sectorTable          ;   advance pointers to next
        add     DI, size a_sectorTable          ;   entries
        loopnz  TrackLoop                       ; End FOR

        pop     AX                              ; restore the saved values
        pop     DI
        pop     BX

SectorInfoSaved:
	clc
	ret

TooManySectorsPerTrack:
	mov	al, 0cH
	stc
	ret

SetDeviceParameters endp


;
; FormatTrack:
; If SpecialFunction byte is 1, then this is a status call to see if there is
; ROM support for the combination of sec/trk and # of cyln, and if the
; combination is legal. If SpecialFunction byte is 0, then format the track.
;
; Input: DS:DI points to BDS for drive
;        ES:BX points to format packet
;
; Output:
;       For status call:
;       SpecialFunction byte set to:
;               0 - ROM support + legal combination
;               1 - No ROM support
;               2 - Illegal Combination
;		3 - no media present			;Rev 3.30
;       Carry cleared.
;
;       For format track:
;               Carry set if error
;
;
;  Flags also may be altered. All other registers preserved.
;  If the call to ROM returns no error, then the current DPT is "replaced" by
;  the one returned by the ROM. This is done by changing the pointer in [DPT]
;  to the one returned. The original pointer to the disk base table is stored
;  in TempDPT, until it is restored.
;
;  This proc was changed to force a status for format call if we are on the
;  new ROM.
;
;
FormatTrack proc near
        test    byte ptr es:[bx].DP_SpecialFunctions,Status_For_Format
	jz	SkipStatusOnly

Do_Status_Only:
	call	FormatStatus
	mov	byte ptr es:[bx].DP_SpecialFunctions,al
	ret
	
SkipStatusOnly:                       ; for a hard disk only do the verify
        cmp     byte ptr ds:[di].FormFactor, DEV_HARDDISK
        jnz     SkipVerify
        jmp     DoVerifyTrack
SkipVerify:
	SaveReg <ds,di,es,bx>		; Format a Track
	call	FormatStatus		; SetDASD checks media_set_for_format
	cmp	al,3			; Check for time out
	je	Format_Failed		; Fail if time out
        call    SetDASD
;
; Store Cylinder,Head in track table
;                       ***** ASSUMPTION *******
;       Since format requests on Fixed Media are converted to Verifies, we
;       assume that we are formatting a floppy and hence have 255 or less
;       tracks and heads. We therefore must change the Cylinder, Head data
;       from the Request Packet Size to that of the TrackTable (see Int 13
;       interface in IBM's Tech Ref.).

; Check to ensure correct disk is in drive
        call    CheckSingle

        mov     ax, word ptr es:[bx].FP_Cylinder
        mov     word ptr cs:[TRKNUM],ax
        mov     cx, word ptr es:[bx].FP_Head
        mov     byte ptr cs:[HDNUM],cl
        mov     ah,cl
                        ; this next piece of code copies the correct head
                        ; and cylinder numbers to the tracktable
        push    di                              ; preserve DI
        mov     di, offset TrackTable
        mov     CX, cs:SectorsPerTrack          ; get number of sectors
        jcxz    EndSetUpTrackTable              ; if nothing to do skip down
SetUpLoop:
        mov     cs:[di], AX                     ; set head and track value
        add     di, 4                           ; move to next entry
        loopnz  SetUpLoop                       ; loop if not done yet
EndSetUpTrackTable:
        pop     di                              ; restore DI (BDS pointer)
        mov     cx, MAXERR                      ; Set up retry count
FormatRetry:
        push    cx
                                ; set up registers for format call to TO_ROM
        mov     AX, word ptr CS:SectorsPerTrack ; set number of sectors
        mov     AH, ROMFormat
        push    cs                              ; set ES:BX to point to
        pop     es                              ;    the track table
        mov     BX, offset TrackTable
                                                ; don't need to set CL on format
        call    to_rom
        jnc     FormatOk
        pop     cx
	mov	cs:[Had_Format_Error],1		; Mark the error
	push	ax							  ;3.30
	push	cx							  ;3.30
	push	dx							  ;3.30
        call    ResetDisk
	call	FormatStatus						  ;3.30
	cmp	al, 1							  ;3.30
	jnz	While_Err						  ;3.30
	call	SetDASD 						  ;3.30
While_Err:								  ;3.30
	pop	dx							  ;3.30
	pop	cx							  ;3.30
	pop	ax							  ;3.30
        loop    FormatRetry

; Format failed
Format_Failed:
	mov	cs:[Had_Format_Error],1		; Indicate a format error
	cmp	ah,Dsk_Change_Line_Err		; Convert change line to
	jne	Map_Err				;   to time out.
	mov	ah,Dsk_Time_Out_Err
Map_Err:
        call    MapError
        RestoreReg <bx,es,di,ds>
        ret

FormatOk:
	mov	cs:[Had_Format_Error],0 ; Reset format error flag
        pop     cx                      ; clean up stack after bailing out
                                        ; of FormatRetry loop early
        RestoreReg <bx,es,di,ds>

DoVerifyTrack:
        call    VerifyTrack             ; Will reset DPT entries.
        ret

FormatTrack endp

;
; FormatStatus:
; If SpecialFunction byte is 1, then this routine is called to see if there is
; ROM support for the combination of sec/trk and # of cyln, and if the
; combination is legal.
;
; Input: DS:DI points to BDS for drive
;	 ES:BX points to format packet
;
; Output:
;	SpecialFunction byte set to:
;		0 - ROM support + legal combination
;		1 - No ROM support
;		2 - Illegal Combination
;		3 - No media present, ROM support exists but can't determine
;		    media
;	Carry cleared.
;
;	For format track:
;		Carry set if error
;
;
;  Flags also may be altered. All other registers preserved.
;  If the call to ROM returns no error, then the current DPT is "replaced" by
;  the one returned by the ROM. This is done by changing the pointer in [DPT]
;  to the one returned. The original pointer to the disk base table is stored
;  in TempDPT, until it is restored.
;
;
FormatStatus proc near
	SaveReg <cx,dx>
	cmp	cs:[Had_Format_Error],1	; Are we here because of a format err
	je	Fstat01
	cmp	byte ptr cs:[Media_Set_For_Format],1
	jnz	FStat03
	jmp	Stat_Ret
Fstat03:
	mov	byte ptr cs:[Media_Set_For_Format],0
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;			modification - sp001
;	
;	remove check for new rom from here. we shall just assume the
;	prescence of the new rom and go ahead and issue the int13 call
;	anyway. later on if there is an error we shall check this to
;	see if it is there because of lack of rom support, in which
;	case the appropriate error will be indicated by setting al to 1
;
;	I would ideally like to see the new rom testing code shifted to
;	msinit and this code reintroduced. however for this version we
;	are aiming to stick close to the IBM variety. 
;
;	More changes to support this commenting out will follow. All
;	will be marked as modification sp001
;
;	mov	al,1			; No ROM support available error code
;	test	byte ptr cs:[New_ROM],1
;	jnz	FStat01
;	jmp	Stat_Ret
Fstat01:
	SaveReg <ds,si>

	xor	ax,ax
	mov	ds,ax
	lds	si, dword ptr ds:[DskAdr]	; DS:SI := pDPT

	mov	word ptr cs:[DPT],si		; cs:[DPT] := pDPT
	mov	word ptr cs:[DPT + 2],ds

	RestoreReg <si,ds>

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;			modification sp001
;	
;	the following instruction introduced for the new rom modification
;
	mov	cs:[New_Rom],1		; assume new rom
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov	ax,word ptr [di].cCyln
	mov	cx,word ptr [di].Seclim
					; set up registers for format status call
	and	AH, 03h 		; 'and' out unneeded track bits
	ror	AH, 1			; get track and sector values correct
	ror	AH, 1
	or	AH, CL			; set sector number
	xchg	AH, AL
	mov	CX, AX
	dec	CH
	mov	DL, byte ptr [DI].DriveNum	; get drive number
	mov	AH, 18h 		; set command to "sec/trk supported?"

	SaveReg <ES,DI,DS,SI>
	int	13h			; call rom bios to see if supported
	jc	Format_Stat_Err 	; if carry, combination is not supported

				; ES:DI points to new Disk Base Table
				; combination for this drive replace
				; current (DskAdr) pointer with new one,
				; saving the old one in TempDPT.

	cmp	cs:[Had_Format_Error],1	; Are we here because of a format err
	jnz	Fstat02			; Then skip the disk base setup
	
	xor	al,al			; Supported and OK
	mov	cs:[Had_Format_Error],al ; Clear format error
	jmp	Pop_Stat_Ret		; Back to work
	
Fstat02:
	xor	ax,ax
	mov	ds,ax
	lds	si, dword ptr ds:[DskAdr]	; DS:SI := pDPT

	mov	word ptr cs:[TempDPT],si
	mov	word ptr cs:[TempDPT + 2],ds	; Save pDPT

	mov	word ptr ds:[DskAdr],DI 	; Setup New DPT returned by
	mov	word ptr ds:[DskAdr + 2],ES	; ROM

	mov	byte ptr cs:[Media_Set_For_Format],1	; set flag
	xor	al,al			; Legal combination + ROM support code
	jmp	short Pop_Stat_Ret

Format_Stat_Err:
	mov	al,3			; Assume a time out
	cmp	ah,Dsk_Time_Out_Err	; Was it a time out???
	jz	Pop_Stat_Ret		;  Yes - then done
	dec	al			; Assume an illegal comb.
	cmp	ah,Dsk_illegal_combination ; Was it an illegal comb???
	jz	Pop_Stat_Ret		; Yes - then done
	dec	al			; Assume No ROM Support	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;			modification sp001
;
;	the following instruction was introduced for the new_rom modification
;
	mov	cs:[New_Rom],0		; the old rom
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Return result of status call
Pop_Stat_Ret:
	RestoreReg <SI,DS,DI,ES>
Stat_Ret:
	clc
	RestoreReg <dx,cx>
	ret
FormatStatus	endp



;
; VerifyTrack:
;
; Input: DS:DI points to BDS for drive
;	 ES:BX points to verify packet
;
	PUBLIC VERIFYTRACK						  ;3.30
VerifyTrack proc near
	mov	cs:RFLAG, ROMverify
	mov	ax, word ptr es:[bx].VP_Cylinder
	mov	cs:curtrk, ax
	mov	ax, word ptr es:[bx].VP_Head

;	****** ASSUMPTION ******
;	we assume that we have less than 256 heads, and that the Request
;	Header Data Structure is unneccessarily big
	mov	cs:curhd, al
	xor	ax, ax
	mov	cx, cs:sectorsPerTrack
; Use 0:0 as the transfer address for verify
	xor	bx, bx
	mov	es, bx
	call	TrackIO
	ret
VerifyTrack endp

;
; ReadTrack:
;
; Input: DS:DI points to BDS for drive
;	 ES:BX points to read packet
;
	PUBLIC READTRACK						  ;3.30
ReadTrack:
	mov	cs:RFLAG, ROMread
	jmp	ReadWriteTrack

;
; WriteTrack:
;
; Input: DS:DI points to BDS for drive
;	 ES:BX points to write packet
;
	PUBLIC WRITETRACK						  ;3.30
WriteTrack:
	mov	cs:RFLAG, ROMwrite
	jmp	ReadWriteTrack
;
; ReadWriteTrack:
;
; Input:
;    DS:DI points to BDS for drive
;    ES:BX points to write packet
;    RFLAG - 2 for read, 3 for write
;
	PUBLIC READWRITETRACK						  ;3.30
ReadWriteTrack proc near
	mov	ax, word ptr es:[bx].TRWP_Cylinder
	mov	cs:curtrk, ax
	mov	ax, word ptr es:[bx].TRWP_Head

;	****** ASSUMPTION ******
;	we assume that we have less than 256 heads, and that the Request
;	Header Data Structure is unneccessarily big
	mov	cs:curhd, al
	mov	ax, word ptr es:[bx].TRWP_FirstSector
	mov	cx, word ptr es:[bx].TRWP_SectorsToReadWrite
	les	bx, es:[bx].TRWP_TransferAddress
	call	TrackIO
	ret
ReadWriteTrack endp


;
; TrackIO:
;    Performs Track Read/Write/Verify
;
;   Input:
;      RFLAG	- 2 = Read
;		  3 = Write
;		  4 = Verify
;      ax	- Index into track table of first sector to IO
;      cx	- number of sectors to IO
;      es:bx	- Transfer address
;      ds:di	- pointer to BDS
;      curtrk	- current cylinder
;      curhd	- current head
;
	public trackio
TrackIO proc near
; procedure `disk' will pop stack to SPsav and return if error
	mov	cs:SPsav, sp
; Ensure correct disk is in drive
	call	CheckSingle
;
; Set up tables and variables for I/O
;
	cmp	byte ptr cs:[Media_Set_For_Format],1
	jz	DPTAlreadySet

;									  ;3.30
; SET UP TABLES AND VARIABLES FOR I/O					  ;3.30
;									  ;3.30
	SaveReg <AX,CX>
	call	IOSetUp
	RestoreReg <CX,AX>
;
; point si at the table entry of the first sector to be IO'd
;
DPTAlreadySet:
	mov	si, offset trackTable
	shl	ax, 1
	shl	ax, 1
	add	si, ax
;
; we want:
;    cx to be the number of times we have to loop
;    dx to be the number of sectors we read on each iteration
	mov	dx, 1
	test	word ptr ds:[di].Flags, GOOD_TRACKLAYOUT
	jz	IOnextSector

; Hey! we can read all the sectors in one blow
	xchg	dx, cx

IOnextSector:
	push	cx
	push	dx
; skip over the cylinder and head in the track table
	inc	si
	inc	si

; Get sector id from track table
        mov     AL, byte ptr cs:[si]    ; get current sector value
        mov     cs:[cursec], AL         ; save cursec value
        
;*** For a Fixed disk multi-track disk I/O -  4/14/86		  ;3.30
;Assumptions: 1). In the input CX (# of sectors to go) to TRACKIO, only CL;3.30  is
;valid.  2). Sector size should be set to 512 bytes. 3). GOODTRACKLAYOUT. ;3.30
;									  ;3.30
	test	word ptr [di].Flags, fNon_Removable	;Fixed disk? - J.K;3.30 .
	jz	IOREMOVABLE				;no -	  ;3.30
	mov	cs:[seccnt], dx 			;# of sectors to I;3.30 /O -
	mov	ax, dx					;		  ;3.30
	call	disk					;		  ;3.30
	pop	dx					;		  ;3.30
	pop	cx					;		  ;3.30
	clc						;		  ;3.30
	ret						;		  ;3.30
IOREMOVABLE:						;		  ;3.30

        mov     AL, byte ptr cs:[si]+1  ; get sector size index

	; The next eight lines put sector size index in DPT
        push    ES                      ; save value while getting pointer
        push    SI                      ;    to DPT
	push	AX

        les     SI, cs:DPT              ; ES:SI points to DPT
                                                ; put size in DPT
        mov     byte ptr ES:[si].Disk_Sector_Siz, AL
        mov     AX, word ptr [di].seclim        ; get number of sector/track
        mov     byte ptr ES:[si].Disk_EOT,AL    ; patch in DPT

	pop	AX			; restore register values
        pop     SI     
        pop     ES
                                        ; convert index to byte value
        call    SectorSizeIndexToSectorSize
        push    AX                      ; save number of bytes in sector
        mov     AX, DX                  ; get number of sector for I/0

DoTheIO:
	mov	cs:[SECCNT],ax		; set up the count of sectors to I/O
	call	disk
					; advance buffer pointer by adding
					;   sector size
	pop	ax
	add	bx, ax
	pop	dx
	pop	cx
	loop	IOnextSector
	call	DONE			; Set time of last access, and reset
	clc				; entries in DPT.
	ret

TrackIO endp
;
; The sector size in bytes needs to be converted to an index value for the IBM
; ROM. (0=>128, 1=>256,2=>512,3=>1024). It is assumed that only these values
; are permissible.
; On Input   AX contains sector size in bytes
; On Output  AL contains index
;
	public SectorSizeToSectorIndex
SectorSizeToSectorIndex proc near
        and     AH, 07h                         ; very simple error correction
        mov     AL, AH                          ; shift left 8 bits
        cmp     AL, 4                           ; size 1024?
        jnz     SecToIndexRet                   ; no, then we are done
        sub     AL, 1                           ; if 1024, adjust index to 3
SecToIndexRet:
        ret
SectorSizeToSectorIndex endp

SectorSizeIndexToSectorSize proc near
; value in AH on entry is not important
        push    CX                      ; save CX value
        mov     CL, AL                  ; use index number as shift size
        mov     AX, 0080h               ; set AX to 128
        shl     AX, CL                  ; shift by index to get proper value
        pop     CX                      ; restore CX value
	ret
SectorSizeIndexToSectorSize endp



;
; Set up the ROM for formatting.
; we have to tell the ROM BIOS what type of disk is in the drive.
; On Input   - DS:DI - points to BDS
;
SetDASD		proc	near
; See if we have new ROM and have issues Set Media Type For Format call
        test    byte ptr cs:[Media_Set_For_Format],1
        jnz     DasdHasBeenSet
; See if we have previously set DASD type
	cmp	cs:[Had_Format_Error],1
	je	DoSetDasd
        test    word ptr ds:[di].Flags, SET_DASD_true
        jz      DASDhasBeenSet
        and     word ptr ds:[di].Flags, not SET_DASD_true
                ; the next nine lines determine and put the DASD type in AL
DoSetDasd:
	mov	cs:[Had_Format_Error],0
        mov     cs:[GAP_PATCH], 50h     ; assume 48tpi or 3.5" drive
        cmp     [di].FormFactor, ffSmall; is 3.5" drive?
        jnz     not35Drive              ; no, skip down
        mov     AL, 04h                 ; yes set proper DASD value
        jmp     short Do_Set            ; jump down

Not35Drive:
        mov     AL, 01h                 ;
        cmp     [di].FormFactor, ff96tpi; 96tpi disk drive?
        jnz     Do_Set                  ; no skip down to rom call
        inc     AL                      ; reflect 96tpi drive in DASD type
        cmp     [di].seclim, 15         ; 96tpi media in drive?
        jnz     Do_Set                  ; no, skip down to rom call
        inc     AL                      ; reflect 96tpi media in DASD type
        mov     cs:[GAP_PATCH], 54h     ;    and in the GAP_PATCH
Do_Set:
        mov     AH, 17h                 ; set command to Set DASD type
        mov     DL, [di].DriveNum       ; set drive number
        int     13h                     ; call rom-bios
DASDhasBeenSet:
        mov     ah,byte ptr [di].seclim
        mov     cs:[FORMT_EOT],ah
        ret
SetDasd	endp


;
; This routine is called if an error occurs while formatting or verifying.
; It resets the drive, and decrements the retry count.
; On Entry - DS:DI - points to BDS for the drive
;	     BP    - contains retry count
; On Exit    Flags indicate result of decrementing retry count
;
;
;  There are some drives that "lose" the changeline indication if another
;  floppy drive is accessed before the changeline is recorded by the device
;  driver. In this situation, it is possible for the ROM to also not detect
;  that the medium has changed. So, the end result is that we could have a
;  diskette in the drive for which we can not even read the boot sector.
;  We "fix" this by setting the byte at location DISK_STATE_MACHINE_DRV_0 (hex)
;  for physical drive 0 (or DISK_STATE_MACHINE_DRV_1  for drive 1) to 0 (See
;  IBM PC/AT "blessed" addresses Document for explanation) . This tells the ROM
;  that the medium is 'unknown'.  The ROM actually uses these locations for
;  itself.  Note that we do this only for internal drives; we do not do this for
;  fixed disks or for physical drives > 1. We may end up corrupting some
;  other bytes in memory that may be used for something else.
;  NOTE: We do not stuff this byte if the last operation was a FORMAT because
;  the ROM loses track of what it is trying to format!!
;
;  This routine was changed to only stuff 61H when the drive indicated it
;  supported changeline. The Phoenix ROM was taking a very long time
;  to figure out what the media was which caused disk time outs to take
;  forever
;
;  We assume that DS:DI points to the current BDS for this drive.
;	no registers should be touched
;

AGAIN:
	call	ResetDisk
	dec	bp			; decrement retry count
	RET

	PUBLIC RESETDISK
ResetDisk:
	push	ax
	xor	AH, AH			; set command to reset disk
	int	13h			; call the rom-bios
	pop	ax
	mov	cs:[STEP_DRV],-1	; zap up the speed
	ret

;
; This routine sets up the Drive Parameter Table with the values needed for
; Format, does an Int 13. Values in DPT are restored after a VERIFY is done.
;
; On Entry  -	DS:DI - points to BDS for the drive
;		ES:BX - points to TRKBUF
;		AL    - number of sectors
;		AH    - Int 13 function code
;		CL    - Sector number for verify
; On Exit   -	DS,DI,ES,BX remain unchanged.
;		ax and flags are the results of the int 13
;
	Public To_ROM
To_ROM:
	SAVEREG <DS,DI,ES,BX,SI>					  ;3.30

; The below line was replaced because saving the DPT is predicated upon
; whether the functionality of the new ROM was used, not if it exists.
;	test	byte ptr cs:[New_ROM],1

	test	byte ptr cs:[Media_Set_For_Format],1
	jnz	Got_Valid_DPT

; Set up values in the DPT
; Set up motor start correctly for 3.5" drives.
	push	ax
	push	ds

	xor	ax,ax
	mov	ds,ax
	lds	si,dword ptr ds:[DskAdr]	; DS:SI := pDPT

	mov	word ptr cs:[DPT],si
	mov	word ptr cs:[DPT+2],ds		; Save pDPT

        pop     ds
        push    ES                      ; save value in ES
        LES     SI, CS:DPT

        mov     DX, [di].seclim         ; set the sector per track in
        mov     es:[si].DISK_EOT, DL    ;    the Disk Parameter Table
        cmp     DX, 15                  ; 96tip media?
        jz      To_ROM1                 ; yes, skip down
                                ; no - set Format Gap to 320/360 media value
        mov     CL, cs:[Gap_Patch]
        mov     byte ptr ES:[si].DISK_FORMT_GAP, CL
To_ROM1:                                ; 3.5" floppy drive?
        cmp     byte ptr [di].FormFactor, ffSmall
        jnz     To_ROM2                 ; no, skip down
                                ; yes - reset disk moter start value
        mov     byte ptr ES:[si].DISK_MOTOR_STRT, 4
To_ROM2:
        pop     ES                      ; restore ES value
        pop     ax

Got_Valid_DPT:
 					; now set up the registers
        mov     DL, [di].DriveNum       ; set drive number
        mov     DH, CS:[HDNUM]          ; set head number
        mov     CX, CS:[TRKNUM]         ; set track number
        ror     CH,1
        ror     CH,1
        xchg    CH, CL
        int     13h                     ; call the rom-bios disk routines
        RestoreReg <si,bx,es,di,ds>
        ret


;
; Get the owner of the physical drive represented by the logical drive in BL.
; The assumption is that we **ALWAYS** keep track of the owner of a drive!!
; If this is not the case, the system may hang, just following the linked list.
;
	PUBLIC	IOCTL$GETOWN
IOCTL$GETOWN:
	call	SetDrive
	mov	al,byte ptr [di].DriveNum	; Get physical drive number
	push	cs
	pop	ds
	mov	di,word ptr Start_BDS
Own_Loop:
	cmp	byte ptr [di].DriveNum,al
	jne	GetNextBDS
	test	word ptr [di].flags,fI_Own_Physical
	jnz	Done_GetOwn
GetNextBDS:
	mov	bx,word ptr [di].link+2
	mov	di,word ptr [di].link
	mov	ds,bx
	jmp	short Own_Loop
Done_GetOwn:
	JMP	SHORT EXIT_OWN

;
; Set the ownership of the physical drive represented by the logical drive in
; BL.
;
	PUBLIC IOCTL$SETOWN
IOCTL$SETOWN:
	call	SetDrive
	mov	byte ptr cs:[fSetOwner],1	; set flag for CheckSingle to
						; look at.
	call	CheckSingle			; Set ownership of drive
	mov	byte ptr cs:[fSetOwner],0	; reset flag
	xor	bx,bx
	mov	es,bx
	mov	cl,-1
	mov	byte ptr es:[LSTDRV],cl 	; Set up SDSB as well

EXIT_OWN:
; If there is only one logical drive assigned to this physical drive, return
; 0 to user to indicate this.
	xor	cl,cl
	test	word ptr [di].flags,fI_Am_Mult
	jz	EXIT_NO_MULT
	mov	cl,byte ptr [di].DriveLet	; Get logical drive number
	inc	cl				; get it 1-based
EXIT_NO_MULT:
	LDS	BX,CS:[PtrSav]
	mov	byte ptr [BX].UNIT,CL
	jmp	EXIT




;
; Moves the old DPT that had been saved in TempDPT back to DPT. This is done
; only if the first byte of TempDPT is not -1.
; All registers (including flags) are preserved.
;
	Public RestoreOldDPT
RestoreOldDPT:
; If we have already restored the disk base table earlier, do not do it
; again.
	push	ax
	xor	al,al
; Reset flag and get current flag setting
	mov	cs:[Had_Format_Error],al
	xchg	byte ptr cs:[Media_Set_For_Format],al
	or	al,al
	jz	DontRestore
	SaveReg <si,ds,es>
	LDS	SI,CS:[TempDPT]
	xor	ax,ax
	mov	es,ax				; have ES -> segment 0
	MOV	WORD PTR ES:[DskAdr],SI
	MOV	WORD PTR ES:[DskAdr+2],DS
GotCurrentDPT:
	RestoreReg <es,ds,si>
DontRestore:
	pop	ax
	clc				; clear carry
	ret				; (7/31/86)

;end of file msioctl.asm
