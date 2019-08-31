#include <ipc.h>
#include <printk.h>
#include <process.h>
#include <resea_idl.h>
#include <server.h>
#include <thread.h>
#include <types.h>

struct channel *kernel_server_ch = NULL;

/// The user pager. When a page fault occurred in vm areas that are registered
/// with this function, the kernel invokes this function to fill the page.
static paddr_t user_pager(struct vmarea *vma, vaddr_t vaddr) {
    struct message *ipc_buffer = &CURRENT->info->ipc_buffer;
    struct channel *pager = vma->arg;
    TRACE("user pager=%d, addr=%p", pager->cid, vaddr);

    // Construct a full_page_request message.
    struct fill_page_request_msg *m =
        (struct fill_page_request_msg *) ipc_buffer;
    m->header = FILL_PAGE_REQUEST_HEADER;
    m->pid = CURRENT->process->pid;
    m->addr = vaddr;

    // Invoke the user pager. This would blocks the current thread.
    sys_ipc(pager->cid, IPC_SEND | IPC_RECV | IPC_FROM_KERNEL);

    // The user pager replied the message.
    if (MSG_LABEL(ipc_buffer->header) < 0) {
        WARN("user pager returned an error");
        return 0;
    }

    struct fill_page_request_reply_msg *r =
        (struct fill_page_request_reply_msg *) ipc_buffer;
    paddr_t paddr = PAGE_PAYLOAD_ADDR(r->page);
    TRACE("received a page from the pager: addr=%p", paddr);
    return paddr;
}

static error_t handle_printchar_msg(uint8_t ch) {
    arch_putchar(ch);
    return OK;
}

static NORETURN void handle_exit_current_msg(UNUSED int code) {
    // TODO: Kill the sender process.
    UNIMPLEMENTED();
}

static error_t handle_create_process_msg(struct process *sender, struct create_process_reply_msg *r) {
    TRACE("kernel: create_process()");
    struct process *proc = process_create("user" /* TODO: */);
    if (!proc) {
        return ERR_OUT_OF_RESOURCE;
    }

    struct channel *user_ch = channel_create(proc);
    if (!user_ch) {
        process_destroy(proc);
        return ERR_OUT_OF_RESOURCE;
    }

    struct channel *pager_ch = channel_create(sender);
    if (!pager_ch) {
        channel_decref(pager_ch);
        process_destroy(proc);
        return ERR_OUT_OF_RESOURCE;
    }

    channel_link(user_ch, pager_ch);

    r->header = CREATE_PROCESS_REPLY_HEADER;
    r->pid = proc->pid;
    r->pager_ch = pager_ch->cid;
    TRACE("kernel: create_process_response(pid=%d, pager_ch=%d)", r->pid,
        r->pager_ch);
    return OK;
}

static error_t handle_spawn_thread_msg(pid_t pid, vaddr_t start, vaddr_t stack,
    vaddr_t buffer, vaddr_t arg, struct spawn_thread_reply_msg *r) {
    TRACE("kernel: spawn_thread(pid=%d, start=%p)", pid, start);

    struct process *proc = idtable_get(&all_processes, pid);
    if (!proc) {
        return ERR_INVALID_MESSAGE;
    }

    struct thread *thread = thread_create(proc, start, stack, buffer,
                                          (void *) arg);
    if (!thread) {
        return ERR_OUT_OF_RESOURCE;
    }

    thread_resume(thread);

    TRACE("kernel: spawn_thread_response(tid=%d)", thread->tid);
    r->header = SPAWN_THREAD_REPLY_HEADER;
    r->tid = thread->tid;
    return OK;
}

static error_t handle_add_pager_msg(pid_t pid, cid_t pager, vaddr_t start,
    vaddr_t size, uint8_t flags, struct add_pager_reply_msg *r) {
    TRACE("kernel: add_pager(pid=%d, pager=%d, range=%p-%p)", pid, pager, start,
        start + size);

    struct process *proc = idtable_get(&all_processes, pid);
    if (!proc) {
        WARN("invalid proc");
        return ERR_INVALID_MESSAGE;
    }

    struct channel *pager_ch = idtable_get(&proc->channels, pager);
    if (!pager_ch) {
        WARN("invalid pger_ch %d", pager);
        process_destroy(proc);
        return ERR_INVALID_MESSAGE;
    }

    error_t err = vmarea_add(proc, start, start + size, user_pager, pager_ch,
                             flags | PAGE_USER);
    if (err != OK) {
        WARN("failed to add a vm area: %d", err);
        process_destroy(proc);
        return err;
    }
    channel_incref(pager_ch);

    TRACE("kernel: add_pager_response()");
    r->header = ADD_PAGER_REPLY_HEADER;
    return OK;
}

NORETURN static void handle_exit_kernel_test_msg(void) {
    INFO("Power off");
    arch_poweroff();
}

NORETURN static void mainloop(cid_t server_ch) {
    struct message *ipc_buffer = &CURRENT->info->ipc_buffer;
    // struct message m;
    sys_ipc(server_ch, IPC_RECV | IPC_FROM_KERNEL);

    while (1) {
        cid_t from = ipc_buffer->from;
        struct channel *ch = idtable_get(&kernel_process->channels, from);
        ASSERT(ch != NULL);
        struct process *sender = ch->linked_to->process;
        error_t err;
        switch (MSG_LABEL(ipc_buffer->header)) {
        case PRINTCHAR_MSG: {
            struct printchar_msg *m = (struct printchar_msg *) ipc_buffer;
            err = handle_printchar_msg(m->ch);
            break;
        }
        case EXIT_CURRENT_MSG: {
            struct exit_current_msg *m = (struct exit_current_msg *) ipc_buffer;
            handle_exit_current_msg(m->code);
        }
        case CREATE_PROCESS_MSG: {
            err = handle_create_process_msg(sender,
                (struct create_process_reply_msg *) ipc_buffer);
            break;
        }
        case SPAWN_THREAD_MSG: {
            struct spawn_thread_msg *m = (struct spawn_thread_msg *) ipc_buffer;
            err = handle_spawn_thread_msg(m->pid, m->start, m->stack, m->buffer,
                m->arg, (struct spawn_thread_reply_msg *) ipc_buffer);
            break;
        }
        case ADD_PAGER_MSG: {
            struct add_pager_msg *m = (struct add_pager_msg *) ipc_buffer;
            err = handle_add_pager_msg(m->pid, m->pager, m->start, m->size,
                m->flags, (struct add_pager_reply_msg *) ipc_buffer);
            break;
        }
        case EXIT_KERNEL_TEST_MSG:
            handle_exit_kernel_test_msg();
            break;
        default:
            WARN("invalid message type %x", MSG_LABEL(ipc_buffer->header));
            err = ERR_INVALID_MESSAGE;
            ipc_buffer->header = ERROR_TO_HEADER(err);
        }

        if (err == ERR_DONT_REPLY) {
            sys_ipc(server_ch, IPC_RECV | IPC_FROM_KERNEL);
        } else {
            sys_ipc(from, IPC_SEND | IPC_RECV | IPC_FROM_KERNEL);
        }
    }
}

static void kernel_server_main(void) {
    ASSERT(CURRENT->process == kernel_process);
    mainloop(kernel_server_ch->cid);
}

void kernel_server_init(void) {
    kernel_server_ch = channel_create(kernel_process);
    struct thread *thread = thread_create(kernel_process,
                                          (vaddr_t) kernel_server_main,
                                          0 /* stack */,
                                          0 /* buffer */,
                                          0 /* arg */);
    thread_resume(thread);
}
