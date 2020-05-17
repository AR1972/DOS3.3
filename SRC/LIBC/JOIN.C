/***	MSDOS JOIN Utility		Vers 4.0
 *
 *  This utility allows the splicing of a physical drive to a pathname
 *  on another physical drive such that operations performed using the
 *  pathname as an arguement take place on the physical drive.
 *
 *  MODIFICATION HISTORY
 *
 *  Converted to CMERGE 03/26/85 by Greg Tibbetts
 *
 *  M000	May 23/85	Barrys
 *  Disallow splicing similar drives.
 *
 *  M001	May 24/85	Barrys
 *  The original IBM version of JOIN allowed the delete splice switch
 *  "/D" immediately after the drive specification.  The argument parsing
 *  code has been modified to allow this combination.
 *
 *  M002	June 5/85	Barrys
 *  Changed low version check for specific 320.
 *
 *  M003	July 15/85	Barrys
 *  Checked for any possible switch characters in the other operands.
 *
 *  M004	July 15/85	Barrys
 *  Moved check for physical drive before check for NET and SHARED tests.
 *
 *  33D0016	July 16/86	Rosemarie Gazzia
 *  Put SHARED test on an equal basis with physical drive check.
 *  Last fix (M004) erroneously allowed joining physical or local shared
 *  drives.  This is because it only performed the SHARED test if the drive
 *  failed the physical test.
 */

#include "types.h"
#include "versionc.h"
#include "sysvar.h"
#include "cds.h"
#include <dos.h>
#include <ctype.h>

extern char NoMem[], ParmNum[], BadParm[], DirNEmp[], NetErr[], BadVer[] ;
extern char *strchr();			/* M003 */

struct sysVarsType SysVars ;


/***	main - program entry point
 *
 *  Purpose:
 *	To test arguements for validity and perform the splice
 *
 *  int main(int c, char *v[])
 *
 *  Args:
 *	c - the number of command line arguements
 *	v - pointer to pointers to the command line arguements
 *
 *  Links:
 *	ERRTST.C - Drive and path validity testing functions
 *	SYSVAR.C - Functions to get/set DOS System Variable structures
 *	CDS.C	 - Functions to get/set DOS CDS structures
 *
 *  Returns:
 *	Appropriate return code with error message to stdout if
 *	necessary.
 *
 */

