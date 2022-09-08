#pragma once
#include <autogen/ipcstub.h>

typedef _BitInt(32) notifications_t;

#define IPC_ANY  0
#define IPC_DENY -1

#define IPC_SEND    (1 << 16)
#define IPC_RECV    (1 << 17)
#define IPC_NOBLOCK (1 << 18)
#define IPC_KERNEL  (1 << 19)
#define IPC_CALL    (IPC_SEND | IPC_RECV)

#define NOTIFY_ABORTED (1 << 0)

#define MSG_HEADER_LEN (sizeof(int) + sizeof(task_t))
#define MSG_LEN(x)     ((x) & (0xfff))

struct message {
    /// The type of message. If it's negative, this field represents an error
    /// (error_t).
    int type;
    /// The sender task of this message.
    task_t src;
    /// The message contents. Note that it's a union, not struct!
    union {
        // The message contents as raw bytes.
        uint8_t raw[0];

        // Auto-generated message fields:
        //
        //     struct { int x; int y; } add;
        //     struct { int answer; } add_reply;
        //     ...
        //
        IPCSTUB_MESSAGE_FIELDS
    };
};

IPCSTUB_STATIC_ASSERTIONS
