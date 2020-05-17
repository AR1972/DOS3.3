page 84,132
;       SCCSID = @(#)format.asm 1.26 85/10/20
;       SCCSID = @(#)format.asm 1.26 85/10/20
;***************************************************************
;
;       86-DOS FORMAT DISK UTILITY
;
;       This routine formats a new disk,clears the FAT and DIRECTORY then
;       optionally copies the SYSTEM and COMMAND.COM to this new disk
;
;       SYNTAX: FORMAT  [drive][/switch1][/switch2]...[/switch16]
;
;       Regardless of the drive designator , the user will be prompted to
;       insert the diskette to be formatted.
;
;***************************************************************

;           5/12/82 ARR Mod to ask for volume ID
;           5/19/82 ARR Fixed rounding bug in CLUSCAL:
;   REV 1.5
;           Added rev number message
;           Added dir attribute to DELALL FCB
;   REV 2.00
;           Redone for 2.0
;   REV 2.10
;           5/1/83 ARR Re-do to transfer system on small memory systems
;   REV 2.20
;           6/17/83 system size re-initialization bug -- mjb001
;   Rev 2.25
;           8/31/83 16-bit fat insertion
;   Rev 2.26
;           11/2/83 MZ fix signed compare problems for bad sectors
;   Rev 2.27
;           11/8/83 EE current directories are always saved and restored
;   Rev 2.28
;           11/9/83 NP Printf and changed to an .EXE file
;   Rev 2.29
;           11/11/83 ARR Fixed ASSIGN detection to use NameTrans call to see
;                       if drive letter remapped. No longer IBM only
;   Rev 2.30
;           11/13/83 ARR SS does NOT = CS, so all use of BP needs CS override
;   Rev 2.31
;           12/27/83 ARR REP STOSB instruction at Clean: changed to be
;                       sure ES = CS.

code    segment public 'CODE'
code    ends

printf_code segment public
        extrn   printf:far
printf_code ends

stack  segment stack
        db   (362 - 80h) + 100H dup (?) ; (362-80h) is the additional IBM ROM
                                        ; overhead recently discovered by them.
stack  ends

data    segment public 'DATA'
data    ends

public  end_of_memory
_end    segment public para 'DATA'
end_of_memory label byte
_end    ends

code    segment

        assume  cs:code,ds:nothing,es:nothing,ss:stack

;-------------------------------------------------------------------------------
; Define as public for debugging

; procedures
        public  GetSize
        public  AddToSystemSize
        public  Phase1Initialisation
        public  SetStartSector
        public  SetfBigFat
        public  Phase2Initialisation
        public  DiskFormat
        public  BadSector
        public  FormatTrack
        public  DisplayCurrentTrack
        public  NextTrack
        public  WriteFileSystem
        public  Done
        public  CurrentLogicalSector
        public  PrintErrorAbort
        public  GetDeviceParameters
        public  SetDeviceParameters

        public  START
        public  GOTBADDOS
        public  OKDOS
        public  BogusDrive
        public  DRVGD
        public  DRVSPEC
        public  NXTSWT
        public  GETPARM
        public  GETCHR
        public  INVALID
        public  SCANOFF
        public  MEMERR
        public  SAVSWT
        public  NotNet
        public  RE_ASSIGN
        public  NO_ASSIGN
        public  FatAllocated
        public  MEMERRJ
        public  MEM_OK
        public  RDFRST
        public  NEEDSYS
        public  INITCALL
        public  SWITCHCHK
        public  SYSLOOP
        public  FRMTPROB
        public  GETTRK
        public  TRKFND
        public  CLRTEST
        public  CMPTRKS
        public  PACKIT
        public  BadClus
        public  DoBig
        public  DoSet
        public  DRTFAT
        public  CLEARED
        public  LOUSE
        public  LOUSEP
        public  FATWRT
        public  SYSOK
        public  STATUS
        public  REPORTC
        public  ONCLUS
        public  MORE
        public  FEXIT
        public  SYSPRM
        public  fexitJ
        public  DoPrompt
        public  TARGPRM
        public  IsRemovable
        public  CheckRemove
        public  IsRemove
        public  NotRemove
        public  DSKPRM
        public  GOPRNIT
        public  crlf
        public  PrintString
        public  std_printf
        public  VOLID
        public  VRET
        public  DOVOL
        public  VOL_LOOP
        public  GOOD_CREATE
        public  VOLRET
        public  READDOS
        public  RDFILS
        public  FILESDONE
        public  CLSALL
        public  GOTBIOS
        public  GOTDOS
        public  CLSALLJ
        public  GOTCOM
        public  WRITEDOS
        public  GOTALLBIO
        public  BIOSDONE
        public  GOTNDOS
        public  PARTDOS
        public  GOTALLDOS
        public  DOSDONE
        public  PARTCOM
        public  GOTALLCOM
        public  COMDONE
        public  MAKEFIL
        public  CheckMany
        public  CLOSETARG
        public  IOLOOP
        public  GOTTARG
        public  GSYS
        public  TESTSYS
        public  GETOFFS
;       public  TESTSYSDISK             ; dcl 8/23/86
        public  SETBIOS
        public  BIOSCLS
        public  SETBIOSSIZ
        public  DOSOPNOK
        public  DOSCLS
        public  SETDOSSIZ
        public  GotComHand
        public  COMCLS
        public  SETCOMSIZ
        public  GETFSIZ
        public  READFILE
        public  WRITEFILE
        public  FILIO
        public  NORMIO
        public  IORETP
        public  IORET
        public  NORMALIZE
        public  GotDeviceParameters
        public  SmallFAT
        public  LoadSectorTable
        public  NotBigTotalSectors
        public  NotBig
        public  FormatLoop
        public  FormatDone
        public  FailDiskFormat
        public  FormatReallyFailed
        public  ContinueFormat
        public  ReportBadTrack
        public  NoMoreTracks
        public  ExitNextTrack
        public  ThatsAllFolks
        public  WriteFATloop
        public  WriteDIRloop
        public  CanNotWriteFAT
        public  CanNotWriteDirectory
        public  ControlC_Handler

; bytes
        public  fBigFat
        public  formatError
        public  ROOTSTR
        public  DBLFLG
        public  DRIVE
        public  FILSTAT
        public  USERDIRS
        public  VOLFCB
        public  VOLNAM
        public  TRANSRC
        public  TRANDST
        public  INBUFF
        public  driveLetter
        public  systemDriveLetter
; words
        public  startSector
        public  fatSpace
        public  firstHead
        public  firstCylinder
        public  tracksLeft
        public  tracksPerDisk
        public  sectorsInRootDirectory
        public  directorySector
        public  printStringPointer
        public  MSTART
        public  MSIZE
        public  TempHandle
        public  BEGSEG
        public  SWITCHMAP
        public  SWITCHCOPY
        public  FAT
        public  CLUSSIZ
        public  SECSIZ
        public  SYSTRKS
        public  SECTORS
        public  ptr_msgHardDiskWarning
        public  ptr_msgInsertDisk
        public  ptr_msgReInsertDisk
        public  ptr_msgInsertDosDisk
        public  ptr_msgCurrentTrack
        public  currentHead
        public  currentCylinder

; other
        public  deviceParameters
        public  formatPacket
;-------------------------------------------------------------------------------

data    segment
        extrn   msgAssignedDrive:byte
        extrn   msgBadDosVersion:byte
        extrn   msgDirectoryWriteError:byte
        extrn   msgFormatComplete:byte
        extrn   msgFormatNotSupported:byte
        extrn   msgFATwriteError:byte
        extrn   msgInvalidDeviceParameters:byte
        extrn   msgLabelPrompt:byte
        extrn   msgNeedDrive:byte
        extrn   msgNoSystemFiles:byte
        extrn   msgTooManyFilesOpen:byte
        extrn   msgNetDrive:byte
        extrn   msgInsertDisk:byte
        extrn   msgHardDiskWarning:byte
        extrn   msgSystemTransfered:byte
        extrn   msgFormatAnother?:byte
        extrn   msgBadCharacters:byte
        extrn   msgBadDrive:byte
        extrn   msgInvalidParameter:byte
        extrn   msgParametersNotSupported:byte
        extrn   msgReInsertDisk:byte
        extrn   msgInsertDosDisk:byte
        extrn   msgFormatFailure:byte
        extrn   msgNotSystemDisk:byte
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;bug007sp
;	reintroduce following extrn
	extrn	msgNoRoomDestDisk:byte
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;bug007sp
        extrn   msgDiskUnusable:byte
        extrn   msgOutOfMemory:byte
        extrn   msgCurrentTrack:byte
        extrn   msgWriteProtected:byte
        extrn   msgNotReady:byte
        extrn   msgInterrupt:byte
        extrn   msgCRLF:byte

data    ends


debug   equ     0
        .xlist
        INCLUDE VERSIONA.INC
        INCLUDE DOSMAC.INC
        INCLUDE SYSCALL.INC
        INCLUDE ERROR.INC
        INCLUDE DPB.INC
        INCLUDE CPMFCB.INC
        INCLUDE DIRENT.INC
        INCLUDE CURDIR.INC
        INCLUDE PDB.INC
        INCLUDE BPB.INC
        .list

;-------------------------------------------------------------------------------
; Constants

;Limits
BIG_FAT_THRESHOLD       equ     4086

;-------------------------------------------------------------------------------

;FORMAT Pre-defined switches
SWITCH_S   EQU     1                       ; System transfer
SWITCH_V   EQU     2                       ; Volume ID prompt
SWITCH_H   EQU     4                       ; E5 dir terminator
SWITCH_C   EQU     8
SWITCH_T   EQU     16
SWITCH_N   EQU     32
SWITCH_1   EQU     64
SWITCH_4   EQU     128
SWITCH_8   EQU     256
SWITCH_B   EQU     512

NUM_SWITCHES EQU  SWITCH_T or SWITCH_N

DRNUM   EQU     5CH

RECLEN  EQU     fcb_RECSIZ+7
RR      EQU     fcb_RR+7

;-------------------------------------------------------------------------------
; These are the data structures which we will need

        include ioctl.INC

;Per system file data structure

a_FileStructure struc
fileHandle              DW      ?
fileSizeInParagraphs    DW      ?
fileSizeInBytes         DD      ?
fileOffset              DD      ?
fileStartSegment        DW      ?
fileDate                DW      ?
fileTime                DW      ?
a_FileStructure ends

;-------------------------------------------------------------------------------
; And this is the actual data

data    segment
        public deviceParameters

validSavedDeviceParameters db   0
savedDeviceParameters   a_DeviceParameters      <>
deviceParameters        a_DeviceParameters      <>

formatPacket            a_FormatPacket          <>

startSector     dw      ?
fatSpace        dd      ?
fBigFat         db      FALSE

firstHead       dw      ?
firstCylinder   dw      ?
tracksLeft      dw      ?
tracksPerDisk   dw      ?

public NumSectors  ,TrackCnt
NumSectors      dw      0FFFFh
TrackCnt        dw      0FFFFh

public  Old_Dir
Old_Dir         db      FALSE

public fLastChance
fLastChance     db      FALSE           ; Flags reinvocation from
                                        ;   LastChanceToSaveIt. Used by DSKPRM

sectorsInRootDirectory  dw      ?

directorySector dd      0

formatError     db      0

printStringPointer      dw      0

; Exit status defines
ExitStatus      db      0
ExitOK          equ     0
ExitCtrlC       equ     3
ExitFatal       equ     4
ExitNo          equ     5

ROOTSTR DB      ?
        DB      ":\",0
DBLFLG DB       0                       ;Initialize flags to zero
IOCNT   DD      ?
MSTART  DW      ?                       ; Start of sys file buffer (para#)
MSIZE   DW      ?                       ; Size of above in paragraphs
TempHandle DW   ?
FILSTAT DB      ?                       ; In memory status of files
                                        ; XXXXXX00B BIOS not in
                                        ; XXXXXX01B BIOS partly in
                                        ; XXXXXX10B BIOS all in
                                        ; XXXX00XXB DOS not in
                                        ; XXXX01XXB DOS partly in
                                        ; XXXX10XXB DOS all in
                                        ; XX00XXXXB COMMAND not in
                                        ; XX01XXXXB COMMAND partly in
                                        ; XX10XXXXB COMMAND all in

USERDIRS DB     DIRSTRLEN+3 DUP(?)      ; Storage for users current directory

bios    a_FileStructure <>
BiosAttributes  EQU     attr_hidden + attr_system + attr_read_only

dos             a_FileStructure <>
DosAttributes   EQU     attr_hidden + attr_system + attr_read_only

command         a_FileStructure <>
CommandAttributes  EQU     0
CommandFile  DB      "X:\COMMAND.COM",0

VOLFCB  DB      -1,0,0,0,0,0,8
        DB      0
VOLNAM  DB      "           "
        DB      8
        DB      26 DUP(?)

TRANSRC DB      "A:CON",0,0             ; Device so we don't hit the drive
TRANDST DB      "A:\",0,0,0,0,0,0,0,0,0,0

BEGSEG  DW      ?
SWITCHMAP DW    ?
SWITCHCOPY DW   ?
FAT     DW      ?
        DW      ?
CLUSSIZ DW      ?
SECSIZ  DW      ?
SYSTRKS DW      ?
SECTORS DW      ?
INBUFF  DB      80,0
        DB      80 DUP(?)

ptr_msgHardDiskWarning  dw      msgHardDiskWarning
                        dw      offset driveLetter

ptr_msgInsertDisk       dw      msgInsertDisk
                        dw      offset driveLetter

ptr_msgReInsertDisk     dw      msgReInsertDisk
                        dw      offset driveLetter

ptr_msgInsertDosDisk    dw      offset msgInsertDosDisk
                        dw      offset systemDriveLetter

ptr_msgFormatNotSupported dw    offset msgFormatNotSupported
                        dw      offset driveLetter

drive           db      0
driveLetter     db      "x"
systemDriveLetter       db      "x"

data    ends

;For FORPROC and FORMES modules

        public  secsiz,clussiz,inbuff

        PUBLIC  crlf,std_printf

;For OEM module
        public  switchmap,drive,driveLetter,fatSpace
        public  fBigFat, PrintString,currentHead,currentCylinder
        extrn   CheckSwitches:near,LastChanceToSaveIt:near
        extrn   WriteBootSector:near,OemDone:near
        extrn   AccessDisk:near
data    segment
        extrn   switchlist:byte
        extrn   fdsksiz:word
        extrn   BiosFile:byte,DosFile:byte
data    ends

;For FORPROC module

        EXTRN   FormatAnother?:near,Yes?:near,REPORT:NEAR,USER_STRING:NEAR
data    segment
        extrn   badsiz:dword,syssiz:dword,biosiz:dword
data    ends

DOSVER_LOW      EQU  0300H+20
DOSVER_HIGH     EQU  0300H+20


START:
        PUSH    AX                      ;Save DRIVE validity info
        MOV     AH,GET_VERSION
        INT     21H
        CMP AX,EXPECTED_VERSION
        JE  OKDOS

;       XCHG    AH,AL                   ;Turn it around to AH.AL
;       CMP     AX,DOSVER_LOW
;       JB      GotBadDos
;       CMP     AX,DOSVER_HIGH
;       JBE     OKDOS


GOTBADDOS:
        MOV     DX,OFFSET msgBadDosVersion
        mov     ax, seg data
        mov     ds, ax
        mov     ah,std_con_string_output
        int     21h
        push    es
        xor     ax,ax
        push    ax

foo     proc    far
        ret                                 ; Must use this method, version may be < 2.00
foo     endp

OKDOS:

        mov     ax, seg data
        mov     es, ax
        assume  es:data
        POP     AX

        CMP     AL,0FFH                 ;See if invalid drive specified
        JNZ     DRVGD                   ;If not proceed
BogusDrive:
        mov     ax, seg data
        mov     ds, ax
        lea     dx, msgBadDrive
        call    PrintString
        JMP     FEXIT                   ;Exit

DRVGD:
        MOV     AH,GET_DEFAULT_DRIVE    ;Must get the default drive
        INT     21H                     ;Default now in AL
        ADD     AL,"A"
        MOV     [BiosFile],AL
        MOV     [DosFile],AL
        MOV     [CommandFile],AL
        MOV     SI,DRNUM                ;So we can get our parameters
        LODSB                           ;Fetch drive designation
        OR      AL,AL                   ;See if specified
        JNZ     DRVSPEC                 ;If specfied proceed
        mov     ax, seg data
        mov     ds, ax
        lea     dx, msgNeedDrive
        call    PrintString
        jmp     fexit
DRVSPEC:
        DEC     AL                      ;Drive designator now correct
        MOV     BYTE PTR DS:[DRNUM],AL  ;And updated
        MOV     DRIVE,AL             ;Save copy
        add     al, 'A'
        mov     driveLetter, al
; Get all the switch information from the command line
        MOV     [BEGSEG],DS          ;Save start segment

        XOR     BX,BX                   ;Store switch information in BX
        MOV     SI,81H                  ;Point to the command line buffer
NXTSWT:
        CALL    SCANOFF
        LODSB
        CMP     AL,"/"
        JZ      GETPARM

        CMP     AL,13
        JNZ     NxtS1
        JMP     SavSwt
NxtS1:
        MOV     AH,AL
        LODSB                           ; AX := getchar()
        CMP     AL,":"                  ; IF (AX != drive_spec)
        JNZ     INVALID                 ;   THEN error

        CMP     BYTE PTR DBLFLG,0       ; IF (previous drive_spec)
        JNZ     INVALID                 ;   THEN error

        INC     BYTE PTR DBLFLG         ; Yes -- set the flag
        OR      AH,020h
        SUB     AH,'a'
        CMP     AH,Drive
        JZ      SHORT NXTSWT
        JMP     BogusDrive
GETPARM:
        LODSB
; Convert any lower case input into upper case
        CMP     AL,41H
        JB      GETCHR                  ; Switch is a digit, so don't try to
                                        ; convert it.
        AND     AL,0DFH
GETCHR:
        MOV     CL,SWITCHLIST           ; CL := Number of Legal switches
        OR      CL,CL                   ; IF (Num_Legal_Switches == 0)
        JZ      INVALID                 ;   THEN error

        MOV     CH,0                    ; FOR (i=0; i <= Max_switches; i++)
        MOV     DI,1+OFFSET SWITCHLIST  ;   IF (switch == SWITCHLIST[i])
        REPNE   SCASB                   ;      THEN set zero flag
                                        ; END for
        JNZ     INVALID                 ; IF (zero_flag != TRUE ) THEN error

        MOV     AX,1
        SHL     AX,CL
        OR      BX,AX                   ;Set the appropriate bit in SWITCHMAP

        MOV     CX,AX                   ; Current_Switch := Switch processed
        Test    AX,NUM_SWITCHES         ; IF (Switch_processed does not require
                                        ;     numeric value)
        JZ      NXTSWT                  ;   THEN parse next switch

        LODSB                           ;   ELSE  then parse :nn and save approp
        cmp     al,':'                  ;     IF (getchar() != ':')
        jne     INVALID

        LODSB                           ;     curr_num := MakeNum (getchar())
        SaveReg <bx,cx>
        call    MakeNum
        RestoreReg <cx,bx>
        jc      INVALID                 ;     IF error, THEN exit

        SaveReg <ds,dx>
        Call    SaveNum                 ;     SaveNum (curr_num)
        Restorereg <dx,ds>                      ;   END else;


        JMP     SHORT NXTSWT            ;See if there are anymore

INVALID:
        mov     ax, seg data
        mov     ds, ax
        lea     dx, msgInvalidParameter
        call    PrintString
        JMP     FEXIT
MEMERR:
        mov     ax, seg data
        mov     ds, ax
        lea     dx, msgOutOfMemory
        call    PrintString
        JMP     FEXIT

SAVSWT:
        mov     ax, seg data
        mov     ds, ax
        assume  ds:data
        MOV     SWITCHMAP,BX

; Set memory requirements
        mov     es, begseg
        mov     bx, seg _end
        sub     bx, begseg
        mov     ah, setblock
        int     21H

; trap ^C
        mov     ax, (Set_Interrupt_Vector shl 8) or 23H
        mov     dx, offset ControlC_Handler
        push    ds
        push    cs
        pop     ds
        int     21H
        pop     ds

AroundControlC_Handler:
        MOV     BL,Drive                ;   x = IOCTL (getdrive, Drive+1);
        INC     BL
        MOV     AX,(IOCTL SHL 8) OR 9
        INT     21H
        JC      NotNet
        TEST    DX,1200H                ; if (x & 0x1200)(redirected or shared)
        JZ      NotNet
        lea     dx, msgNetDrive         ; Cann't format over net
        call    PrintString
        JMP     FEXIT

NotNet:
        TEST    DX,8000h                ; if local use
        jnz     re_assign
        MOV     BL,Drive
        ADD     BYTE PTR [TRANSRC],BL   ; Make string "D:\"
        MOV     SI,OFFSET TRANSRC
        push    ds
        pop     es
        MOV     DI,OFFSET TRANDST
        MOV     AH,xNameTrans
        INT     21H
        MOV     BL,BYTE PTR [TRANSRC]
        CMP     BL,BYTE PTR [TRANDST]   ; Did drive letter change?
        JZ      NO_ASSIGN               ; No
RE_ASSIGN:
        lea     dx, msgAssignedDrive
        call    PrintString
        JMP     FEXIT

NO_ASSIGN:

        CALL    Phase1Initialisation
        jnc     FatAllocated

        lea     dx, msgFormatFailure    ; IF (error_allocating_FAT)
        call    PrintString             ;   ISSUE error and abort
        jmp     Fexit
FatAllocated:

        TEST    SWITCHMAP,SWITCH_S
        JZ      INITCALL
        MOV     BX,0FFFFH
        MOV     AH,ALLOC
        INT     21H
        OR      BX,BX
        JZ      MEMERRJ                 ;No memory
        MOV     [MSIZE],BX
        MOV     AH,ALLOC
        INT     21H
        JNC     MEM_OK
MEMERRJ:
        JMP     MEMERR                  ;No memory

MEM_OK:
        MOV     [MSTART],AX

RDFRST:
        mov     bios.fileSizeInParagraphs,0              ;mjb001 initialize file size
        mov     dos.fileSizeInParagraphs,0               ;mjb001 ...
        mov     command.fileSizeInParagraphs,0               ;mjb001 ...
        CALL    READDOS                 ;Read BIOS and DOS
        JNC     INITCALL                ;OK -- read next file
NEEDSYS:
        CALL    SYSPRM                  ;Prompt for system disk
        JMP     RDFRST                  ;Try again

INITCALL:
        CALL    Phase2Initialisation
; Barry S - No reason to jump on carry!!!
;       JNC     SWITCHCHK
;       lea     dx, msgFormatFailure
;       call    PrintString
;       JMP     FEXIT

SWITCHCHK:
        MOV     DX,SWITCHMAP
        MOV     SWITCHCOPY,DX

SYSLOOP:
        MOV     WORD PTR BADSIZ,0       ;Must intialize for each iteration
        MOV     WORD PTR BADSIZ+2,0
        MOV     WORD PTR SYSSIZ,0
        MOV     WORD PTR SYSSIZ+2,0
        MOV     BYTE PTR DBLFLG,0
        mov     ExitStatus, ExitOK
        MOV     DX,SWITCHCOPY
        MOV     SWITCHMAP,DX            ;Restore original Switches
; DiskFormat will handle call for new disk
;       CALL    DSKPRM                  ;Prompt for new disk
        CALL    DISKFORMAT              ;Format the disk
        JNC     GETTRK
FRMTPROB:
        lea     dx, msgFormatFailure
        call    PrintString
        mov     ExitStatus, ExitFatal
        CALL    MORE                    ;See if more disks to format
        JMP     SHORT SYSLOOP

;Mark any bad sectors in the FATs
;And keep track of how many bytes there are in bad sectors

GETTRK:
        CALL    BADSECTOR               ;Do bad track fix-up
        JC      FRMTPROB                ;Had an error in Formatting - can't recover
        CMP     AX,0                    ;Are we finished?
        JNZ     TRKFND                  ;No - check error conditions
        JMP     DRTFAT                  ;Yes
TRKFND:
        CMP     BX,STARTSECTOR          ;Are any sectors in the system area bad?
        JAE     CLRTEST                 ; MZ 2.26 unsigned compare
        lea     dx, msgDiskUnusable
        call    PrintString
        JMP     FRMTPROB                ;Bad disk -- try again
CLRTEST:
        MOV     SECTORS,AX              ;Save the number of sectors on the track
        TEST    SWITCHMAP,SWITCH_S         ;If system requested calculate size
        JZ      BAD100
        CMP     BYTE PTR DBLFLG,0       ;Have we already calculated System space?
        JNZ     CMPTRKS                 ;Yes -- all ready for the compare
        INC     BYTE PTR DBLFLG         ;No -- set the flag
        CALL    GETBIOSIZE              ; Get the size of the BIOS
        MOV     DX,WORD PTR SYSSIZ+2
        MOV     AX,WORD PTR SYSSIZ
        MOV     WORD PTR BIOSIZ+2,DX
        MOV     WORD PTR BIOSIZ,AX
        CALL    GETDOSSIZE
        CALL    GETCMDSIZE
        MOV     DX,WORD PTR BIOSIZ+2
        MOV     AX,WORD PTR BIOSIZ
        DIV     deviceParameters.DP_BPB.BPB_BytesPerSector
        ADD     AX,STARTSECTOR
        MOV     SYSTRKS,AX              ;Space FAT,Dir,and system files require
CMPTRKS:
        CMP     BX,SYSTRKS
        JA      BAD100                  ; MZ 2.26 unsigned compare
        mov     ExitStatus, ExitFatal
        lea     dx, msgNotSystemDisk
        call    PrintString
        AND     SWITCHMAP,NOT SWITCH_S     ;Turn off system transfer switch
        MOV     WORD PTR SYSSIZ+2,0     ;No system to transfer
        MOV     WORD PTR SYSSIZ,0       ;No system to transfer
BAD100:
;   BX is the first bad sector #, SECTORS is the number of bad sectors
;   starting at BX.  This needs to be converted to clusters.  The start sector
;   number may need to be rounded down to a cluster boundry, the end sector
;   may need to be rounded up to a cluster boundry.  Know BX >= STARTSECTOR
        SUB     BX,STARTSECTOR          ; BX is now DATA area relative
        MOV     CX,BX
        ADD     CX,SECTORS
        DEC     CX                      ; CX is now the last bad sector #
        MOV     AX,BX
        XOR     DX,DX
        xor     bx,bx
        mov     bl, deviceParameters.DP_BPB.BPB_SectorsPerCluster
        DIV     bx
        MOV     BX,AX                   ; BX is rounded down and converted to
                                        ; a cluster #.  Where cluster 0 =
                                        ; first cluster of data.  First bad
                                        ; Sector is in cluster BX.
        MOV     AX,CX
        XOR     DX,DX
        push    bx
        xor     bx,bx
        mov     bl, deviceParameters.DP_BPB.BPB_SectorsPerCluster
        DIV     bx
        pop     bx
        MOV     CX,AX                   ; CX is rounded up and converted to a
                                        ; to a cluster #.  Where cluster 0 =
                                        ; first cluster of data.  Last bad
                                        ; Sector is in cluster CX.
        SUB     CX,BX
        INC     CX                      ; CX is number of clusters to mark bad
        ADD     BX,2                    ; Bias start by correct amount since
                                        ; first cluster of data is really
                                        ; cluster 2.
        xor     ax,ax
        MOV     Al,deviceParameters.DP_BPB.BPB_SectorsPerCluster
        MUL     deviceParameters.DP_BPB.BPB_BytesPerSector
        MOV     BP,AX                   ; = Bytes/Cluster

; Mark CX clusters bad starting at cluster BX
PACKIT:
        CALL    BadClus                 ;Put it in the allocation map
        JZ      BAD150                  ;If already marked bad, don't count it
        ADD     WORD PTR BADSIZ,BP      ;Add in number of bad bytes
        JNB     BAD150
        INC     WORD PTR BADSIZ+2
BAD150:
        INC     BX                      ;Next cluster
        LOOP    PACKIT                  ;Continue for # of clusters
        JMP     GETTRK

;   Inputs:     BX = Cluster number
;   Outputs:    The given cluster is marked as invalid
;               Zero flag is set if the cluster was already marked bad
;   Registers modified: DX,SI
;   No other registers affected
BadClus:
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        CMP     fBigFat,-1              ;   if (!fBigFat) {
        JZ      DoBig
        MOV     DX,0FF7h                ;       badval = 0xFF7;
        MOV     AX,0FFFh                ;       mask = 0xFFF;
        MOV     SI,BX                   ;       p = FAT+clus+clus/2;
        SHR     SI,1
        ADD     SI,BX
        ADD     SI, word ptr fatspace
        TEST    BX,1                    ;       if (clus&1) {
        JZ      DoSet
        MOV     CL,4                    ;           mask <<= 4;
        SHL     AX,CL
        MOV     CL,4                    ;           badval <<= 4;
        SHL     DX,CL                   ;           }
        JMP     SHORT DoSet
DoBig:                                  ;   else {
        MOV     DX,0FFF7h               ;       badval = 0xFFF7;
        MOV     AX,0FFFFh               ;       mask = 0xFFFF;
        MOV     SI, word ptr fatSpace   ;       p = FAT + clus + clus;
        ADD     SI,BX
        ADD     SI,BX
DoSet:                                  ;       }
        push    es
        mov     es, word ptr fatSpace + 2
        MOV     CX,es:[SI]              ;   op = *p & mask;
        AND     CX,AX
        NOT     AX                      ;   *p &= ~mask;
        AND     es:[SI],AX
        OR      es:[SI],DX              ;   *p |= badval;
        CMP     DX,CX                   ;   return op == badval;
        pop     es
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        return

DRTFAT:
        TEST    SWITCHMAP,SWITCH_S         ;If system requested, calculate size
        JZ      CLEARED
        CMP     BYTE PTR DBLFLG,0       ;Have we already calculated System space?
        JNZ     CLEARED                 ;Yes
        INC     BYTE PTR DBLFLG         ;No -- set the flag
        CALL    GETSIZE                 ;Calculate the system size
CLEARED:
        CALL    WriteFileSystem
        JNC     FATWRT
LOUSE:
        lea     dx, msgDiskUnusable
        call    PrintString
        JMP     FRMTPROB

LOUSEP:
        POP     DS
        JMP     LOUSE

FATWRT:

        PUSH    DS
        MOV     DL,DRIVE
        INC     DL
        MOV     AH,GET_DPB
        INT     21H
        CMP     AL,-1
        JZ      LOUSEP                  ;Something BAD has happened
        MOV     [BX.dpb_next_free],0    ; Reset allocation to start of disk
        MOV     [BX.dpb_free_cnt],-1    ; Force free space to be computed
        POP     DS
        TEST    SWITCHMAP,SWITCH_S         ;System desired
        JZ      STATUS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;bug007sp
;reintroduce following section of code
;
	CALL	CHKSPACE		;Enough free space for system?
	JNC	SPACEOK 		; Y: Go load system files
	LEA	DX, msgNoRoomDestDisk	; N: Print error message
	CALL	PrintString		;
	MOV	WORD PTR SYSSIZ+2,0	;No system transfered
	MOV	WORD PTR SYSSIZ,0	;No system transfered
	JMP	SHORT STATUS		;
SPACEOK:				;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;bug007sp
        mov     al, drive
        call    AccessDisk              ; note what is current logical drive
        CALL    WRITEDOS                ;Write the BIOS & DOS
        JNC     SYSOK
        lea     dx, msgNotSystemDisk
        call    PrintString
        MOV     WORD PTR SYSSIZ+2,0     ;No system transfered
        MOV     WORD PTR SYSSIZ,0       ;No system transfered
        JMP     SHORT STATUS

SYSOK:
        lea     dx, msgSystemTransfered
        call    PrintString
STATUS:
        CALL    CRLF
        CALL    VOLID
        MOV     AH,DISK_RESET
        INT     21H
        CALL    DONE                    ;Final call to OEM module
        JNC     REPORTC
        JMP     FRMTPROB                ;Report an error

REPORTC:
        CALL    REPORT

        CALL    MORE                    ;See if more disks to format
        JMP     SYSLOOP                 ;If we returned from MORE then continue

;******************************************
; Calculate the size in bytes of the system rounded up to sector and
;   cluster boundries, Answer in SYSSIZ

GetSize proc near
        call    GetBioSize
        call    GetDosSize
        call    GetCmdSize
        return
GetSize endp

GetBioSize proc near
        MOV     AX,WORD PTR bios.fileSizeInBytes
        MOV     DX,WORD PTR bios.fileSizeInBytes+2
        CALL    AddToSystemSize
        return
GetBioSize endp

GetDosSize proc near
        MOV     AX,WORD PTR dos.fileSizeInBytes
        MOV     DX,WORD PTR dos.fileSizeInBytes+2
        CALL    AddToSystemSize
        return
GetDosSize endp

GetCmdSize proc near
        MOV     AX,WORD PTR command.fileSizeInBytes
        MOV     DX,WORD PTR command.fileSizeInBytes+2
        call    AddToSystemSize
        return
GetCmdSize endp

;Calculate the number of sectors used for the system
PUBLIC AddToSystemSize
AddToSystemSize proc near
        push    bx
        DIV     deviceParameters.DP_BPB.BPB_BytesPerSector
        OR      DX,DX
        JZ      FNDSIZ0
        INC     AX                      ; Round up to next sector
FNDSIZ0:
        PUSH    AX
        XOR     DX,DX
        xor     bx,bx
        mov     bl, deviceParameters.DP_BPB.BPB_SectorsPerCluster
        div     bx
        POP     AX
        OR      DX,DX
        JZ      ONCLUS
        SUB     DX, bx
        NEG     DX
        ADD     AX,DX                   ; Round up sector count to cluster
                                        ;       boundry
ONCLUS:
        MUL     deviceParameters.DP_BPB.BPB_BytesPerSector
        ADD     WORD PTR SYSSIZ,AX
        ADC     WORD PTR SYSSIZ+2,DX
        pop     bx
        return
AddToSystemSize endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;bug007sp
;	reintroduce following section of code
;; Check free space to see if there is enough room to load the system
;; On Entry: DL = drive
;; On Exit:  carry flag set if not enough room
;;	    no other registers are affected
CHKSPACE	PROC	NEAR
	PUSH	AX			;Save resisters
	PUSH	BX
	PUSH	CX
	PUSH	DX

	MOV	AH,36H			;Get free space 
	INT	21h

;;16 bit math okay here, no danger of overflow
	MUL	CX			;Get bytes/cluster
	MOV	CX,AX			;
	MOV	AX,WORD PTR SYSSIZ	;Get # of bytes for system
	MOV	DX,WORD PTR SYSSIZ+2	;
	DIV	CX			;Get # of clusters for system

	CMP	AX,BX			;Is there enough space? 
	JBE	ENOUGHSPACE		; Y: Go clear carry
	STC				; N: Set carry
	JMP	SHORT	RESTOREREGS	;	
;	
ENOUGHSPACE:
	CLC
;
RESTOREREGS:
	POP	DX			;Restore resisters
	POP	CX
	POP	BX
	POP	AX
	RET
CHKSPACE	ENDP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;bug007sp

MORE:   CMP     deviceParameters.DP_DeviceType, DEV_HARDDISK
        je      ExitProgram
        CALL    FormatAnother?                  ;Get yes or no response
        JC      ExitProgram
        CALL    CRLF
        JMP     CRLF


FEXIT:
        mov     ExitStatus,ExitFatal

ExitProgram:
        test    validSavedDeviceParameters, 0ffH
        jz      DoNotRestoreDeviceParameters
        mov     savedDeviceParameters.DP_SpecialFunctions, TRACKLAYOUT_IS_GOOD
        lea     dx, savedDeviceParameters
        call    SetDeviceParameters
DoNotRestoreDeviceParameters:
        mov     al, ExitStatus
        mov     ah,exit
        INT     21H

; Prompt the user for a system diskette in the default drive
SYSPRM:
        MOV     AH,GET_DEFAULT_DRIVE    ;Will find out the default drive
        INT     21H                     ;Default now in AL
        MOV     BL,AL
        INC     BL                      ; A = 1
        ADD     AL,41H                  ;Now in Ascii
        MOV     systemDriveLetter,AL               ;Text now ok
        CALL    IsRemovable
        JNC     DoPrompt
;
; Media is non-removable. Switch sys disk to drive A.  Check, though, to see
; if drive A is removable too.
;
        MOV     AL,"A"
        MOV     BYTE PTR [systemDriveLetter],AL
        MOV     [BiosFile],AL
        MOV     [DosFile],AL
        MOV     [CommandFile],AL
        MOV     BX,1
        CALL    IsRemovable
        JNC     DoPrompt
        lea     dx, msgNoSystemFiles
        call    PrintString
fexitJ:
        JMP     FEXIT

DoPrompt:
        mov     al, systemDriveLetter
        sub     al, 'A'
        call    AccessDisk
        lea     dx, ptr_msgInsertDosDisk
        CALL    std_printf              ;Print first line
        CALL    USER_STRING             ;Wait for a key
        CALL    CRLF
        return

TARGPRM:
        mov     al, drive
        call    AccessDisk
        lea     DX, ptr_msgInsertDisk
        CALL    std_printf              ;Print first line
        CALL    USER_STRING             ;Wait for a key
        CALL    CRLF
        return

;
; Determine if the drive indicated in BX is removable or not.
;
;   Inputs:     BX has drive (0=def, 1=A)
;   Outputs:    Carry clear
;                   Removable
;               Carry set
;                   not removable
;   Registers modified: none

IsRemovable:
        SaveReg <AX>
        MOV     AX,(IOCTL SHL 8) OR 8   ; Rem media check
        INT     21H
        JNC     CheckRemove
        MOV     AX,(IOCTL SHL 8) + 9    ; Is it a NET drive?
        INT     21h
        JC      NotRemove               ; Yipe, say non-removable
        TEST    DX,1000h
        JNZ     NotRemove               ; Is NET drive, say non-removeable
        JMP     IsRemove                ; Is local, say removable
CheckRemove:
        TEST    AX,1
        JNZ     NotRemove
IsRemove:
        CLC
        RestoreReg  <AX>
        return
NotRemove:
        STC
        RestoreReg  <AX>
        return


; DiSKPRoMpt:
;
;       This routine prompts for the insertion of the correct diskette
;  into the Target drive, UNLESS we are being re-entrantly invoked
;  from LastChanceToSaveIt.  If the target is a Hardisk we issue a
;  warning message.
;
;       INPUTS:
;               deviceParameters.DP_DeviceType
;               fLastChance
;
;       OUTPUTS:
;               Prompt string
;               fLastChance     := FALSE
;
;       Registers affected:
;                               Flags
;
DSKPRM:
        CMP     fLastChance,TRUE
        JE      PrmptRet

        CMP     deviceParameters.DP_DeviceType, DEV_HARDDISK
        jne     goprnit
        lea     dx, ptr_msgHardDiskWarning
        call    std_printf
        CALL    Yes?
        jnc     OkToFormatHardDisk
        mov     ExitStatus, ExitNo
        jmp     ExitProgram

OkToFormatHardDisk:
        CALL    CRLF
        CALL    CRLF
        return

GOPRNIT:
        mov     al, drive
        call    AccessDisk
        lea     dx,ptr_msgInsertDisk
        CALL    std_printf
        CALL    USER_STRING             ;Wait for any key
        CALL    CRLF
        CALL    CRLF

PrmptRet:
        mov     fLastChance, FALSE
        return

;-------------------------------------------------------------------------------
; ScanOff
;       Scan Off separator characters

SCANOFF:
        LODSB
        CMP     AL,' '
        JZ      SCANOFF
        CMP     AL,9
        JZ      SCANOFF
        DEC     SI
        return

;-------------------------------------------------------------------------------
; MakeNum
;       Makenum converts digits from ASCII AlphaNumeric format to
;       numeric values
;
;       Entry:
;               AL == Character to be converted
;               DS:SI == Command line text
;
;       Exit:
;               AX == Value
;               IF AX == 0 THEN Zero Flag == SET
;               IF ERROR   THEN Carry Flag == SET
;               BX,CX,DX == Garbage
;               DS:SI == Character after numeric value
;
;       Procs used:
;               ToDigit

Public MakeNum,CalcLoop
MakeNum:
        xor     BX,BX                           ; Initialize running cnt
        mov     CX,10                           ; and base of arithmetic
CalcLoop:                                       ; UNTIL no more digits
        call    ToDigit                         ;   AL := AL - '0'
        jc      BadNum                          ;   IF error EXIT with carry set

        xchg    ax,bx                           ;   AX := running_cnt * 10 +
        mul     cx                              ;                       digit
        add     ax,bx
        jc      BadNum                          ;   IF Overflow EXIT with carry

        xchg    ax,bx                           ;   BX := Running total

        LODSB                                   ;   Get Next Digit
        cmp     al,' '                          ;   IF ( ax = (' ',',',))
        je      RetVal                          ;      THEN return parsed value
        cmp     al,','
        je      RetVal

        cmp     al,'/'                          ;   IF (ax = ('/','cr'))
        je      BURetVal                        ;      THEN backup DS:SI and
        cmp     al,0dh                          ;       return parsed value
        je      BURetVal
        or      al,al
        jnz     CalcLoop                        ; END until

BURetVal:
        dec     SI
RetVal:
        mov     ax,bx
        or      ax,ax
        return

public Badnum
BadNum:
        xor     ax,ax
        stc
        return

; ToDigit:
;      Convert value in AX to decimal digit, range checking for valid values
;
public ToDigit
ToDigit:
        sub     al,'0'
        jb      NotDigit
        cmp     al,9
        ja      NotDigit
        clc
        return

NotDigit:
        stc
        return

;-------------------------------------------------------------------------------

ControlC_Handler:
        mov     ax, seg data
        mov     ds, ax
        lea     dx, msgInterrupt
        call    PrintString
        mov     ExitStatus, ExitCtrlC
        jmp     ExitProgram

;-------------------------------------------------------------------------------
; SaveNum
;       Save Number from switches into appropriate variable for later use
;       Some switches have upper and lower bounds for legal values and
;       these are checked for here
;
;       ENTRY:
;               cx == Switch just parsed
;               ax == value parsed
;
;       EXIT:
;               Value stored in appropriate variable
;               DS,DX == garbage
;

public SaveNum
SaveNum:
        mov     dx, seg data
        mov     ds, dx
        test    word ptr data:Switchmap, CX     ; IF already set THEN ignore
        jnz     done_ret

        test    CX,SWITCH_T
        jnz     Store_T

        test    CX,SWITCH_N
        jz      BadNum

Store_N:
        cmp     AX,0                            ; IF (value == 0) THEN ignore
        je      done_ret

        cmp     AX, MAX_SECTORS_IN_TRACK        ; IF (value > Max_sectors)
        jbe     short Store_N1                  ;   THEN issue error
        jmp     INVALID

Store_N1:
        mov     word ptr data:NumSectors  , AX

        jmp     short done_ret

Store_T:
        mov     word ptr data:TrackCnt, AX

Done_ret:
        ret
;-------------------------------------------------------------------------------

crlf:
        lea     dx, msgCRLF

PrintString:
        mov     printStringPointer, dx
        lea     dx, PrintStringPointer

std_printf:
        push    dx
        call    printf
        return

;-------------------------------------------------------------------------------

;*****************************************
; Process V switch if set

VOLID:
        TEST    [SWITCHMAP],SWITCH_V
        JNZ     DOVOL
VRET:   CLC
        return

DOVOL:
        PUSH    CX
        PUSH    SI
        PUSH    DI
        PUSH    ES
        PUSH    DS
        POP     ES
VOL_LOOP:
        MOV     AL,DRIVE
        INC     AL
        MOV     DS:BYTE PTR[VOLFCB+7],AL
        lea     dx, msgLabelPrompt
        call    PrintString
        CALL    USER_STRING
        call    crlf
        call    crlf
        MOV     CL,[INBUFF+1]
        OR      CL,CL
        JZ      VOLRET
        XOR     CH,CH
        MOV     SI,OFFSET INBUFF+2
        MOV     DI,SI
        ADD     DI,CX
        MOV     CX,11
        MOV     AL,' '
        REP     STOSB
        MOV     CX,5
        MOV     DI,OFFSET VOLNAM
        REP     MOVSW
        MOVSB
        MOV     DX,OFFSET VOLFCB
        MOV     AH,FCB_CREATE
        INT     21H
        OR      AL,AL
        JZ      GOOD_CREATE
        lea     dx, msgBadCharacters
        call    PrintString
        JMP     VOL_LOOP
GOOD_CREATE:
        MOV     DX,OFFSET VOLFCB
        MOV     AH,FCB_CLOSE
        INT     21H
        CALL    CRLF
VOLRET:
        POP     ES
        POP     DI
        POP     SI
        POP     CX
        return

;****************************************
;Copy IO.SYS, MSDOS.SYS and COMMAND.COM into data area.
; Carry set if problems

READDOS:
;       CALL    TESTSYSDISK             ; dcl 8/23/86
        call    Get_BIOS                ; dcl 8/23/86
        JNC     RDFILS
        return

RDFILS:
        MOV     BYTE PTR [FILSTAT],0
        MOV     BX,[bios.fileHandle]
        MOV     AX,[MSTART]
        MOV     DX,AX
        ADD     DX,[MSIZE]              ; CX first bad para
        MOV     [bios.fileStartSegment],AX
        MOV     CX,[bios.fileSizeInParagraphs]
        ADD     AX,CX
        CMP     AX,DX
        JBE     GOTBIOS
        MOV     BYTE PTR [FILSTAT],00000001B    ; Got part of BIOS
        MOV     SI,[MSIZE]
        XOR     DI,DI
        CALL    DISIX4
        push    ds
        MOV     DS,[bios.fileStartSegment]
        assume  ds:nothing
        CALL    READFILE
        pop     ds
        assume  ds:data
        JC      CLSALL
        XOR     DX,DX
        MOV     CX,DX
        MOV     AX,(LSEEK SHL 8) OR 1
        INT     21H
        MOV     WORD PTR [bios.fileOffset],AX
        MOV     WORD PTR [bios.fileOffset+2],DX
FILESDONE:
        CLC
CLSALL:
        PUSHF
;       CALL    COMCLS                  ; dcl 8/23/86
        call    FILE_CLS                ; dcl 8/23/86
        POPF
        return

GOTBIOS:
        MOV     BYTE PTR [FILSTAT],00000010B    ; Got all of BIOS
        push    es
        LES     SI,[bios.fileSizeInBytes]
        MOV     DI,ES
        pop     es
        push    ds
        MOV     DS,[bios.fileStartSegment]
        assume  ds:nothing
        CALL    READFILE
        pop     ds
        assume  ds:data
        JC      CLSALL

        push    ax                              ; dcl 8/23/86
        push    dx                              ; dcl 8/23/86
        call    File_Cls                        ; dcl 8/23/86
        call    Get_DOS                         ; dcl 8/23/86
        pop     dx                              ; dcl 8/23/86
        pop     ax                              ; dcl 8/23/86

        JNC     Found_MSDOS                     ;mt 12/8/86 P894
        return                                  ;mt 12/8/86

Found_MSDOS:                                    ;mt 12/8/86

        MOV     BX,[dos.fileHandle]
        MOV     [dos.fileStartSegment],AX
        CMP     AX,DX                   ; No room left?
        JZ      CLSALL                  ; Yes
        MOV     CX,[dos.fileSizeInParagraphs]
        ADD     AX,CX
        CMP     AX,DX
        JBE     GOTDOS
        OR      BYTE PTR [FILSTAT],00000100B    ; Got part of DOS
        SUB     DX,[dos.fileStartSegment]
        MOV     SI,DX
        XOR     DI,DI
        CALL    DISIX4
        push    ds
        MOV     DS,[dos.fileStartSegment]
        assume  ds:nothing
        CALL    READFILE
        pop     ds
        assume  ds:data
        JC      CLSALL
        XOR     DX,DX
        MOV     CX,DX
        MOV     AX,(LSEEK SHL 8) OR 1
        INT     21H
        MOV     WORD PTR [dos.fileOffset],AX
        MOV     WORD PTR [dos.fileOffset+2],DX
        JMP     FILESDONE

GOTDOS:
        OR      BYTE PTR [FILSTAT],00001000B    ; Got all of DOS
        LES     SI,[dos.fileSizeInBytes]
        MOV     DI,ES
        push    ds
        MOV     DS,[dos.fileStartSegment]
        assume  ds:nothing
        CALL    READFILE
        pop     ds
        assume  ds:data

CLSALLJ: JNC    NOTCLSALL               ;PTM P894  mt 12/8/86
         jmp    clsall                  ;

NotCLSALL:
        push    ax                      ; dcl 8/23/86

        push    dx                      ; dcl 8/23/86
        call    File_cls                ; dcl 8/23/86
        call    Get_COMMAND             ; dcl 8/23/86
        pop     dx                      ; dcl 8/23/86
        pop     ax                      ; dcl 8/23/86

        JNC     Found_COMMAND                   ;mt 12/8/86 P894
        return                                  ;mt 12/8/86

Found_COMMAND:                                  ;mt 12/8/86
        MOV     BX,[command.fileHandle]
        MOV     [command.fileStartSegment],AX
        CMP     AX,DX                   ; No room left?
        JZ      CLSALLJ                 ; Yes
        MOV     CX,[command.fileSizeInParagraphs]
        ADD     AX,CX
        CMP     AX,DX
        JBE     GOTCOM
        OR      BYTE PTR [FILSTAT],00010000B    ; Got part of COMMAND
        SUB     DX,[command.fileStartSegment]
        MOV     SI,DX
        XOR     DI,DI
        CALL    DISIX4
        push    ds
        MOV     DS,[command.fileStartSegment]
        assume  ds:nothing
        CALL    READFILE
        pop     ds
        assume  ds:data
        JC      CLSALLJ
        XOR     DX,DX
        MOV     CX,DX
        MOV     AX,(LSEEK SHL 8) OR 1
        INT     21H
        MOV     WORD PTR [command.fileOffset],AX
        MOV     WORD PTR [command.fileOffset+2],DX
        JMP     FILESDONE

GOTCOM:
        OR      BYTE PTR [FILSTAT],00100000B    ; Got all of COMMAND
        LES     SI,[command.fileSizeInBytes]
        MOV     DI,ES
        push    ds
        MOV     DS,[command.fileStartSegment]
        assume  ds:nothing
        CALL    READFILE
        pop     ds
        assume  ds:data
        JMP     CLSALL

;**************************************************
;Write BIOS DOS COMMAND to the newly formatted disk.

ASSUME DS:DATA
WRITEDOS:
        MOV     CX,BiosAttributes
        MOV     DX,OFFSET BiosFile
        LES     SI,[bios.fileSizeInBytes]
        MOV     DI,ES
        CALL    MAKEFIL
        retc

        MOV     [TempHandle],BX
        TEST    BYTE PTR FILSTAT,00000010B
        JNZ     GOTALLBIO
        call    Get_BIOS                        ; dcl 8/23/86
        jnc     Got_WBIOS                       ;mt 12/8/86  P894
        ret

Got_WBIOS:

        LES     SI,[bios.fileOffset]
        MOV     DI,ES
        MOV     WORD PTR [IOCNT],SI
        MOV     WORD PTR [IOCNT+2],DI
        MOV     BP,OFFSET bios
        CALL    GOTTARG
        retc
        JMP     SHORT BIOSDONE

GOTALLBIO:
        LES     SI,[bios.fileSizeInBytes]
        MOV     DI,ES
        push    ds
        MOV     DS,[bios.fileStartSegment]
        assume  ds:nothing
        CALL    WRITEFILE
        pop     ds
        assume  ds:data
BIOSDONE:
        MOV     BX,[TempHandle]
        MOV     CX,bios.fileTime
        MOV     DX,bios.fileDate
        CALL    CLOSETARG
        MOV     CX,DosAttributes
        MOV     DX,OFFSET DosFile
        LES     SI,[dos.fileSizeInBytes]
        MOV     DI,ES
        CALL    MAKEFIL
        retc

GOTNDOS:
        MOV     [TempHandle],BX
        TEST    BYTE PTR FILSTAT,00001000B
        JNZ     GOTALLDOS
        call    Get_DOS                         ; dcl 8/23/86
        jnc     Got_WDOS                       ;mt 12/8/86  P894
        ret

Got_WDOS:
        MOV     BP,OFFSET dos
        TEST    BYTE PTR FILSTAT,00000100B
        JNZ     PARTDOS
        MOV     WORD PTR [dos.fileOffset],0
        MOV     WORD PTR [dos.fileOffset+2],0
        CALL    GETSYS3
        retc
        JMP     SHORT DOSDONE

PARTDOS:
        LES     SI,[dos.fileOffset]
        MOV     DI,ES
        MOV     WORD PTR [IOCNT],SI
        MOV     WORD PTR [IOCNT+2],DI
        CALL    GOTTARG
        retc
        JMP     SHORT DOSDONE

GOTALLDOS:
        LES     SI,[dos.fileSizeInBytes]
        MOV     DI,ES
        push    ds
        MOV     DS,[dos.fileStartSegment]
        assume  ds:nothing
        CALL    WRITEFILE
        pop     ds
        assume  ds:data
DOSDONE:
        MOV     BX,[TempHandle]
        MOV     CX,dos.fileTime
        MOV     DX,dos.fileDate
        CALL    CLOSETARG
        MOV     CX,CommandAttributes
        MOV     DX,OFFSET CommandFile
        LES     SI,[command.fileSizeInBytes]
        MOV     DI,ES
        CALL    MAKEFIL
        retc

        MOV     [TempHandle],BX
        TEST    BYTE PTR FILSTAT,00100000B
        JNZ     GOTALLCOM
        call    Get_COMMAND                     ; dcl 8/23/86
        jnc     Got_WCOM                       ;mt 12/8/86  P894
        ret

Got_WCOM:
        MOV     BP,OFFSET command
        TEST    BYTE PTR FILSTAT,00010000B
        JNZ     PARTCOM
        MOV     WORD PTR [command.fileOffset],0
        MOV     WORD PTR [command.fileOffset+2],0
        CALL    GETSYS3
        retc
        JMP     SHORT COMDONE

PARTCOM:
        LES     SI,[command.fileOffset]
        MOV     DI,ES
        MOV     WORD PTR [IOCNT],SI
        MOV     WORD PTR [IOCNT+2],DI
        CALL    GOTTARG
        retc
        JMP     SHORT COMDONE

GOTALLCOM:
        LES     SI,[command.fileSizeInBytes]
        MOV     DI,ES
        push    ds
        MOV     DS,[command.fileStartSegment]
        assume  ds:nothing
        CALL    WRITEFILE
        pop     ds
        assume  ds:data
COMDONE:
        MOV     BX,[TempHandle]
        MOV     CX,command.fileTime
        MOV     DX,command.fileDate
        CALL    CLOSETARG
;****************************************************************
; I don't see the need for the following code!! - RS 3.20
;       CMP     BYTE PTR [FILSTAT],00101010B
;       JZ      NOREDOS
;RDFRST2:
;       CALL    READDOS                 ; Start back with BIOS
;       JNC     NOREDOS
;       CALL    SYSPRM                  ;Prompt for system disk
;       JMP     RDFRST2                 ;Try again
;NOREDOS:
;****************************************************************
        CLC
        return

;*********************************************
; Create a file on target disk
; CX = attributes, DX points to name
; DI:SI is size file is to have
;
;   There is a bug in DOS 2.00 and 2.01 having to do with writes
;   from the end of memory. In order to circumvent it this routine
;   must create files with the length in DI:SI
;
; On return BX is handle, carry set if problem

MAKEFIL:
        MOV     BX,DX
        PUSH    WORD PTR [BX]
        MOV     AL,DriveLetter
        MOV     [BX],AL
        MOV     AH,CREAT
        INT     21H
        POP     WORD PTR [BX]
        MOV     BX,AX
        JC      CheckMany
        MOV     CX,DI
        MOV     DX,SI
        MOV     AX,LSEEK SHL 8
        INT     21H                     ; Seek to eventual EOF
        XOR     CX,CX
        MOV     AH,WRITE
        INT     21H                     ; Set size of file to position
        XOR     CX,CX
        MOV     DX,CX
        MOV     AX,LSEEK SHL 8
        INT     21H                     ; Seek back to start
        return

;
; Examine error code in AX to see if it is too-many-open-files.
; If it is, we abort right here. Otherwise we return.
;
CheckMany:
        CMP     AX,error_too_many_open_files
        retnz
        lea     dx, msgTooManyFilesOpen
        call    PrintString
        JMP     FEXIT

;*********************************************
; Close a file on the target disk
; CX/DX is time/date, BX is handle

CLOSETARG:
        MOV     AX,(FILE_TIMES SHL 8) OR 1
        INT     21H
        MOV     AH,CLOSE
        INT     21H
        return

;****************************************
; Transfer system files
; BP points to data structure for file involved
; offset is set to current amount read in
; Start set to start of file in buffer
; TempHandle is handle to write to on target

IOLOOP:
        MOV     AL,[systemDriveLetter]
        CMP     AL,[DriveLetter]
        JNZ     GOTTARG
        MOV     AH,DISK_RESET
        INT     21H
        CALL    TARGPRM                 ;Get target disk

GOTTARG:
ASSUME DS:DATA
;Enter here if some of file is already in buffer, IOCNT must be set
; to size already in buffer.
        MOV     BX,[TempHandle]
        MOV     SI,WORD PTR [IOCNT]
        MOV     DI,WORD PTR [IOCNT+2]
        push    ds
        MOV     DS,ds:[BP.fileStartSegment]
        assume  ds:nothing
        CALL    WRITEFILE               ; Write next part
        pop     ds
        assume  ds:data
        retc

        LES     AX,ds:[BP.fileOffset]
        CMP     AX,WORD PTR ds:[BP.fileSizeInBytes]
        JNZ     GETSYS3
        MOV     AX,ES
        CMP     AX,WORD PTR ds:[BP.fileSizeInBytes+2]
        JNZ     GETSYS3
        return                             ; Carry clear from CMP

GETSYS3:
;Enter here if none of file is in buffer
        MOV     AH,DISK_RESET
        INT     21H
        MOV     AX,[MSTART]                     ;Furthur IO done starting here
        MOV     ds:[BP.fileStartSegment],AX
        MOV     AL,[systemDriveLetter]
        CMP     AL,[DriveLetter]
        JNZ     TESTSYS
GSYS:
        MOV     AH,DISK_RESET
        INT     21H
        CALL    SYSPRM                          ;Prompt for system disk
TESTSYS:
;       CALL    TESTSYSDISK                     ; dcl 8/23/86
        JC      GSYS
        MOV     BX,word ptr DS:[BP.fileHandle]  ; CS over ARR 2.30
        LES     DX,dword ptr DS:[BP.fileOffset] ; CS over ARR 2.30
        PUSH    DX
        MOV     CX,ES
        MOV     AX,LSEEK SHL 8
        INT     21H
        POP     DX
        LES     SI,dword ptr DS:[BP.fileSizeInBytes]   ; CS over ARR 2.30
        MOV     DI,ES
        SUB     SI,DX
        SBB     DI,CX                   ; DI:SI is #bytes to go
        PUSH    DI
        PUSH    SI
        ADD     SI,15
        ADC     DI,0
        CALL    DISID4
        MOV     AX,SI
        POP     SI
        POP     DI
        CMP     AX,[MSIZE]
        JBE     GOTSIZ2
        MOV     SI,[MSIZE]
        XOR     DI,DI
        CALL    DISIX4
GOTSIZ2:
        MOV     WORD PTR [IOCNT],SI
        MOV     WORD PTR [IOCNT+2],DI
        push    ds
        MOV     DS,[MSTART]
        assume  ds:nothing
        CALL    READFILE
        pop     ds
        assume  ds:data
        JNC     GETOFFS
        CALL    CLSALL
        JMP     GSYS
GETOFFS:
        XOR     DX,DX
        MOV     CX,DX
        MOV     AX,(LSEEK SHL 8) OR 1
        INT     21H
        MOV     WORD PTR DS:[BP.fileOffset],AX     ; CS over ARR 2.30
        MOV     WORD PTR DS:[BP.fileOffset+2],DX   ; CS over ARR 2.30
        CALL    CLSALL
        JMP     IOLOOP

;*************************************************
; Test to see if correct system disk. Open handles

CRET12:
        STC
        return

;TESTSYSDISK:                                   ; dcl 8/23/86
Get_BIOS:                                       ; dcl 8/23/86
        MOV     AX,OPEN SHL 8
        MOV     DX,OFFSET BiosFile
        INT     21H
        JNC     SETBIOS
;       call    CheckMany                       ; dcl 8/23/86
        jmp     CheckMany                       ; dcl 8/23/86

SETBIOS:
        MOV     [Bios.fileHandle],AX
        MOV     BX,AX
        CALL    GETFSIZ
        CMP     [bios.fileSizeInParagraphs],0
        JZ      SETBIOSSIZ
        CMP     [bios.fileSizeInParagraphs],AX
        JZ      SETBIOSSIZ
BIOSCLS:
        MOV     AH,CLOSE
        MOV     BX,[Bios.fileHandle]
        INT     21H
;       JMP     CRET12                 ; dcl 8/23/86
        ret

SETBIOSSIZ:
        MOV     [bios.fileSizeInParagraphs],AX
        MOV     WORD PTR [bios.fileSizeInBytes],SI
        MOV     WORD PTR [bios.fileSizeInBytes+2],DI
        MOV     [bios.fileDate],DX
        MOV     [bios.fileTime],CX
        clc
        ret                                     ; dcl 8/23/86

Get_DOS:                                        ; dcl 8/23/86
        MOV     AX,OPEN SHL 8
        MOV     DX,OFFSET DosFile
        INT     21H
        JNC     DOSOPNOK
;       call    CheckMany                       ; dcl 8/23/86
;       JMP     BIOSCLS                         ; dcl 8/23/86  Checkmany no ret.
        jmp     CheckMany                       ; dcl 8/23/86

DOSOPNOK:
        MOV     [dos.fileHandle],AX
        MOV     BX,AX
        CALL    GETFSIZ
        CMP     [dos.fileSizeInParagraphs],0
        JZ      SETDOSSIZ
        CMP     [dos.fileSizeInParagraphs],AX
        JZ      SETDOSSIZ

DOSCLS:
        MOV     AH,CLOSE
        MOV     BX,[dos.fileHandle]
        INT     21H
;       JMP     BIOSCLS                 ; dcl 8/23/86
        ret                             ; dcl 8/23/86

SETDOSSIZ:
        MOV     [dos.fileSizeInParagraphs],AX
        MOV     WORD PTR [dos.fileSizeInBytes],SI
        MOV     WORD PTR [dos.fileSizeInBytes+2],DI
        MOV     [dos.fileDate],DX
        MOV     [dos.fileTime],CX
        clc
        ret                             ; dcl 8/23/86

Get_COMMAND:
        MOV     AX,OPEN SHL 8
        MOV     DX,OFFSET CommandFile
        INT     21H
        JNC     GotComHand
;       call    CheckMany               ; dcl 8/23/86
;       JMP     DosCls                  ; dcl 8/23/86
        jmp     Checkmany               ; dcl 8/23/86

GotComHand:
        MOV     [command.fileHandle],AX
        MOV     BX,AX
        CALL    GETFSIZ
        CMP     [command.fileSizeInParagraphs],0
        JZ      SETCOMSIZ
        CMP     [command.fileSizeInParagraphs],AX
        JZ      SETCOMSIZ
COMCLS:
        MOV     AH,CLOSE
        MOV     BX,[command.fileHandle]
        INT     21H
;       JMP     DOSCLS                  ; dcl 8/23/86
        ret                             ; dcl 8/23/86

SETCOMSIZ:
        MOV     [command.fileSizeInParagraphs],AX
        MOV     WORD PTR [command.fileSizeInBytes],SI
        MOV     WORD PTR [command.fileSizeInBytes+2],DI
        MOV     [command.fileDate],DX
        MOV     [command.fileTime],CX
        CLC
        return

FILE_CLS:                               ; dcl 8/23/86
        MOV     AH,CLOSE                ; dcl 8/23/86
        INT     21H                     ; dcl 8/23/86
        ret                             ; dcl 8/23/86

;*******************************************
; Handle in BX, return file size in para in AX
; File size in bytes DI:SI, file date in DX, file
; time in CX.

GETFSIZ:
        MOV     AX,(LSEEK SHL 8) OR 2
        XOR     CX,CX
        MOV     DX,CX
        INT     21H
        MOV     SI,AX
        MOV     DI,DX
        ADD     AX,15                   ; Para round up
        ADC     DX,0
        AND     DX,0FH                  ; If the file is larger than this it
                                        ; is bigger than the 8086 address
                                        ; space!
        MOV     CL,12
        SHL     DX,CL
        MOV     CL,4
        SHR     AX,CL
        OR      AX,DX
        PUSH    AX
        MOV     AX,LSEEK SHL 8
        XOR     CX,CX
        MOV     DX,CX
        INT     21H
        MOV     AX,FILE_TIMES SHL 8
        INT     21H
        POP     AX
        return

;********************************************
; Read/Write file
;       DS:0 is Xaddr
;       DI:SI is byte count to I/O
;       BX is handle
; Carry set if screw up
;
; I/O SI bytes
; I/O 64K - 1 bytes DI times
; I/O DI bytes


READFILE:
; Must preserve AX,DX
        PUSH    AX
        PUSH    DX
        PUSH    BP
        MOV     BP,READ SHL 8
        CALL    FILIO
        POP     BP
        POP     DX
        POP     AX
        return

WRITEFILE:
        PUSH    BP
        MOV     BP,WRITE SHL 8
        CALL    FILIO
        POP     BP
        return

FILIO:
        XOR     DX,DX
        MOV     CX,SI
        JCXZ    K64IO
        MOV     AX,BP
        INT     21H
        retc
        ADD     DX,AX
        CMP     AX,CX                   ; If not =, AX<CX, carry set.
        retnz
        CALL    NORMALIZE
K64IO:
        CLC
        MOV     CX,DI
        JCXZ    IORET
        MOV     AX,BP
        INT     21H
        retc
        ADD     DX,AX
        CMP     AX,CX                   ; If not =, AX<CX, carry set.
        retnz
        CALL    NORMALIZE
        MOV     CX,DI
K64M1:
        PUSH    CX
        XOR     AX,AX
        OR      DX,DX
        JZ      NORMIO
        MOV     CX,10H
        SUB     CX,DX
        MOV     AX,BP
        INT     21H
        JC      IORETP
        ADD     DX,AX
        CMP     AX,CX                   ; If not =, AX<CX, carry set.
        JNZ     IORETP
        CALL    NORMALIZE
NORMIO:
        MOV     CX,0FFFFH
        SUB     CX,AX
        MOV     AX,BP
        INT     21H
        JC      IORETP
        ADD     DX,AX
        CMP     AX,CX                   ; If not =, AX<CX, carry set.
        JNZ     IORETP
        CALL    NORMALIZE               ; Clears carry
        POP     CX
        LOOP    K64M1
        PUSH    CX
IORETP:
        POP     CX
IORET:
        return


;*********************************
; Shift DI:SI left 4 bits
DISIX4:
        MOV     CX,4
SH32:
        SHL     SI,1
        RCL     DI,1
        LOOP    SH32
        return

;*********************************
; Shift DI:SI right 4 bits
DISID4:
        MOV     CX,4
SH32B:
        SHR     DI,1
        RCR     SI,1
        LOOP    SH32B
        return

;********************************
; Normalize DS:DX

NORMALIZE:
        PUSH    DX
        PUSH    AX
        SHR     DX,1
        SHR     DX,1
        SHR     DX,1
        SHR     DX,1
        MOV     AX,DS
        ADD     AX,DX
        MOV     DS,AX
        POP     AX
        POP     DX
        AND     DX,0FH                  ; Clears carry
        return

;-------------------------------------------------------------------------------
; Phase1Initialisation:
;    This routine MUST set up fatSpace, and fBigFat
;    It also does most of the other initialisation
;
;    Algorithm:
;       Open a handle for accessing the drive
;       Get device parameters
;       save device parameters for exit
;       Check switches against parameters
;       Use switches to modify device parameters
;       directorySector = malloc( Bytes Per Sector )
;       fatSpace = malloc( Bytes Per Sector * Sectors Per Fat )
;       Calculate start sector (first sector not used by DOS)
;       fBigFat = (((Total Sectors - StartSector)/Sectors Per Cluster) >= 4086)
;
Phase1Initialisation proc near

; Get device parameters
        lea     dx, deviceParameters
        mov     deviceParameters.DP_SpecialFunctions, 0
        call    GetDeviceParameters
        jnc     GotDeviceParameters
        lea     dx, ptr_msgFormatNotSupported
        call    std_printf
        jmp     fexit
GotDeviceParameters:

; Save the device parameters for when we exit
        lea     si, deviceParameters
        lea     di, savedDeviceParameters
        mov     cx, size a_DeviceParameters
        push    ds
        pop     es
        rep     movsb

; Ensure that there is a valid number of sectors in the track table
        mov     savedDeviceParameters.DP_TrackTableEntries, 0
        mov     validSavedDeviceParameters, 1

; Initialise this to zero to know if CheckSwitches defined the track layout
        mov     deviceParameters.DP_TrackTableEntries, 0

; Detect whether "set media type" is supported
;       test    DeviceParameters.DeviceAttributes, SetMediaType
;       jnz     SetMTsupp

SetMTsupp:

; Check switches against parameters and use switches to modify device parameters
        call    CheckSwitches
        retc

        cmp     deviceParameters.DP_TrackTableEntries, 0
        jne     TrackLayoutSet                  ; There is a good track layout

; Store sector table info
        mov     cx, deviceParameters.DP_BPB.BPB_SectorsPerTrack
        mov     deviceParameters.DP_TrackTableEntries, cx
        mov     ax, 1
        mov     bx, deviceParameters.DP_BPB.BPB_bytesPerSector
        lea     di, deviceParameters.DP_SectorTable
LoadSectorTable:
        stosw
        xchg    ax, bx
        stosw
        xchg    ax, bx
        inc     ax
        loop    LoadSectorTable
TrackLayoutSet:

;
; directorySector = malloc( Bytes Per Sector )
;
        mov     bx, deviceParameters.DP_BPB.BPB_BytesPerSector
        add     bx, 0fH
        shr     bx, 1
        shr     bx, 1
        shr     bx, 1
        shr     bx, 1
        mov     ah, Alloc
        int     21H
        retc
        mov     word ptr directorySector+2, ax
        xor     ax,ax
        mov     word ptr directorySector, ax

;
; fatSpace = malloc( Bytes Per Sector * Sectors Per FAT )
;
        mov     ax, deviceParameters.DP_BPB.BPB_BytesPerSector
        mul     deviceParameters.DP_BPB.BPB_SectorsPerFAT
        add     ax, 0fH
        shr     ax, 1
        shr     ax, 1
        shr     ax, 1
        shr     ax, 1
        mov     bx, ax
        mov     ah, Alloc
        int     21H
        retc
        mov     word ptr fatSpace+2, ax
        xor     ax, ax
        mov     word ptr fatSpace, ax

        call    SetStartSector
        call    SetfBigFat

        clc
        return

Phase1Initialisation endp

;-------------------------------------------------------------------------------

SetStartSector proc near

; startSector = number of reserved sectors
;        + number of FAT Sectors        ( Number of FATS * Sectors Per FAT )
;        + number of directory sectors  ( 32* Root Entries / bytes Per Sector )
;                                       ( above is rounded up )

; Calculate the number of directory sectors
        mov     ax, deviceParameters.DP_BPB.BPB_RootEntries
        mov     bx, size dir_entry
        mul     bx
        add     ax, deviceParameters.DP_BPB.BPB_bytesPerSector
        dec     ax
        xor     dx,dx
        div     deviceParameters.DP_BPB.BPB_bytesPerSector
        mov     sectorsInRootDirectory,ax
        mov     startSector, ax

; Calculate the number of FAT sectors
        mov     ax, deviceParameters.DP_BPB.BPB_SectorsPerFAT
        mul     deviceParameters.DP_BPB.BPB_numberOfFATs
; Add in the number of boot sectors
        add     ax, deviceParameters.DP_BPB.BPB_ReservedSectors
        add     startSector, ax

        return

SetStartSector endp

;-------------------------------------------------------------------------------

SetfBigFat proc near
;
; fBigFat = ( ( (Total Sectors - Start Sector) / Sectors Per Cluster) >= 4086 )
;
        mov     ax, deviceParameters.DP_BPB.BPB_TotalSectors


;************************* Fix for PTM PCDOS P51

       ;
       ;   Old code
       ;
       ;cmp     ax,20740
       ;jbe     SmallFAT
       ;mov     fBigFat, TRUE

       ;
       ;   New Code
       ;

       sub      ax,startSector                  ;Get sectors in data area
       xor      dx,dx
       xor      bx,bx
       mov      bl,deviceParameters.DP_BPB.BPB_sectorsPerCluster
       div      bx                              ;Get total clusters
       cmp      ax,BIG_FAT_THRESHOLD            ;Is clusters < 4086?
       jb       SmallFAT                        ;12 bit FAT if so
       mov      fBigFAT,TRUE                    ;16 bit FAT if >=4096

;************************* END of fix for PTM PCDOS P51

SmallFAT:

        return

SetfBigFat endp

;-------------------------------------------------------------------------------
;
;    Phase2Initialisation:
;       Use device parameters to build information that will be
;       required for each format
;
;    Algorithm:
;       Calculate first head/cylinder to format
;       Calculate number of tracks to format
;       Calculate the total bytes on the disk and save for later printout
;       First initialise the directory buffer
;
Phase2Initialisation proc near

; Calculate first track/head to format (round up - kludge)
        mov     ax, deviceParameters.DP_BPB.BPB_HiddenSectors
        mov     dx, deviceParameters.DP_BPB.BPB_HiddenSectors + 2
        add     ax, deviceParameters.DP_BPB.BPB_SectorsPerTrack
        adc     dx, 0
        dec     ax
        sbb     dx, 0
        div     deviceParameters.DP_BPB.BPB_SectorsPerTrack
        xor     dx,dx
        div     deviceParameters.DP_BPB.BPB_Heads
        mov     firstCylinder, ax
        mov     firstHead, dx

; Calculate the total number of tracks to be formatted (round down - kludge)
        mov     ax, deviceParameters.DP_BPB.BPB_TotalSectors
        xor     dx,dx
; if (TotalSectors == 0) then use BigTotalSectors
        or      ax,ax
        jnz     NotBigTotalSectors
        mov     ax, deviceParameters.DP_BPB.BPB_BigTotalSectors
        mov     dx, deviceParameters.DP_BPB.BPB_BigTotalSectors + 2

NotBigTotalSectors:
        div     deviceParameters.DP_BPB.BPB_SectorsPerTrack
        mov     tracksPerDisk, ax

; Initialise the directory buffer
; Clear out the Directory Sector before any information is inserted.
        mov     cx, deviceParameters.DP_BPB.BPB_BytesPerSector
        les     di, directorySector
        xor     ax,ax
        rep     stosb

        mov     ax, deviceParameters.DP_BPB.BPB_BytesPerSector
        xor     dx, dx
        mov     bx, size dir_entry
        div     bx
        mov     cx, ax

        les     bx, directorySector
; If Old_Dir = TRUE then put the first letter of each directory entry must be 0E5H
        xor     al, al
        cmp     old_Dir, TRUE
        jne     StickE5
        mov     al, 0e5H
StickE5:
        mov     es:[bx], al
        add     bx, size dir_entry
        loop    stickE5

;
; fDskSiz = (Total Sectors - Start Sector) * Bytes Per Sector
;
        mov     ax, deviceParameters.DP_BPB.BPB_TotalSectors
        sub     ax, startSector
        mul     deviceParameters.DP_BPB.BPB_BytesPerSector
        mov     word ptr fDskSiz, ax
        mov     word ptr fDskSiz+2, dx

        return

Phase2Initialisation endp

;-------------------------------------------------------------------------------
;
;   SetDeviceParameters:
;      Set the device parameters
;
;   Input:
;      drive
;      dx - pointer to device parameters
;
SetDeviceParameters proc near

        mov     ax, (IOCTL shl 8) or GENERIC_IOCTL
        mov     bl, drive
        inc     bl
        mov     cx, (RAWIO shl 8) or SET_DEVICE_PARAMETERS
        int     21H
        return

SetDeviceParameters endp

;-------------------------------------------------------------------------------
;
;   GetDeviceParameters:
;      Get the device parameters
;
;   Input:
;      drive
;      dx - pointer to device parameters
;
GetDeviceParameters proc near

        mov     ax, (IOCTL shl 8) or GENERIC_IOCTL
        mov     bl, drive
        inc     bl
        mov     cx, (RAWIO shl 8) or GET_DEVICE_PARAMETERS
        int     21H
        return

GetDeviceParameters endp

;-------------------------------------------------------------------------------
;
;    DiskFormat:
;       Format the tracks on the disk
;       Since we do our SetDeviceParameters here, we also need to
;       detect the legality of /N /T if present and abort with errors
;       if not.
;       This routine stops as soon as it encounters a bad track
;       Then BadSector is called to report the bad track, and it continues
;       the format
;
;    Algorithm:
;       Initialise in memory FAT
;       current track = first
;       while not done
;          if format track fails
;             DiskFormatErrors = true
;             return
;          next track

DiskFormat proc near


;
; Initialise fatSpace
;
        push    es
        les     di, fatSpace
        mov     ax, deviceParameters.DP_BPB.BPB_SectorsPerFAT
        mul     deviceParameters.DP_BPB.BPB_bytesPerSector
        mov     cx, ax
        xor     ax,ax
        rep     stosb

        mov     di, word ptr fatSpace
        mov     al, deviceParameters.DP_BPB.BPB_MediaDescriptor
        mov     ah, 0ffH
        stosw
        mov     ax, 00ffH
        test    fBigFat, TRUE
        jz      NotBig
        mov     ax, 0ffffH
NotBig: stosw
        pop     es

; don't bother to do the formatting if /c was given
        test    switchmap, SWITCH_C
        jz      Keep_Going
        jmp     FormatDone              ;FormatDone is to far away

Keep_Going:
foofoo  =       INSTALL_FAKE_BPB or TRACKLAYOUT_IS_GOOD
        mov     deviceParameters.DP_SpecialFunctions, foofoo
        lea     dx, deviceParameters

        call    SetDeviceParameters

        test    switchmap, SWITCH_H     ;Suppress prompt?
        jnz     No_Prompt

        call    DSKPRM                  ; prompt user for disk

No_Prompt:
        test    switchmap,switch_8      ; DCL 5/12/86 avoid Naples AH=18h
        jnz     stdBpB                  ; lackof support for 8 sectors/track

       ; DCL 5/12/86
       ; Always do the STATUS_FOR_FORMAT test, as we don't know if the machine
       ; has this support.  For 3.2 /N: & /T: were not documented & therefore
       ; not fully supported thru the ROM of Aquarius & Naples & Royal Palm

       ;test    SwitchMap, SWITCH_N or SWITCH_T         ; IF ( /N or /T ) ;; DCL 5/12/86
       ;jz      StdBPB
                                                        ;   THEN check if
                                                        ;     supported
        mov     formatPacket.FP_SpecialFunctions, STATUS_FOR_FORMAT
        mov     ax, (IOCTL shl 8) or GENERIC_IOCTL
        mov     bl, drive
        inc     bl
        mov     cx, (RAWIO shl 8) or FORMAT_TRACK
        lea     dx, formatPacket
        int     21H
                                                ; switch ( FormatStatusCall)

       ;cmp     FormatPacket.FP_SpecialFunctions, Format_No_ROM_Support
       ;jb      NTSupported                     ; 0 returned from IO.SYS
       ;ja      IllegalComb                     ; 2 returned - ROM Support
                                                ;   Illegal Combination!
        cmp     FormatPacket.FP_SpecialFunctions,0
        je      NTSupported
        lea     dx, msgInvalidParameter
        cmp     FormatPacket.FP_SpecialFunctions,2
        je      Abort_Prog
        lea     dx, msgNotReady
        cmp     FormatPacket.FP_SpecialFunctions,3
        je      Abort_Prog

                                                ; DCL No ROM support is okay
                                                ; except for /N: & /T:
        test    SwitchMap, SWITCH_N or SWITCH_T ; DCL 5/12/86
        jz      StdBPB
        lea     dx, msgParametersNotSupported   ;   CASE: NOT SUPPORTED

Abort_Prog:
        Call    PrintString
        jmp     Fexit
;
; We have the support to carry out the FORMAT
;
NTSupported:
StdBPB:
       ;call    DSKPRM                  ; prompt user for disk ;; DCL 5/12/86
        mov     FormatPacket.FP_SpecialFunctions, 0
        mov     ax, firstHead
        mov     formatPacket.FP_Head, ax
        mov     ax, firstCylinder
        mov     formatPacket.FP_Cylinder, ax
        mov     cx, tracksPerDisk
        dec     cx
        mov     tracksLeft, cx
FormatLoop:
        call    DisplayCurrentTrack
        call    FormatTrack
        jc      FailDiskFormat
        call    NextTrack
        jnc     FormatLoop

; All done
FormatDone:
        mov     formatError, 0
        clc
        return

FailDiskFormat:
        call    CheckError
        retc
        call    LastChanceToSaveIt
        jc      FormatReallyFailed

        call    SetStartSector
        call    SetfBigFat
        push    ax
        call    Phase2Initialisation
        clc
        pop     ax
;       jc      FormatReallyFailed
        jmp     DiskFormat

FormatReallyFailed:
        mov     formatError, 1
        clc
        return

DiskFormat endp


;-------------------------------------------------------------------------------
;
;    BadSector:
;       Reports the bad sectors.
;       Reports the track where DiskFormat stopped.
;       From then on it formats until it reaches a bad track, or end,
;       and reports that.
;
;    Output:
;       Carry: set --> fatal error
;       if Carry not set
;          ax - The number of consecutive bad sectors encountered
;               ax == 0 --> no more bad sectors
;          bx - The logical sector number of the first bad sector
;
;    Algorithm:
;       if DiskFormatErrors
;          DiskFormatErrors = false
;          return current track
;       else
;          next track
;          while not done
;             if format track fails
;                return current track
;             next track
;          return 0

BadSector proc near


; don't bother to do the formatting if /c was given
        test    switchmap, SWITCH_C
        jnz     NoMoreTracks

        test    formatError, 0ffH
        jz      ContinueFormat
        mov     formatError, 0
        jmp     ReportBadTrack

ContinueFormat:
        call    NextTrack
        jc      NoMoreTracks

        call    DisplayCurrentTrack
        call    FormatTrack
        jnc     ContinueFormat
        call    CheckError
        retc

ReportBadTrack:
        call    CurrentLogicalSector
        mov     ax, deviceParameters.DP_BPB.BPB_SectorsPerTrack
        clc
        return

NoMoreTracks:
        lea     dx, msgFormatComplete
        call    PrintString
        mov     ax, 0
        clc
        return

BadSector endp


;-------------------------------------------------------------------------------
;    FormatTrack:
;       format the current track
;
;    Input:
;       formatPacket
;
;    Output:
;       Carry: set if format failed
;
FormatTrack proc near

        mov     ax, (IOCTL shl 8) or GENERIC_IOCTL
        mov     bl, drive
        inc     bl
        mov     cx, (RAWIO shl 8) or FORMAT_TRACK
        lea     dx, formatPacket
        int     21H
        retnc

        mov     ah, 59H
        xor     bx,bx
        int     21H
        stc
        return

FormatTrack endp

;-------------------------------------------------------------------------------

data segment

ptr_msgCurrentTrack     dw      offset msgCurrentTrack
currentHead             dw      0
currentCylinder         dw      0

data ends

DisplayCurrentTrack proc near

        mov     ax, formatPacket.FP_Cylinder
        mov     currentCylinder, ax
        mov     ax, formatPacket.FP_Head
        mov     currentHead, ax
        lea     dx, ptr_msgCurrentTrack
        call    std_printf
        return

DisplayCurrentTrack endp

;-------------------------------------------------------------------------------
;    NextTrack:
;       Advance to the next track for formatting
;
;    Input:
;       formatPacket.FP_Head
;       formatPacket.FP_Cylinder
;       deviceParameters.DP_BPB.BPB_Heads
;       tracksLeft
;
;    Output:
;       Carry: set --> all done
;       formatPacket.FP_Head
;       formatPacket.FP_cyliner
;       tracksLeft
;
;    Algorithm:
;       if tracksLeft
;          tracksLeft--
;          if ++head > highest head
;             head = 0
;             cylinder++
;
NextTrack proc near

        cmp     tracksLeft, 0
        je      ThatsAllFolks
        dec     tracksLeft

; Bump the head
        inc     formatPacket.FP_Head
        mov     ax, formatPacket.FP_Head
        cmp     ax, deviceParameters.DP_BPB.BPB_Heads
        jb      ExitNextTrack

; We've done all heads on this cylinder so move on to next
; (start on head 0 of the next cylinder)
        mov     formatPacket.FP_Head, 0
        inc     formatPacket.FP_Cylinder

ExitNextTrack:
        clc
        return

ThatsAllFolks:
; Oh wow, we're all done
        stc
        return

NextTrack endp

;-------------------------------------------------------------------------------
;    CheckError:
;       Input:
;          ax - extended error code
;       Ouput:
;          carry set if error is fatal
;          Message printed if Not Ready or Write Protect
;
CheckError proc near
        cmp     ax, error_write_protect
        je      WriteProtectError
        cmp     ax, error_not_ready
        je      NotReadyError
        cmp     currentCylinder, 0
        jne     CheckRealErrors
        cmp     currentHead, 0
        je      BadTrackZero

CheckRealErrors:
        cmp     ax, error_CRC
        je      JustABadTrack
        cmp     ax, error_sector_not_found
        je      JustABadTrack
        cmp     ax, error_write_fault
        je      JustABadTrack
        cmp     ax, error_read_fault
        je      JustABadTrack
        cmp     ax, error_gen_failure
        je      JustABadTrack

        stc
        ret

JustABadTrack:
        clc
        ret

WriteProtectError:
        lea     dx, msgWriteProtected
        call    PrintString
        stc
        ret

NotReadyError:
        lea     dx, msgNotReady
        call    PrintString
        stc
        ret

BadTrackZero:
        lea     dx, msgDiskUnusable
        call    PrintString
        stc
        ret

CheckError endp

;-------------------------------------------------------------------------------
;    WriteFileSystem:
;       Write the boot sector and FATs out to disk
;       Clear the directory sectors to zero
;
WriteFileSystem proc near


        call    WriteBootSector
        retc

; Write out each of the FATs
        xor     cx, cx
        mov     cl, deviceParameters.DP_BPB.BPB_numberOfFATs
        mov     dx, deviceParameters.DP_BPB.BPB_ReservedSectors
WriteFATloop:
        push    cx
        push    dx
        mov     al, drive
        mov     cx, deviceParameters.DP_BPB.BPB_SectorsPerFAT
        push    ds
        lds     bx, fatSpace
        int     26H
        pop     ax
        pop     ds
        jc      CanNotWriteFAT

        pop     dx
        add     dx, deviceParameters.DP_BPB.BPB_SectorsPerFAT
        pop     cx
        loop    WriteFATLoop

; Clear the directory

; Now write the initialised directory sectors out to disk
        mov     ax, deviceParameters.DP_BPB.BPB_SectorsPerFAT
        xor     dx,dx
        mul     deviceParameters.DP_BPB.BPB_NumberOfFATs
        mov     dx, deviceParameters.DP_BPB.BPB_ReservedSectors
        add     dx, ax
        mov     cx, sectorsInRootDirectory
WriteDIRloop:
        push    cx
        push    dx
        mov     al, drive
        mov     cx, 1
        push    ds
        lds     bx, directorySector
        int     26H
        pop     ax
        pop     ds
        jc      CanNotWriteDirectory

        pop     dx
        add     dx, 1
        pop     cx
        loop    WriteDIRLoop


; Ok, we can tell the device driver that we are finished formatting
        mov     savedDeviceParameters.DP_TrackTableEntries, 0
        mov     savedDeviceParameters.DP_SpecialFunctions, TRACKLAYOUT_IS_GOOD
        lea     dx, savedDeviceParameters
        call    SetDeviceParameters

        MOV     AH,DISK_RESET                   ; Flush any directories in
        INT     21H                             ; buffers

        return

CanNotWriteFAT:
        lea     dx, msgFATwriteError
        jmp     PrintErrorAbort

CanNotWriteDirectory:
        lea     dx, msgDirectorywriteError
        jmp     PrintErrorAbort

WriteFileSystem endp

;-------------------------------------------------------------------------------
;    Done:
;       format is done... so clean up the disk!
;
Done proc near


        call    OemDone
        return

Done endp

;-------------------------------------------------------------------------------
;    CurrentLogicalSector:
;       Get the current logical sector number
;
;    Input:
;       current track = tracksPerDisk - tracksLeft
;       SectorsPerTrack
;
;    Output:
;       BX = logical sector number of the first sector in the track we
;            just tried to format
;
CurrentLogicalSector proc near
        mov     ax, tracksPerDisk
        sub     ax, tracksLeft
        dec     ax
        mul     deviceParameters.DP_BPB.BPB_SectorsPerTrack
        mov     bx, ax
        return

CurrentLogicalSector endp

;-------------------------------------------------------------------------------
;    PrintErrorAbort:
;       Print an error message and abort
;
;    Input:
;       dx - Pointer to error message string
;
PrintErrorAbort proc near

        push    dx
        call    crlf
        pop     dx
        call    PrintString

        jmp     fexit

PrintErrorAbort endp

code    ends

        END     START
