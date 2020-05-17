;       SCCSID = @(#)oemfor.asm 1.28 85/10/15
        name    OemFormatRoutines

debug   equ     0
;-------------------------------------------------------------------------------
; Public for debugging only

        public  CheckSwitches
        public  LastChanceToSaveIt
        public  WriteBootSector
        public  OemDone
        public  WriteBogusDos
        public  ConvertToOldDirectoryFormat
        public  SetPartitionTable
        public  ReadSector
        public  WriteSector
        public  SectorIO
        public  GetVolumeId
        public  CheckVolumeId

        public  customBPBs
        public  BootSectorIsFine
        public  NotSlashB
        public  NotSingleSided
        public  EndSwitchCheck
        public  WeCanNotIgnoreThisError
        public  CanNotWriteBoot
        public  HardDisk?
        public  BogusDos
        public  sys_mess_loop
        public  end_sys_loop
        public  DirectoryRead
        public  wrtdir
        public  DirectoryWritten
        public  PartitionTableRead
        public  partitionscan
        public  dochange
        public  partitionset
        public  BadPartitionTable
        public  FCBforVolumeIdSearch
        public  CopyVolumeId
        public  CompareVolumeIds
        public  VolumeToUpper
        public  NextLetter
        public  BadVolumeId

        public  switchlist
        public  boot2
        public  boot
        public  scratchBuffer
        public  bootDrive
        public  biosFilename
        public  dosFilename
        public  oldDrive
        public  oldVolumeId

        public  bootSignature
        public  ptr_msgWhatIsVolumeId?

        public  trackReadWritePacket

        public  BPB81
        public  BPB82
        public  BPB91
        public  BPB92

;-------------------------------------------------------------------------------

data    segment public 'DATA'
data    ends

code    segment public 'CODE'
        assume  cs:code,ds:data

        Public  AccessDisk
        public  CheckSwitches
        public  LastChanceToSaveIt
        public  WriteBootSector
        public  OemDone
        public  BiosFile
        public  DosFile

data segment
        extrn   AddToSystemSize:near
        extrn   currentCylinder:word
        extrn   currentHead:word
        extrn   deviceParameters:byte
        extrn   drive:byte
        extrn   driveLetter:byte
        extrn   fBigFAT:byte
        extrn   inbuff:byte
        extrn   switchmap:word
        extrn   Old_Dir:byte
        extrn   fLastChance:byte

        extrn   msgBadVolumeId:byte
        extrn   msgBadPartitionTable:byte
        extrn   msgBootWriteError:byte
        extrn   msgDirectoryReadError:byte
        extrn   msgDirectoryWriteError:byte
        extrn   msgInvalidParameter:byte
        extrn   msgIncompatibleParameters:byte
        extrn   msgIncompatibleParametersForHardDisk:byte
        extrn   msgParametersNotSupportedByDrive:byte
        extrn   msgPartitionTableReadError:byte
        extrn   msgPartitionTableWriteError:byte
        extrn   msgWhatIsVolumeId?:byte
        extrn   NumSectors:word, TrackCnt:word

IF DEBUG
        extrn   msgFormatBroken:byte
ENDIF

data ends

        extrn   PrintString:near
        extrn   std_printf:near
        extrn   crlf:near
        extrn   user_string:near

;-------------------------------------------------------------------------------
; Support Routines

Switches        macro   s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15,s16
;;
switchCount = 0
switchmask = 1
 irp x,<&s1,&s2,&s3,&s4,&s5,&s6,&s7,&s8,&s9,&s10,&s11,&s12,&s13,&s14,&s15,&s16>
    ifnb <x>
       switchCount = switchCount + 1
       SWITCH_&&x = switchmask
       switchmask = 2 * switchmask
    endif
 endm
public switchlist
switchlist db switchCount
 db "&s16&&s15&&s14&&s13&&s12&&s11&&s10&&s9&&s8&&s7&&s6&&s5&&s4&&s3&&s2&&s1&"
 endm

;-------------------------------------------------------------------------------
; Constants

; Standard dos macros
        INCLUDE DOSMAC.INC

; This defines all the int 21H system calls
        INCLUDE SYSCALL.INC

; Limits

; following were removed into FILESIZE.INC by kwc on 10/04/86

;BIOS_SIZE               equ     5400h           ; Used to set size of
;DOS_SIZE                equ     7600h           ; Bogus DOS for /B switch

        include filesize.inc

; end of FILESIZE.INC change by kwc on 10/04/86

LOGBOOTSECT             equ     1
;MAX_SECTORS_IN_TRACK   equ     20  Already defined in ioctl.INC
Set_Drv_Owner           equ     0Fh             ; IOCTL subfunction

;-------------------------------------------------------------------------------
; These are the data structures which we will need

        INCLUDE DIRENT.INC
        include ioctl.INC

;-------------------------------------------------------------------------------
; And this is the actual data
data segment

BiosFile db "x:\IO.SYS", 0
DosFile db "x:\MSDOS.SYS", 0

trackReadWritePacket    a_TrackReadWritePacket  <>

        Switches        S,V,H,C,T,N,1,4,8,B

; BIOS parameter blocks for various media
customBPBs label byte
BPB92   a_BPB   <512, 2, 1, 2, 112, 2*9*40, 0fdH, 2, 9, 2, 0, 0, 0, 0>
BPB91   a_BPB   <512, 1, 1, 2,  64, 1*9*40, 0fcH, 2, 9, 1, 0, 0, 0, 0>
BPB82   a_BPB   <512, 2, 1, 2, 112, 2*8*40, 0ffH, 1, 8, 2, 0, 0, 0, 0>
BPB81   a_BPB   <512, 1, 1, 2,  64, 1*8*40, 0feH, 1, 8, 1, 0, 0, 0, 0>
BPB720  a_BPB   <512, 2, 1, 2, 112, 2*9*80, 0F9h, 3, 9, 2, 0, 0, 0, 0>

Custom_Media    equ     0F0H    ; Media byte for custom format
Dual_8_Media    equ     0FFh    ; Dual sided 8 sectored
Single_8_Media  equ     0FEh    ; Single sided 8 sectored
Dual_9_Media    equ     0FDh    ; Dual sided 9 sectored
Single_9_Media  equ     0FCh    ; Single sided 9 sectored
Dual_15_Media   equ     0F9h    ; Dual sided 15 sectored
Fixed_Disk      equ     0F8h    ; Fixed Disk


boot2   db      0,0,0, "Boot 1.x"
        db      512 - 11 dup(?)

REORG2  LABEL BYTE
        ORG BOOT2
        INCLUDE ..\BOOT\BOOT11.INC
        ORG REORG2

boot            db      0,0,0,"Boot 2.x"
bootBPB         a_BPB   <>
                db      512 - (size a_BPB + 11 + 3) dup(0)

bootDrive       db      0
bootSignature   dw      0

REORG   LABEL BYTE
        ORG BOOT
        INCLUDE ..\BOOT\BOOT.INC
        ORG REORG

scratchBuffer   db      512 dup(?)

ptr_msgWhatIsVolumeId?  dw      offset msgWhatIsVolumeId?
                        dw      offset driveLetter

data ends
;-------------------------------------------------------------------------------
; AccessDisk:
;    Called whenever a different disk is about to be accessed
;
;    Input:
;       al - drive letter (0=A, 1=B, ...)
;
;    Output:
;       none
AccessDisk proc near

        push    ax                      ; save drive letter
        mov     bl,al                   ; Set up GENERIC IOCTL REQUEST preamble
        inc     bl
        mov     ax,(IOCTL SHL 8) + Set_Drv_Owner ; IOCTL function
        int     21h
        pop     ax
        return

AccessDisk endp

;-------------------------------------------------------------------------------
;    CheckSwitches:
;       Check switches against device parameters
;       Use switches to modify device parameters
;
;    Input:
;       deviceParameters
;
;    Output:
;       deviceParameters may be modified
;       Carry set if error
;
;    Algorithm:
;       if hard disk
;          Check Boot Sector for valid Signature
;          IF (valid)
;               Check the volume id
;          Make sure no switches other than /V, /S are specifed
;       else if 96 tpi without /4 or not 5.25" disk
;          Make sure no switches other than /V, /S are specifed
;       else
;          if 48 tpi drive and switch /4
;             turn off switch /4
;          if single sided drive and switch /1 but not switch /8
;             turn off switch /1
;          if any of interesting switches are on (/C, /O, /V, /S are not)
;             set number of cylinders to 40
;             choose new BPB depending on switches /1 and /8
;
CheckSwitches proc near

IF      DEBUG
; See if the boot sector was initialised correctly
        cmp     bootSignature, 0aa55H
        je      BootSectorIsFine
        lea     dx, msgFormatBroken
        jmp     short SwitchError
ENDIF   ; DEBUG

BootSectorIsFine:

; Disallow /C
        lea     dx, msgInvalidParameter
        test    switchmap, SWITCH_C
        jz      CheckExcl

SwitchError:
        call    PrintString
        stc
        ret

; Only certain permutations of the switches /N /T /V /B /S and /V are legal.
;    For specific cases see the file Switchmap.legal.

CheckExcl:
        lea     dx, msgIncompatibleParameters   ; Error message


        test    SwitchMap, SWITCH_B             ; IF ( SWITCH_B)
        jz      SVpermitted

        test    SwitchMap, SWITCH_S or SWITCH_V ;   THEN exclude SWITCH_S and
        jnz     SwitchError                     ;        SWITCH_V

SVpermitted:
        test    SwitchMap, SWITCH_8             ; IF ( SWITCH_8 )
        jz      Check_N
                                                ;   THEN
        test    SwitchMap, SWITCH_N or SWITCH_T ;     exclude SWITCH_N and
        jnz     SwitchError


        test    SwitchMap, SWITCH_V             ;      SWITCH_V if unaccompanied
        jz      Check_N                         ;        by SWITCH_S

        test    SwitchMap, SWITCH_S
        jz      SwitchError                     ; ENDIF ( SWITCH_8 )


Check_N:                                        ; IF ( SWITCH_N or SWITCH_T )
        test    SwitchMap, SWITCH_N or SWITCH_T
        jz      ExclChkDone

        test    SwitchMap, SWITCH_1 or SWITCH_4 ;   THEN exclude SWITCH_1 and
        jnz     SwitchError                     ;        SWITCH_4

ExclChkDone:
; Patch the boot sector so that the boot strap loader knows what disk to
; boot from
        mov     bootDrive, 00H

        cmp     deviceParameters.DP_DeviceType, DEV_HARDDISK
        jne     CheckFor5InchDrives

; Formatting a hard disk so we must repatch the boot sector
        mov     bootDrive, 80H
        test    switchmap, not (SWITCH_S or SWITCH_V)
        jz      SwitchesOkForHardDisk
        lea     dx, msgIncompatibleParametersForHardDisk
        call    PrintString
        stc
        ret

; Before checking the Volume Id we need to verify that a valid one exists
; We assume that unless a valid boot sector exists on the target disk, no
; valid Volume Id can exist.

SwitchesOkForHardDisk:
        SaveReg <ax,bx,cx,dx,ds>
        mov     al,drive
        mov     cx,LogBootSect
        xor     dx,dx
        lea     bx,scratchBuffer        ; ScratchBuffer := Absolute_Disk_Read(
        INT     25h                     ;                    Logical_sec_1 )
        pop     ax                      ;       Stupid Int 25! leaves flags
                                        ;       on the stack. We throw them away

        jnc     CheckSignature
        stc
        RestoreReg <ds,dx,cx,bx,ax>
        ret

CheckSignature:                 ; IF (BootSector.BootSignature != aa55)

        mov     ax, Word Ptr (ScratchBuffer + (BootSignature - boot))
        cmp     ax, 0aa55h
        RestoreReg <ds,dx,cx,bx,ax>
        clc                             ;        not an error, just not vol.
        retnz                           ;   THEN RETURN

        call    CheckVolumeId           ;   ELSE CheckVolumeID
        return

OnlyVSpermitted:
        test    switchmap, not (SWITCH_S or SWITCH_V)
        retz
        lea     dx, msgIncompatibleParameters

Print_And_Return:
        call    PrintString
        stc
        return


CheckFor5InchDrives:

      ;If drive type is anything other than 48 or 96, then only /V/S/H/N/T allowed
        cmp     byte ptr deviceParameters.DP_DeviceType,DEV_5INCH96TPI
        je      Got96

        cmp     byte ptr deviceParameters.DP_DeviceType,DEV_5INCH
        je      Got48

        test    switchmap, not (SWITCH_V or SWITCH_S or SWITCH_N or SWITCH_T or SWITCH_H)
        jz      Goto_Got_BPB
        lea     dx,msgParametersNotSupportedByDrive
        jmp     short Print_And_Return

   ; We have a 96tpi floppy drive
   ; /4 allows just about all switches however, /1 requires /4
Got96:
        test    switchmap, SWITCH_4
        jnz     CheckForInterestingSwitches     ;If /4 check /N/T/V/S

        test    switchmap, SWITCH_1             ;If /1 and /4 check others
        jz      Got48

      ;If only /1 with no /4, see if /N/T
        test    SwitchMap,(Switch_N or Switch_T)
        jnz     CheckForInterestingSwitches

        lea     dx, msgIncompatibleParameters   ;If no /4 but /1 die
        jmp     short Print_And_Return

Got48:
  ;Ignore /4 for non-96tpi 5 1/4" drives
        and     switchmap, not SWITCH_4

  ;Ignore /1 if drive has only one head and not /8
        cmp     word ptr deviceParameters.DP_BPB.BPB_Heads, 1
        ja      CheckForInterestingSwitches
        test    switchmap, SWITCH_8
        jz      CheckForInterestingSwitches
        and     switchmap, not SWITCH_1

  ;Are any interesting switches set?
CheckForInterestingSwitches:
        test    switchmap, not (SWITCH_V or SWITCH_S or SWITCH_H)  ;Anything but /V/S/H?
        jz      Goto_EndSwitchCheck                    ;No, everything ok

      ;At this point there are switches other than /v/s/h
        test    SwitchMap,(SWITCH_N or SWITCH_T)
        jz      Use_48tpi   ;Not /n/t, so must be /b/1/8/4

      ;We've got /N/T, see if there are others
        test    SwitchMap, not (SWITCH_N or SWITCH_T or SWITCH_V or SWITCH_S or SWITCH_H)
        jz      NT_Compatible   ;Nope, all is well

      ;If 96tpi drive and /1 exists with /N/T, then okay, otherwise error
        cmp     byte ptr deviceParameters.DP_DeviceType,DEV_5INCH96TPI
        jne     Bad_NT_Combo

        test    SwitchMap, not (SWITCH_1 or SWITCH_N or SWITCH_T or SWITCH_V or SWITCH_S or SWITCH_H)
        jz      Goto_Got_BPB

Bad_NT_Combo:
        lea     dx, msgIncompatibleParameters
        jmp     Print_And_Return

Goto_Got_BPB:
        jmp     Got_BPB_Ok        ;Sleazy, but je won't reach it

Goto_EndSwitchCheck:
        jmp     EndSwitchCheck
  ;There is a problem with /N/T in that IO.SYS will default to a BPB with the
  ;media byte set to F0 (other) if the /N/T combo is used for the format. This
  ;will cause problems if we are creating a media that has an assigned media
  ;byte, i.e. 160,180,320,360, or 720k media using /N/T. To avoid this problem,
  ;if we detect a /N/T combo that would correspond to one of these medias, then
  ; we will set things up using the /4/1/8 switches instead of the /N/T
  ; MT - 7/17/86 PTR 33D0110

  ; Combo's that we look for - 96tpi drive @ /T:40, /N:9
  ;                            96tpi drive @ /T:40, /N:8
  ;
  ; Look for this combo after we set everything up with the /T/N routine
  ;                            1.44 drive  @ /T:80, /N:9

NT_Compatible:
        cmp     byte ptr deviceParameters.DP_DeviceType,DEV_5INCH96TPI
        jne     Goto_Got_BPB

        cmp     TrackCnt,40           ;Look for 40 tracks
        jne     Got_BPB_Ok

        cmp     NumSectors,9          ;9 sectors?
        je      Found_48tpi_Type

        cmp     NumSectors,8          ;8 sectors?
        jne     Goto_Got_BPB          ;Nope, different type, let it go thru

        or      SwitchMap,SWITCH_8    ;Yes, turn on /8 switch

Found_48tpi_Type:
        and     SwitchMap,not (SWITCH_N or SWITCH_T) ;Turn off /T/N

;******End PTR fix

; if we have a 96 tpi drive then we will be using it in 48 tpi mode
Use_48tpi:
        cmp     byte ptr deviceParameters.DP_DeviceType, DEV_5INCH96TPI
        jne     Not96tpi

        mov     byte ptr deviceParameters.DP_MediaType, 1
        mov     word ptr deviceParameters.DP_Cylinders, 40
Not96tpi:

; Since we know we are formatting in 48 tpi mode turn on /4 switch
; (We use this info in LastChanceToSaveIt)
        or      switchmap, SWITCH_4

; At this point we know that we will require a special BPB
; It will be one of:
;    0) 9 track 2 sides - if no switches
;    1) 9 track 1 side  - if only /1 specified
;    2) 8 track 2 sides - if only /8 specified
;    3) 8 track 1 side  - if /8 and /1 specified
;
Get_BPBs:
; ax is used to keep track of which of the above BPB's we want
        xor     ax, ax

