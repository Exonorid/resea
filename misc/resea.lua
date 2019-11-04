--
--  The Wireshark dissector for Resea IPC messages.
--
--  Setup:
--
--    1. Install Wireshark
--    2. Install this dissector (in macOS, copy this file to ~/.config/wireshark/plugins/)
--    3. Open Prefrences > Protocols > DLT_USER > Encapsulations Table
--    4. Add a new rule: DLT="User 0 (DLT=147)", Payload protocol="resea", Header/Trailer size=0
--       (see https://wiki.wireshark.org/HowToDissectAnything)
--
--  How to use:
--
--    $ make run | tee boot.log
--    $ grep "pcap>" boot.log > messages.log
--    $ text2pcap -l 147 messages.log messages.pcap
--    $ wireshark messages.pcap
--
proto = Proto("resea", "Resea IPC Messages")

function main()
    local optional_payloads = { [0] = "Not included", [1] = "Included" }

    proto.fields.source =
        ProtoField.string("resea.source", "Source")
    proto.fields.dest =
        ProtoField.string("resea.source", "Destination")
    proto.fields.inline_len =
        ProtoField.uint8("resea.inline_len", "Inline Payload Length", base.DEC)
    proto.fields.interface =
        ProtoField.uint8("resea.interface", "Interface ID", base.DEC)
    proto.fields.message_type =
        ProtoField.uint16("resea.message_type", "Message Type", base.HEX,
            message_types)
    proto.fields.page_included =
        ProtoField.uint8("resea.page_included", "Page Payload", base.HEX,
            optional_payloads, 0x08)
    proto.fields.channel_included =
        ProtoField.uint8("resea.channel_included", "Channel Payload", base.HEX,
            optional_payloads, 0x10)

    function proto.dissector(buffer, pinfo, tree)
        function msg(start, end_)
            if start == nil then
                start = 0
            end

            return buffer (72 + start, end_)
        end

        pinfo.cols.protocol = "Resea"
        subtree = tree:add(proto, msg(), message)

        --
        -- Packet Header
        --
        source = "@" .. buffer(0, 32):stringz() .. "." .. buffer(64, 4):le_uint()
        dest = "@" .. buffer(32, 32):stringz() .. "." .. buffer(68, 4):le_uint()
        subtree:add(proto.fields.source, source)
        subtree:add(proto.fields.dest, dest)
        pinfo.cols.src = source;
        pinfo.cols.dst = dest;

        --
        --  Message Header
        --
        local inline_len = msg(0, 1):le_uint()
        header = subtree:add(msg(0, 4), "Header")
        header:add_le(proto.fields.interface, msg(3, 1))
        header:add_le(proto.fields.message_type,  msg(2, 2))
        header:add_le(proto.fields.inline_len, inline_len)
        header:add_le(proto.fields.page_included, msg(1, 1))
        header:add_le(proto.fields.channel_included, msg(1, 1))

        local message_type = msg(2, 2):le_uint()
        local message = resea_messages[message_type]
        if message == nil then
            -- Unknown message
            pinfo.cols.info = "(unknown message)"
            return
        end
        pinfo.cols.info = message["name"]

        --
        --  Payloads
        --
        fields = subtree:add(msg(5), "Payloads")
        for _, field in ipairs(message["fields"]) do
            fields:add_le(field["proto"], msg(field["offset"], field["len"]))
        end


        --
        --  Set colors
        --
        set_color_filter_slot(10, "resea.interface == 1")  -- runtime
        set_color_filter_slot(2,  "resea.interface == 2")  -- process
        set_color_filter_slot(2,  "resea.interface == 3")  -- thread
        set_color_filter_slot(4,  "resea.interface == 12") -- pager
    end

    wtap_encap = DissectorTable.get("wtap_encap")
    wtap_encap:add(wtap.USER0, proto)
end

main()

-- -----------------------------------------------------------------------------
-- Message definitions generated by generate-wireshark-dissector-data.py
--

proto.fields.runtime_exit_code = ProtoField.int32("resea.payloads.runtime.exit.code", "code" , base.DEC);
proto.fields.runtime_printchar_ch = ProtoField.string("resea.payloads.runtime.printchar.ch", "ch" );
proto.fields.runtime_print_str_str = ProtoField.string("resea.payloads.runtime.print_str.str", "str" );
proto.fields.process_create_name = ProtoField.string("resea.payloads.process.create.name", "name" );
proto.fields.process_destroy_proc = ProtoField.int32("resea.payloads.process.destroy.proc", "proc" , base.DEC);
proto.fields.process_add_pager_proc = ProtoField.int32("resea.payloads.process.add_pager.proc", "proc" , base.DEC);
proto.fields.process_add_pager_pager = ProtoField.int32("resea.payloads.process.add_pager.pager", "pager" , base.DEC);
proto.fields.process_add_pager_start = ProtoField.uint64("resea.payloads.process.add_pager.start", "start" , base.HEX);
proto.fields.process_add_pager_size = ProtoField.uint64("resea.payloads.process.add_pager.size", "size" , base.HEX);
proto.fields.process_add_pager_flags = ProtoField.uint8("resea.payloads.process.add_pager.flags", "flags" , base.DEC);
proto.fields.process_send_channel_proc = ProtoField.int32("resea.payloads.process.send_channel.proc", "proc" , base.DEC);
proto.fields.thread_spawn_proc = ProtoField.int32("resea.payloads.thread.spawn.proc", "proc" , base.DEC);
proto.fields.thread_spawn_start = ProtoField.uint64("resea.payloads.thread.spawn.start", "start" , base.HEX);
proto.fields.thread_spawn_stack = ProtoField.uint64("resea.payloads.thread.spawn.stack", "stack" , base.HEX);
proto.fields.thread_spawn_buffer = ProtoField.uint64("resea.payloads.thread.spawn.buffer", "buffer" , base.HEX);
proto.fields.thread_spawn_arg = ProtoField.uint64("resea.payloads.thread.spawn.arg", "arg" , base.HEX);
proto.fields.thread_destroy_thread = ProtoField.int32("resea.payloads.thread.destroy.thread", "thread" , base.DEC);
proto.fields.timer_set_initial = ProtoField.int32("resea.payloads.timer.set.initial", "initial" , base.DEC);
proto.fields.timer_set_interval = ProtoField.int32("resea.payloads.timer.set.interval", "interval" , base.DEC);
proto.fields.timer_clear_timer = ProtoField.int32("resea.payloads.timer.clear.timer", "timer" , base.DEC);
proto.fields.server_connect_interface = ProtoField.uint8("resea.payloads.server.connect.interface", "interface" , base.DEC);
proto.fields.memory_alloc_pages_order = ProtoField.uint64("resea.payloads.memory.alloc_pages.order", "order" , base.HEX);
proto.fields.memory_alloc_phy_pages_map_at = ProtoField.uint64("resea.payloads.memory.alloc_phy_pages.map_at", "map_at" , base.HEX);
proto.fields.memory_alloc_phy_pages_order = ProtoField.uint64("resea.payloads.memory.alloc_phy_pages.order", "order" , base.HEX);
proto.fields.pager_fill_proc = ProtoField.int32("resea.payloads.pager.fill.proc", "proc" , base.DEC);
proto.fields.pager_fill_addr = ProtoField.uint64("resea.payloads.pager.fill.addr", "addr" , base.HEX);
proto.fields.pager_fill_size = ProtoField.uint64("resea.payloads.pager.fill.size", "size" , base.HEX);

resea_messages = {
    [0x101] = {
        interface_name = "runtime",
        name = "runtime.exit",
        fields = {
            { name="code", proto=proto.fields.runtime_exit_code, offset=32, len=4 },
        }
    },
    [0x102] = {
        interface_name = "runtime",
        name = "runtime.printchar",
        fields = {
            { name="ch", proto=proto.fields.runtime_printchar_ch, offset=32, len=1 },
        }
    },
    [0x103] = {
        interface_name = "runtime",
        name = "runtime.print_str",
        fields = {
            { name="str", proto=proto.fields.runtime_print_str_str, offset=32, len=128 },
        }
    },
    [0x201] = {
        interface_name = "process",
        name = "process.create",
        fields = {
            { name="name", proto=proto.fields.process_create_name, offset=32, len=128 },
        }
    },
    [0x202] = {
        interface_name = "process",
        name = "process.destroy",
        fields = {
            { name="proc", proto=proto.fields.process_destroy_proc, offset=32, len=4 },
        }
    },
    [0x203] = {
        interface_name = "process",
        name = "process.add_pager",
        fields = {
            { name="proc", proto=proto.fields.process_add_pager_proc, offset=32, len=4 },
            { name="pager", proto=proto.fields.process_add_pager_pager, offset=36, len=4 },
            { name="start", proto=proto.fields.process_add_pager_start, offset=40, len=8 },
            { name="size", proto=proto.fields.process_add_pager_size, offset=48, len=8 },
            { name="flags", proto=proto.fields.process_add_pager_flags, offset=56, len=1 },
        }
    },
    [0x204] = {
        interface_name = "process",
        name = "process.send_channel",
        fields = {
            { name="proc", proto=proto.fields.process_send_channel_proc, offset=32, len=4 },
        }
    },
    [0x301] = {
        interface_name = "thread",
        name = "thread.spawn",
        fields = {
            { name="proc", proto=proto.fields.thread_spawn_proc, offset=32, len=4 },
            { name="start", proto=proto.fields.thread_spawn_start, offset=36, len=8 },
            { name="stack", proto=proto.fields.thread_spawn_stack, offset=44, len=8 },
            { name="buffer", proto=proto.fields.thread_spawn_buffer, offset=52, len=8 },
            { name="arg", proto=proto.fields.thread_spawn_arg, offset=60, len=8 },
        }
    },
    [0x302] = {
        interface_name = "thread",
        name = "thread.destroy",
        fields = {
            { name="thread", proto=proto.fields.thread_destroy_thread, offset=32, len=4 },
        }
    },
    [0x401] = {
        interface_name = "timer",
        name = "timer.set",
        fields = {
            { name="initial", proto=proto.fields.timer_set_initial, offset=32, len=4 },
            { name="interval", proto=proto.fields.timer_set_interval, offset=36, len=4 },
        }
    },
    [0x402] = {
        interface_name = "timer",
        name = "timer.clear",
        fields = {
            { name="timer", proto=proto.fields.timer_clear_timer, offset=32, len=4 },
        }
    },
    [0xa01] = {
        interface_name = "server",
        name = "server.connect",
        fields = {
            { name="interface", proto=proto.fields.server_connect_interface, offset=32, len=1 },
        }
    },
    [0xb01] = {
        interface_name = "memory",
        name = "memory.alloc_pages",
        fields = {
            { name="order", proto=proto.fields.memory_alloc_pages_order, offset=32, len=8 },
        }
    },
    [0xb02] = {
        interface_name = "memory",
        name = "memory.alloc_phy_pages",
        fields = {
            { name="map_at", proto=proto.fields.memory_alloc_phy_pages_map_at, offset=32, len=8 },
            { name="order", proto=proto.fields.memory_alloc_phy_pages_order, offset=40, len=8 },
        }
    },
    [0xc01] = {
        interface_name = "pager",
        name = "pager.fill",
        fields = {
            { name="proc", proto=proto.fields.pager_fill_proc, offset=32, len=4 },
            { name="addr", proto=proto.fields.pager_fill_addr, offset=36, len=8 },
            { name="size", proto=proto.fields.pager_fill_size, offset=44, len=8 },
        }
    },
}
