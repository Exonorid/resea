#include <resea/ipc.h>
#include <resea/printf.h>
#include <resea/task.h>
#include <resea/timer.h>
#include <string.h>
#include <ui.h>

static void onclick_callback(ui_button_t button, int x, int y) {
    INFO("clicked the button!");
    ui_button_set_label(button, "Clicked!");
}

void main(void) {
    ui_init();

    ui_window_t window = ui_window_create("Hello World", 10, 200);
    ASSERT_OK(window);

    ui_button_t button = ui_button_create(window, 10, 10, "Click Here!");
    ASSERT_OK(button);
    ui_button_on_click(button, onclick_callback);

    while (true) {
        struct message m;
        bzero(&m, sizeof(m));
        ASSERT_OK(ipc_recv(IPC_ANY, &m));

        switch (m.type) {
            case NOTIFICATIONS_MSG:
                if (m.notifications.data & NOTIFY_ASYNC) {
                    ui_handle_async();
                }
                break;
            default:
                discard_unknown_message(&m);
        }
    }
}