; /B implies /8
        test    switchmap, SWITCH_B
        jz      NotSlashB
        or      switchmap, SWITCH_8
NotSlashB:

        test    switchmap, SWITCH_1
        jz      NotSingleSided
        add     ax, 1
NotSingleSided:

        test    switchmap, SWITCH_8
        jz      Not8SectorsPerTrack
        add     ax, 2
; /8 implies Old_Dir = TRUE
        mov     Old_Dir,TRUE
Not8SectorsPerTrack:

; Ok now we know which BPB to use so lets move it to the device parameters

        mov     bx, size a_BPB
        mul     bx
        lea     si, CustomBPBs
        add     si, ax
        lea     di, deviceParameters.DP_BPB
        mov     cx, size a_BPB
        push    ds
        pop     es
        repnz   movsb

;*****************************************************************
;*  /N/T DCR stuff.  Possible flaw exists if we are dealing with a
;*  HardDisk. If they support the  "custom format" features for
;*  Harddisks too, then CheckForInterestingSwitches should
;*  consider /n/t UNinteresting, and instead of returning
;*  after setting up the custom BPB we fall through and do our
;*  Harddisk Check.
Got_BPB_OK:
        test    switchmap,SWITCH_N+SWITCH_T
        jnz     Setup_Stuff
        jmp     EndSwitchCheck
