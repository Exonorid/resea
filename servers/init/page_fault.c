#include "page_fault.h"
#include "bootfs.h"
#include "task.h"
#include <print_macros.h>
#include <resea/syscall.h>

__aligned(PAGE_SIZE) uint8_t tmp_page[PAGE_SIZE];

/// Tries to fill a page at `vaddr` for the task. Returns the allocated physical
/// memory address on success or 0 on failure.
error_t handle_page_fault(struct task *task, uaddr_t uaddr, uaddr_t ip,
                          unsigned fault) {
    if (uaddr < PAGE_SIZE) {
        WARN("%s (%d): null pointer dereference at vaddr=%p, ip=%p", task->name,
             task->tid, uaddr, ip);
        return ERR_ABORTED;  // FIXME:
    }

    uaddr_t uaddr_original = uaddr;
    uaddr = ALIGN_DOWN(uaddr, PAGE_SIZE);

    // TODO:
    // if (fault & EXP_PF_PRESENT) {
    //     // Invalid access. For instance the user thread has tried to write to
    //     // readonly area.
    //     WARN("%s: invalid memory access at %p (IP=%p, perhaps segfault?)",
    //          task->name, vaddr_original, ip);
    //     return ERR_ABORTED;  // FIXME:
    // }

    // Look for the associated program header.
    elf_phdr_t *phdr = NULL;
    for (unsigned i = 0; i < task->ehdr->e_phnum; i++) {
        // Ignore GNU_STACK
        if (!task->phdrs[i].p_vaddr) {
            continue;
        }

        uaddr_t start = task->phdrs[i].p_vaddr;
        uaddr_t end = start + task->phdrs[i].p_memsz;
        if (start <= uaddr && uaddr <= end) {
            phdr = &task->phdrs[i];
            break;
        }
    }

    if (phdr) {
        // TODO: return err instead
        ASSERT(phdr->p_memsz >= phdr->p_filesz);

        // Allocate a page and fill it with the file data.
        // TODO:
        paddr_t paddr = sys_pm_alloc(PAGE_SIZE, 0);
        DBG("mapping u:%p to p:%p", uaddr, paddr);

        void *tmp_page = (void *) 0xa000;
        ASSERT_OK(sys_vm_map(sys_task_self(), (uaddr_t) tmp_page, paddr,
                             PAGE_SIZE,
                             /*FIXME: */ 0));

        size_t offset_in_segment = (uaddr - phdr->p_vaddr) + phdr->p_offset;
        size_t copy_len = MIN(PAGE_SIZE, phdr->p_filesz - offset_in_segment);
        bootfs_read(task->file, offset_in_segment, (void *) tmp_page, copy_len);

        sys_vm_map(task->tid, uaddr, paddr, PAGE_SIZE,
                   /*FIXME: */ 0);
        return OK;
    }

    WARN("invalid memory access (addr=%p, IP=%p), killing %s...",
         uaddr_original, ip, task->name);
    return ERR_ABORTED;  // FIXME:
}
