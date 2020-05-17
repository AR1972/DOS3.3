;	SCCSID = @(#)messages.asm 1.10 85/08/13
TITLE FORMAT Messages

data	segment public 'DATA'

	public	Yes_Byte
	public	No_Byte
	public	msgCRLF
	public	msgCurrentTrack
	public	msgSystemTransfered
	public	msgFormatComplete
	public	msgInterrupt
	public	msgInsertDisk
	public	msgHardDiskWarning
	public	msgFormatAnother?
	public	msgInsertDosDisk
	public	msgReInsertDisk
	public	msgLabelPrompt
	public	msgTotalDiskSpace
	public	msgSystemSpace
	public	msgBadSpace
	public	msgDataSpace
	public	msgFormatNotSupported
	public	msgInvalidDeviceParameters
	public	msgErrorInIOCTL
	public	msgNotBlockDevice
	public	msgFATwriteError
	public	msgDirectoryWriteError
	public	msgAssignedDrive
	public	msgNeedDrive
	public	msgBadDosVersion
	public	msgNoSystemFiles
	public	msgTooManyFilesOpen
	public	msgNetDrive
	public	msgBadCharacters
	public	msgBadDrive
	public	msgInvalidParameter
	public	msgParametersNotSupported
	public	msgFormatFailure
	public	msgNotSystemDisk
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;bug007sp
; 	reintroduce following public for fix
	public	msgNoRoomDestDisk
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;bug007sp
	public	msgDiskUnusable
	public	msgOutOfMemory
	public	msgWriteProtected
	public	msgNotReady
	public	msgBootWriteError
	public	msgDirectoryReadError
	public	msgBadVolumeId
	public	msgWhatIsVolumeId?
	public	msgIncompatibleParameters
	public	msgIncompatibleParametersForHardDisk
	public	msgBadPartitionTable
	public	msgParametersNotSupportedByDrive
	public	msgPartitionTableReadError
	public	msgPartitionTableWriteError

CR	equ	13
LF	equ	10

; Oem dependent messages

	include messages.inc

data	ends
	END
