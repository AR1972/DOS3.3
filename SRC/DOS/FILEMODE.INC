;	SCCSID = @(#)filemode.asm	1.1 85/04/10
;	SCCSID = @(#)filemode.asm	1.1 85/04/10
BREAK <Standard I/O assignments>

stdin	    EQU     0
stdout	    EQU     1
stderr	    EQU     2
stdaux	    EQU     3
stdprn	    EQU     4

BREAK <File modes>

access_mask	EQU 0FH
open_for_read	EQU 00h
open_for_write	EQU 01h
open_for_both	EQU 02h

sharing_mask	    EQU 0F0H
sharing_compat	    EQU 000H
sharing_deny_both   EQU 010H
sharing_deny_write  EQU 020H
sharing_deny_read   EQU 030H
sharing_deny_none   EQU 040H
sharing_net_FCB     EQU 070h
sharing_no_inherit  EQU 080H
