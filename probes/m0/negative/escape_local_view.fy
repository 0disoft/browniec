module main;
import std::bytes as bytes;
fn ref u8[] invalid() {
    let bytes::Buffer buffer = bytes::empty();
    return bytes::view(ref buffer);
}
fn i32 main() { return 0; }
