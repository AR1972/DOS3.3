;	SCCSID = @(#)messages.inc 1.6 85/08/02

DEBUG	EQU	0		; for Boot sector installation check

IF DEBUG
	public	msgFormatBroken
ENDIF

; THE FOLLOWING ONE BYTE CHARACTERS ARE THE PROMPT ANSWERS.
; THEY MUST BE LOWER CASE, AND THE UPPER TO LOWER, OR LOWER
; TO LOWER CONVERSION MUST BE DOABLE BY "OR  AL,20h".
; Yes/No Answers

Yes_Byte	db	"y"
No_Byte 	db	"n"

msgCRLF db CR, LF, 0

; Status messages

msgCurrentTrack db	"Head: %3d Cylinder: %4d", CR, 0

msgSystemTransfered db "System transferred",CR,LF,0

msgInterrupt db 13,10, 10, 0

; Note: This message must be long enough to wipe out message msgCurrentTrack
msgFormatComplete db "Format complete              ",CR,LF,0

; Prompts

msgInsertDisk db "Insert new diskette for drive %c:",CR,LF
	      db "and strike ENTER when ready",0

msgHardDiskWarning db CR,LF
		   db "WARNING, ALL DATA ON NON-REMOVABLE DISK",CR,LF
		   db "DRIVE %c: WILL BE LOST!",CR,LF
		   db "Proceed with Format (Y/N)?",0

msgFormatAnother? db "Format another (Y/N)?",0

msgInsertDosDisk db "Insert DOS disk in drive %c:", CR, LF
		 db "and strike ENTER when ready", CR, LF, 0

msgReInsertDisk db "Re-insert diskette for drive %c:",0

msgLabelPrompt db "Volume label (11 characters, ENTER for none)? ",0

; Disk usage messages

msgTotalDiskSpace db "%l10d bytes total disk space", CR, LF, 0

msgSystemSpace db "%l10d bytes used by system", CR, LF, 0

msgBadSpace db "%l10d bytes in bad sectors", CR, LF, 0

msgDataSpace db "%l10d bytes available on disk",CR,LF,0

; Error messages

msgFormatNotSupported db "Format not supported on drive %c:", CR,LF,0

msgInvalidDeviceParameters db "Invalid device parameters from device driver"
			   db CR, LF, 0

msgErrorInIOCTL db "Error in IOCTL call", CR, LF, 0

msgNotBlockDevice db "Not a block device", CR, LF, 0

msgFATwriteError db "Error writing FAT", CR, LF, 0

msgDirectoryWriteError db "Error writing directory", CR, LF, 0

msgAssignedDrive db "Cannot format an ASSIGNed or SUBSTed drive. ", CR, LF, 0

msgNeedDrive db "Drive letter must be specified",CR,LF,0

msgBadDosVersion db "Incorrect DOS version",CR,LF,"$"

msgNoSystemFiles db "Cannot find System Files",CR,LF,0

msgTooManyFilesOpen db "Too many open files",CR,LF,0

msgNetDrive db "Cannot FORMAT a Network drive", CR, LF, 0

msgBadCharacters db "Invalid characters in volume label", CR, LF, 0

msgBadDrive db "Invalid drive specification", CR, LF, 0

msgInvalidParameter db "Invalid parameter", CR, LF, 0

msgParametersNotSupported db	"Parameters not supported",CR,LF,0

; Note: This message must be long enough to wipe out message msgCurrentTrack
msgFormatFailure db "Format failure               ",CR,LF,0

msgNotSystemDisk db "Disk unsuitable for system disk", CR, LF, 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;bug007sp
;	reintroduce following message for fix
msgNoRoomDestDisk db "No room for system on destination disk", CR, LF, 0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;bug007sp

msgDiskUnusable db "Invalid media or Track 0 bad - disk unusable", CR, LF, 0

msgOutOfMemory db "Insufficient memory for system transfer", CR, LF, 0

; Note: This message must be long enough to wipe out message msgCurrentTrack
msgWriteProtected db "Attempted write-protect violation", CR, LF, 0

; Note: This message must be long enough to wipe out message msgCurrentTrack
msgNotReady db "Drive not ready                ", CR, LF, 0


msgBootWriteError db "Unable to write BOOT", CR, LF, 0

msgDirectoryReadError db "Error reading directory", CR, LF, 0

msgBadVolumeId db "Invalid Volume ID", CR, LF, 0

msgWhatIsVolumeId? db "Enter current Volume Label for drive %c: ", 0

msgIncompatibleParameters db "Parameters not compatible", CR,LF,0

msgIncompatibleParametersForHardDisk db "Parameters not compatible"
 db " with fixed disk", CR,LF,0

msgBadPartitionTable db "Bad Partition Table", CR, LF, 0

msgParametersNotSupportedByDrive    db "Parameters not Supported by Drive", CR, LF, 0

msgPartitionTableReadError db "Error reading partition table", CR, LF, 0

msgPartitionTableWriteError db "Error writing partition table", CR, LF, 0

IF DEBUG
msgFormatBroken db "Format Broken", CR, LF, 0
ENDIF

