module main;

import std::io as io;
import std::bytes as bytes;

@effects(console)
fn i32 main() {
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
