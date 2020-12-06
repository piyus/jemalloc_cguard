.text
.globl fasan_limit
.globl fasan_interior
.globl fasan_check_interior
.globl fasan_bounds
.extern san_page_fault_limit1
.extern san_base
.extern abort

#ARGS: rdi, rsi, rdx, rcx, r8, r9
#CALLEE-SAVED: RBX, R12-R15, RBP

#fasan_interior(char *base, char *ptr)
#fasan_check_interior(char *base, char *ptr, size_t ptrsz, char *limit);
#fasan_bounds(char *base, char *ptr, char *ptrlimit, char *limit);

fasan_bounds:

	cmp %rdx, %rcx
	jb 3f

	mov %rdi, %rdx
	shr $49, %rdx
	sub %rdx, %rdi

	cmp %rdi, %rsi
	jae 1f

	push %rax
	push %rsi
	push %r8
	push %r9
	push %r10
	push %r11


	call san_base
	mov %rax, %rdx

	pop %r11
	pop %r10
	pop %r9
	pop %r8
	pop %rsi
	pop %rax


	cmp $0, %rdx
	je 3f

	shl $16, %rsi
	shr $16, %rsi

	cmp %rdx, %rsi
	jb 3f

1:
	ret
3:
	call abort
	ret


fasan_interior:
	mov %rdi, %rax
	shr $49, %rax
	cmp $0x7FFF, %rax
	jae 1f

	sub %rsi, %rdi
	neg %rdi
	add %rdi, %rax
	mov $0x7FFF, %rdi
	cmp %rdi, %rax
	cmova %rdi, %rax
  shl $15, %rsi
  shr $15, %rsi
	shl $49, %rax
	or %rax, %rsi

1:
	mov %rsi, %rax
	ret

fasan_check_interior:
	add %rsi, %rdx
	cmp %rcx, %rdx
	ja 3f

	mov %rdi, %rax
	shr $49, %rax

	mov %rdi, %rdx
	sub %rax, %rdx

	cmp %rdx, %rsi
	jae 2f

	cmp $0x7FFF, %rax
	jb 3f

#	sub     $16, %rsp
#	movdqu  %xmm0, (%rsp)
#	sub     $16, %rsp
#	movdqu  %xmm1, (%rsp)
#	sub     $16, %rsp
#	movdqu  %xmm2, (%rsp)
#	sub     $16, %rsp
#	movdqu  %xmm3, (%rsp)
#	sub     $16, %rsp
#	movdqu  %xmm4, (%rsp)
#	sub     $16, %rsp
#	movdqu  %xmm5, (%rsp)
#	sub     $16, %rsp
#	movdqu  %xmm6, (%rsp)
#	sub     $16, %rsp
#	movdqu  %xmm7, (%rsp)


	push %rdi
	push %rcx
	push %rdx
	push %rsi
	push %r8
	push %r9
	push %r10
	push %r11


	call san_base

	pop %r11
	pop %r10
	pop %r9
	pop %r8
	pop %rsi
	pop %rdx
	pop %rcx
	pop %rdi

#	movdqu  (%rsp), %xmm7
#	add     $16, %rsp
#	movdqu  (%rsp), %xmm6
#	add     $16, %rsp
#	movdqu  (%rsp), %xmm5
#	add     $16, %rsp
#	movdqu  (%rsp), %xmm4
#	add     $16, %rsp
#	movdqu  (%rsp), %xmm3
#	add     $16, %rsp
#	movdqu  (%rsp), %xmm2
#	add     $16, %rsp
#	movdqu  (%rsp), %xmm1
#	add     $16, %rsp
#	movdqu  (%rsp), %xmm0
#	add     $16, %rsp


	cmp $0, %rax
	je 3f

	mov %rsi, %rdx

	shl $16, %rdx
	shr $16, %rdx

	cmp %rax, %rdx
	jb 3f

	mov %rdi, %rax
	shr $49, %rax

2:

	cmp $0x7FFF, %rax
	jae 1f

	sub %rsi, %rdi
	neg %rdi
	add %rdi, %rax
	mov $0x7FFF, %rdi
	cmp %rdi, %rax
	cmova %rdi, %rax
  shl $15, %rsi
  shr $15, %rsi
	shl $49, %rax
	or %rax, %rsi

1:
	mov %rsi, %rax
	ret
3:
	movabs $(1ULL<<48), %rax
	or %rsi, %rax
	ret


# char *fasan_limit(char *base)
fasan_limit:
	mov %rdi, %rax
	shr $49, %rax
	cmp $0x7FFF, %rax
	jl 1f
	
#	sub     $16, %rsp
#	movdqu  %xmm0, (%rsp)
#	sub     $16, %rsp
#	movdqu  %xmm1, (%rsp)
#	sub     $16, %rsp
#	movdqu  %xmm2, (%rsp)
#	sub     $16, %rsp
#	movdqu  %xmm3, (%rsp)
#	sub     $16, %rsp
#	movdqu  %xmm4, (%rsp)
#	sub     $16, %rsp
#	movdqu  %xmm5, (%rsp)
#	sub     $16, %rsp
#	movdqu  %xmm6, (%rsp)
#	sub     $16, %rsp
#	movdqu  %xmm7, (%rsp)


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

#	movdqu  (%rsp), %xmm7
#	add     $16, %rsp
#	movdqu  (%rsp), %xmm6
#	add     $16, %rsp
#	movdqu  (%rsp), %xmm5
#	add     $16, %rsp
#	movdqu  (%rsp), %xmm4
#	add     $16, %rsp
#	movdqu  (%rsp), %xmm3
#	add     $16, %rsp
#	movdqu  (%rsp), %xmm2
#	add     $16, %rsp
#	movdqu  (%rsp), %xmm1
#	add     $16, %rsp
#	movdqu  (%rsp), %xmm0
#	add     $16, %rsp



	ret

1:
	sub %rax, %rdi
	mov %rdi, %rax
	shl $15, %rdi
	shr $15, %rdi
	movl -4(%rdi), %edi
	add %rdi, %rax
	ret
