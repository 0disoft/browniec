module ir_inspect;
import ir as ir;
import compiler as compiler;
import verifier as verifier;
import array_source as arrays;
import program_image as programs;
import static_call_ir as calls;
import static_image as images;
import source_features as features;
import cli_input as input;
import lexer as lexer;
import errors as errors;
import render as render;
import std::bytes as bytes;
import std::io as io;
import std::text as text;
import std::process as process;

enum Error { Allocation; Limit; }
pub fn usize output_limit(){return 131072;}
fn Result<usize,Error> append(ref mut bytes::Buffer out,ref u8[] value){
    let usize used=bytes::len(out);
    if(used>output_limit() || value.len>output_limit()-used){return .err(.Limit);}
    return switch(bytes::append(out,value)){case .ok(n):{.ok(n)}case .err(_):{.err(.Allocation)}};
}
fn Result<usize,Error> number(ref mut bytes::Buffer out,usize value){
    return switch(bytes::append_usize(out,value)){case .ok(n):{.ok(n)}case .err(_):{.err(.Allocation)}};
}
fn ref u8[] profile(u8 kind){
    if(kind==8){return b"brownie.m2-reference/1";}if(kind==7){return b"brownie.m2-struct-nested/1";}
    if(kind==6){return b"brownie.m2-struct-copy/1";}if(kind==5){return b"brownie.m2-struct-write/1";}
    if(kind==4){return b"brownie.m2-struct-read/1";}if(kind==3){return b"brownie.m2-array-copy/1";}
    if(kind==2){return b"brownie.m2-array-write/1";}if(kind==1){return b"brownie.m2-array-read/1";}
    return b"brownie.m1-scalar/1";
}
fn Result<usize,Error> property(ref mut bytes::Buffer out,ref u8[] name,usize value){
    let usize key=append(out,name)?;return number(out,value);
}
// Called only with an admitted Program. This is bounded diagnostic output, not
// an external bytecode format, loader, code cache or executable authority.
fn Result<bytes::Buffer,Error> encode(ref ir::Program p,u8 kind,usize literal_bytes,bool json){
    if(p.count>256 || p.registers>128 || p.constant_count>128 || p.function_count>16 ||
        p.call_count>32 || p.list_used>4096){return .err(.Limit);}
    var bytes::Buffer out=bytes::empty();
    let usize header=append(ref mut out,if(json){b"{\"schema\":\"browniec.ir/v1\",\"command\":\"inspect\",\"status\":\"inspected\",\"profile\":\""}
        else{b"Brownie C private IR diagnostics; not reloadable\nprofile="})?;
    let usize selected=append(ref mut out,profile(kind))?;
    let usize format=append(ref mut out,if(json){b"\",\"format\":\"brownie.private-instructions/1\",\"entry\":"}else{b"\nentry="})?;
    let usize entry=number(ref mut out,p.entry)?;
    let usize instructions=property(ref mut out,if(json){b",\"instruction_count\":"}else{b" instructions="},p.count)?;
    let usize registers=property(ref mut out,if(json){b",\"register_count\":"}else{b" registers="},p.registers)?;
    let usize literals=property(ref mut out,if(json){b",\"literal_bytes\":"}else{b" literal_bytes="},literal_bytes)?;
    let usize function_open=append(ref mut out,if(json){b",\"functions\":["}else{b"\nfunctions:\n"})?;
    var usize i=0;
    while(i<p.function_count){
        if(json && i>0){let usize comma=append(ref mut out,b",")?;}
        let usize id=property(ref mut out,if(json){b"{\"id\":"}else{b"  id="},i)?;
        let usize start=property(ref mut out,if(json){b",\"start\":"}else{b" start="},p.starts[i])?;
        let usize end=property(ref mut out,if(json){b",\"end\":"}else{b" end="},p.ends[i])?;
        let usize first=property(ref mut out,if(json){b",\"register_start\":"}else{b" register_start="},p.register_starts[i])?;
        let usize last=property(ref mut out,if(json){b",\"register_end\":"}else{b" register_end="},p.register_ends[i])?;
        let usize arity=property(ref mut out,if(json){b",\"arity\":"}else{b" arity="},p.arities[i])?;
        let usize result=property(ref mut out,if(json){b",\"return_tag\":"}else{b" return_tag="},p.return_types[i] as usize)?;
        let usize close=append(ref mut out,if(json){b"}"}else{b"\n"})?;i+=1;
    }
    let usize types=append(ref mut out,if(json){b"],\"register_types\":["}else{b"register_types:"})?;i=0;
    while(i<p.registers){
        let usize separator=append(ref mut out,if(json){if(i==0){b""}else{b","}}else{b" "})?;
        let usize tag=number(ref mut out,p.types[i] as usize)?;i+=1;
    }
    let usize constants=append(ref mut out,if(json){b"],\"constants\":["}else{b"\nconstants:"})?;i=0;
    while(i<p.constant_count){
        let usize separator=append(ref mut out,if(json){if(i==0){b""}else{b","}}else{b" "})?;
        let usize value=switch(bytes::append_i64(ref mut out,p.constants[i])){case .ok(n):{n}case .err(_):{return .err(.Allocation);}};
        i+=1;
    }
    let usize code=append(ref mut out,if(json){b"],\"instructions\":["}else{b"\ninstructions:\n"})?;i=0;
    while(i<p.count){
        if(json && i>0){let usize comma=append(ref mut out,b",")?;}
        let usize pc=property(ref mut out,if(json){b"{\"pc\":"}else{b"  pc="},i)?;
        let usize offset=property(ref mut out,if(json){b",\"byte_offset\":"}else{b" source_byte="},p.offsets[i])?;
        let usize open=append(ref mut out,if(json){b",\"bytes\":["}else{b" bytes="})?;var usize b=0;
        while(b<8){
            if(b>0){let usize separator=append(ref mut out,if(json){b","}else{b" "})?;}
            let usize value=number(ref mut out,p.code[i*8+b] as usize)?;b+=1;
        }
        let usize close=append(ref mut out,if(json){b"]}"}else{b"\n"})?;i+=1;
    }
    let usize end=append(ref mut out,if(json){b"],\"error\":null}\n"}else{b""})?;
    if(bytes::len(ref out)>output_limit()){return .err(.Limit);}
    return .ok(out);
}
@effects(console)
fn i32 write(bytes::Buffer output){
    let ref u8[] view=bytes::view(ref output);
    return switch(io::write_bytes(view)){case .ok(n):{if(n==view.len){0}else{7}}case .err(_):{7}};
}
fn Result<bytes::Buffer,Error> encode_failure(errors::Error e){
    var bytes::Buffer out=bytes::empty();
    let usize header=append(ref mut out,b"{\"schema\":\"browniec.ir/v1\",\"command\":\"inspect\",\"status\":\"error\",\"error\":{\"kind\":\"")?;
    let usize kind=append(ref mut out,text::as_bytes(render::kind(e.kind)))?;
    let usize offset=property(ref mut out,b"\",\"byte_offset\":",e.offset)?;
    let usize end=append(ref mut out,b"}}\n")?;return .ok(out);
}
@effects(console)
fn i32 failure(bool json,errors::Error e){
    if(!json){return render::outcome(false,false,true,0,e);}
    let bytes::Buffer output=switch(encode_failure(e)){case .ok(v):{v}case .err(_):{return 7;}};
    let i32 result=write(output);return if(result==0){render::exit_code(e.kind)}else{result};
}
@effects(console)
fn i32 show(ref ir::Program p,u8 kind,usize literals,bool json){
    let bytes::Buffer output=switch(encode(p,kind,literals,json)){case .ok(v):{v}case .err(_):{return 7;}};
    return write(output);
}
// Keep large owning compiler returns in separate, nonrecursive stack frames.
@effects(console)
fn i32 legacy(ref u8[] source,bool json){
    let ir::Program p=switch(compiler::compile(source)){case .ok(v):{v}case .err(e):{return failure(json,e);}};
    let usize checked=switch(verifier::verify(ref p)){case .ok(v):{v}case .err(e):{return failure(json,e);}};
    return show(ref p,arrays::profile(ref p),0,json);
}
@effects(console)
fn i32 retained(ref u8[] source,bool json){
    let programs::ReferenceReturnProgram p=switch(compiler::compile_reference_returns(source,images::metadata_charge()+images::byte_limit())){
        case .ok(v):{v}case .err(e):{return failure(json,compiler::public_error(e));}
    };
    let ref calls::Program code=programs::reference_return_code(ref p);
    return show(ref code.body,8,images::payload_bytes(programs::reference_return_literals(ref p)),json);
}
@effects(console,filesystem)
pub fn i32 cli(){
    let usize argc=process::arg_count();var bool json=false;var bool ir_seen=false;var usize at=3;
    if(argc<3){return failure(false,errors::make(10,0));}
    while(at<argc){
        var u8[64] option=[0;64];
        let usize n=switch(process::arg(at,ref mut option)){case .ok(v):{v}case .err(_):{return failure(json,errors::make(10,0));}};
        let ref u8[] all=ref option;
        if(lexer::equal(all[..n],b"--json") && !json){json=true;}
        else if(lexer::equal(all[..n],b"--ir") && !ir_seen){ir_seen=true;}
        else if(lexer::equal(all[..n],b"--isolated")){return failure(json,errors::make(11,0));}
        else{return failure(json,errors::make(10,0));}at+=1;
    }
    if(!ir_seen){return failure(json,errors::make(10,0));}
    let input::Source source=switch(input::read_source(2)){case .ok(v):{v}case .err(e):{return failure(json,e);}};
    let ref u8[] all=ref source.data;let ref u8[] selected=all[..source.length];
    let bool image=switch(features::retained(selected)){case .ok(v):{v}case .err(e):{return failure(json,e);}};
    return if(image){retained(selected,json)}else{legacy(selected,json)};
}