Setup_Stuff:
; Set up NumSectors and SectorsPerTrack entries correctly
        test    switchmap,SWITCH_N
        jz      No_Custom_Seclim
        mov     ax,word ptr NumSectors
        mov     DeviceParameters.DP_BPB.BPB_SectorsPerTrack,ax
        jmp     short Handle_Cyln
No_Custom_Seclim:
        mov     ax,deviceParameters.DP_BPB.BPB_SectorsPerTrack
        mov     NumSectors,ax

Handle_Cyln:
        test    switchmap,SWITCH_T
        jz      No_Custom_Cyln
; Set up TrackCnt and Cylinders entries correctly
        mov     ax,TrackCnt
        mov     DeviceParameters.DP_Cylinders,ax
        jmp     short Check_720
No_Custom_Cyln:
        mov     ax,DeviceParameters.DP_Cylinders
        mov     TrackCnt,ax

;****PTM P868  - Always making 3 1/2 media byte 0F0h. If 720, then set to
;                0F9h and use the DOS 3.20 BPB. Should check all drives
;                at this point (Make sure not 5 inch just for future
;                protection)
;                We will use the known BPB info for 720 3 1/2 diskettes for
;                this special case. All other new diskette media will use the
;                calculations that follow Calc_Total for BPB info.
; Fix MT  11/12/86

