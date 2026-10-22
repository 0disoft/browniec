module main;
import std::bytes as bytes;
fn i32 main() {
    let bytes::Buffer original = bytes::empty();
    let bytes::Buffer moved = original;
    assert(bytes::len(ref original) == 0);
    assert(bytes::len(ref moved) == 0);
    return 0;
}
