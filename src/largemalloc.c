#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <string.h>
#include <fcntl.h>
#include <elf.h>
#include <assert.h>
#include <pthread.h>

typedef unsigned long long ulong64;

#define SEGMENT_SIZE (1ULL << 32)
#define PAGE_SIZE 4096
#define Align(x, y) (((x) + (y-1)) & ~(y-1))
#define ADDR_TO_PAGE(x) (char*)(((ulong64)(x)) & ~(PAGE_SIZE-1))
#define ADDR_TO_SEGMENT(x) (Segment*)(((ulong64)(x)) & ~(SEGMENT_SIZE-1))
#define MAX_ULONG 0xFFFFFFFFFFFFFFFFULL


typedef struct Segment
{
	size_t AlignmentMask;
	size_t AlignedSize;
	size_t NumFreePages;
	size_t MaxBitMapIndex;
	struct Segment *Next;
	unsigned long long BitMap[];
} Segment;

size_t GetLargeIndex(size_t size)
{
  size_t i;
  for (i = 0; i < 48; i++) {
    if ((1ULL << i) >= size) {
      assert(i <= 31 && i >= 16);
      return i - 16;
    }
  }
	assert(0);
  return -1;
}

struct Segment *Segments[32] = {NULL};

static void allowAccess(void *Ptr, size_t Size)
{
	Size = Align(Size, PAGE_SIZE);
	assert(((ulong64)Ptr & (PAGE_SIZE-1)) == 0);

	int Ret = mprotect(Ptr, Size, PROT_READ|PROT_WRITE);
	if (Ret == -1)
	{
		printf("unable to mprotect %s():%d\n", __func__, __LINE__);
		exit(0);
	}
}

static Segment* allocateSegment(size_t Idx)
{
	void* Base = mmap(NULL, SEGMENT_SIZE * 2, PROT_NONE, MAP_ANON|MAP_PRIVATE, -1, 0);
	if (Base == MAP_FAILED)
	{
		printf("unable to allocate a segment\n");
		exit(0);
	}

	/* segments are aligned to segment size */
	Segment *S = (struct Segment*)Align((ulong64)Base, SEGMENT_SIZE);

	size_t AlignShift = Idx + 16;
	assert(AlignShift < 32);
	size_t Alignment = (1ULL << AlignShift);
	size_t AlignmentMask = ~(Alignment-1);
	AlignmentMask = (AlignmentMask << 15) >> 15;
	size_t BitmapSize = SEGMENT_SIZE / Alignment;
	BitmapSize = BitmapSize / 64;

	assert(BitmapSize > 0);

	size_t MetadataSize = (BitmapSize * 8) + sizeof(struct Segment);
	allowAccess(S, MetadataSize);
	S->MaxBitMapIndex = BitmapSize;
	S->NumFreePages = BitmapSize * 64;
	S->AlignmentMask = AlignmentMask;
	S->AlignedSize = Alignment;
	S->Next = NULL;

	return S;
}

static void reclaimMemory(void *Ptr, size_t Size)
{
	assert((Size % PAGE_SIZE) == 0);
	assert(((ulong64)Ptr & (PAGE_SIZE-1)) == 0);
	
	int Ret = mprotect(Ptr, Size, PROT_NONE);
	if (Ret == -1)
	{
		printf("unable to mprotect %s():%d\n", __func__, __LINE__);
		exit(0);
	}
	Ret = madvise(Ptr, Size, MADV_DONTNEED);
	if (Ret == -1)
	{
		printf("unable to reclaim physical page %s():%d\n", __func__, __LINE__);
		exit(0);
	}
}

static void san_largefree(void *Ptr, size_t Size)
{
	size_t AlignedSize = Align(Size, PAGE_SIZE);
	Segment *Cur = ADDR_TO_SEGMENT(Ptr);

	reclaimMemory(Ptr, AlignedSize);
	size_t FreeIdx = ((char*)Ptr - (char*)Cur) / Cur->AlignedSize;
	assert(FreeIdx > 0);
	FreeIdx -= 1;
	size_t BitMapIdx = FreeIdx / 64;
	size_t BitIdx = FreeIdx % 64;
	Cur->BitMap[BitMapIdx] &= ~(1ULL << BitIdx);
	Cur->NumFreePages++;
}

static int findFirstFreeIdx(unsigned long long BitVal)
{
	int i = 0;
	for (i = 0; i < 63; i++) {
		if (((BitVal >> i) & 1) == 0) {
			return i;
		}
	}
	assert(0);
	return -1;
}


static void* san_largealloc(size_t Size)
{
	size_t AlignedSize = Align(Size, PAGE_SIZE);
	size_t Idx = GetLargeIndex(AlignedSize);

	Segment *Cur = Segments[Idx];

	while (Cur != NULL && Cur->NumFreePages == 0) {
		Cur = Cur->Next;
	}
	if (Cur == NULL) {
		Cur = allocateSegment(Idx);
		if (Segments[Idx] != NULL) {
			Cur->Next = Segments[Idx];
		}
		Segments[Idx] = Cur;
	}
	assert(Cur->NumFreePages > 0);

	size_t i;
	size_t FreeIdx = -1;
	for (i = 0; i < Cur->MaxBitMapIndex; i++) {
		if (Cur->BitMap[i] != MAX_ULONG) {
			FreeIdx = findFirstFreeIdx(Cur->BitMap[i]);
			Cur->BitMap[i] |= (1ULL << FreeIdx);
			FreeIdx += (i*64);
			break;
		}
	}
	assert(FreeIdx != (size_t)-1);

	char *Addr = (char*)(Cur) + ((FreeIdx + 1) * Cur->AlignedSize);
	Cur->NumFreePages--;
	allowAccess(Addr, AlignedSize);
	return Addr;
}
