module cli_source_manifest;

import catalog_digest as hash;
import errors as errors;
import project_manifest as projects;
import render as render;
import source_snapshot as sources;
import std::bytes as bytes;
import std::io as io;

fn errors::Error invalid(){return errors::absent(5,0);}
fn errors::Error allocation(){return errors::absent(15,0);}

fn Result<usize,errors::Error> append(ref mut bytes::Buffer output,ref u8[] data){
    return switch(bytes::append(output,data)){case .ok(n):{.ok(n)}case .err(_):{.err(allocation())}};
}

fn Result<ref u8[],errors::Error> path(ref projects::Project project,usize row){
    return switch(projects::path(project,row)){case .ok(p):{.ok(p)}case .err(_):{.err(invalid())}};
}

fn bool before(ref u8[] a,ref u8[] b){
    let usize length=if(a.len<b.len){a.len}else{b.len};
    var usize i=0;
    while(i<length){
        if(a[i]!=b[i]){return a[i]<b[i];}
        i+=1;
    }
    return a.len<b.len;
}

fn Result<usize,errors::Error> append_row(ref mut bytes::Buffer output,ref projects::Project project,
    ref sources::Snapshot snapshot,usize row){
    let ref u8[] declared=path(project,row)?;
    let ref u8[] member=switch(sources::name(snapshot,row)){
        case .ok(v):{v}case .err(_):{return .err(invalid());}
    };
    // Anchored collection preserves the manifest row order.
    if(!bytes::equal(member,declared)){return .err(invalid());}
    let ref u8[] name=switch(projects::module_name(project,row)){
        case .ok(v):{v}case .err(_):{return .err(invalid());}
    };
    let sources::Span span=switch(sources::whole(snapshot,row)){
        case .ok(v):{v}case .err(_):{return .err(invalid());}
    };
    let ref u8[] source=switch(sources::view(snapshot,span)){
        case .ok(v):{v}case .err(_):{return .err(invalid());}
    };
    let u32[8] digest=switch(hash::digest(source)){
        case .ok(v):{v}case .err(_):{return .err(invalid());}
    };
    var u8[64] text=[0;64];
    let ref u8[] hex=b"0123456789abcdef";
    var usize i=0;
    while(i<64){
        let usize word=digest[i/8] as usize;
        text[i]=hex[(word>>(28-4*(i%8)))&15];
        i+=1;
    }
    // Both fields were validated by the manifest parser's ASCII grammar.
    discard append(output,b"{\"module\":\"")?;
    discard append(output,name)?;
    discard append(output,b"\",\"path\":\"")?;
    discard append(output,member)?;
    discard append(output,b"\",\"sha256\":\"")?;
    discard append(output,ref text)?;
    return append(output,b"\"}");
}

fn Result<bytes::Buffer,errors::Error> encode(ref projects::Project project,ref sources::Snapshot snapshot){
    let usize count=sources::count(snapshot);
    if(count==0 || count>16 || count!=projects::count(project)){return .err(invalid());}
    var usize[16] order=[0;16];
    var usize row=0;
    while(row<count){
        let ref u8[] member=path(project,row)?;
        var usize at=row;
        while(at>0){
            if(!before(member,path(project,order[at-1])?)){break;}
            order[at]=order[at-1];
            at-=1;
        }
        order[at]=row;
        row+=1;
    }
    var bytes::Buffer output=switch(bytes::with_capacity(128+count*480)){
        case .ok(v):{v}case .err(_):{return .err(allocation());}
    };
    discard append(ref mut output,b"{\"schema\":\"browniec.source-manifest/v1\",\"command\":\"check\",\"status\":\"checked\",\"sources\":[")?;
    row=0;
    while(row<count){
        if(row!=0){discard append(ref mut output,b",")?;}
        discard append_row(ref mut output,project,snapshot,order[row])?;
        row+=1;
    }
    discard append(ref mut output,b"]}\n")?;
    return .ok(output);
}

@effects(console)
pub fn i32 publish(ref projects::Project project,ref sources::Snapshot snapshot){
    let bytes::Buffer output=switch(encode(project,snapshot)){
        case .ok(v):{v}
        case .err(e):{return render::selected_outcome(.Json,false,true,0,e,0);}
    };
    let ref u8[] data=bytes::view(ref output);
    return switch(io::write_bytes(data)){case .ok(n):{if(n==data.len){0}else{7}}case .err(_):{7}};
}
