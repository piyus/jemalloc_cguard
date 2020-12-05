.text
.globl fasan_limit
.extern san_page_fault_limit1


# char *fasan_limit(char *base)
fasan_limit:
	mov %rdi, %rax
	shr $49, %rax
	cmp $0x7FFF, %rax
	jle 1f
	
	push %rcx
	push %rdx
	push %rsi
	push %r8
	push %r9
	push %r10
	push %r11


	call san_page_fault_limit1

	pop %r11
	pop %r10
	pop %r9
	pop %r8
	pop %rsi
	pop %rdx
	pop %rcx
	ret

1:
	sub %rax, %rdi
	shl $15, %rdi
	shr $15, %rdi
	movl -4(%rdi), %eax
	add %rdi, %rax
	ret
