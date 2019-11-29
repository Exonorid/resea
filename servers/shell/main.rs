use resea::idl;
use resea::idl::text_screen_device::{call_print_char, call_print_str};
use resea::prelude::*;
use resea::server::connect_to_server;

static _MEMMGR_SERVER: Channel = Channel::from_cid(1);
static KERNEL_SERVER: Channel = Channel::from_cid(2);

struct Server {
    ch: Channel,
    screen: Channel,
    input: String,
}

impl Server {
    pub fn new() -> Server {
        // Connect to the dependent servers...
        let screen = connect_to_server(idl::text_screen_device::INTERFACE_ID)
            .expect("failed to connect to a text_screen_device server");
        let keyboard = connect_to_server(idl::keyboard_device::INTERFACE_ID)
            .expect("failed to connect to a keyboard_device server");

        // Print the welcome message.
        call_print_str(&screen, "Resea Version \n").unwrap();
        call_print_str(&screen, "Type 'help' for usage.\n").unwrap();
        call_print_str(&screen, ">>> ").unwrap();

        // Start receiving keyboard inputs from the driver.
        use idl::keyboard_device::call_listen;
        let server_ch = Channel::create().unwrap();
        let listener_ch = Channel::create().unwrap();
        listener_ch.transfer_to(&server_ch).unwrap();
        call_listen(&keyboard, listener_ch).unwrap();

        Server {
            ch: server_ch,
            screen,
            input: String::new(),
        }
    }

    fn run_command(&mut self) {
        if self.input == "help" {
            self.print_string("echo <string>   -  Prints a string.\n");
        } else if self.input == "dmesg" {
            loop {
                let r = idl::kernel::call_read_kernel_log(&KERNEL_SERVER).unwrap();
                if r.is_empty() {
                    break;
                }
                self.print_string(&r);
            }
        } else if self.input.starts_with("echo ") {
            self.print_string(&self.input[5..]);
            self.print_string("\n");
        } else {
            self.print_string("Unknown command.\n");
        }
    }

    fn print_string(&self, string: &str) {
        call_print_str(&self.screen, string).unwrap();
    }

    fn print_prompt(&self) {
        call_print_str(&self.screen, ">>> ").unwrap();
    }

    fn readchar(&mut self, ch: char) {
        call_print_char(&self.screen, ch as u8).ok();
        if ch == '\n' {
            self.run_command();
            self.input.clear();
            self.print_prompt();
        } else {
            self.input.push(ch);
        }
    }
}

impl resea::idl::keyboard_device_client::Server for Server {
    fn pressed(&mut self, _from: &Channel, ch: u8) {
        self.readchar(ch as char);
    }
}

impl resea::server::Server for Server {}

#[no_mangle]
pub fn main() {
    info!("starting...");
    let mut server = Server::new();
    info!("ready");
    serve_forever!(&mut server, [keyboard_device_client]);
}
