module render;

import errors as errors;
import std::bytes as bytes;
import std::io as io;
import std::text as text;

pub fn ref str kind(u8 code) {
    if (code == 1) { return "lexical"; }
    if (code == 2) { return "syntax"; }
    if (code == 3) { return "type"; }
    if (code == 4) { return "compile_limit"; }
    if (code == 5) { return "verification"; }
    if (code == 6) { return "overflow"; }
    if (code == 7) { return "zero_divisor"; }
    if (code == 8) { return "fuel"; }
    if (code == 9) { return "input_io"; }
    if (code == 10) { return "usage"; }
    if (code == 12) { return "frame_limit"; }
    if (code == 13) { return "array_limit"; }
    if (code == 14) { return "bounds"; }
    if (code == 15) { return "allocation"; }
    return "unavailable";
}
pub fn i32 exit_code(u8 kind) {
    if (kind >= 1 && kind <= 4) { return 3; }
    if (kind == 5) { return 6; }
    if ((kind >= 6 && kind <= 8) || (kind >= 12 && kind <= 15)) { return 5; }
    if (kind == 9) { return 7; }
    if (kind == 10) { return 2; }
    return 4;
}

fn Result<bytes::Buffer, bytes::BufferError> encode(bool run, bool failed, i64 value, errors::Error error, u8 arrays) {
    var bytes::Buffer output = bytes::with_capacity(512)?;
    let usize header = bytes::append(ref mut output, if (arrays == 6) {
        b"{\"schema\":\"browniec.result/v1\",\"profile\":\"brownie.m2-struct-copy/1\",\"command\":"
    } else if (arrays == 5) {
        b"{\"schema\":\"browniec.result/v1\",\"profile\":\"brownie.m2-struct-write/1\",\"command\":"
    } else if (arrays == 4) {
        b"{\"schema\":\"browniec.result/v1\",\"profile\":\"brownie.m2-struct-read/1\",\"command\":"
    } else if (arrays == 3) {
        b"{\"schema\":\"browniec.result/v1\",\"profile\":\"brownie.m2-array-copy/1\",\"command\":"
    } else if (arrays == 2) {
        b"{\"schema\":\"browniec.result/v1\",\"profile\":\"brownie.m2-array-write/1\",\"command\":"
    } else if (arrays == 1) {
        b"{\"schema\":\"browniec.result/v1\",\"profile\":\"brownie.m2-array-read/1\",\"command\":"
    } else { b"{\"schema\":\"browniec.result/v1\",\"profile\":\"brownie.m1-scalar/1\",\"command\":" })?;
    let usize command = bytes::append(ref mut output, if (run) { b"\"run\"" } else { b"\"check\"" })?;
    let usize status = bytes::append(ref mut output, if (failed) { b",\"status\":\"error\",\"return_i32\":null,\"error\":{\"kind\":\"" }
        else if (run) { b",\"status\":\"completed\",\"return_i32\":" }
        else { b",\"status\":\"checked\",\"return_i32\":null,\"error\":null" })?;
    if (failed) {
        let usize a = bytes::append(ref mut output, text::as_bytes(kind(error.kind)))?;
        let usize b = bytes::append(ref mut output, b"\",\"byte_offset\":")?;
        let usize c = bytes::append_usize(ref mut output, error.offset)?;
        let usize d = bytes::append(ref mut output, b"}")?;
    } else if (run) {
        let usize a = bytes::append_i64(ref mut output, value)?;
        let usize b = bytes::append(ref mut output, b",\"error\":null")?;
    }
    let usize end = bytes::append(ref mut output, b"}\n")?;
    return .ok(output);
}

@effects(console)
pub fn i32 outcome(bool json, bool run, bool failed, i64 value, errors::Error error) {
    return selected_outcome(json, run, failed, value, error, 0);
}
@effects(console)
pub fn i32 selected_outcome(bool json, bool run, bool failed, i64 value, errors::Error error, u8 arrays) {
    let i32 code = if (failed) { exit_code(error.kind) } else { 0 };
    if (json) {
        let bytes::Buffer output = switch (encode(run, failed, value, error, arrays)) {
            case .ok(value): { value } case .err(_): { return 7; }
        };
        let ref u8[] view = bytes::view(ref output);
        return switch (io::write_bytes(view)) {
            case .ok(n): { if (n == view.len) { code } else { 7 } }
            case .err(_): { 7 }
        };
    }
    if (failed) {
        if (!io::write_stderr("browniec: ").is_ok || !io::write_stderr(kind(error.kind)).is_ok ||
            !io::write_stderr(" at byte ").is_ok || !io::write_stderr_usize(error.offset).is_ok ||
            !io::write_stderr("\n").is_ok) { return 7; }
    } else if (run) {
        if (!io::write_stderr("return_i32=").is_ok || !io::write_stderr_i64(value).is_ok ||
            !io::write_stderr("\n").is_ok) { return 7; }
    } else if (!io::write_stderr("checked\n").is_ok) { return 7; }
    return code;
}