main(c, v)
int c ;
char *v[] ;
{
	char *strbscan() ;

	union REGS ir;
	register union REGS *iregs = &ir ;	/* Used for DOS calls */
	struct findType findbuf ;
	char path [MAXPATHLEN],*p ;
	struct CDSType CDS ;
	int i ;
	int	dstdrv; 			/* dest. drive number M000 */
	int	delflag = FALSE;		/* delete splice flag M001 */
	int	arglen; 			/* length of argument M001 */

	/* check os version */
	iregs->h.ah = GETVERS ; 		/* Function 0x30	   */
	intdos(iregs, iregs) ;

	if ( (iregs->h.al != expected_version_major) || (iregs->h.ah != expected_version_minor) )
	    Fatal(BadVer);

 /*	i = (iregs->h.al * 100) + iregs->h.ah;	 */
 /*	if (i < LowVersion || i > HighVersion)	 */
 /*		Fatal(BadVer) ; 		 */

	SHIFT(c,v) ;

	for (i=0 ; i < c ; i++) 	/* Convert to upper case	   */
		strupr(v[i]) ;

	GetVars(&SysVars) ;		/* Access to DOS data structures   */

	if (c > 2)			/* M001 */
		Fatal(ParmNum); 	/* M001 */

	if (c == 0)
		DoList() ;		/* list splices 		   */
	else {
		/* Process drive letter */
		i = **v - 'A' ;
		if ((*v)[1] != ':') {
			if (c == 1) {
				Fatal(ParmNum);
			}
			else {
				Fatal(BadParm) ;
			}
		}
		if (!fGetCDS(i, &CDS)) {
			Fatal(BadParm) ;
		}

		/* Accept arguments separate or mixed with drive spec  M001 */
		arglen = strlen(*v);
		if (arglen != 2) {
			if ((*v)[2] != SwitChr) {
				Fatal(ParmNum);
			}
			if (arglen != 4) {
				if (c == 1) {
					Fatal(BadParm);
				}
				else {
					Fatal(ParmNum);
				}
			}
			/* Advance arg pointer to possible switches */
			(*v)++; (*v)++;
		}
		else {
			SHIFT(c,v) ;
		}
		/* Check for splice deletion switch */
		if (**v == SwitChr) {
			if ((*v)[1] == 'D')
				delflag = TRUE;
			else {
				Fatal(BadParm);
			}
		}

		if (delflag == TRUE) {	/* Deassigning perhaps?    */

			if (!TESTFLAG(CDS.flags, CDSSPLICE)) {
				Fatal(BadParm) ; /* If NOT spliced */
			}

			if (fPathErr(CDS.text)) {
				Fatal(BadParm) ; /* If prefix of curdir */
			}

			CDS.text[0] = i + 'A' ;
			CDS.text[1] = ':' ;
			CDS.text[2] = '\\' ;
			CDS.text[3] = 0 ;
			CDS.cbEnd = 2 ;

			if (i >= SysVars.cDrv)
				CDS.flags = FALSE ;
			else
				CDS.flags = CDSINUSE ;
			GetVars(&SysVars) ;
			SysVars.fSplice-- ;
			PutVars(&SysVars) ;
			fPutCDS(i, &CDS) ;
		}
		else {
			/* Test if there are any other possible switches
			 * in the operand M003
			 */
			if (strchr(v[0], SwitChr)) {
				Fatal(ParmNum);
			}

			if (TESTFLAG(CDS.flags,CDSSPLICE)) {
				Fatal(BadParm) ; /* If now spliced */
			}

			rootpath(*v, path) ;	/* Get root path   */
			strupr(path) ;		/* Upper case	   */

			/* M004 Start */
			if (i == getdrv() ||	/* Can't mov curdrv */
			    fPathErr(path) ||	/* or curdir prefix */
			    *strbscan(path+3, "/\\") != 0 ||
			    !fPhysical(i)  ||
			    fShared(i))    {	/* 33D0016   RG    */
				/* Determine if it was a NET error */
				if (fNet(i) || fShared(i)) {
					Fatal(NetErr) ;
				}
				Fatal(BadParm) ;
			}

			if (fNet(path[0] - 'A') || fNet(path[0] - 'A')) {
				Fatal(NetErr) ; /* Same for dest   */
			}
			/* M004 End */


			/* Check src and dst drives are not same */
			dstdrv = *path - 'A';           /* M000 */
			if (i == dstdrv)		/* M000 */
				Fatal (BadParm);	/* M000 */
			if (mkdir(path) == -1) {  /* If can't mkdir */
						/* or if no dir or  */
						/* if node is file  */
				if (ffirst(path, A_D, &findbuf) == -1 ||
				    !TESTFLAG(findbuf.attr,A_D))
					Fatal(BadParm) ;

				p = path + strlen(path) ;
				strcat(p, "\\*.*") ;

				if (ffirst(path, 0, &findbuf) != -1)
					Fatal(DirNEmp) ; /* if dir   */
							/* not empty */
				*p = 0 ;
			} ;

			strcpy(CDS.text, path) ;
			CDS.flags = CDSINUSE | CDSSPLICE ;
			fPutCDS(i, &CDS) ;
			GetVars(&SysVars) ;
			SysVars.fSplice++ ;
			PutVars(&SysVars) ;
		} ;
	}
	exit(0) ;
}

DoList()
{
	int i ;
	struct CDSType CDS ;

	for (i=0 ; fGetCDS(i, &CDS) ; i++) {
		if (TESTFLAG(CDS.flags,CDSSPLICE))
			printf("%c: => %s\n", i+'A', CDS.text) ;
	} ;
}
