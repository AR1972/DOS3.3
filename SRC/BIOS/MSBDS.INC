;
;  BDS is the Bios Data Structure.
;
;  There is one BDS for each logical drive in the system.  All the BDS's
;  are linked together in a list with the pointer to the first BDS being
;  found in Start_BDS.	The BDS hold various values important to the disk
;  drive.  For example there is a field for last time accesses.  As actions
;  take place in the system the BDS are update to reflect the actions.
;  For example is there is a read to a disk the last access field for the
;  BDS for that drive is update to the current time.
;
; Values for various flags in BDS.Flags.
;

fNon_Removable	    equ     01H 	;For non-removable media
fChangeline	    equ     02H 	;If changeline supported on drive
RETURN_FAKE_BPB     equ     04H 	; When set, don't do a build BPB
					; just return the fake one
GOOD_TRACKLAYOUT    equ     08H 	; The track layout has no funny sectors
fI_Am_Mult	    equ     10H 	;If more than one logical for this physical
fI_Own_Physical     equ     20H 	;Signify logical owner of this physical
fChanged	    equ     40H 	;Indicates media changed
SET_DASD_true	    equ     80H 	; Set DASD before next format
fChanged_by_format  equ    100h

;
; Various form factors to describe media
;

ff48tpi 	    equ     0
ff96tpi 	    equ     1
ffSmall 	    equ     2
ffHardFile	    equ     5
ffOther 	    equ     7

BDS_Type struc
Link		DD		?	; Link to next BDS
DriveNum	DB		?	; Physical drive number
DriveLet	DB		?	; DOS drive number
BytePerSec	DW		?	; number of bytes/sec
SecPerClus	DB		?	; sec per allocation unit
RESSEC		DW		?	; number of reserved sectors
cFAT		DB		?	; number of fats
cDir		DW		?	; number of directory entries
DRVLIM		DW		?	; number of sectors on medium
mediad		DB		?	; media descriptor byte
cSecFat 	DW		?	; number of sectors/fat
SECLIM		DW		?	; sectors per track
HDLIM		DW		?	; max number of heads
HIDSEC		DW		?	; number of hidden sectors
FatSiz		DB		?	; flags...
Opcnt		DW		?	; Open ref. count
Volid		DB		12 dup (?)	; volume ID of medium
FormFactor	DB		?	; form factor index
Flags		DW		?	; various flags
cCyln		DW		?	; max number of cylinders
RBytePerSec	DW		?	; Recommended BPB
RSecPerClus	DB		?
RRESSEC 	DW		?
RcFAT		DB		?
RcDir		DW		?
RDRVLIM 	DW		?
Rmediad 	DB		?
RcSecFat	DW		?
RSECLIM 	DW		?
RHDLIM		DW		?
RHIDSEC 	DW		?
RHHIDSEC	DW		?
RLOGSEC 	DD		?
Reserve 	DB		6 dup (?)	; Reserved for future
					; changed to word -- kcd9:85
Track		DB		?	; last track accessed on drive
Tim_Lo		DW		?	; Time of last access. Keep
Tim_Hi		DW		?	; these contiguous.
BDS_Type ends

BPBSize     =	Track - RBytePerSec ; size in bytes of RecBPB area in the BDS


;;Rev 3.30 Modification
;*********************************************************************
;	BDS structure for mini disk
;*********************************************************************	  
									  
BDSM_type	struc							  
mlink		DW	-1			;Link to next structure   
		DW	?						  
mdriveNum	DB	80			;Int 13 Drive Number	  
mdriveLet	DB	3			;Logical Drive Number	  
mBytePerSec	DW	512						  
mSecPerClus	DB	1			;Sectors/allocation unit  
mRESSEC 	DW	1			;Reserved sectors for DOS 
mcFAT		DB	2			;No. of allocation tables 
mcDIR		DW	16			;Number of directory entries
mDRVLIM 	DW	0			;Number of sectors (at 512 bytes each)
mMediad 	DB	11111000B		;Media descriptor	  
mcSecFat	DW	1			;Number of FAT sectors	  
mSECLIM 	DW	0			;Sector limit		  
mHDLIM		DW	0			;Head limit		  
mHIDSEC 	DW	0			;Hidden sector count	  
mFatSiz 	DB	0			;TRUE => bigfat 	  
mOPCNT		DW	0			;Open Ref. Count	  
mVOLID		DB	"NO NAME    "           ;Volume ID for this disk  
		DB	0			;ASCIZII for "NO NAME    "
mFormFactor	DB	3			;Form Factor		  
mFLAGS		DW	0020H			;Various Flags		  
mcCyln		dw	40			;max number of cylinders  
mRecBPB 	db	31 dup (0)		;Recommended BPB for drive
mTrack		db	-1						  
IsMini		dw	1			;Overlapping TIM_LOH	  
Hidden_Trks	dw	0			;Overlapping TIM_HIH	  
									  
;TIM_LOH DW	 -1			 ;Keep these two contiguous (?)   
;TIM_HIH DW	 -1							  
BDSM_type	ENDS							  
;******************************************************************************
Max_mini_dsk_num = 23	      ; Max # of mini disk bios can support
;;End of Modification
