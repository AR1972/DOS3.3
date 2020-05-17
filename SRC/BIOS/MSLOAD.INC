									  ;3.30
Stack_Frame		STRUC						  ;3.30
Number_Of_Heads 	dw	0					  ;3.30
Size_Cluster		dw	0					  ;3.30
Logical_Sector		dw	0					  ;3.30
Sector_Count		dw	0					  ;3.30
Number_Of_FAT_Sectors	dw	0					  ;3.30
Hidden_Sectors		dw	0					  ;3.30
Sector_Size		dw	0					  ;3.30
Reserved_Sectors	dw	0					  ;3.30
Last_Found_Cluster	dw	0					  ;3.30
Next_BIO_Location	dw	0					  ;3.30
First_Sector		dw	0					  ;3.30
Sectors_Per_Track	dw	0					  ;3.30
Drive_Number		db	0					  ;3.30
FAT_Size		db	0					  ;3.30
Media_Byte		db	0					  ;3.30
EOF			db	0					  ;3.30
									  ;3.30
Stack_Frame		ENDS						  ;3.30
									  ;3.30
									  ;3.30
BPB			STRUC						  ;3.30
JUMP	DB	0							  ;3.30
	DB	0							  ;3.30
	DB	0							  ;3.30
OEM	DB	"IBM  "                                                   ;3.30
	DB	"3.3"                                                     ;3.30
ByteSec DW	512			; SIZE OF A PHYSICAL SECTOR	  ;3.30
cAlloc	DB	8			; SECTORS PER ALLOCATION UNIT	  ;3.30
cSecRes DW	1			; NUMBER OF RESERVED SECTORS	  ;3.30
cFat	DB	2			; NUMBER OF FATS		  ;3.30
DirNum	DW	512			; NUMBER OF DIREC ENTRIES	  ;3.30
NumSec	DW	4*17*305-1		; NUMBER OF SECTORS - NUMBER OF HI;3.30 DDEN SECTORS
MEDIA	DB	0F8H			; MEDIA BYTE			  ;3.30
cSecFat DW	8			; NUMBER OF FAT SECTORS 	  ;3.30
SECLIM	DW	17			; SECTORS PER TRACK		  ;3.30
HDLIM	DW	4			; NUMBER OF SURFACES		  ;3.30
cSecHid DW	1			; NUMBER OF HIDDEN SECTORS	  ;3.30
hSecHid dw	0			; high order word of Hidden Sector;3.30 s
BNumSec dd	0			; 32 bit version of NUMBER OF SECT;3.30 ORS
					; (when 16 bit version is zero)   ;3.30
Other	db	6 dup(?)		; reserved for later expansion	  ;3.30
BPB			ENDS						  ;3.30
									  ;3.30
									  ;3.30
									  ;3.30
End_Of_File	equ	0FFh						  ;3.30
FAT12_Bit	equ	01h						  ;3.30
FAT16_Bit	equ	04h						  ;3.30
									  ;3.30
