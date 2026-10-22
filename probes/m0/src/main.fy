module main;

import std::io as io;
import std::bytes as bytes;
import arithmetic_checks as arithmetic_checks;
import codec_checks as codec_checks;
import storage_checks as storage_checks;
import std::process as process;

@effects(console)
fn i32 main() {
    if (process::arg_count() == 2) {
        storage_checks::oom();
    } else {
        arithmetic_checks::run();
        codec_checks::run();
        storage_checks::run();
    }
    var bytes::Buffer buffer = switch (bytes::with_capacity(64)) {
        case .ok(value): { value }
        case .err(_): { return 1; }
    };
    assert(bytes::capacity(ref buffer) == 64);
    assert(bytes::len(ref buffer) == 0);
    return switch (io::write("brownie-m0: baseline passed\n")) {
        case .ok(_): { 0 }
        case .err(_): { 2 }
    };
}
