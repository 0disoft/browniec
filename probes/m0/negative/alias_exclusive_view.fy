module main;
import std::bytes as bytes;
fn i32 main() {
    var bytes::Buffer buffer = bytes::empty();
    let ref mut u8[] view = bytes::view_mut(ref mut buffer);
    assert(bytes::len(ref buffer) == 0);
    assert(view.len == 0);
    return 0;
}