Check_720:

        cmp     byte ptr deviceParameters.DP_DeviceType,DEV_5INCH96TPI
        je      Calc_Total

        cmp     byte ptr deviceParameters.DP_DeviceType,DEV_5INCH
        je      Calc_Total

        cmp     TrackCnt,80
        jne     Calc_Total

        cmp     NumSectors,9
        jne     Calc_Total

; At this point we know we have a 3 1/2 720kb diskette to format. Use the
; built in BPB rather than the one handed to us by DOS, because the DOS one
; will be based on the default for that drive, and it can be different from
; what we used in DOS 3.20 for the 720's. Short sighted on our part to use
; 0F9h as the media byte, should have use 0F0h (OTHER) and then we wouldn't
; have this problem.

        SaveReg <ds,es,si,di,cx>


        mov     cx,seg data    ;Setup seg regs, just in case they ain't!
        mov     ds,cx
        mov     es,cx

        mov     si,offset BPB720        ;Copy the BPB!
        mov     di,offset deviceParameters.DP_BPB
        mov     cx,size a_BPB
        rep     movsb
        RestoreReg  <cx,di,si,es,ds>
        jmp     EndSwitchCheck

;End PTM P868 fix ****************************************

Calc_Total:
        mov     ax,NumSectors
        mov     bx,DeviceParameters.DP_BPB.BPB_Heads
        mul     bl                      ; AX = # of sectors * # of heads
        mul     TrackCnt                ; DX:AX = Total Sectors
        or      dx,dx
        jnz     Got_BigTotalSectors
        mov     DeviceParameters.DP_BPB.BPB_TotalSectors,ax
        jmp     short Set_BPB
