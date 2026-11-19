module render;

import errors as errors;
import fuel as meter;
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
    if (code == 18) { return "must_use_result"; }
    return "unavailable";
}
pub fn i32 exit_code(u8 kind) {
    if ((kind >= 1 && kind <= 4) || kind == 18) { return 3; }
    if (kind == 5) { return 6; }
    if ((kind >= 6 && kind <= 8) || (kind >= 12 && kind <= 15)) { return 5; }
    if (kind == 9) { return 7; }
    if (kind == 10) { return 2; }
    return 4;
}

pub enum Format { Text; Json; JsonV2; }
pub fn bool text_mode(Format format){
    return switch(format){case .Text:{true}case .Json:{false}case .JsonV2:{false}};
}
fn bool v2(Format format){
    return switch(format){case .Text:{false}case .Json:{false}case .JsonV2:{true}};
}
fn bool has_location(u8 location){
    return location!=errors::absent_location();
}
fn ref str location_name(u8 location){
    if(location==errors::instruction_location()){return "instruction_index";}
    if(location!=errors::absent_location()){return "source_byte";}
    return "none";
}
fn Result<usize,bytes::BufferError> encode_location(ref mut bytes::Buffer output,Format format,errors::Error error){
    if(!v2(format)){
        let usize key=bytes::append(output,b"\",\"byte_offset\":")?;
        return bytes::append_usize(output,error.offset);
    }
    let usize open=bytes::append(output,b"\",\"location\":{\"kind\":\"")?;
    let usize name=bytes::append(output,text::as_bytes(location_name(error.location)))?;
    if(has_location(error.location)){
        let usize offset=bytes::append(output,b"\",\"offset\":")?;
        let usize value=bytes::append_usize(output,error.offset)?;
        return bytes::append(output,b"}");
    }
    return bytes::append(output,b"\"}");
}
fn Result<bytes::Buffer, bytes::BufferError> encode(Format format,bool run,bool eval, bool failed, i64 value, errors::Error error, u8 arrays) {
    var bytes::Buffer output = bytes::with_capacity(512)?;
    let usize prefix=bytes::append(ref mut output,if(v2(format)){
        b"{\"schema\":\"browniec.result/v2\",\"profile\":"
    }else{b"{\"schema\":\"browniec.result/v1\",\"profile\":"})?;
    let usize header = bytes::append(ref mut output, if (arrays == 8) {
        b"\"brownie.m2-reference/1\",\"command\":"
    } else if (arrays == 7) {
        b"\"brownie.m2-struct-nested/1\",\"command\":"
    } else if (arrays == 6) {
        b"\"brownie.m2-struct-copy/1\",\"command\":"
    } else if (arrays == 5) {
        b"\"brownie.m2-struct-write/1\",\"command\":"
    } else if (arrays == 4) {
        b"\"brownie.m2-struct-read/1\",\"command\":"
    } else if (arrays == 3) {
        b"\"brownie.m2-array-copy/1\",\"command\":"
    } else if (arrays == 2) {
        b"\"brownie.m2-array-write/1\",\"command\":"
    } else if (arrays == 1) {
        b"\"brownie.m2-array-read/1\",\"command\":"
    } else { b"\"brownie.m1-scalar/1\",\"command\":" })?;
    let usize command = bytes::append(ref mut output, if(eval){b"\"eval-i32\""}else if(run){b"\"run\""}else{b"\"check\"" })?;
    let usize status = bytes::append(ref mut output, if (failed) { b",\"status\":\"error\",\"return_i32\":null,\"error\":{\"kind\":\"" }
        else if (run) { b",\"status\":\"completed\",\"return_i32\":" }
        else { b",\"status\":\"checked\",\"return_i32\":null,\"error\":null" })?;
    if (failed) {
        let usize a = bytes::append(ref mut output, text::as_bytes(kind(error.kind)))?;
        let usize location=encode_location(ref mut output,format,error)?;
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
    return selected_outcome(if(json){.Json}else{.Text}, run, failed, value, error, 0);
}
@effects(console)
pub fn i32 selected_outcome(Format format, bool run, bool failed, i64 value, errors::Error error, u8 arrays) {
    return command_outcome(format,run,false,failed,value,error,arrays);
}
@effects(console)
pub fn i32 eval_outcome(Format format,bool failed,i64 value,errors::Error error){
    return command_outcome(format,true,true,failed,value,error,0);
}
@effects(console)
fn i32 command_outcome(Format format,bool run,bool eval,bool failed,i64 value,errors::Error error,u8 arrays){
    let i32 code = if (failed) { exit_code(error.kind) } else { 0 };
    if (!text_mode(format)) {
        let bytes::Buffer output = switch (encode(format,run,eval, failed, value, error, arrays)) {
            case .ok(value): { value } case .err(_): { return 7; }
        };
        let ref u8[] view = bytes::view(ref output);
        return switch (io::write_bytes(view)) {
            case .ok(n): { if (n == view.len) { code } else { 7 } }
            case .err(_): { 7 }
        };
    }
    if (failed) {
        if(!io::write_stderr("browniec: ").is_ok || !io::write_stderr(kind(error.kind)).is_ok){return 7;}
        if(has_location(error.location)){
            let bool instruction=error.location==errors::instruction_location();
            let ref str label=if(instruction){" at instruction "}else{" at byte "};
            if(!io::write_stderr(label).is_ok || !io::write_stderr_usize(error.offset).is_ok){return 7;}
        }
        if(!io::write_stderr("\n").is_ok){return 7;}
    } else if (run) {
        if (!io::write_stderr("return_i32=").is_ok || !io::write_stderr_i64(value).is_ok ||
            !io::write_stderr("\n").is_ok) { return 7; }
    } else if (!io::write_stderr("checked\n").is_ok) { return 7; }
    return code;
}

// Append discoverable limits to the existing version object, then write once.
fn Result<bytes::Buffer,bytes::BufferError> encode_version(ref str prefix){
    var bytes::Buffer output=bytes::with_capacity(4096)?;
    let usize a=bytes::append(ref mut output,text::as_bytes(prefix))?;
    let usize b=bytes::append(ref mut output,b",\"fuel_default\":")?;
    let usize c=bytes::append_usize(ref mut output,meter::cli_default())?;
    let usize d=bytes::append(ref mut output,b",\"fuel_limit\":")?;
    let usize e=bytes::append_usize(ref mut output,meter::cli_limit())?;
    let usize f=bytes::append(ref mut output,b",\"inspect_ir\":true}\n")?;return .ok(output);
}
@effects(console)
pub fn i32 version(ref str prefix){
    let bytes::Buffer output=switch(encode_version(prefix)){case .ok(v):{v}case .err(_):{return 7;}};
    let ref u8[] view=bytes::view(ref output);
    return switch(io::write_bytes(view)){case .ok(n):{if(n==view.len){0}else{7}}case .err(_):{7}};
}
