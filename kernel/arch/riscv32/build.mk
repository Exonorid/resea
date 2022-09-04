objs-y += boot.o setup.o uart.o task.o vm.o switch.o trap.o usercopy.o

ldflags-y += -T$(dir)/kernel.ld

QEMU := $(QEMU_PREFIX)qemu-system-riscv32
QEMUFLAGS += -m 128 -machine virt -bios none

ifneq ($(QEMU_DEBUG),)
QEMUFLAGS += -d unimp,guest_errors,int
endif

# Append RISC-V specific C compiler flags globally (including userspace
# programs).
CFLAGS += --target=riscv32 -mno-relax
