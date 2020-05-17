TEST = 0								  ;3.30
include msequ.inc							  ;3.30
include msmacro.inc							  ;3.30
									  ;3.30
SYSINITSEG	SEGMENT PUBLIC BYTE 'SYSTEM_INIT'                         ;3.30
									  ;3.30
	PUBLIC	BADOPM,CRLFM,BADSIZ_PRE,BADLD_PRE,BADCOM,SYSSIZE,BADCOUNTRY ;3.30
	PUBLIC	BADLD_POST,BADSIZ_POST,BADMEM,BADBLOCK,BADSTACK 	  ;3.30
	PUBLIC	INSUFMEMORY,BADCOUNTRYCOM				  ;3.30
									  ;3.30
include sysimes.inc							  ;3.30
									  ;3.30
SYSSIZE LABEL	BYTE							  ;3.30
									  ;3.30
PATHEND 	001,SYSMES						  ;3.30
									  ;3.30
SYSINITSEG	ENDS							  ;3.30
	END								  ;3.30