Got_BigTotalSectors:
        mov     DeviceParameters.DP_BPB.BPB_BigTotalSectors,ax
        mov     DeviceParameters.DP_BPB.BPB_BigTotalSectors+2,dx
        push    dx                      ; preserve dx for further use
        xor     dx,dx
        mov     DeviceParameters.DP_BPB.BPB_TotalSectors,dx
        pop     dx

Set_BPB:
; We calculate the number of sectors required in a FAT. This is done as:
; # of FAT Sectors = TotalSectors / SectorsPerCluster * # of bytes in FAT to
; represent one cluster (i.e. 3/2) / BytesPerSector (i.e. 512)
        xor     bx,bx
        mov     bl,DeviceParameters.DP_BPB.BPB_SectorsPerCluster
        div     bx                      ; DX:AX contains # of clusters
; now multiply by 3/2
        mov     bx,3
        mul     bx
        mov     bx,2
        div     bx
        xor     dx,dx                   ; throw away modulo
; now divide by 512
        mov     bx,512
        div     bx
; dx:ax contains number of FAT sectors necessary
        inc     ax                      ; Go one higher
        mov     DeviceParameters.DP_BPB.BPB_SectorsPerFAT,ax
        mov     DeviceParameters.DP_MediaType,0
        mov     DeviceParameters.DP_BPB.BPB_MediaDescriptor,Custom_Media


