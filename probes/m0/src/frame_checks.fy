module frame_checks;

pub struct Frame { i64[4] registers; usize length; }

fn Frame edit(Frame input) {
    var Frame result = input;
    result.registers[1] = 9223372036854775807;
    return result;
}

fn void exclusive(ref mut Frame frame) {
    let ref mut i64[] slots = ref mut frame.registers;
    slots[0] = -9223372036854775808;
    slots[3] = 42;
}

pub fn void run() {
    var Frame original = Frame { .registers = [0, 1, 2, 3], .length = 4 };
    let Frame saved = original;
    let Frame changed = edit(original);
    assert(saved.registers[1] == 1 && original.registers[1] == 1);
    assert(changed.registers[1] == 9223372036854775807);
    exclusive(ref mut original);
    assert(original.registers[0] == -9223372036854775808 && original.registers[3] == 42);
    assert(saved.registers[0] == 0 && saved.registers[3] == 3);
    assert(changed.length == 4);
}
