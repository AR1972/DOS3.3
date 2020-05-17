

						  ;;Rev 3.30 Modification
; ROM BIOS CALL PACKET STRUCTURES					  
									  
;*******************************					  
;System Service call ( Int 15h )					  
;*******************************					  
;Function AH = 0C0h, Return system configuration			  
;For PC and PCJR on return:						  
;	(AH)	= 80h							  
;	(CY)	= 1							  
;For PCXT, PC PORTABLE and PCAT on return:				  
;	(AH)	= 86h							  
;	(CY)	= 1							  
;For all others:							  
;	(AH)	= 0							  
;	(CY)	= 0							  
;	(ES:BX) = pointer to system descriptor vector in ROS		  
; System descriptor :							  
;	DW	xxxx		length of descriptor in bytes,		  
;				minimum length = 8			  
;	DB	xx		model byte				  
;				0FFh	= PC				  
;				0FEh	= PC/XT, Portable		  
;				0FDh	= PC/JR 			  
;				0FCh	= PC/AT				  
;				0F9h	= Convertable			  
;				0F8h	= Model 80			  
;				0E0 thru 0EFh = reserved		  
;									  
;	DB	xx		secondary model byte			  
;				000h	= PC1				  
;				000h	= PC/XT, Portable		  
;				000h	= PC/JR 			  
;				000h	= PC/AT 			  
;				001h	= PC/AT Model 339		  
;				003h	= PC/RT				  
;				000h	= Convertable			  
;									  
;	DB	xx		bios revision level			  
;				00 for first release, subsequent release  
;				of code with same model byte and	  
;				secondary model byte require revison level
;				to increase by one.			  
;									  
;	DB	xx		feature information byte 1		  
;				X0000000 = 1, bios use DMA channel 3	  
;					 = 0, DMA channel 3 not used	  
;									  
;				0X000000 = 1, 2nd Interrupt chip present  
;					 = 0, 2nd Interrupt chip not present
;									  
;				00X00000 = 1, Real Time Clock present	  
;					 = 0, Real Time Clock not present 
;									  
;				000X0000 = 1, Keyboard escape sequence(INT 15h)
;						called in keyboard interrupt
;						(Int 09h).		  
;					 = 0, Keyboard escape sequence not
;						called. 		  
;				0000XXXX reserved			  
;									  
;	DB	xx		feature information byte 2 - reserved	  
;									  
;	DB	xx		feature information byte 2 - reserved	  
;									  
;	DB	xx		feature information byte 2 - reserved	  
;									  
;	DB	xx		feature information byte 2 - reserved	  
;									  
									  
BIOS_SYSTEM_DESCRIPTOR	struc						  
bios_SD_leng		dw	?					  
bios_SD_modelbyte	db	?					  
bios_SD_scnd_modelbyte	db	?					  
			db	?					  
bios_SD_featurebyte1	db	?					  
			db   4 dup (?)					  
BIOS_SYSTEM_DESCRIPTOR ends						  
									  
;FeatureByte1	bit map equates 					  
DMAchannel3		equ 10000000b					  
ScndIntController	equ 01000000b					  
RealTimeClock		equ 00100000b					  
KeyEscapeSeq		equ 00010000b					  
						;;End of Modification									  