EndSwitchCheck:
        clc
        return

CheckSwitches endp

;-------------------------------------------------------------------------------
;    LastChanceToSaveIt:
;       This routine is called when an error is detected in DiskFormat.
;       If it returns with carry not set then DiskFormat is restarted.
;       It gives the oem one last chance to try formatting differently.
;       fLastChance gets set Then to prevent multiple prompts from being
;       issued for the same diskette.
;
;       Algorithm:
;               IF (error_loc == Track_0_Head_1) &
;                         ( Device_type < 96TPI )
;                  THEN
;                       fLastChance  := TRUE
;                       try formatting 48TPI_Single_Sided
;                  ELSE return ERROR
;
LastChanceToSaveIt proc near

        cmp     currentCylinder, 0
        jne     WeCanNotIgnoreThisError
        cmp     currentHead, 1
        jne     WeCanNotIgnoreThisError

        cmp     deviceParameters.DP_DeviceType, DEV_5INCH
        ja      WeCanNotIgnoreThisError

        mov     fLastChance, TRUE

        or      switchmap, SWITCH_1
        call    CheckSwitches
        clc
        ret

WeCanNotIgnoreThisError:
        stc
        ret

LastChanceToSaveIt endp

;-------------------------------------------------------------------------------

WriteBootSector proc near

; Copy BPB to boot sector
        lea     si, deviceParameters.DP_BPB
        lea     di, bootBPB
        mov     cx, size a_BPB
        push    ds
        pop     es
        repnz   movsb

; Write out the boot sector
        mov     al, drive
        mov     cx, 1
        xor     dx, dx
        lea     bx, boot
        int     26H
        pop     ax
        jc      CanNotWriteBoot
        return

CanNotWriteBoot:
        lea     dx, msgBootWriteError
        call    PrintString
        stc
        ret

WriteBootSector endp

;-------------------------------------------------------------------------------
; OemDone:
;
OemDone proc near

; if /b write out a fake dos & bios
        test    switchmap, SWITCH_B
        jz      Switch8?
        call    WriteBogusDos
        retc

Switch8?:
        test    switchmap, SWITCH_8
        jz      HardDisk?
        call    ConvertToOldDirectoryFormat
        retc

HardDisk?:
        cmp     deviceParameters.DP_DeviceType, DEV_HARDDISK
        clc
        retnz
        call    SetPartitionTable

        return

OemDone endp

;------------------------------------------------------------------------------

data segment

biosFilename db      "x:\io.sys",0
dosFilename  db      "x:\msdos.sys",0

data ends

; simple code to stuff bogus dos in old-style diskette.


BogusDos:
        push    cs
        pop     ds
        mov     al,20h
        out     20h,al                  ; turn on the timer so the disk motor
        mov     si,mesofs               ; shuts off
sys_mess_loop:
        lodsb
end_sys_loop:
        or      al,al
        jz      end_sys_loop
        mov     ah,14
        mov     bx,7
        int     16
        jmp     sys_mess_loop

        include bootmes.inc

mesofs  equ     no_sys_mess - BogusDos

WriteBogusDos proc near

        mov     al,driveLetter
        mov     biosFilename,al
        mov     dosFilename,al
        mov     cx, ATTR_HIDDEN or ATTR_SYSTEM
        lea     dx, biosFilename
        mov     ah,CREAT
        int     21h
        mov     bx,ax
        mov     cx, BIOS_SIZE
        push    ds
        push    cs
        pop     ds
        assume  ds:code
        lea     dx, BogusDos
        mov     ah,WRITE
        int     21h
        pop     ds
        assume  ds:data
        mov     ah,CLOSE
        int     21h
        mov     cx, ATTR_HIDDEN or ATTR_SYSTEM
        lea     dx, dosFilename
        mov     ah,CREAT
        int     21h
        mov     bx,ax
        mov     cx, DOS_SIZE
        lea     dx, BogusDos
        mov     ah,WRITE
        int     21h
        mov     ah,CLOSE
        int     21h
; Comunicate system size to the main format program
        xor     dx,dx
        mov     ax,DOS_SIZE
        call    AddToSystemSize
        xor     dx,dx
        mov     ax,BIOS_SIZE
        call    AddToSystemSize

        clc
        return

