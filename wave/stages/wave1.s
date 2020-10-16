;;; read in warm program, search for halt
	lea	warm,r0
	mov	$0x0,r1		; program counter
	trap	$SysOverlay
	cmp	$0x06800000,warm(r0)
	jne	loop
	trap	$SysPutNum
	mov	$'\n,r0
	trap	$SysPutChar
	trap	$SysHalt
loop:	add	$1,r1		; incrementing pc
	mov	r1,r0
	cmp	$0x06800000,warm(r0)
	jne	loop
	mov	r1,r0
	trap	$SysPutNum
	mov	$'\n,r0
	trap	$SysPutChar
	trap	$SysHalt
	
;;; warm overlay loading area
	.origin 1000
warm:
