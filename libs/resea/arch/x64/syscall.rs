use crate::error::Error;
use crate::message::Message;

const SYSCALL_IPC: u32 = 0;
const SYSCALL_OPEN: u32 = 1;
const SYSCALL_TRANSFER: u32 = 4;
const IPC_SEND: u32 = 1 << 8;
const IPC_RECV: u32 = 1 << 9;

unsafe fn convert_error(error: i32) -> Result<(), Error> {
    if error < 0 {
        Err(core::mem::transmute::<u8, Error>(-error as u8))
    } else {
        Ok(())
    }
}

unsafe fn ipc_syscall(cid: i32, ops: u32) -> Result<(), Error> {
    let error: i32;
    asm!(
        "syscall"
        : "={eax}"(error)
        : "{eax}"(SYSCALL_IPC | ops),
          "{rdi}"(cid)
        : "rsi", "rdx", "rcx", "r8", "r9", "r10" "r11"
    );

    convert_error(error)
}

pub unsafe fn open() -> Result<i32, Error> {
    let cid_or_error: i32;
    asm!(
        "syscall"
        : "={eax}"(cid_or_error)
        : "{eax}"(SYSCALL_OPEN)
        : "rdi", "rsi", "rdx", "rcx", "r8", "r9", "r10" "r11"
    );

    if cid_or_error < 0 {
        Err(core::mem::transmute::<u8, Error>(-cid_or_error as u8))
    } else {
        Ok(cid_or_error)
    }
}

pub unsafe fn transfer(src: i32, dst: i32) -> Result<(), Error> {
    let error: i32;
    asm!(
        "syscall"
        : "={eax}"(error)
        : "{eax}"(SYSCALL_TRANSFER),
          "{rdi}"(src),
          "{rsi}"(dst)
        : "rdx", "rcx", "r8", "r9", "r10" "r11"
    );

    convert_error(error)
}

pub unsafe fn send(cid: i32) -> Result<(), Error> {
    ipc_syscall(cid, IPC_SEND)
}

pub unsafe fn recv(cid: i32) -> Result<(), Error> {
    ipc_syscall(cid, IPC_RECV)
}

pub unsafe fn call(cid: i32) -> Result<(), Error> {
    ipc_syscall(cid, IPC_SEND | IPC_RECV)
}