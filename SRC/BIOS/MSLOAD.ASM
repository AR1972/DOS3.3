title	Non-Contiguous BIOS Loader (MSLOAD)				  
									  
IF1									  
	%OUT ASSEMBLING: Non-Contiguous BIOS Loader (MSLOAD)		  
	%OUT								  
ENDIF									  
									  
bootseg 	segment at 0h						  
       org	7C00h							  
Boot_Sector		label	byte					  
	org	7D00h							  
Relocate_Start		label	byte					  
bootseg 	ends							  
									  
									  
dosseg	       segment at 70h						  
       org	00h							  
BIOS_Address	    label   byte					  
									  
dosseg	       ends							  
									  
									  
cseg		segment public para 'code'                                
		assume	cs:cseg,ds:cseg,es:cseg,ss:cseg 		  
									  
									  
									  
include msload.inc							  
									  
org	0h								  
									  
start:									  
									  
subttl	Setup Stack							  
page									  
;***********************************************************************  
;  Setup_Stack								  
;***********************************************************************  
;									  
; Input:     none							  
;									  
; Output:								  
;									  
;   SS:SP =  0:7C00h							  
;   AX destroyed							  
;-----------------------------------------------------------------------  
; First thing is to reset the stack to a better and more known place.	  
;									  
; Move the stack to just under the boot record and relocation area (0:7C00h)
;									  
; Preserve all other registers						  
;----------------------------------------------------------------------   
									  
	CLI				;Stop interrupts till stack ok	  
	XOR	AX,AX							  
	MOV	SS,AX			;Work in stack just below this routine
	MOV	SP,7C00h - 30		;Leave room for stack frame	  
	MOV	BP,7C00h - 30		;Point BP as stack index pointer  
	STI								  
									  
									  
subttl	Save Input Values						  
page									  
;***********************************************************************  
;  Save_Input_Values							  
;***********************************************************************  
;									  
; Input:     none							  
;									  
;   DL = INT 13 drive number we booted from				  
;   CH = media byte							  
;   BX = First data sector on disk (0-based)				  
;									  
; Output:								  
;									  
;   BX = first data sector on disk					  
;   CL = number of floppies including fake one				  
;   CH = media byte							  
;									  
;   [bp].Media_Byte = input CH						  
;   [bp].Drive_Number = input DL					  
;   [bp].First_Sector = input BX					  
;   [bp].Drive_Boot = output AX 					  
;   [bp].Number_Floppy = output CL					  
;   [bp].Number_Sectors = Sectors/track 				  
;   [bp].Number_Heads = heads/cylinder					  
;									  
;   DS = 0								  
;   AX,DX,SI destroyed							  
;									  
; Calls:     none							  
;-----------------------------------------------------------------------  
; Save input information						  
;									  
; Get Equipment Flag							  
;									  
; Find how many drives on system					  
;									  
; Figure out boot drive 						  
;									  
;----------------------------------------------------------------------   
Save_Input_Values:							  
	mov	[bp].First_Sector,bx					  
	mov	[bp].media_Byte,ch					  
	mov	[bp].Drive_Number,dl					  
;	INT	11h			;GET EQUIPMENT STATUS		  
;	ROL	AL,1			;Put bits 6 & 7 into bits 0 & 1   
;	ROL	AL,1							  
;	AND	AX,3			;Only look at bits 0 & 1	  
;	JNZ	NOTsingle		;Zero means single drive system   
;	INC	AX			;Pretend it's a two drive system  
NOTSingle:								  
;	INC	AX			;AX has number of drives, 2-4	  
					;Is also 0 indexed boot drive if we
					;  booted off hard file 	  
;	MOV	CL,AL			;CH is FAT ID, CL # floppies	  
;	TEST	DL,80H			;BOOT FROM FLOPPY ?		  
;	JNZ	GOTHRD			;NO.				  
;	XOR	AX,AX			;INDICATE BOOT FROM DRIVE A	  
GotHrd: 								  
	xor	ax,ax				;Segment 0		  
	mov	ds,ax							  
									  
	assume	ds:Bootseg						  
									  
	mov	ax,Boot_Sector.SECLIM		;Get Sectors per track	  
	mov	[bp].Sectors_Per_Track,ax				  
	mov	ax,Boot_Sector.HDLIM		;Get BPB heads per cylinder
	mov	[bp].Number_Of_Heads,ax 				  
	mov	ax,Boot_Sector.cSecFat		;Get sectors per FAT	  
	mov	[bp].Number_Of_FAT_Sectors,ax				  
	mov	ax,Boot_Sector.cSecHid		;Get hidden sectors	  
	mov	[bp].Hidden_Sectors,ax					  
	mov	ax,Boot_Sector.cSecRes		;Get Reserved Sectors	  
	mov	[bp].Reserved_Sectors,ax				  
									  
									  
