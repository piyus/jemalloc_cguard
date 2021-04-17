.text
.globl fasan_limit
.globl fasan_limit_check
.globl fasan_interior
.globl fasan_interior1
.globl fasan_check_interior
.globl fasan_check_interior1
.globl fasan_bounds
.globl fasan_bounds1
.globl fasan_check_size
.extern san_page_fault_limit1
.extern san_get_limit_check
.extern abort
.extern san_abort

# .comm name, size, alignment

.comm MinGlobalAddr, 8, 8
.comm MaxGlobalAddr, 8, 8
.comm MinLargeAddr, 8, 8
.comm __text_start, 8, 8
.comm __text_end, 8, 8
.comm GlobalCache, 32, 8
.comm LastCrashAddr1, 8, 8
.comm LastCrashAddr2, 8, 8

#ARGS: rdi, rsi, rdx, rcx, r8, r9
#CALLEE-SAVED: RBX, R12-R15, RBP

#fasan_interior(char *base, char *ptr)
#fasan_interior1(char *base, char *ptr)
#fasan_check_interior(char *base, char *ptr, size_t ptrsz, char *limit);
#fasan_check_interior1(char *base, char *ptr, size_t ptrsz, char *limit);
#fasan_bounds(char *base, char *ptr, char *ptrlimit, char *limit);
#fasan_bounds1(char *base, char *ptr, char *ptrlimit, char *limit);
#fasan_check_size(char *ptr, size_t ptrsz, char *limit);
# char *fasan_limit(char *base)
# char *fasan_limit_check(char *base)

fasan_limit_check:
	movabs $(1ULL<<48), %rax
	and %rdi, %rax
	jne 3f

	mov %rdi, %rax
	shl $15, %rax
	shr $15, %rax

	cmp MinGlobalAddr, %rax
	jbe 3f

	mov %rdi, %rax
	shr $49, %rax
	cmp $0x7FFF, %rax
	jae 1f

	sub %rax, %rdi
	mov %rdi, %rax
	shl $16, %rax
	shr $16, %rax

	movw -8(%rax), %di
	jmp 4f
	nop
	nop
	nop
	nop
	nop
	nop
	nop
4:
	cmp $0xface, %di
	jne 3f
	ret

1:
	movabs $0xFFFF00000000ULL, %rax
	and %rdi, %rax
	cmp MaxGlobalAddr, %rax
	jbe 5f
	and (%rax), %rdi
	add $8, %rdi
	mov %rdi, %rax
	ret

5:
	push %rdi
	push %rcx

	shl $15, %rdi
	shr $15, %rdi

	movq GlobalCache, %rax
	cmp %rdi, %rax
	ja 10f
	movl -4(%rax), %ecx
	add %rax, %rcx
	cmp %rdi, %rcx
	jbe 10f

	pop %rcx
	pop %rdi
	ret
10:
	movq GlobalCache+8, %rax
	cmp %rdi, %rax
	ja 10f
	movl -4(%rax), %ecx
	add %rax, %rcx
	cmp %rdi, %rcx
	jbe 10f

	pop %rcx
	pop %rdi
	ret

10:
	movq GlobalCache+16, %rax
	cmp %rdi, %rax
	ja 10f
	movl -4(%rax), %ecx
	add %rax, %rcx
	cmp %rdi, %rcx
	jbe 10f

	pop %rcx
	pop %rdi
	ret

10:
	movq GlobalCache+24, %rax
	cmp %rdi, %rax
	ja 10f
	movl -4(%rax), %ecx
	add %rax, %rcx
	cmp %rdi, %rcx
	jbe 10f

	pop %rcx
	pop %rdi
	ret


10:
	pop %rcx
	pop %rdi


	push %rcx
	push %rdx
	push %rsi
	push %r8
	push %r9
	push %r10
	push %r11


	call san_get_limit_check

	pop %r11
	pop %r10
	pop %r9
	pop %r8
	pop %rsi
	pop %rdx
	pop %rcx

	cmp $0, %rax
	je 3f

	movw -8(%rax), %di
	cmp $0xface, %di
	jne 2f
	ret

2:
	int3
	ret

3:
	xor %rax, %rax
	ret


