;;STRUC.INC--Stucture Macro Library
;;Version 2.10		03/07/86

if1
$noconj equ	0
$and		equ	1
$or		equ	2
$short		equ	3
$near		equ	4
$andor		=	0
$temp		=	0
$temp2		=	0
$dist		=	0

$notype equ	10
$conjif equ	11
$iftype equ	12
$elsetype	equ	13
$whiletype	equ	14
$conjwhile	equ	15
$repeattype	equ	16
$conjuntil	equ	17
$fortype	equ	18
$conjleave	equ	19

jbuild	macro	c1,c2,blank
j&c1	macro	tgt
.xcref	j&c1
					j&c2 tgt
	blank&endm
	endm

	irp	x,<<eq,e>,<lt,l>,<gt,g>,<neq,ne>,<nlt,nl>,<ngt,ng>,<npe,po>,<npo,pe>>
	jbuild	x
	endm

	irp	x,<a,ae,b,be,c,e,g,ge,l,le,o,p,s,z,cxz>
	jbuild	nn&x,x
	endm

jncxz	macro	tgt
	local	skip
					jcxz skip
					jmp short tgt
skip:
	endm

	purge	jbuild

$getconj macro	p1
	ifidn	<p1>,<and>
		$andor = $and
	endif
	ifidn	<p1>,<AND>
		$andor = $and
	endif
	ifidn	<p1>,<or>
		$andor = $or
	endif
	ifidn	<p1>,<OR>
		$andor = $or
	endif
	endm

$getdist macro	p1
	ifidn	<p1>,<short>
		$dist = $short
	endif
	ifidn	<p1>,<SHORT>
		$dist = $short
	endif
	ifidn	<p1>,<near>
		$dist = $near
	endif
	ifidn	<p1>,<NEAR>
		$dist = $near
	endif
	endm


$poke	macro	num,value
	$st&num = value
.xcref	$st&num
	endm

$peek	macro	sym,num
	sym	= $st&num
	endm

$push	macro	value
	$st	= $st+1
	$poke	%$st,value
	endm

$pop	macro	sym
	$peek	sym,%$st
	$st	= $st-1
	endm

$labl	macro	num
$l&num:
	endm

$cjump	macro	lnum,tf,cond,d1,d2
	local	skip
	$dist	= $defdist
	ifnb	<d1>
		$getdist d1
		ifnb		<d2>
			$getdist d2
		endif
	endif

	if	$dist eq $short
		ifb	<cond>
					jmp short $l&lnum
		else
			ifidn <tf>,<f>
					jn&cond $l&lnum
			else
					j&cond $l&lnum
			endif
		endif
	else
		ifnb	<cond>
			ifidn <tf>,<f>
					j&cond skip
			else
					jn&cond skip
			endif
		endif
					jmp $l&lnum
		ifnb		<cond>
skip:
		endif
	endif
	endm

$cloop	macro	lnum,cond
					loop&cond $l&lnum
	endm
;;*****************************************************************************
.if	macro	tst,p2,p3
	$if_2	p2,p3,tst
	endm
$if_2	macro	p1,p2,a1,a2,a3
	ifb	<a2>
		$if_3	,a1,,p1,p2
	else
		$if_3	<a1>,a2,<a3>,p1,p2
	endif
	endm
$if_3	macro	arg1,cond,arg2,p4,p5
	$peek	$temp,%$st
	if	$temp eq $conjif
		$pop	$temp
	else
		$push	$elseiffound
		$elseiffound = 0
		$orfound = 0
		$sn	= $sn+1
		$push	$sn
		$sn	= $sn+1
		$push	$sn
		$sn	= $sn+1
		$push	$sn
	endif

	$andor	= $noconj
	ifnb	<p4>
		$getconj p4
		ifnb	<p5>
			$getconj p5
		endif
	endif

	ifnb	<arg1>
					cmp arg1,arg2
	endif

	if	$andor eq $noconj
		$cjump %$sn-1,f,cond,p4,p5
		$pop	$temp
		if	 $orfound
			$labl  %$temp
		endif
		$push	$iftype
	else
		if	$andor eq $and
			$cjump %$sn-1,f,cond,p4,p5
		else
			$orfound = 1
			$cjump %$sn,t,cond,p4,p5
		endif
		$push	$conjif
	endif
	endm
;;*****************************************************************************
.then	macro
	$peek	$temp,%$st
	if	$temp ne $iftype
					structure error--then without if
	endif
	endm
;;*****************************************************************************
.elseif macro	tst,p2,p3
	$elseif_2 p2,p3,tst
	endm
