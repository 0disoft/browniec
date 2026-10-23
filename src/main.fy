module main;

import cli_input as input;
import compiler as compiler;
import errors as errors;
import lexer as lexer;
import render as render;
import verifier as verifier;
import vm as vm;
import std::process as process;
import std::num as num;
import std::io as io;

@effects(console)
fn i32 fail(bool json, bool run, u8 kind, usize offset) {
    return render::outcome(json, run, true, 0, errors::make(kind, offset));
}
@effects(console, filesystem)
fn i32 main() {
    let usize argc = process::arg_count();
    if (argc < 2) { return fail(false, false, 10, 0); }
    var u8[64] command = [0; 64];
    let usize command_length = switch (process::arg(1, ref mut command)) {
        case .ok(n): { n } case .err(_): { return fail(false, false, 10, 0); }
    };
    let ref u8[] command_view = ref command;
    if (lexer::equal(command_view[..command_length], b"--version")) {
        if (argc == 2) {
            return if (io::write("Brownie C M1 scalar (experimental), brownie.m1-scalar/1\n").is_ok) { 0 } else { 7 };
        }
        var u8[16] option = [0; 16];
        let usize size = switch (process::arg(2, ref mut option)) {
            case .ok(n): { n } case .err(_): { return fail(false, false, 10, 0); }
        };
        let ref u8[] view = ref option;
        if (argc != 3 || !lexer::equal(view[..size], b"--json")) { return fail(false, false, 10, 0); }
        return if (io::write("{\"schema\":\"browniec.version/v1\",\"profile\":\"brownie.m1-scalar/1\",\"core\":true,\"restricted\":false,\"embed\":false}\n").is_ok) { 0 } else { 7 };
    }
    if (lexer::equal(command_view[..command_length], b"--help") && argc == 2) {
        return if (io::write("browniec check SOURCE [--json]\nbrowniec run SOURCE [--fuel N] [--json]\nTrusted local source only; experimental i32 expression subset.\n").is_ok) { 0 } else { 7 };
    }
    let bool run = lexer::equal(command_view[..command_length], b"run");
    if (!run && !lexer::equal(command_view[..command_length], b"check")) {
        return fail(false, false, 10, 0);
    }
    if (argc < 3) { return fail(false, run, 10, 0); }
    var bool json = false;
    var bool fuel_seen = false;
    var usize fuel = 256;
    var usize at = 3;
    while (at < argc) {
        var u8[64] option = [0; 64];
        let usize length = switch (process::arg(at, ref mut option)) {
            case .ok(n): { n } case .err(_): { return fail(json, run, 10, 0); }
        };
        let ref u8[] view = ref option;
        if (lexer::equal(view[..length], b"--json") && !json) { json = true; }
        else if (lexer::equal(view[..length], b"--fuel") && run && !fuel_seen && at + 1 < argc) {
            at += 1;
            var u8[20] raw = [0; 20];
            let usize count = switch (process::arg(at, ref mut raw)) {
                case .ok(n): { n } case .err(_): { return fail(json, run, 10, 0); }
            };
            let ref u8[] number = ref raw;
            let i64 parsed = switch (num::parse_i64_decimal(number[..count])) {
                case .ok(n): { n } case .err(_): { return fail(json, run, 10, 0); }
            };
            if (parsed < 0 || parsed > 1000000) { return fail(json, run, 10, 0); }
            fuel = switch (num::usize_from_i64(parsed)) {
                case .ok(n): { n } case .err(_): { return fail(json, run, 10, 0); }
            };
            fuel_seen = true;
        } else if (lexer::equal(view[..length], b"--isolated")) { return fail(json, run, 11, 0); }
        else { return fail(json, run, 10, 0); }
        at += 1;
    }
    let input::Source source = switch (input::read_source(2)) {
        case .ok(value): { value } case .err(e): { return fail(json, run, e.kind, e.offset); }
    };
    let ref u8[] source_view = ref source.data;
    let program = switch (compiler::compile(source_view[..source.length])) {
        case .ok(value): { value } case .err(e): { return fail(json, run, e.kind, e.offset); }
    };
    let usize verified = switch (verifier::verify(ref program)) {
        case .ok(n): { n } case .err(e): { return fail(json, run, e.kind, e.offset); }
    };
    if (!run) { return render::outcome(json, false, false, 0, errors::make(0, 0)); }
    return switch (vm::run(ref program, fuel)) {
        case .ok(value): { render::outcome(json, true, false, value, errors::make(0, 0)) }
        case .err(e): { fail(json, true, e.kind, e.offset) }
    };
}