fasan_limit_check1:
	movabs $(1ULL<<48), %rax
	and %rdi, %rax
	jne 3f

	mov %rdi, %rax
	shl $15, %rax
	shr $15, %rax

	cmp MinGlobalAddr, %rax
	jbe 3f

	mov %rdi, %rax
	shr $49, %rax
	cmp $0x7FFF, %rax
	jl 1f

	movabs $0xFFFF00000000ULL, %rax
	and %rdi, %rax

	cmp MaxGlobalAddr, %rax
	jbe 5f

	push %rcx
	movq 8(%rax), %rcx
	cmp $0xdeaddeed, %ecx
	jne 2f
	and (%rax), %rdi
	add $8, %rdi
	mov %rdi, %rax
	movw -8(%rax), %di
	cmp $0xface, %di
	jne 2f
	pop %rcx
	ret

5:

	push %rdi
	push %rcx

	shl $15, %rdi
	shr $15, %rdi

	movq GlobalCache, %rax
	cmp %rdi, %rax
	ja 10f
	movl -4(%rax), %ecx
	add %rax, %rcx
	cmp %rdi, %rcx
	jbe 10f

	pop %rcx
	pop %rdi
	ret
10:
	movq GlobalCache+8, %rax
	cmp %rdi, %rax
	ja 10f
	movl -4(%rax), %ecx
	add %rax, %rcx
	cmp %rdi, %rcx
	jbe 10f

	pop %rcx
	pop %rdi
	ret

10:
	movq GlobalCache+16, %rax
	cmp %rdi, %rax
	ja 10f
	movl -4(%rax), %ecx
	add %rax, %rcx
	cmp %rdi, %rcx
	jbe 10f

	pop %rcx
	pop %rdi
	ret

10:
	movq GlobalCache+24, %rax
	cmp %rdi, %rax
	ja 10f
	movl -4(%rax), %ecx
	add %rax, %rcx
	cmp %rdi, %rcx
	jbe 10f

	pop %rcx
	pop %rdi
	ret


10:
	pop %rcx
	pop %rdi


	push %rcx
	push %rdx
	push %rsi
	push %r8
	push %r9
	push %r10
	push %r11


	call san_get_limit_check

	pop %r11
	pop %r10
	pop %r9
	pop %r8
	pop %rsi
	pop %rdx
	pop %rcx

	cmp $0, %rax
	je 3f

	movw -8(%rax), %di
	cmp $0xface, %di
	jne 2f

	ret

1:
	sub %rax, %rdi
	mov %rdi, %rax
	shl $16, %rax
	shr $16, %rax

	mov %rax, %rdi
	shr $12, %rdi
	#cmp %rdi, LastCrashAddr1
	#je 3f
	#cmp %rdi, LastCrashAddr2
	#je 3f
	movw -8(%rax), %di
	jmp 4f
	nop
	nop
	nop
	nop
	nop
	nop
	nop
4:
	cmp $0xface, %di
	jne 5f

	ret

#1:
#	cmp $0x1dead, %rdi
#	je 3f
#	cmp __text_start, %rax
#	jb 2f
#	cmp __text_end, %rax
#	jae 2f
#	jmp 3f

2:
	int3
	ret

3:
	xor %rax, %rax
	ret

5:
	#mov LastCrashAddr1, %rax
	#mov %rdi, LastCrashAddr1
	#mov %rax, LastCrashAddr2
	xor %rax, %rax
	ret
	
	

fasan_check_size:
	int3
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
#	int3

	cmp %rdx, %rcx
	jb 3f

	cmp %rdi, %rsi
	jb 3f

	movw -8(%rdi), %si
	cmp $0xface, %si
	jne 2f

	ret
3:
	int3
	xor %rdi, %rdi
	call san_abort
	ret
2:
	int3
	xor %rdi, %rdi
	call san_abort
	ret

fasan_bounds1:
#	int3

	cmp %rdx, %rcx
	jb 3f

	cmp %rdi, %rsi
	jb 3f

	ret
3:
	int3
	xor %rdi, %rdi
	call san_abort
	ret
2:
	int3
	xor %rdi, %rdi
	call san_abort
	ret


