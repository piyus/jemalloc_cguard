.text
.globl fasan_limit
.globl fasan_interior
.globl fasan_check_interior
.globl fasan_bounds
.globl fasan_check_size
.extern san_page_fault_limit1
.extern san_base
.extern abort

#ARGS: rdi, rsi, rdx, rcx, r8, r9
#CALLEE-SAVED: RBX, R12-R15, RBP

#fasan_interior(char *base, char *ptr)
#fasan_check_interior(char *base, char *ptr, size_t ptrsz, char *limit);
#fasan_bounds(char *base, char *ptr, char *ptrlimit, char *limit);
#fasan_check_size(char *ptr, size_t ptrsz, char *limit);

fasan_check_size:
	mov %rdi, %rax
	shl $15, %rax
	shr $15, %rax
	add %rsi, %rax
	cmp %rax, %rdx
	jb 1f
	shr $48, %rdx
	jne 2f
	mov %rdi, %rax
	ret
1:
	movabs $(1ULL<<48), %rax
	or %rdi, %rax
	ret
2:
	int3
	ret

fasan_bounds:
	shl $15, %rsi
	shr $15, %rsi

	shl $15, %rdx
	shr $15, %rdx

	cmp %rdx, %rcx
	jb 3f

	cmp %rdi, %rsi
	jb 3f

	shr $48, %rdi
	jne 2f

	shr $48, %rcx
	jne 2f


	ret
3:
	call abort
	ret
2:
	int3
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
	mov %rdi, %rax
	shr $48, %rax
	jne 2f

	mov %rcx, %rax
	shr $48, %rax
	jne 2f

	shl $15, %rsi
	shr $15, %rsi

	add %rsi, %rdx

	cmp %rdx, %rcx
	jb 3f

	cmp %rdi, %rsi
	jb 3f

	sub %rsi, %rdi
	neg %rdi
	mov $0x7FFF, %rax
	cmp %rdi, %rax
	cmova %rdi, %rax
	shl $49, %rax
	or %rsi, %rax
	ret

3:
	movabs $(1ULL<<48), %rax
	or %rsi, %rax
	ret

2:
	int3
	ret


# char *fasan_limit(char *base)
fasan_limit:
	mov %rdi, %rax
	shr $49, %rax
	cmp $0x7FFF, %rax
	jl 1f
	

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
	mov %rdi, %rax
	shl $16, %rax
	shr $16, %rax
	ret
