#pragma once
#include <types.h>

void riscv_task_switch(uint32_t *prev_sp, uint32_t *next_sp);