WriteBogusDos endp

;-------------------------------------------------------------------------------

ConvertToOldDirectoryFormat proc near

;
; convert to 1.1 directory
;
        mov     al,drive                ; Get 1st sector of directory
        mov     cx,1                    ; 1.1 directory always starts on
        mov     dx,3                    ; sector 3
        lea     bx,scratchBuffer
        int     25h
        pop     ax                      ; clean up stack
        jnc     DirectoryRead
        lea     dx, msgDirectoryReadError
        call    PrintString
        stc
        ret
DirectoryRead:

; fix attribute of io.sys and msdos.sys
        lea     bx,scratchBuffer
        mov     byte ptr [bx].dir_attr, ATTR_HIDDEN or ATTR_SYSTEM
        add     bx, size dir_entry
        mov     byte ptr [bx].dir_attr, ATTR_HIDDEN or ATTR_SYSTEM

wrtdir:
        mov     al,[drive]              ; write out the directory
        cbw
        mov     cx,1
        mov     dx,3
        lea     bx,scratchBuffer
        int     26h
        pop     ax                      ; clean up stack
        jnc     DirectoryWritten
        lea     dx, msgDirectoryWriteError
        call    PrintString
        stc
        ret
DirectoryWritten:

        test    switchmap, SWITCH_S     ; Was system requested?
        retnz                           ; yes, don't write old boot sector
        mov     al,drive
        cbw
        mov     bx,offset boot2         ; no,  write old boot sector
        cmp     deviceParameters.DP_BPB.BPB_Heads, 1
        je      bootset8
        mov     word ptr [bx+3],0103h   ; start address for double sided drives
bootset8:
        mov     cx,1
        xor     dx,dx
        int     26h                     ; write out that boot sector
        pop     ax
        retnc

        lea     dx, msgBootWriteError
        call    PrintString
        stc
        ret

ConvertToOldDirectoryFormat endp

;-------------------------------------------------------------------------------

a_PartitionTableEntry   struc
BootInd         db  ?
BegHead         db  ?
BegSector       db  ?
BegCylinder     db  ?
SysInd          db  ?
EndHead         db  ?
EndSector       db  ?
EndCylinder     db  ?
RelSec          dd  ?
CSec            dd  ?
a_PartitionTableEntry   ends

; structure of the IBM hard disk boot sector:
IBMBoot         STRUC
                db      512 - (4*size a_PartitionTableEntry + 2) dup(?)
PartitionTable  db      4*size a_PartitionTableEntry dup(?)
Signature       dw      ?
IBMBoot         ENDS


SetPartitionTable proc near

        mov     ax, 0                   ; Head
        mov     bx, 0                   ; Cylinder
        mov     cx, 0                   ; Sector
        lea     dx, boot2
        call    ReadSector
        jnc     PartitionTableRead
        lea     dx, msgPartitionTableReadError
        call    PrintString
        stc
        ret
PartitionTableRead:

; Check to see if there is a partition table (by looking for its signature)
        cmp     boot2.signature, 0aa55H
        jne     BadPartitionTable

; Scan all the partitions search for the FIRST DOS partition.  We then set the
;   appropriate FAT size in the FIRST DOS partition and return.

        lea     bx, boot2.PartitionTable
partitionscan:

; have we scanned all partitions?
        cmp     bx,(offset Boot2.PartitionTable)+4*size a_PartitionTableEntry
        jae     BadPartitionTable

        cmp     [bx].sysind,1
        jz      dochange
        cmp     [bx].sysind,4
        jz      dochange

        add     bx,size a_PartitionTableEntry
        jmp     partitionscan

dochange:
        mov     [bx].sysind,4           ; assume 16 bit fat
        cmp     fbigfat,0               ; test assumption
        jnz     partitionset            ; is 16 bit fat, assumption correct
        mov     [bx].sysind,1           ; 12 bit fat, pre 3.0 dos can read it

partitionset:
        mov     ax, 0                   ; Head
        mov     bx, 0                   ; Cylinder
        mov     cx, 0                   ; Sector
        lea     dx, boot2
        call    WriteSector
        retnc

        lea     dx, msgPartitionTableWriteError
        call    PrintString
        stc
        ret

BadPartitionTable:
        lea     dx, msgBadPartitionTable
        call    PrintString
        stc
        ret

SetPartitionTable endp

;-------------------------------------------------------------------------------
; ReadSector:
;    Read one sector
;
;    Input:
;       ax - head
;       bx - cylinder
;       cx - sector
;       dx - transfer address

