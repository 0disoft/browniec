module main;
import std::bytes as bytes;
fn i32 main() {
    var bytes::Buffer buffer = bytes::empty();
    let ref u8[] view = bytes::view(ref buffer);
    switch (bytes::reserve(ref mut buffer, 8)) { case .ok(_): { } case .err(_): { } };
    assert(view.len == 0);
    return 0;
}
