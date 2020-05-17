;	SCCSID = @(#)sysvar.asm 1.1 85/04/10
SysInitVars STRUC
SYSI_DPB    DD	    ?			; DPB chain
SYSI_SFT    DD	    ?			; SFT chain
SYSI_CLOCK  DD	    ?			; CLOCK device
SYSI_CON    DD	    ?			; CON device
SYSI_MAXSEC DW	    ?			; maximum sector size
SYSI_BUF    DD	    ?			; buffer chain
SYSI_CDS    DD	    ?			; CDS list
SYSI_FCB    DD	    ?			; FCB chain
SYSI_Keep   DW	    ?			; keep count
SYSI_NUMIO  DB	    ?			; Number of block devices
SYSI_NCDS   DB	    ?			; number of CDS's
SYSI_DEV    DD	    ?			; device list
SysInitVars ENDS

;This is added for more information exchage between DOS, BIOS.
;DOS will give the pointer to SysInitTable in ES:DI. - J.K. 5/29/86
SysInitVars_Ext struc
SYSI_InitVars		DD	0	; Points to the above structure.
SYSI_Country_Tab	DD	0	; DOS_Country_cdpg_info
SysInitVars_Ext ends