ReadSector proc near

        mov     TrackReadWritePacket.TRWP_FirstSector, cx
        mov     cx,(RAWIO shl 8) or READ_TRACK
        call    SectorIO
        return

ReadSector endp

;-------------------------------------------------------------------------------
; WriteSector:
;    Write one sector
;
;    Input:
;       ax - head
;       bx - cylinder
;       cx - sector
;       dx - transfer address

WriteSector proc near

        mov     TrackReadWritePacket.TRWP_FirstSector, cx
        mov     cx,(RAWIO shl 8) or WRITE_TRACK
        call    SectorIO
        return

WriteSector endp

;-------------------------------------------------------------------------------
; SectorIO:
;    Read/Write one sector
;
;    Input:
;       ax - head
;       bx - cylinder
;       cx - (RAWIO shl 8) or READ_TRACK
;          - (RAWIO shl 8) or WRITE_TRACK
;       dx - transfer address

SectorIO proc near

        mov     TrackReadWritePacket.TRWP_Head, ax
        mov     TrackReadWritePacket.TRWP_Cylinder, bx
        mov     WORD PTR TrackReadWritePacket.TRWP_TransferAddress, dx
        mov     WORD PTR TrackReadWritePacket.TRWP_TransferAddress + 2, ds
        mov     TrackReadWritePacket.TRWP_SectorsToReadWrite, 1

        mov     bl, drive
        inc     bl
        mov     ax, (IOCTL shl 8) or GENERIC_IOCTL
        lea     dx, trackReadWritePacket
        int     21H
        return

SectorIO endp

;-------------------------------------------------------------------------------

data segment

oldDrive db     ?

FCBforVolumeIdSearch    db      0ffH
                        db      5 dup(0)
                        db      08H
                        db      0
                        db      "???????????"
                        db      40 DUP(0)

data ends

GetVolumeId proc near
; Input:
;    dl = drive
;    di = name buffer

; Save current drive
        mov     ah,19H
        int     21H
        mov     oldDrive, al

; Change current drive to the drive that has the volume id we want
        mov     ah, 0eH
        int     21H

; Search for the volume id
        mov     ah, 11H
        lea     dx, FCBforVolumeIdSearch
        int     21H
        push    ax

; Restore current drive
        mov     ah, 0eH
        mov     dl,oldDrive
        int     21H

; Did the search succeed?
        pop     ax
        or      al,al
        jz      CopyVolumeId
        stc
        ret

CopyVolumeId:
; Find out where the FCB for the located volume id was put
        mov     ah,2fH
        int     21H

; Copy the Volume Id
        mov     si, bx
        add     si, 8
        push    es
        push    ds
        pop     es
        pop     ds
        mov     cx, 11
        rep     movsb
        push    es
        pop     ds

        clc
        ret

GetVolumeId endp

data segment
oldVolumeId db  11 dup(0)
data ends

CheckVolumeId proc near

; Get the volume id that's on the disk
        lea     di, oldVolumeId
        mov     dl, drive
        call    GetVolumeId
        jnc     Ask_User                ;Did we find one?
        clc                             ;No, return with no error
        ret

; Ask the user to enter the volume id that he/she thinks is on the disk
; (first blank out the input buffer)
Ask_User:
        lea     dx, ptr_msgWhatIsVolumeId?
        call    std_printf
        call    user_string
        call    crlf

; If the user just pressed ENTER, then there must be no label
        cmp     inbuff+1, 0
        jne     CompareVolumeIds
        cmp     oldVolumeId, 0
        jne     BadVolumeId
        ret

CompareVolumeIds:
; pad the reponse with blanks
; The buffer is big enough so just add 11 blanks to what the user typed in
        push    ds
        pop     es
        mov     cx, 11
        xor     bx,bx
        mov     bl, inbuff + 1
        lea     di, inbuff + 2
        add     di, bx
        mov     al, ' '
        rep     stosb
; Make the reply all uppercase
        mov     cl, inbuff + 1
        xor     ch,ch
        lea     si, inbuff + 2
VolumeToUpper:
        mov     al, [si]
        cmp     al, 'a'
        jb      NextLetter
        cmp     al, 'z'
        ja      NextLetter
        sub     al, 'a' - 'A'
        mov     [si],al
NextLetter:
        inc     si
        loop    VolumeToUpper

; Now compare what the user specified with what is really out there
        mov     cx, 11
        lea     si, inbuff + 2
        lea     di, oldVolumeId
        repe    cmpsb
        jne     BadVolumeId
        ret

BadVolumeId:
        lea     dx, msgBadVolumeId
        call    PrintString
        stc
        ret

CheckVolumeId endp

code    ends
        end