$elseif_2 macro p1,p2,a1,a2,a3
	ifb	<a2>
		$elseif_3 ,a1,,p1,p2
	else
		$elseif_3 <a1>,a2,<a3>,p1,p2
	endif
	endm
$elseif_3 macro arg1,cond,arg2,p4,p5
	$pop	$temp
	if	$temp ne $iftype
					structure error--elseif without if
		exitm
	endif
	$elseiffound = 1
	$orfound = 0
	$pop	$temp
	$peek	$temp2,%$st
	$cjump	%$temp2,,,near
	$labl	%$temp
	$sn	= $sn+1
	$push	$sn
	$sn	= $sn+1
	$push	$sn

	$andor	= $noconj
	ifnb	<p4>
		$getconj p4
		ifnb	<p5>
			$getconj p5
		endif
	endif

	ifnb	<arg1>
					cmp arg1,arg2
	endif

	if	$andor eq $noconj
		$cjump %$sn-1,f,cond,p4,p5
		$pop	$temp
		if	$orfound
			$labl %$temp
		endif
		$push	$iftype
	else
		if	$andor eq $and
			$cjump %$sn-1,f,cond,p4,p5
		else
			$orfound = 1
			$cjump %$sn,t,cond,p4,p5
		endif
		$push	$conjif
	endif
	endm
;;*****************************************************************************
.else	macro	dist
	$pop	$temp
	if	$temp ne $iftype
					structure error--else without if
		exitm
	endif
	$sn	= $sn+1
	$cjump	%$sn,,,dist
	$pop	$temp
	$labl	%$temp
	$push	$sn
	$push	$elsetype
	endm
;;*****************************************************************************
.endif	macro
	$pop	$temp
	if	$temp ne $iftype
		if		$temp ne $elsetype
					structure error--endif without if
			exitm
		endif
	endif
	$pop	$temp
	$labl	%$temp
	$pop	$temp
	if	$elseiffound
		$labl	 %$temp
	endif
	$pop	$elseiffound
	endm
;;*****************************************************************************
.while	macro	tst,p2,p3
	$while_2	p2,p3,tst
	endm
$while_2 macro	p1,p2,a1,a2,a3
	ifb	<a2>
		$while_3 ,a1,,p1,p2
	else
		$while_3 <a1>,a2,<a3>,p1,p2
	endif
	endm
$while_3 macro	arg1,cond,arg2,p4,p5
	$peek	$temp,%$st
	if	$temp eq $conjwhile
		$pop		$temp
	else
		$push $endloop
		$orfound = 0
		$sn		= $sn + 1
		$push $sn
		$labl %$sn
		$sn		= $sn + 2
		$push $sn
		$endloop = $sn - 1
	endif

	$andor	= $noconj
	ifnb	<p4>
		$getconj p4
		ifnb		<p5>
			$getconj p5
		endif
	endif

	ifnb	<arg1>
					cmp arg1,arg2
	endif

	if	$andor eq $noconj
		$cjump %$sn-1,f,cond,p4,p5
		$pop		$temp
		if	$orfound
			$labl %$temp
		endif
		$push $whiletype
	else
		if	$andor eq $and
			$cjump	%$sn-1,f,cond,p4,p5
		else
			$orfound	= 1
			$cjump	%$sn,t,cond,p4,p5
		endif
		$push $conjwhile
	endif
	endm
;;*****************************************************************************
.endwhile macro
	$pop	$temp
	if	$temp ne $whiletype
					structure error -- endwhile without while
		exitm
	endif
	$pop	$temp
	$cjump	%$temp,,,near
	$labl	%$temp+1
	$pop	$endloop
	endm
;;*****************************************************************************
.repeat macro
	$push	$endloop
	$push	$leavefound
	$sn	= $sn+1
	$labl	%$sn
	$push	$sn
	$push	$repeattype
	$sn	= $sn+1
	$endloop = $sn
	$leavefound = 0
	endm
;;*****************************************************************************
.until	macro	tst,p2,p3
	$until_2	p2,p3,tst
	endm
$until_2 macro	p1,p2,a1,a2,a3
	ifb	<a1>
		$until_3 ,,,near
	else
		ifb		<a2>
			$until_3 ,a1,,p1,p2
		else
			$until_3 <a1>,a2,<a3>,p1,p2
		endif
	endif
	endm