subttl	Find_Cluster_Size						  
page									  
;***********************************************************************  
;  Find_Cluster_Size							  
;***********************************************************************  
;									  
; Input:     BPB information in loaded boot record at 0:7C00h		  
;									  
; Output:								  
;									  
;	DS = 0								  
;	AX = Bytes/Cluster						  
;	BX = Sectors/Cluster						  
;	SI destroyed							  
; Calls:     none							  
;-----------------------------------------------------------------------  
;									  
; Get Bytes/sector from BPB						  
;									  
; Get sectors/cluster from BPB						  
;									  
; Bytes/cluster = Bytes/sector * sector/cluster 			  
;----------------------------------------------------------------------   
Find_Cluster_Size:							  
									  
;For the time being just assume the boot record is valid and the BPB	  
;is there.								  
									  
	xor	ax,ax				;Segment 0		  
	mov	ds,ax							  
									  
	assume ds:bootseg						  
									  
	mov	ax,Boot_Sector.ByteSec		;Get BPB bytes/sector	  
	xor	bx,bx							  
	mov	bl,Boot_Sector.cAlloc		;Get sectors/cluster	  
	mul	bx				;Bytes/cluster		  
	mov	[bp].Size_Cluster,ax		  ;Save it		  
									  
									  
									  
subttl	Determine FAT size						  
page									  
;***********************************************************************  
;  Determine_FAT_Size							  
;***********************************************************************  
;									  
; Notes:								  
;									  
;   Determine if FAT is 12 or 16 bit FAT. 12 bit FAT if floppy, read MBR  
;   to find out what system id byte is. 				  
;									  
; Input:     [bp].Media_Byte = FAT ID Byte				  
;									  
; Output:								  
;									  
;   [BP].Fat_Size = FAT12_bit or FAT16_bit				  
;   ES = 0								  
;   All other registers destroyed					  
;									  
; Calls: READ_DISK							  
;-----------------------------------------------------------------------  
;IF (not FAT ID of F8)							  
;    {12 bit FAT}							  
;ELSE									  
;   {									  
;     Read in master boot record at 0:7C00h				  
;									  
;     Scan system id bytes for 1 or 4					  
;									  
;     IF (Sys id = 4)							  
;	 {16 bit FAT}							  
;     ELSE								  
;	 {IF (Sys id = 1)						  
;	     {12 bit FAT}						  
;	  ELSE								  
;	     {Error}							  
;	  ENDIF 							  
;     ENDIF								  
; ENDIF 								  
;									  
;----------------------------------------------------------------------   
Determine_FAT_Size:							  
	mov	[bp].FAT_Size,FAT12_bit 	      ;Assume 12 bit fat  
	cmp	[bp].Media_Byte,0F8h		  ;Is it floppy 	  
	jne	FAT_Size_Found			;Yep, all set		  
	mov	[bp].Logical_Sector,0		  ;Got hardfile, go get MBR
	xor	ax,ax							  
	mov	es,ax							  
	mov	di,offset Relocate_Start				  
	mov	[bp].Sector_Count,1					  
	call	Disk_Read						  
	mov	si,offset Relocate_Start+1C2h				  
	mov	cx,4							  
	xor	ax,ax							  
	mov	ds,ax							  
Find_Sys_Id:								  
	mov	[bp].FAT_Size,FAT12_bit 	      ;Assume 12 bit fat  
	cmp	byte ptr [si],1 					  
	je	FAT_Size_Found						  
	mov	[bp].FAT_Size,FAT16_bit 	      ;Assume 12 bit fat  
	cmp	byte ptr [si],4 					  
	je	Fat_Size_Found						  
	add	si,16							  
	loop	Find_Sys_Id						  
       ;xxxxxxxxxxxxxxxxxxxxxxxxxx error				  
FAT_Size_Found: 							  
									  
									  
subttl Determine First Cluster						  
page									  
;***********************************************************************  
;  Determine_First_Cluster						  
;***********************************************************************  
;									  
; Notes: Find the last cluster that was loaded				  
;									  
;									  
; Input:								  
;									  
;   [BP].Size_Cluster							  
;   Total_Length is offset of end of MSLOAD				  
;									  
; Output:								  
;									  
;   [BP].Last_Found_Cluster = the last cluster loaded containing MSLOAD   
;			      code. This is also the number of clusters   
;			      with MSLOAD code +2			  
;									  
; Calls:     none							  
;-----------------------------------------------------------------------  
;									  
;Get length of loader portion of bios					  
;									  
;Divide by bytes/cluster						  
;									  
;If (Remainder = 0)							  
;   {Last_Used_Cluster = quotient+2}					  
;Else									  
;   {Last_Used_Cluster = quotient+3}					  
;----------------------------------------------------------------------   
Determine_First_Cluster:						  
	mov	[bp].Last_Found_Cluster,1	;2 is the first cluster-1 
	mov	ax,offset Total_Length		;Get whole length	  
	xor	dx,dx							  
	div	[bp].Size_Cluster		;Div by bytes/sector	  
	add	[bp].Last_Found_Cluster,ax	;Save the result	  
	cmp	dx,0				;Was there remainder?	  
	je	First_Cluster_Found		;No			  
	inc	[bp].Last_Found_Cluster 	;Yes, round up		  
									  
First_Cluster_Found:							  
									  
									  
subttl	Relocate							  
page									  
;									  
;***********************************************************************  
;  RELOCATE								  
;***********************************************************************  
;									  
; Notes:								  
;									  
;   Relocate the loader code to 0:7C00 - this will allow bios to be loaded
;   underneath at 70:0							  
;									  
; Input:     none							  
;									  
; Output:    es is set to 0						  
;	     ds is set to cs (70h)					  
;	     ax,cx,si,di destroyed					  
;									  
; Calls:     none							  
;-----------------------------------------------------------------------  
; Copy code from Relocate_Code to Relocate_Start (7C00h)		  
;									  
; The length to copy is Relocate_Length 				  
;									  
; Jump to relocated code						  
;-----------------------------------------------------------------------  
;									  
Relocate:								  
	push	cs				;Set up ds segreg	  
	pop	ds							  
	xor	ax,ax				;Set up ES segreg	  
	mov	es,ax							  
									  
	assume	es:bootseg,ds:cseg					  
									  
	mov	si,offset Relocate_Code 	;Source 		  
	mov	di,offset Relocate_Start	;Target 		  
	mov	cx,Relocate_Length		;Length 		  
	rep	movsb				;Go do it		  
									  
	jmp	far ptr Relocate_Start					  
									  
;									  
;*************************************************************************
;* RELOCATED CODE ********************************************************
;*************************************************************************
;									  
									  
Relocate_Code	label	byte						  
									  
subttl	Read In FAT							  
page									  
;***********************************************************************  
;  Read_In_FAT								  
;***********************************************************************  
;									  
; Notes:								  
;									  
;   Reads in the entire FAT at 0:8000. This gives the relocated portion   
;   of this loader a maximum size of 1024 bytes (8000 - 7C00). The max	  
;   size of the FAT is 64 sectors (32k) so everything will fit under the  
;   64k DMA boundary, so no problems with loading.			  
;									  
; Input:     none							  
;									  
; Output:								  
;									  
;   ES = 0								  
;   All sectors destroyed						  
;									  
; Calls:  READ DISK							  
;-----------------------------------------------------------------------  
; Get number of sectors in FAT						  
;									  
; Set ES:DI to 0:8000h							  
;									  
; Read in the sectors							  
;									  
;----------------------------------------------------------------------   
Read_In_FAT:								  
	xor	ax,ax							  
	mov	ds,ax							  
									  
	assume	ds:bootseg						  
									  
	mov	ax,[bp].Number_Of_FAT_Sectors	;Get sectors/FAT	  
	mov	[bp].Sector_Count,ax		;Number of sectors to read
	mov	ax,[bp].Hidden_Sectors		;Hidden+Reserved = Fat	  
	add	ax,[bp].Reserved_Sectors				  
	mov	[bp].Logical_Sector,ax		;Save it, setup for read  
	xor	ax,ax							  
	mov	es,ax							  
	mov	di,8000h			;Point to buffer	  
	call	Disk_Read						  
									  
subttl	Keep Loaded BIO 						  
page									  
;***********************************************************************  
;  KEEP LOADED BIO							  
;***********************************************************************  
;									  
; Notes:								  
;									  
;   Determine how much of bios was loaded in when the loader was loaded   
;   by the boot record (only the portion that is guaranteed to be	  
;   contiguous								  
;									  
; Input:								  
;									  
;   [BP].Last_Found_Cluster = number of clusters used for loader+2	  
;									  
; Output:								  
;	ES = DS = 70h							  
;	DI = Next offset to load bios code				  
;	AX,BX,CX,DX,SI destroyed					  
;									  
;	[bp].Next_BIO_Location = DI on output				  
;	[bp].Last_Cluster = last cluster loaded 			  
;									  
; Calls:     none							  
;-----------------------------------------------------------------------  
;Number of clusters loaded+2 is in [BP].Last_Found_Cluster		  
;									  
;Multiply cluster * cluster size in bytes to get total loaded for MSLOAD  
;									  
;Subtract TOTAL_LOADED - LOADBIO_SIZE to get loaded bios in last cluster  
;									  
;Relocate this piece of bios down to 70:0				  
;									  
;----------------------------------------------------------------------   
Keep_Loaded_BIO:							  
	push	ds							  
	mov	ax,[bp].Last_Found_Cluster	;Point to last cluster loaded  
	sub	ax,1				;Get number of clusters loaded 
	mul	[bp].Size_Cluster		;Get total bytes loaded by
						;This is always < 64k, so 
						;lower 16 bits ok	  
	sub	ax,LoadBio_Size 		;Get portion of bios loaded
	mov	cx,ax				;Save length to move	  
	mov	ax,70h				;Segment at 70h 	  
	mov	ds,ax							  
	mov	es,ax							  
	mov	si,offset cs:Total_Length	;Point at bios		  
	mov	di,0				;Point at 70:0		  
	rep	movsb				;Relocate this code	  
	mov	[bp].Next_Bio_Location,di	  ;Save where to load next
	pop	ds							  
									  
subttl Get Contiguous Clusters						  
page									  
;***********************************************************************  
;  Get_Contiguous_Clusters						  
;***********************************************************************  
;									  
; Notes: Go find clusters as long as they are contiguous		  
;									  
;									  
; Input:								  
;									  
;   [BP].Next_BIO_Location						  
;   [BP].								  
;									  
;									  
; Output:								  
;									  
;									  
; Calls: Get_Next_FAT_Entry						  
;-----------------------------------------------------------------------  
;									  
;Set [BP].Sector_Count to Sectors per cluster				  
;									  
;Call Get_Next_FAT_Entry to get next cluster in file			  
;									  
;Call Check_for_EOF							  
;									  
;IF (NC returned)							  
;									  
;   {Call Get_Next_FAT_Entry						  
;									  
;    IF (New cluster is contig to old cluster)				  
;	{Add sectors per cluster to [BP].Sector_Count			  
;									  
;	 Call Check_For_EOF						  
;									  
;	 IF (NC returned)						  
;									  
;									  
;----------------------------------------------------------------------   
Get_Contiguous_Cluster: 						  
	xor	ah,ah							  
	mov	al,Boot_Sector.cAlloc	;Assume we will get one cluster   
	mov	[bp].Sector_Count,ax					  
	call	Get_Next_Fat_Entry	;Go get it			  
	mov	[bp].Last_Found_Cluster,ax ;Update the last one found	  
	cmp	[bp].EOF,End_Of_File					  
	je	GOTO_bios						  
									  
Got_Contig_Clusters:							  
	sub	ax,2			;Zero base the cluster		  
	xor	ch,ch							  
	mov	cl,Boot_Sector.cAlloc	;Get sectors per cluster	  
	mul	cx			;Get how many			  
	add	ax,[bp].First_Sector	;See where the data sector starts 
	mov	[bp].Logical_Sector,ax	;Save it			  
	mov	di,[bp].Next_Bio_Location ;Get where to put code	  
	push	[bp].Sector_Count	;Save how many sectors		  
	mov	ax,dosseg		;Get area to load code		  
	mov	es,ax							  
	call	Disk_Read						  
	pop	ax			;Get back total sectors read in   
;	jc	##########						  
	mul	Boot_Sector.ByteSec	  ;Get number of bytes we loaded  
	add	[bp].Next_Bio_Location,ax ;Point to where to load next	  
	jmp	short Get_Contiguous_Cluster				  
									  
subttl	GOTO bios							  
page									  
;***********************************************************************  
;  GOTO_bios								  
;***********************************************************************  
;									  
; Notes:								  
;									  
;  Set up required registers for bios, then jump to it (70:0)		  
;									  
; Input:     none							  
;									  
;   [bp].Media_Byte = media byte					  
;   [bp].Drive_Number = INT 13 drive number we booted from		  
;   [bp].First_Sector = First data sector on disk (0-based)		  
;									  
; Output:								  
;									  
;   Required by MSINIT							  
;   DL = INT 13 drive number we booted from				  
;   CH = media byte							  
;   BX = First data sector on disk (0-based)				  
;									  
; Calls:     none							  
;-----------------------------------------------------------------------  
;									  
; Set up registers for MSINIT then do Far Jmp				  
;									  
;----------------------------------------------------------------------   
GOTO_bios:								  
	mov	ch,[bp].Media_Byte	  ;Restore regs required for MSINT
	mov	dl,[bp].Drive_Number					  
	mov	bx,[bp].First_Sector					  
	jmp	far ptr bios_Address					  
									  
									  
									  
									  
subttl	Disk Read							  
page									  
;***********************************************************************  
; Disk_Read								  
;***********************************************************************  
;									  
; Notes:								  
;									  
;  Read in the [BP].Sector_Count number of sectors at ES:DI		  
;									  
;									  
; Input:     none							  
;									  
;   DI = Offset of start of read					  
;   ES = Segment of read						  
;   [bp].Sector_Count = number of sectors to read			  
;   [bp].Logical_sector = starting sector				  
;   Following is BPB info that must be setup prior to call		  
;   [bp].Number_Of_Heads						  
;   [bp].Number_Of_Sectors						  
;   [bp].Drive_Number							  
;   [bp].Sectors_Per_Track						  
;									  
; Output:								  
;									  
;   ES = 0								  
;   AX,BX,CX,DX,SI,DI destroyed 					  
;									  
;									  
; Calls:     none							  
;-----------------------------------------------------------------------  
; Divide start sector by sectors per track				  
; The remainder is the actual sector number, 0 based			  
;									  
; Increment actual sector number to get 1 based 			  
;									  
; The quotient is the number of tracks - divide by heads to get the cyl   
;									  
; The remainder is actual head, the quotient is cylinder		  
;									  
; Figure the number of sectors in that track, set AL to this		  
;									  
; Do the read								  
;									  
; If Error, Do RESET, then redo the INT 13h				  
;									  
; If successful read, Subtract # sectors read from Sector_Count, Add to   
; Logical Sector, add #sectors read * Sector_Size to BX;		  
;									  
; If Sector_Count <> 0 Do next read					  
;----------------------------------------------------------------------   
Disk_Read:								  
									  
;									  
; convert a logical sector into Track/sector/head.  AX has the logical	  
; sector number 							  
;									  
DODIV:									  
	MOV	cx,5			;5 retries			  
									  
Try_Read:								  
       PUSH    cx		       ;Save it 			  
									  
       MOV     AX,[bp].Logical_Sector	 ;Get starting sector		  
       XOR     DX,DX							  
       DIV     word ptr [bp].Sectors_Per_Track				  
       MOV     bx,[bp].Sectors_Per_Track ;Get number of sectors we can	  
       sub     bx,dx		       ;read in this track		  
       mov     si,bx							  
       cmp     [bp].Sector_Count,si    ;Is possible sectors in track more 
       jae     Got_Length	       ;than what we need to read?	  
       mov     si,[bp].Sector_Count    ;Yes, only read what we need to	  
									  
Got_Length:								  
       INC     DL		       ; sector numbers are 1-based	  
       MOV     bl,dl		       ;Start sector in DL		  
       XOR     DX,DX							  
       DIV     word ptr [bp].Number_Of_Heads  ;Start cyl in ax,head in DL 
       MOV     DH,DL							  
;									  
; Issue one read request.  ES:BX have the transfer address, AL is the number
; of sectors.								  
;									  
;								      
;  Now convert to standard ROM call				      
;								      
	mov	cl,bl			;Get starting sector	      
	ror	ah,1			;Set up high 2 bits	      
	ror	ah,1			;Set up high 2 bits	      
	or	cl,ah			;Combine cyl/start sector     
	mov	ch,al			;Set low order of cyl	      
	mov	bx,di			;Set offset		      
	mov	dl,[bp].Drive_Number	;Set drive		      
	mov	ax,si			;Set count		      
	mov	ah,02			;Read Command		      
	push	ax			;Save regs		      
	push	di			; *			      
	int	13h			;Call ROM-Bios		      
	pop	di			;Restore Regs		      
	pop	ax			; *			      
	pop	cx			;Get retry count back		  
	jnc	Read_OK 						  
	push	cx							  
	mov	bx,di			;
	push	di			;Save Reg		      
	mov	dl,[bp].Drive_Number	;Set drive		      
	mov	ah,0			;RESET Disk Command	      
	int	13h			;Call ROM-Bios		      
	pop	di			;Restore Reg		      
	pop	cx							  
	loop	Try_Read						  
       ;xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx error				  
Read_OK:								  
	xor	ah,ah			;Mask out command, just get # read
	sub	[bp].Sector_Count,ax	  ;Bump number down		  
	jz	Read_Finished						  
	add	[bp].Logical_Sector,ax	  ;Where to start next time	  
	xor	bx,bx			  ;Get number sectors read	  
	mov	bl,al							  
	mov	ax,Boot_Sector.ByteSec	  ;Bytes per sector		  
	mul	bx			  ;Get total bytes read 	  
	add	di,ax			  ;Add it to offset		  
	jmp	short DODIV						  
Read_Finished:								  
	RET								  
									  
subttl	GET NEXT FAT ENTRY						  
page									  
;***********************************************************************  
;  GET_NEXT_FAT_ENTRY							  
;***********************************************************************  
;									  
; Notes:								  
;									  
;   Given the last cluster found, this will return the next cluster of	  
;   bios. If the last cluster is (F)FF8 - (F)FFF, then the final cluster  
;   of bios has been loaded, and control is passed to GOTO_bios 	  
;									  
; Input:								  
;									  
;    [bp].Last_Found_Cluster						  
;    [bp].Fat_Size							  
;									  
; Output:								  
;									  
;   [bp].Last_Found_Cluster (updated)					  
;									  
; Calls:  none								  
;-----------------------------------------------------------------------  
; Get Last_Found_Cluster						  
;									  
; IF (16 bit FAT)							  
;    {IF (Last_Found_Cluster = FFF8 - FFFF)				  
;	 {JMP GOTO_bios}						  
;     ELSE								  
;	{Get offset by multiply cluster by 2}				  
;									  
; ELSE									  
;    {IF (Last_Found_Cluster = FF8 - FFF)				  
;	 {JMP GOTO_bios}						  
;     ELSE								  
;	{Get offset by	- multiply cluster by 3 			  
;									  
;	 Rotate right to divide by 2					  
;									  
;	 IF (CY set - means odd number) 				  
;	    {SHR 4 times to keep high twelve bits}			  
;									  
;	 ELSE								  
;	    {AND with 0FFFh to keep low 12 bits}			  
;	}								  
;    }									  
;									  
; Add in 8000h to get offset of next cluster in FAT buffer		  
;									  
;----------------------------------------------------------------------   
Get_Next_FAT_Entry:							  
									  
	mov	[bp].EOF,End_Of_File		;Assume last cluster	  
	mov	ax,[bp].Last_Found_Cluster	;Get last cluster	  
	cmp	[bp].Fat_Size,FAT12_bit 				  
	jne	Got_16_Bit						  
	xor	bx,bx							  
	mov	bl,3				;Mult by 3		  
	mul	bx							  
	shr	ax,1				;Div by 2 to get 1.5	  
	mov	si,ax				;Get the final buffer offset
	mov	ax,[si]+8000h			;Get new cluster	  
	test	[bp].Last_Found_Cluster,1	;Was last cluster odd?	  
	jnz	Odd_Result			;If Carry set it was odd  
	and	ax,0FFFh			;Keep low 12 bits	  
	jmp	short Test_EOF						  
									  
Odd_Result:								  
	 mov	cl,4				;Keep high 12 bits for odd
	 shr	ax,cl							  
Test_EOF:								  
	 cmp	 ax,0FF8h			 ;Is it last cluster?	  
	 jae	 Got_Cluster_Done		 ;Yep, all done here	  
	 jmp	short Not_Last_CLuster					  
									  
Got_16_Bit:								  
	shl	ax,1				;Multiply cluster by 2	  
	mov	si,ax				;Get the final buffer offset
	mov	ax,[si]+8000h			;Get new cluster	  
	cmp	ax,0FFF8h						  
	jae	Got_Cluster_Done					  
									  
Not_Last_Cluster:							  
	mov	[bp].EOF,not End_Of_File	    ;Assume last cluster  
									  
Got_Cluster_Done:							  
	ret								  
									  
									  
									  
									  
Relocate_Length   equ  $ - Read_In_FAT					  
Total_Length label byte 						  
LoadBIO_Size	equ	$ - Start					  
									  
cseg	ends								  
end	start								  
