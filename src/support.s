.text
.globl fasan_limit
.globl fasan_interior
.globl fasan_interior1
.globl fasan_check_interior
.globl fasan_check_interior1
.globl fasan_bounds
.globl fasan_bounds1
.globl fasan_check_size
.extern san_page_fault_limit1
.extern san_base
.extern abort

#ARGS: rdi, rsi, rdx, rcx, r8, r9
#CALLEE-SAVED: RBX, R12-R15, RBP

#fasan_interior(char *base, char *ptr)
#fasan_interior1(char *base, char *ptr)
#fasan_check_interior(char *base, char *ptr, size_t ptrsz, char *limit);
#fasan_check_interior1(char *base, char *ptr, size_t ptrsz, char *limit);
#fasan_bounds(char *base, char *ptr, char *ptrlimit, char *limit);
#fasan_bounds1(char *base, char *ptr, char *ptrlimit, char *limit);
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
	shr $48, %rdx
	jne 2f

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

	movw -8(%rdi), %si
	cmp $0xface, %si
	jne 2f

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

fasan_bounds1:
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
	shr $48, %rax
	jne 3f

	movw -8(%rdi), %ax
	cmp $0xface, %ax
	jne 3f


	shl $15, %rsi
	shr $15, %rsi

	sub %rsi, %rdi
	neg %rdi
	mov $0x7FFF, %rax
	cmp %rdi, %rax
	cmova %rdi, %rax
	shl $49, %rax
	or %rsi, %rax
	ret

3:
	int3
	ret

fasan_interior1:
	mov %rdi, %rax
	shr $48, %rax
	jne 3f


	shl $15, %rsi
	shr $15, %rsi

	sub %rsi, %rdi
	neg %rdi
	mov $0x7FFF, %rax
	cmp %rdi, %rax
	cmova %rdi, %rax
	shl $49, %rax
	or %rsi, %rax
	ret

3:
	int3
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

	movw -8(%rdi), %ax
	cmp $0xface, %ax
	jne 2f

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


fasan_check_interior1:
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

	movw -8(%rax), %di
	cmp $0xface, %di
	jne 2f

	ret

1:
	sub %rax, %rdi
	mov %rdi, %rax
	shl $16, %rax
	shr $16, %rax

	movw -8(%rax), %di
	cmp $0xface, %di
	jne 2f

	ret

2:
	int3
	ret
