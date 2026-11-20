module render;

import errors as errors;
import cli_output_base64 as base64;
import runtime_output as output_limits;
import project_names as names;
import source_snapshot as sources;
import fuel as meter;
import std::bytes as bytes;
import std::io as io;
import std::text as text;

pub fn u8 input_limit_kind(){return 31;}

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
    if (code == 19) { return "output_denied"; }
    if (code == 20) { return "output_limit"; }
    if (code == errors::cancelled_kind()) { return "cancelled"; }
    if (code == errors::deadline_kind()) { return "deadline"; }
    if (code == errors::memory_limit_kind()) { return "memory_limit"; }
    if (code == input_limit_kind()) { return "input_limit"; }
    return "unavailable";
}
pub fn i32 exit_code(u8 kind) {
    if ((kind >= 1 && kind <= 4) || kind == 18) { return 3; }
    if (kind == 5) { return 6; }
    if ((kind >= 6 && kind <= 8) || (kind >= 12 && kind <= 15) || kind == 20 || kind == input_limit_kind()) { return 5; }
    if (kind == errors::deadline_kind() || kind == errors::memory_limit_kind() || kind == errors::cancelled_kind()) { return 5; }
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
fn Result<usize,bytes::BufferError> encode_location(ref mut bytes::Buffer output,Format format,errors::Error error,
    ref u8[] path,sources::Span span,sources::Position position){
    if(!v2(format)){
        let usize key=bytes::append(output,b"\",\"byte_offset\":")?;
        return bytes::append_usize(output,error.offset);
    }
    let usize open=bytes::append(output,b"\",\"location\":{\"kind\":\"")?;
    let usize name=bytes::append(output,text::as_bytes(location_name(error.location)))?;
    if(has_location(error.location)){
        let usize offset=bytes::append(output,b"\",\"offset\":")?;
        let usize value=bytes::append_usize(output,error.offset)?;
        if(path.len!=0){
            discard bytes::append(output,b",\"path\":\"")?;
            discard bytes::append(output,path)?;
            discard bytes::append(output,b"\",\"source_index\":")?;
            discard bytes::append_usize(output,span.source)?;
            discard bytes::append(output,b",\"end_offset\":")?;
            discard bytes::append_usize(output,span.end)?;
            discard bytes::append(output,b",\"line\":")?;
            discard bytes::append_usize(output,position.line)?;
            discard bytes::append(output,b",\"byte_column\":")?;
            discard bytes::append_usize(output,position.byte_column)?;
        }
        return bytes::append(output,b"}");
    }
    return bytes::append(output,b"\"}");
}
fn Result<bytes::Buffer, bytes::BufferError> encode(Format format,bool run,bool eval,bool failed,i64 value,
    errors::Error error,u8 arrays,ref u8[] path,sources::Span span,sources::Position position,
    bool with_output,ref u8[] payload){
    let usize encoded=base64::encoded_bytes(payload.len);
    var bytes::Buffer output=bytes::with_capacity(512+encoded)?;
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
        let usize location=encode_location(ref mut output,format,error,path,span,position)?;
        let usize d = bytes::append(ref mut output, b"}")?;
    } else if (run) {
        let usize a = bytes::append_i64(ref mut output, value)?;
        let usize b = bytes::append(ref mut output, b",\"error\":null")?;
        if(with_output){
            discard bytes::append(ref mut output,b",\"output_b64\":\"")?;
            discard base64::append(ref mut output,payload)?;
            discard bytes::append_byte(ref mut output,34)?;
        }
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
        return json_outcome(format,run,eval,failed,value,error,arrays,b"",sources::no_source(),
            sources::Position{.line=0,.byte_column=0});
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

@effects(console)
fn i32 json_outcome(Format format,bool run,bool eval,bool failed,i64 value,errors::Error error,u8 arrays,
    ref u8[] path,sources::Span span,sources::Position position){
    let bytes::Buffer output=switch(encode(format,run,eval,failed,value,error,arrays,path,span,position,false,b"")){
        case .ok(v):{v}case .err(_):{return 7;}
    };
    return write_result(ref output,if(failed){exit_code(error.kind)}else{0});
}

@effects(console)
fn i32 write_result(ref bytes::Buffer output,i32 code){
    let ref u8[] view=bytes::view(output);
    return switch(io::write_bytes(view)){
        case .ok(n):{if(n==view.len){code}else{7}}
        case .err(_):{7}
    };
}

@effects(console)
pub fn i32 published_output(Format format,i64 value,ref u8[] payload){
    if(text_mode(format)){return selected_outcome(format,true,true,0,errors::absent(10,0),8);}
    if(payload.len>output_limits::hard_limit()){return 7;}
    let bytes::Buffer output=switch(encode(format,true,false,false,value,errors::absent(0,0),8,b"",
        sources::no_source(),sources::Position{.line=0,.byte_column=0},true,payload)){
        case .ok(v):{v}case .err(_):{return 7;}
    };
    return write_result(ref output,0);
}

fn Result<bytes::Buffer,bytes::BufferError> project_message(ref u8[] path,errors::Error error,sources::Position position){
    var bytes::Buffer output=bytes::with_capacity(512)?;
    discard bytes::append(ref mut output,b"browniec: ")?;
    discard bytes::append(ref mut output,text::as_bytes(kind(error.kind)))?;
    discard bytes::append(ref mut output,b" at ")?;
    discard bytes::append(ref mut output,path)?;
    discard bytes::append(ref mut output,b":")?;
    discard bytes::append_usize(ref mut output,position.line)?;
    discard bytes::append(ref mut output,b":")?;
    discard bytes::append_usize(ref mut output,position.byte_column)?;
    discard bytes::append(ref mut output,b"\n")?;
    return .ok(output);
}

@effects(console)
pub fn i32 project_failure(Format format,bool run,errors::Error error,ref sources::Snapshot snapshot,
    sources::Span span,u8 arrays){
    if(error.location==errors::instruction_location()){return selected_outcome(format,run,true,0,error,arrays);}
    let errors::Error absent=errors::absent(error.kind,0);
    let sources::Position position=switch(sources::position(snapshot,span)){
        case .ok(v):{v}case .err(_):{return selected_outcome(format,run,true,0,absent,arrays);}
    };
    let ref u8[] path=switch(sources::name(snapshot,span.source)){
        case .ok(v):{v}case .err(_):{return selected_outcome(format,run,true,0,absent,arrays);}
    };
    // Canonical member spellings exclude delimiters, terminal controls and newlines.
    if(!names::member_path(path)){return selected_outcome(format,run,true,0,absent,arrays);}
    let errors::Error located=errors::make(error.kind,span.start);
    if(v2(format)){return json_outcome(format,run,false,true,0,located,arrays,path,span,position);}
    if(!text_mode(format)){return selected_outcome(format,run,true,0,located,arrays);}
    let bytes::Buffer output=switch(project_message(path,located,position)){
        case .ok(v):{v}case .err(_):{return 7;}
    };
    let ref u8[] view=bytes::view(ref output);
    return switch(io::write_stderr_bytes(view)){
        case .ok(n):{if(n==view.len){exit_code(error.kind)}else{7}}
        case .err(_):{7}
    };
}

// Append discoverable limits to the existing version object, then write once.
fn Result<bytes::Buffer,bytes::BufferError> encode_version(ref str prefix){
    var bytes::Buffer output=bytes::with_capacity(4096)?;
    let usize a=bytes::append(ref mut output,text::as_bytes(prefix))?;
    let usize b=bytes::append(ref mut output,b",\"fuel_default\":")?;
    let usize c=bytes::append_usize(ref mut output,meter::cli_default())?;
    let usize d=bytes::append(ref mut output,b",\"fuel_limit\":")?;
    let usize e=bytes::append_usize(ref mut output,meter::cli_limit())?;
    let usize f=bytes::append(ref mut output,b",\"inspect_ir\":true,\"inspect_limits\":true}\n")?;return .ok(output);
}
@effects(console)
pub fn i32 version(ref str prefix){
    let bytes::Buffer output=switch(encode_version(prefix)){case .ok(v):{v}case .err(_):{return 7;}};
    let ref u8[] view=bytes::view(ref output);
    return switch(io::write_bytes(view)){case .ok(n):{if(n==view.len){0}else{7}}case .err(_):{7}};
}
