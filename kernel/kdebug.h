#ifndef __KDEBUG_H__
#define __KDEBUG_H__

#include <types.h>

void kdebug_handle_interrupt(void);
MUSTUSE error_t kdebug_run(const char *cmdline);
void stack_check(void);
void stack_set_canary(void);

// Implemented in arch.
int kdebug_readchar(void);

#endif