$until_3 macro	arg1,cond,arg2,p4,p5
	$pop	$temp
	if	$temp ne $repeattype
		if		$temp ne $conjuntil
					structure error -- until without repeat
			exitm
		endif
	else
		$orfound = 0
	endif

	ifnb	<arg1>
					cmp arg1,arg2
	endif

	$andor	= $noconj
	ifnb	<p4>
		$getconj p4
		ifnb		<p5>
			$getconj p5
		endif
	endif

	if	$andor eq $noconj
		$pop		$temp
		$cjump %$temp,f,cond,p4,p5
		if		$orfound or $leavefound
			$labl %$temp+1
		endif
		$pop		$leavefound
		$pop		$endloop
	else
		$peek $temp,%$st
		if		$andor eq $and
			$cjump %$temp,f,cond,p4,p5
		else
			$orfound = 1
			$cjump %$temp+1,t,cond,p4,p5
		endif
		$push $conjuntil
	endif
	endm
;;*****************************************************************************
.loop	macro	cond
	$pop	$temp
	if	$temp ne $repeattype
					structure error -- loop without repeat
		exitm
	endif
	$pop	$temp
	$cloop	%$temp,cond
	if	$leavefound
		$labl %$temp+1
	endif
	$pop	$leavefound
	$pop	$endloop
	endm
;;*****************************************************************************
.for	macro	index,equals,start,to,stop,by,step,dist
					mov index,start
	$push	$endloop
	$sn	= $sn+1
	$push	$sn
	$labl	%$sn
	$sn	= $sn+1
	$endloop = $sn
					cmp index,stop

	ifb	<step>
		$push 1
		$cjump %$sn,t,gt,by
	else
		$push %(step)
		if		step lt 0
			$cjump %$sn,t,lt,dist
		else
			$cjump %$sn,t,gt,dist
		endif
	endif
	$push	$fortype
	endm
;;*****************************************************************************
.next	macro	index
	$pop	$temp
	if	$temp ne $fortype
					structure error -- next without for
		exitm
	endif
	$pop	$temp
	if	$temp eq 1
					inc index
	else
		if		$temp eq -1
					dec index
		else
					add index,$temp
		endif
	endif
	$pop	$temp
	$cjump	%$temp,,,near
	$labl	%$temp+1
	$pop	$endloop
	endm
;;*****************************************************************************
.leave	macro	tst,p2,p3
	$leave_2 p2,p3,tst
	endm

$leave_2 macro	p1,p2,a1,a2,a3
	$dist	= 0
	$getdist <a1>
	if	$dist
		$leave_3 ,,,a1
	else
		ifb		<a2>
			$leave_3 ,a1,,p1,p2
		else
			$leave_3 <a1>,a2,<a3>,p1,p2
		endif
	endif
	endm

$leave_3 macro	arg1,cond,arg2,p4,p5
	ife	$endloop
					structure error--leave outside a loop
		exitm
	endif
	$leavefound = 1
	$peek	$temp,%$st
	if	$temp eq $conjleave
		$pop		$temp
	else
		$orfound = 0
		$sn		= $sn + 1
	endif

	$andor	= $noconj
	ifnb	<p4>
		$getconj p4
		ifnb		<p5>
			$getconj p5
		endif
	endif

	ifnb	<arg1>
					cmp arg1,arg2
	endif

	if	$andor eq $noconj
		$cjump %$endloop,t,cond,p4,p5
		if	$orfound
			$labl %$sn
		endif
	else
		if	$andor eq $and
			$orfound	= 1
			$cjump	%$sn,f,cond,p4,p5
		else
			$cjump	%$endloop,t,cond,p4,p5
		endif
		$push $conjleave
	endif
	endm
;;*****************************************************************************
else
	$pop	 $temp
	if	 $temp ne $notype
					structure error -- open structure(s)
	endif
	.xcref $noconj,$and,$or,$short,$near,$andor,$temp,$temp2,$dist
	.xcref $notype,$conjif,$iftype,$elsetype,$whiletype,$conjwhile
	.xcref $repeattype,$conjuntil,$fortype,$conjleave,jncxz
	.xcref jeq,jgt,jlt,jneq,jngt,jnlt,jnna,jnnae,jnnb,jnnbe,jnnc,jnncxz
	.xcref jnne,jnng,jnnge,jnnl,jnnle,jnno,jnnp,jnns,jnnz,jnpe,jnpo,jbuild
	.xcref $getconj,$getdist,$poke,$peek,$push,$pop,$labl,$cjump,$cloop
	.xcref $if_2,$if_3,$elseif_2,$elseif_3,$while_2,$while_3
	.xcref $until_2,$until_3,$leave_2,$leave_3
	.xcref $st,$sn,$orfound,$elseiffound,$endloop,$leavefound,$defdist
endif
$st		= 0
$sn		= 0
$orfound	= 0
$elseiffound	= 0
$endloop	= 0
$leavefound	= 0
$defdist	= $short
$push	%$notype
