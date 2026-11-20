module main;

import cli_published_output as cli;
import module_output_program as programs;
import module_input_entry as entries;
import module_index as modules;
import source_snapshot as sources;
import runtime_input as inputs;
import render as render;
import std::bytes as bytes;

fn Result<programs::Program,u8> compile(ref u8[] source){
    var sources::Builder builder=switch(sources::builder(4096,4096)){
        case .ok(v):{v}case .err(_):{return .err(1);}
    };
    if(!sources::add(ref mut builder,b"app.brc",source).is_ok){return .err(2);}
    let sources::Snapshot snapshot=switch(sources::freeze(ref builder)){
        case .ok(v):{v}case .err(_):{return .err(3);}
    };
    let modules::Index index=switch(modules::build(snapshot)){
        case .ok(v):{v}case .err(_):{return .err(4);}
    };
    let entries::InputEntry entry=switch(entries::select_i32_input(index,b"app",b"chosen")){
        case .ok(v):{v}case .err(_):{return .err(5);}
    };
    return switch(programs::compile_input(entry,65536)){case .ok(v):{.ok(v)}case .err(_):{.err(6)}};
}
@effects(console)
fn i32 verify(ref programs::Program program,ref u8[] data,usize limit,bool allowed,render::Format format){
    var usize charge=0;
    let inputs::Snapshot input=switch(inputs::snapshot(data,inputs::hard_limit(),0,ref mut charge)){
        case .ok(v):{v}case .err(_):{return 70;}
    };
    let programs::Execution result=programs::complete(program,ref input,16000000,limit,allowed);
    return cli::write(format,program,ref result);
}
@effects(console)
fn i32 main(){
    let programs::Program success=switch(compile(
        b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 77;}")){
        case .ok(v):{v}case .err(e):{return e as i32;}
    };
    if(verify(ref success,b"",0,true,.Json)!=0){return 10;}
    if(verify(ref success,b"\xFF",1,true,.JsonV2)!=0){return 11;}
    if(verify(ref success,b"\x00\xFF",2,true,.JsonV2)!=0){return 12;}
    if(verify(ref success,b"\x00\xFF\xFE",3,true,.JsonV2)!=0){return 13;}
    if(verify(ref success,b"x",0,true,.JsonV2)!=5){return 14;}
    if(verify(ref success,b"x",1,false,.JsonV2)!=4){return 15;}
    let programs::Program trap=switch(compile(
        b"module app;pub fn i32 chosen(ref u8[] data){output::emit(ref data);return 1/0;}")){
        case .ok(v):{v}case .err(e):{return e as i32;}
    };
    if(verify(ref trap,b"discard",7,true,.JsonV2)!=5){return 16;}
    var bytes::Buffer maximum=bytes::empty();
    if(!bytes::resize_zeroed(ref mut maximum,inputs::hard_limit()).is_ok){return 17;}
    let ref mut u8[] data=bytes::view_mut(ref mut maximum);
    data[data.len-1]=255;
    if(verify(ref success,bytes::view(ref maximum),inputs::hard_limit(),true,.JsonV2)!=0){return 18;}
    return 0;
}
