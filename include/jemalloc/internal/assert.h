#ifndef __ASSERT_H_
#define __ASSERT_H_
#include "jemalloc/internal/malloc_io.h"
#include "jemalloc/internal/util.h"



#include <execinfo.h>
#define BT_BUF_SIZE 100

static void myfunc3(void)
{
	int j, nptrs;
	void *buffer[BT_BUF_SIZE];
	char **strings;
	
	nptrs = backtrace(buffer, BT_BUF_SIZE);
	malloc_printf("backtrace() returned %d addresses\n", nptrs);
	
	/* The call backtrace_symbols_fd(buffer, nptrs, STDOUT_FILENO)
	   would produce similar output to the following: */
	
	strings = backtrace_symbols(buffer, nptrs);
	if (strings == NULL) {
		perror("backtrace_symbols");
		exit(EXIT_FAILURE);
	}
	
	for (j = 0; j < nptrs; j++)
		malloc_printf("%s\n", strings[j]);
	
	free(strings);
}






/*
 * Define a custom assert() in order to reduce the chances of deadlock during
 * assertion failure.
 */
#ifndef assert
#define assert(e) do {							\
	if (unlikely( !(e))) {				\
		malloc_printf(						\
		    "<jemalloc>: %s:%d: Failed assertion: \"%s\"\n",	\
		    __FILE__, __LINE__, #e);				\
		myfunc3(); \
		abort();						\
	}								\
} while (0)
#endif

#ifndef not_reached
#define not_reached() do {						\
	if (1) {						\
		malloc_printf(						\
		    "<jemalloc>: %s:%d: Unreachable code reached\n",	\
		    __FILE__, __LINE__);				\
		abort();						\
	}								\
	unreachable();							\
} while (0)
#endif

#ifndef not_implemented
#define not_implemented() do {						\
	if (1) {						\
		malloc_printf("<jemalloc>: %s:%d: Not implemented\n",	\
		    __FILE__, __LINE__);				\
		abort();						\
	}								\
} while (0)
#endif

#ifndef assert_not_implemented
#define assert_not_implemented(e) do {					\
	if (unlikely(1 && !(e))) {				\
		not_implemented();					\
	}								\
} while (0)
#endif

/* Use to assert a particular configuration, e.g., cassert(config_debug). */
#ifndef cassert
#define cassert(c) do {							\
	if (unlikely(!(c))) {						\
		not_reached();						\
	}								\
} while (0)
#endif

#endif
