#include "asm.h"
#include <kernel/arch.h>
#include <kernel/main.h>
#include <kernel/printk.h>

// FIXME:
struct cpuvar cpuvar_fixme;
extern char __kernel_image_end[];

__noreturn static void setup_smode(void) {
    struct bootinfo bootinfo;
    bootinfo.memory_maps[0].paddr =
        ALIGN_UP((paddr_t) __kernel_image_end, PAGE_SIZE);
    bootinfo.memory_maps[0].size = 64 * 1024 * 1024;
    bootinfo.memory_maps[0].type = MEMORY_MAP_FREE;
    bootinfo.num_memory_maps = 1;

    kernel_main(&bootinfo);
    UNREACHABLE();
}

__noreturn void riscv_setup(void) {
    write_medeleg(0xffff);
    write_mideleg(0xffff);
    // TODO:
    //   write_sie(read_sie() | SIE_SEIE | SIE_STIE | SIE_SSIE);

    write_satp(0);
    write_pmpaddr0(0xffffffff);
    write_pmpcfg0(0xf);

    uint32_t mstatus = read_mstatus();
    mstatus &= ~MSTATUS_MPP_MASK;
    mstatus |= MSTATUS_MPP_S;
    write_mstatus(mstatus);

    write_mepc((uint32_t) setup_smode);
    __asm__ __volatile__("mret");
    UNREACHABLE();
}
