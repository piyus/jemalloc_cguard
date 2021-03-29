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
#include <sys/time.h>
#include <sys/resource.h>

typedef unsigned long long ulong64;


#define SEGMENT_SIZE (1ULL << 32)
#define PAGE_SIZE 4096
#define Align(x, y) (((x) + (y-1)) & ~(y-1))
#define ADDR_TO_PAGE(x) (char*)(((ulong64)(x)) & ~(PAGE_SIZE-1))
#define ADDR_TO_SEGMENT(x) (Segment*)(((ulong64)(x)) & ~(SEGMENT_SIZE-1) & 0xFFFFFFFFFFFF)
#define MAX_ULONG 0xFFFFFFFFFFFFFFFFULL
#define LARGE_MAGIC 0xdeadfacedeaddeed
#define MAX_CACHE_SIZE (1ULL << 20)
#define MAX_CACHE_ENTRIES 32
extern void *MinLargeAddr;

static void *san_largerealloc(void *Ptr, size_t OldSize, size_t NewSize);

typedef struct Segment
{
	size_t AlignmentMask;
	size_t MagicString;
	size_t AlignedSize;
	size_t NumFreePages;
	size_t MaxBitMapIndex;
	int MaxCacheEntries;
	struct Segment *Next;
	size_t *Cache[MAX_CACHE_ENTRIES];
	int NumCacheEntries;
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

__thread struct Segment *Segments[32] = {NULL};
size_t TotalCommitMem = 0;
size_t TotalDeCommitMem = 0;

static void printRlimit()
{
	struct rlimit old;
	if (getrlimit(RLIMIT_AS, &old) == -1)
		perror("prlimit-1");

	printf("Previous limits as: soft=%jd; hard=%jd\n", 
		(intmax_t) old.rlim_cur, (intmax_t) old.rlim_max);
}

static void setRlimit()
{
#if 0
	struct rlimit old = {(1ULL << 40), (1ULL<<40)};
	if (setrlimit(RLIMIT_AS, &old) == -1)
		perror("prlimit-1");
#endif
}

static bool allowAccess(void *Ptr, size_t Size)
{
	TotalCommitMem += Size;
	Size = Align(Size, PAGE_SIZE);
	assert(((ulong64)Ptr & (PAGE_SIZE-1)) == 0);

	int Ret = mprotect(Ptr, Size, PROT_READ|PROT_WRITE);
	//malloc_printf("Allowing: Ptr:%p Size:%zd\n", Ptr, Size);
	if (Ret == -1)
	{
		perror("mprotect :: ");
		printf("unable to mprotect %s():%d TotalComm:%zd TotalDecomm:%zd\n",
			__func__, __LINE__, TotalCommitMem, TotalDeCommitMem);
		printRlimit();
		exit(0);
		return false;
	}
	return true;
}

static Segment* allocateSegment(size_t Idx)
{
	setRlimit();
	void* Base = mmap(NULL, SEGMENT_SIZE * 2, PROT_NONE, MAP_ANON|MAP_PRIVATE|MAP_NORESERVE, -1, 0);
	if (Base == MAP_FAILED)
	{
		printf("unable to allocate a segment\n");
		exit(0);
	}

	/* segments are aligned to segment size */
	Segment *S = (struct Segment*)Align((ulong64)Base, SEGMENT_SIZE);

	if ((void*)S < MinLargeAddr) {
		MinLargeAddr = (void*)S;
	}

	//malloc_printf("SEGMENT: %p-%p\n", S, (char*)S + SEGMENT_SIZE);

	size_t AlignShift = Idx + 16;
	assert(AlignShift < 32);
	size_t Alignment = (1ULL << AlignShift);
	size_t AlignmentMask = ~(Alignment-1);
	AlignmentMask = (AlignmentMask << 15) >> 15;
	size_t BitmapSize = (SEGMENT_SIZE / Alignment) - 1;

	assert(BitmapSize > 0);

	size_t MetadataSize = ((BitmapSize + 7) / 8) + sizeof(struct Segment);
	bool Ret = allowAccess(S, MetadataSize);
	assert(Ret);
	S->MagicString = LARGE_MAGIC;
	S->MaxBitMapIndex = BitmapSize;
	S->NumFreePages = BitmapSize;
	S->AlignmentMask = AlignmentMask;
	S->AlignedSize = Alignment;
	S->NumCacheEntries = 0;
	S->MaxCacheEntries = 1;
	S->Next = NULL;
	//malloc_printf("Alloc Seg: %p Idx:%zd\n", S, Idx);

	return S;
}

static void reclaimMemory(void *Ptr, size_t Size)
{
	TotalDeCommitMem += Size;
	assert((Size % PAGE_SIZE) == 0);
	assert(((ulong64)Ptr & (PAGE_SIZE-1)) == 0);
#if 0
	//malloc_printf("Revoking: Ptr:%p Size:%zd\n", Ptr, Size);
	int Ret = mprotect(Ptr, Size, PROT_NONE);
	//void* Ret = mmap(Ptr, Size, PROT_NONE, MAP_FIXED|MAP_PRIVATE|MAP_ANON, -1, 0);
	if (Ret == -1)
	//if (Ret != Ptr)
	{
		malloc_printf("unable to mprotect %s():%d\n", __func__, __LINE__);
		exit(0);
	}
#endif
	//int Ret1 = msync(Ptr, Size, MS_INVALIDATE);
	int Ret = madvise(Ptr, Size, MADV_DONTNEED);
	//if (Ret1 == -1)
	if (Ret == -1)
	{
		perror("madvise :: ");
		malloc_printf("unable to reclaim physical page %s():%d\n", __func__, __LINE__);
		exit(0);
	}
}

static void san_largefree(void *Ptr, size_t Size)
{
	size_t AlignedSize = Align(Size, PAGE_SIZE);
	Segment *Cur = ADDR_TO_SEGMENT(Ptr);
	if (Cur->NumCacheEntries < Cur->MaxCacheEntries && Cur->AlignedSize <= MAX_CACHE_SIZE) {
		Cur->Cache[Cur->NumCacheEntries] = (size_t*)Ptr;
		((size_t*)Ptr)[0] = Size;
		//malloc_printf("free cache:%zd alined:%zd num:%d\n", Size, AlignedSize, Cur->NumCacheEntries);
		Cur->NumCacheEntries++;
		return;
	}

	reclaimMemory(Ptr, AlignedSize);
	size_t FreeIdx = ((char*)Ptr - (char*)Cur) / Cur->AlignedSize;
	assert(FreeIdx > 0);
	FreeIdx -= 1;
	//malloc_printf("Free Ptr: %p Idx:%zd Size:%zd\n", Ptr, FreeIdx, Size);
	size_t BitMapIdx = FreeIdx / 64;
	size_t BitIdx = FreeIdx % 64;
	Cur->BitMap[BitMapIdx] &= ~(1ULL << BitIdx);
	Cur->NumFreePages++;
	//malloc_printf("free:%zd\n", Size);
}

static int findFirstFreeIdx(unsigned long long BitVal)
{
	int i = 0;
	for (i = 0; i <= 63; i++) {
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

	if (Cur->NumCacheEntries) {
		//malloc_printf("cache: Size:%zd AlignedSz:%zd Num:%d\n", Size, AlignedSize, Cur->NumCacheEntries);
		assert(Cur->NumCacheEntries > 0 && Cur->NumCacheEntries <= Cur->MaxCacheEntries);
		assert(Cur->AlignedSize <= MAX_CACHE_SIZE);
		size_t *Ptr = Cur->Cache[Cur->NumCacheEntries -1 ];
		Cur->NumCacheEntries--;
		if (Cur->NumCacheEntries == 0 && Cur->MaxCacheEntries != MAX_CACHE_ENTRIES) {
			Cur->MaxCacheEntries++;
		}
		return san_largerealloc(Ptr, Ptr[0], Size);
	}

	size_t i;
	size_t FreeIdx = -1;
	//malloc_printf("MaxBitMapIndex:%zd NumFreePages:%zd\n", Cur->MaxBitMapIndex, Cur->NumFreePages);
	for (i = 0; i < Cur->MaxBitMapIndex; i+=64) {
		size_t MapIdx = i / 64;
		if (Cur->BitMap[MapIdx] != MAX_ULONG) {
			FreeIdx = findFirstFreeIdx(Cur->BitMap[MapIdx]);
			Cur->BitMap[MapIdx] |= (1ULL << FreeIdx);
			FreeIdx += i;
			//malloc_printf("FreeIdx: %zd\n", FreeIdx);
			assert(FreeIdx < Cur->MaxBitMapIndex);
			break;
		}
	}
	assert(FreeIdx != (size_t)-1);

	char *Addr = (char*)(Cur) + ((FreeIdx + 1) * Cur->AlignedSize);
	Cur->NumFreePages--;
	bool Ret = allowAccess(Addr, AlignedSize);
	if (Ret == false) {
		return san_largealloc(Size);
	}
	//memset(Addr, 0, AlignedSize);
	//malloc_printf("Large alloc: %p FreeIdx:%zd Idx:%zd Size:%zd AlignedSz:%zd\n", Addr, FreeIdx, Idx, Size, AlignedSize);
	//malloc_printf("Size:%zd AlignedSz:%zd\n", Size, AlignedSize);
	return Addr;
}

static void *san_largerealloc(void *Ptr, size_t OldSize, size_t NewSize)
{
	size_t OldAlignedSize = Align(OldSize, PAGE_SIZE);
	size_t NewAlignedSize = Align(NewSize, PAGE_SIZE);
	if (NewAlignedSize < OldAlignedSize) {
		reclaimMemory(Ptr + NewAlignedSize, OldAlignedSize - NewAlignedSize);
		return Ptr;
	}
	if (NewAlignedSize == OldAlignedSize) {
		return Ptr;
	}
	Segment *S = ADDR_TO_SEGMENT(Ptr);
	if (S->AlignedSize >= NewAlignedSize) {
		bool Ret = allowAccess(Ptr + OldAlignedSize, NewAlignedSize - OldAlignedSize);
		assert(Ret);
		return Ptr;
	}
	void *NewPtr = san_largealloc(NewSize);
	memcpy(NewPtr, Ptr, OldSize);
	san_largefree(Ptr, OldSize);
	return NewPtr;
}

static void *san_largeheader(void *Ptr)
{
	Segment *S = ADDR_TO_SEGMENT(Ptr);
	if ((void*)S < MinLargeAddr) {
		return NULL;
	}
	assert(S->MagicString == LARGE_MAGIC);
	return (void*)((size_t)Ptr & S->AlignmentMask);
}
