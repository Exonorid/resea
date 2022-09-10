V ?=
RELEASE ?=
ARCH ?= riscv32
BUILD_DIR ?= build
SERVERS ?= shell pingpong test
STARTUP_SERVERS ?= shell

ifeq ($(shell uname), Darwin)
LLVM_PREFIX ?= /opt/homebrew/opt/llvm/bin/
endif

# Disable builtin implicit rules and variables.
MAKEFLAGS += --no-builtin-rules --no-builtin-variables
.SUFFIXES:

# Enable verbose output if $(V) is set.
ifeq ($(V),)
.SILENT:
endif

top_dir := $(shell pwd)
kernel_elf := $(BUILD_DIR)/resea.elf
boot_elf := $(BUILD_DIR)/servers/init.elf
bootfs_bin := $(BUILD_DIR)/bootfs.bin

#
#  Commands
#
CC        := $(LLVM_PREFIX)clang$(LLVM_SUFFIX)
LD        := $(LLVM_PREFIX)ld.lld$(LLVM_SUFFIX)
OBJCOPY   := $(LLVM_PREFIX)llvm-objcopy$(LLVM_SUFFIX)
ADDR2LINE := $(LLVM_PREFIX)llvm-addr2line$(LLVM_SUFFIX)
PROGRESS  ?= printf "  \\033[1;96m%8s\\033[0m  \\033[1;m%s\\033[0m\\n"
DOXYGEN   ?= doxygen
PYTHON3   ?= python3
MKDIR     ?= mkdir -p

LDFLAGS := $(LDFLAGS)
CFLAGS := $(CFLAGS)
CFLAGS += -g3 -std=c11 -ffreestanding -fno-builtin -nostdlib -nostdinc
CFLAGS += -Wall -Wextra
CFLAGS += -Werror=implicit-function-declaration
CFLAGS += -Werror=int-conversion
CFLAGS += -Werror=incompatible-pointer-types
CFLAGS += -Werror=shift-count-overflow
CFLAGS += -Werror=switch
CFLAGS += -Werror=return-type
CFLAGS += -Werror=pointer-integer-compare
CFLAGS += -Werror=tautological-constant-out-of-range-compare
CFLAGS += -Werror=visibility
CFLAGS += -Wno-unused-parameter
CFLAGS += -I$(top_dir) -I$(BUILD_DIR)/autogen/include

# Required for backtrace().
CFLAGS += -fno-omit-frame-pointer -fno-optimize-sibling-calls

ifeq ($(RELEASE),)
CFLAGS += -O1 -fsanitize=undefined
else
CFLAGS += -O3
endif

QEMUFLAGS += -serial mon:stdio --no-reboot
QEMUFLAGS += $(if $(GUI),,-nographic)
QEMUFLAGS += $(if $(GDB),-S -s,)

.PHONY: build
build: $(kernel_elf)
	$(PROGRESS) "GEN" "$(BUILD_DIR)/compile_commands.json"
	$(PYTHON3) ./tools/merge_compile_commands_json.py -o $(BUILD_DIR)/compile_commands.json $(BUILD_DIR)

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)

.PHONY: run
run: $(kernel_elf)
	$(QEMU) $(QEMUFLAGS) -kernel $(kernel_elf)

.PHONY: doxygen
doxygen:
	$(DOXYGEN) Doxyfile

all_idls :=
executable := $(kernel_elf)
name := kernel
dir := kernel
build_dir := $(BUILD_DIR)/kernel
objs-y :=
libs-y :=
idls-y :=
cflags-y :=
ldflags-y :=
include kernel/build.mk

all_libs := $(notdir $(patsubst %/build.mk, %, $(wildcard libs/*/build.mk)))
$(foreach lib, $(all_libs),                                       \
	$(eval dir := libs/$(lib))                                \
	$(eval build_dir := $(BUILD_DIR)/$(dir))                  \
	$(eval output := $(BUILD_DIR)/libs/$(lib).o)              \
	$(eval objs-y :=)                                         \
	$(eval cflags-y :=)                                       \
	$(eval ldflags-y :=)                                      \
	$(eval subdirs-y :=)                                      \
	$(eval include $(dir)/build.mk)                           \
)

all_servers := $(notdir $(patsubst %/build.mk, %, $(wildcard servers/*/build.mk)))
$(foreach server, $(all_servers),                                 \
	$(eval dir := servers/$(server))                          \
	$(eval build_dir := $(BUILD_DIR)/$(dir))                  \
	$(eval executable := $(BUILD_DIR)/servers/$(server).elf)  \
	$(eval name := $(server))                                 \
	$(eval objs-y :=)                                         \
	$(eval libs-y :=)                                         \
	$(eval idls-y :=)                                         \
	$(eval cflags-y :=)                                       \
	$(eval ldflags-y :=)                                      \
	$(eval subdirs-y :=)                                      \
	$(eval include $(dir)/build.mk)                           \
)

autogen_files := $(BUILD_DIR)/autogen/include/autogen/ipcstub.h

$(BUILD_DIR)/%.o: %.c Makefile $(autogen_files)
	$(PROGRESS) CC $<
	$(MKDIR) $(@D)
	$(CC) $(CFLAGS) -c -o $@ $< -MD -MF $(@:.o=.deps) -MJ $(@:.o=.json)

$(BUILD_DIR)/%.o: $(BUILD_DIR)/%.c Makefile $(autogen_files)
	$(PROGRESS) CC $<
	$(MKDIR) $(@D)
	$(CC) $(CFLAGS) -c -o $@ $< -MD -MF $(@:.o=.deps) -MJ $(@:.o=.json)

$(BUILD_DIR)/%.o: %.S Makefile $(autogen_files)
	$(PROGRESS) CC $<
	$(MKDIR) $(@D)
	$(CC) $(CFLAGS) -c -o $@ $< -MD -MF $(@:.o=.deps) -MJ $(@:.o=.json)

$(BUILD_DIR)/%.o: $(BUILD_DIR)/%.S Makefile $(autogen_files)
	$(PROGRESS) CC $<
	$(MKDIR) $(@D)
	$(CC) $(CFLAGS) -c -o $@ $< -MD -MF $(@:.o=.deps) -MJ $(@:.o=.json)

$(bootfs_bin): $(foreach server, $(SERVERS), $(BUILD_DIR)/bootfs/$(server).elf)
	$(PROGRESS) "MKBOOTFS" "$@"
	$(MKDIR) $(@D)
	$(PYTHON3) ./tools/mkbootfs.py -o $@ $(BUILD_DIR)/bootfs

$(BUILD_DIR)/bootfs/%.elf: $(BUILD_DIR)/servers/%.elf
	$(MKDIR) $(@D)
	cp $< $@

$(BUILD_DIR)/autogen/include/autogen/ipcstub.h: $(all_idls)
	$(PROGRESS) "IPCSTUB" "$@"
	$(MKDIR) $(@D)
	$(PYTHON3) ./tools/ipc_stub.py --lang c -o $@ $^

# Build dependencies generated by clang and Cargo.
-include $(shell find $(BUILD_DIR) -name "*.deps" 2>/dev/null)
