#include <string.h>
#include "kdebug.h"
#include "task.h"

static void quit(void) {
#ifdef CONFIG_ARCH_X64
    // QEMU
    io_out16(0x604, 0x2000);
#endif
#ifdef CONFIG_ARCH_ARM64
    // ARM Semihosting
    uint64_t params[] = {
        0x20026, // application exit
        0,       // exit code
    };

    register uint64_t x0 __asm__("x0") = 0x20;    // exit
    register uint64_t x1 __asm__("x1") = (uint64_t) params;    // exit
    __asm__ __volatile__("hlt #0xf000" :: "r"(x0), "r"(x1));
#endif

    PANIC("halted by the kdebug");
}

error_t kdebug_run(const char *cmdline) {
    if (strcmp(cmdline, "help") == 0) {
        DPRINTK("Kernel debugger commands:\n");
        DPRINTK("\n");
        DPRINTK("  ps - List tasks.\n");
        DPRINTK("  q  - Quit the emulator.\n");
        DPRINTK("\n");
    } else if (strcmp(cmdline, "ps") == 0) {
        task_dump();
    } else if (strcmp(cmdline, "q") == 0) {
        quit();
    } else {
        WARN("Invalid debugger command: '%s'.", cmdline);
        return ERR_NOT_FOUND;
    }

    return OK;
}

void kdebug_handle_interrupt(void) {
    static char cmdline[64];
    static unsigned long cursor = 0;
    int ch;
    while ((ch = kdebug_readchar()) > 0) {
        if (ch == '\r') {
            printk("\n");
            cmdline[cursor] = '\0';
            if (cursor > 0) {
                kdebug_run(cmdline);
                cursor = 0;
            }
            DPRINTK("kdebug> ");
            continue;
        }

        DPRINTK("%c", ch);
        cmdline[cursor++] = (char) ch;

        if (cursor > sizeof(cmdline) - 1) {
            WARN("Too long kernel debugger command.");
            cursor = 0;
        }
    }
}

static uint32_t *get_canary_ptr(void) {
    vaddr_t sp = (vaddr_t) __builtin_frame_address(0);
    return (uint32_t *) ALIGN_DOWN(sp, PAGE_SIZE);
}

/// Writes the stack canary at the borrom of the current kernel stack.
void stack_set_canary(void) {
    *get_canary_ptr() = STACK_CANARY_VALUE;
}

/// Checks that the kernel stack canary is still alive.
void stack_check(void) {
    if (*get_canary_ptr() != STACK_CANARY_VALUE) {
        PANIC("the kernel stack has been exhausted");
    }
}
