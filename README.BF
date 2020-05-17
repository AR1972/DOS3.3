	    DOCUMENTATION FOR MS-DOS 3.30 BUGFIX DISKETTE

This diskette contains code for bugfixes in the MS-DOS 3.30 Release that
are corrected in the Microsoft MS-DOS 3.30 Packaged Product.  These may also
be corrected in an OEM's 3.30 product by utilizing the code on this diskette.
To to this, just copy the files on this disk over the corresponding files in
the DISTRIBUTION DISKETTE tree before doing the builds and making up your
OEM product.

     *********************************************************************

     Problem:	FDISK: logical drive creation doesn't show on fdisk.

	   Run FDISK. Create a primary partition and then an extended
	   partition. While creating the extended partition the menu
	   sequence to create logical drives in the extended partition
	   should turn up, but it doesn't.

     Solution:
	   
	   Difference in versions of the C compiler (we used C 4.0
	   instead of C 3.0) exposed a bug in the forcing of a constant
	   to a long unsigned number. The two compilers treat this
	   differently. 

	   Changes made were:
	 
	   a) FDISK.H : line 14  DOS_MAX = 64*1024 ....old
				 DOS_MAX = 65536L  ....new
	   b) INT13.C : (not related to problem, was just something
			 noticed along the way)
		   	line 148   max_head[0] ...old
			   	   max_head[i] ...new


     *************************************************************************

     MS-DOS 3.30 Beta FORMAT d: /S on very small partitions problem

     Description:    Attempting to do a FORMAT d: /S on a hard disk partition
		that is smaller than the space required for the system files
		resulted in the system files overwritting other partitions
		and format reporting approximately 4 GB of free space.

     Problem:	The problem is simply that a check is never done to see if
		enough free space exists to load the system files after the
		formatting is done.  This problem also occurs on PC-DOS 3.30.

     Solution:	The solution is to add a check to make sure that there is
		enough free space for the system files before we attempt to
		copy them.  This was done by adding a routine called
		CHKSPACE which is called just before WRITEDOS in the module
		FORMAT.ASM.  CHKSPACE uses DOS interrupt Get Disk Free Space
		and compares the number of available clusters with the number
		required for the system files.	If the amount of free space
		is greater than or equal to the amount of space required by
		the system files, CHKSPACE returns with the carry flag clear.
		Otherwise, it returns withe the carry flag set.  Following the
		call to CHKSPACE is a check for carry.	If carry is set, the
		message "No room for system on destination disk" is printed
		and the system files are not copied.  If carry is not set,
		control continues on to WRITEDOS.

     Modules:	Fixing this bug required changing FORMAT.ASM, MESSAGES.ASM,
		and MESSAGES.INC.

     Documentation: The entry for "No room for system on destination disk" in
		the messages section of the DOS manual states that this error
		message is the result of a SYS command.  This should be changed
		to read SYS or FORMAT.	In addition, the entry assumes that the
		destination disk is always a diskette and suggests that the
		appropriate action is to format a blank diskette with the /S
		option.  This will do you no good if you are trying to add the
		system files to a hard disk partition.	The recommended action
		should include using FDISK to make the partition larger and
		retrying the command if the error occured while attempting to
		format a hard disk partition with the /S option.


     **************************************************************************

     Problem:	Volumes in abundance cause boot problems.

	   Create primary partition and then the extended partition.
	   in the extended partition create the maximum number of
	   volumes permitted, i.e. 23. Try booting machine off a 3.30
	   floppy the machine is down on its knees. Problem doesn't
	   exist if you have volumes < 23. Problem only on 6M AT.

     Solution:
	
	   MSBIO2 has a buffer of 23 BDSMs at the end. MSBIO2 is followed
	   by MSHARD. Since the BDSMs are substancially long in size 
	   the bios relocates MSHARD to the paragraph boundary after
	   the last BDSM used. This works fine for volumes < 23. 
	   However if all 23 BDSMs are used up MSHARD is relocated to
	   the next para boundary which happens to be within MSHARD
	   itself. So MSHARD ends up destroying itself.

	   Fix - a para buffer between the last BDSM and MSHARD in 
	   MSBIO2.ASM.


     **********************************************************************

     Problem:

	   On exercising last two sysinit error messages dos code is
	   displayed instead of just the messages.

     Solution:

	  In calculating the location where to load dos, a constant is
	  used to indicate the size of the sysinit segment. this is 
	  different for us. 

     Changes:  In msequ.inc changed sysize from 200 to 203.

     Further changes planned: Change the sysize constant to a variable sizing
	  the sysinit segment.


     *************************************************************************

     Problem:  type filename > "=" hangs the system.

	Not only = in quotes but any delimitor causes problems.

	This comes from a basic lack of consistency in the treatment
	of the role of the " character. In command line parsing anything
	between " ----- " is not interpreted. But in forming filenames
	a " is taken as a valid character. Once the '>' character is 
	reached the parser begins forming the filename and takes " as
	the first character. The following = is taken as a delimitor and
	the filename ended. When the filename is formed the processing
	returns to the command line parsing main routine and sees the 
	next ". After this it just moves anything that comes along till
	it meets the next quote and ends up destroying the stack.

     Solution: changed filename parsing code to test for quote and decrement
	  the number of quotes. File changed - tmisc1.asm


     ************************************************************************

     Problem:	DOS FDISK creates partition which overlaps Xenix partition.

	   Create bad track table (xenix) and then a xenix partition 
	   which occupies whole disk. then boot dos and create partiton
	   asking it to use all of the space for dos. It just does that
	   overlapping the partition over the xenix partition.

     Problem:	3.3 fdisk was not handling the no space condition.

     Solution:

	   added code to detect no space condition and report error on
	   such a condition. files changed fdisk.c and space.c. also
	   when dos tries to create primary partition with a space 
	   requested from the user added error message when there is
	   no space.


     ************************************************************************

     Problem:

     The bug is that the routine make_partition had been checking for a free
     "slot" in the Master Boot Record and aborting the menu if there was none.
     This action is not desirable if the user wishes to create a Logical DOS
     volume in an existing Extended DOS Partition.

     There are several circumstances where this problem becomes evident.
     Probably the most common problem would be experienced on a large hard disk with several
     DOS partitions defined on it (COMPAQ is not the only OEM to support
     multiple DOS partitions on a hard disk...).

     Consider a disk with 4 DOS partitions defined on it and the user wants to
     delete ONE of the DOS partitions so that an Extended DOS partition may be
     defined.  After doing this, the ext_create_partition routine allows the
     user to define logical DOS volumes.

     The user decides that the Logical DOS Volumes he previously created are not
     satisfactory after having left FDISK, perhaps he had previously defined
     only one Logical DOS Volume and it did not use the entire Extended
     Partition.

     This time FDISK will not allow the user to select the Create Logical
     Volume menu option because there are no free "slots" in the Master Boot
     Record although there may well be plenty of space within the Extended DOS
     partition.

     NOTE: This problem also occurs with the OS/2 implementation of FDISK.


     *************************************************************************

     Problem:  Extend file handle count is broken.

     Solution: The para calculation code in handle.asm to calculate the number
	  of paragraphs needed is coded wrongly. For handle values
	  less than a para away from the maximum this will cause a carry.
	  The subsequent rotate by 4 should shift the carry in. IBM 3.3
	  doesn't use the appropriate rotate instruction.

     **************************************************************************

     Problem:	 Disk info initialisation in extended volume wrongly done.

            The problem involves creation of Logical DOS Volumes in
            an Extended DOS Partition.  As you know, each Logical DOS Volume
            has a "dummy" Master Boot Record which is necessary to define
            the extent of its Logical Volume and to indicate the location of
            the next Logical Volume (if one exists).  The "dummy" Master
            Boot Record for each Logical Volume (except the last one)
            contains an entry with a system indicator byte with the value of
            5 - this is the pointer to the next volume.  The END_HEAD number
            of this type 5 record is ONE greater than the greatest physical
            head number on the drive.
    
    
            This occurs because the entries in the "max_head" array are
            initialized to be one more than the greatest physical head
            number in the routine "get_disk_info()" in the file INT13.C for
            use in calculations.  The routine "write_ext_boot_to_disk" in
            the file DISKOUT.C does not subtract one from the max_head value
            before placeing it into the extended boot record - which is what
            results in the "End_Head" field being wrong for the type 5
            record.
    
            The line in "write_ext_boot_to_disk" where the subtraction
            should take place is shown below...
    
            /* End head */
            boot_record[0x1D3] = max_head[disk];

     Solution:	 As mentioned above the line given above should be
	    boot_record[0x1d3] = max_head[disk] - 1;