fasan_interior:
	int3
	mov %rdi, %rax
	shr $48, %rax
	jne 3f

	movw -8(%rdi), %ax
	cmp $0xface, %ax
	jne 3f

	mov %rsi, %rax
	shr $49, %rax
	jne 3f

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
	int3
	mov %rdi, %rax
	shr $48, %rax
	jne 3f

	mov %rsi, %rax
	shr $49, %rax
	jne 3f


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
	int3
	mov %rdi, %rax
	shr $48, %rax
	jne 2f

	mov %rcx, %rax
	shr $48, %rax
	jne 2f

	mov %rsi, %rax
	shr $49, %rax
	jne 2f

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
	int3
	mov %rdi, %rax
	shr $48, %rax
	jne 2f

	mov %rcx, %rax
	shr $48, %rax
	jne 2f

	mov %rsi, %rax
	shr $49, %rax
	jne 2f

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

fasan_limit:
	mov %rdi, %rax
	shr $49, %rax
	cmp $0x7FFF, %rax
	jae 1f
	sub %rax, %rdi
	mov %rdi, %rax
	shl $16, %rax
	shr $16, %rax
	ret

1:
	movabs $0xFFFF00000000ULL, %rax
	and %rdi, %rax
	cmp MaxGlobalAddr, %rax
	jbe 5f
	and (%rax), %rdi
	add $8, %rdi
	mov %rdi, %rax
	ret

5:
	push %rcx

	shl $15, %rdi
	shr $15, %rdi

	movq GlobalCache, %rax
	cmp %rdi, %rax
	ja 10f
	movl -4(%rax), %ecx
	add %rax, %rcx
	cmp %rdi, %rcx
	jbe 10f

	pop %rcx
	ret
10:
	movq GlobalCache+8, %rax
	cmp %rdi, %rax
	ja 10f
	movl -4(%rax), %ecx
	add %rax, %rcx
	cmp %rdi, %rcx
	jbe 10f

	pop %rcx
	ret

10:
	movq GlobalCache+16, %rax
	cmp %rdi, %rax
	ja 10f
	movl -4(%rax), %ecx
	add %rax, %rcx
	cmp %rdi, %rcx
	jbe 10f

	pop %rcx
	ret

10:
	movq GlobalCache+24, %rax
	cmp %rdi, %rax
	ja 10f
	movl -4(%rax), %ecx
	add %rax, %rcx
	cmp %rdi, %rcx
	jbe 10f

	pop %rcx
	ret


10:
	mov $0xFFFE, %rax
	shl $48, %rax
	or %rax, %rdi

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


2:
	int3
	ret


# char *fasan_limit(char *base)
fasan_limit1:
	mov %rdi, %rax
	shr $49, %rax
	cmp $0x7FFF, %rax
	jl 1f

	movabs $0xFFFF00000000ULL, %rax
	and %rdi, %rax

	cmp MaxGlobalAddr, %rax
	jbe 5f

	push %rcx
	movq 8(%rax), %rcx
	cmp $0xdeaddeed, %ecx
	jne 2f
	and (%rax), %rdi
	add $8, %rdi
	mov %rdi, %rax
	movw -8(%rax), %di
	cmp $0xface, %di
	jne 2f
	pop %rcx
	ret

5:
	push %rdi
	push %rcx

	shl $15, %rdi
	shr $15, %rdi

	movq GlobalCache, %rax
	cmp %rdi, %rax
	ja 10f
	movl -4(%rax), %ecx
	add %rax, %rcx
	cmp %rdi, %rcx
	jbe 10f

	pop %rcx
	pop %rdi
	ret
10:
	movq GlobalCache+8, %rax
	cmp %rdi, %rax
	ja 10f
	movl -4(%rax), %ecx
	add %rax, %rcx
	cmp %rdi, %rcx
	jbe 10f

	pop %rcx
	pop %rdi
	ret

10:
	movq GlobalCache+16, %rax
	cmp %rdi, %rax
	ja 10f
	movl -4(%rax), %ecx
	add %rax, %rcx
	cmp %rdi, %rcx
	jbe 10f

	pop %rcx
	pop %rdi
	ret

10:
	movq GlobalCache+24, %rax
	cmp %rdi, %rax
	ja 10f
	movl -4(%rax), %ecx
	add %rax, %rcx
	cmp %rdi, %rcx
	jbe 10f

	pop %rcx
	pop %rdi
	ret


10:
	pop %rcx
	pop %rdi


	

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
