module tests::m2::project_manifest;
import project_manifest as project;
import std::bytes as bytes;

fn project::Project parsed(ref u8[] source){
    return switch(project::parse(source)){
        case .ok(p):{p}
        case .err(_):{assert(false);return parsed(b"");}
    };
}
fn bool rejected(ref u8[] source){
    return switch(project::parse(source)){case .err(_):{true}case .ok(_):{false}};
}
fn u8 code(project::Failure failure){
    return switch(failure){
        case .Json:{0}case .Limit:{1}case .Unknown:{2}case .Duplicate:{3}
        case .Missing:{4}case .Value:{5}case .Allocation:{6}case .Bounds:{7}
    };
}
fn void denied(ref u8[] source,project::Failure kind){
    switch(project::parse(source)){case .err(e):{assert(code(e.kind)==code(kind));}case .ok(_):{assert(false);}};
}
fn void append(ref mut bytes::Buffer b,ref u8[] text){assert(bytes::append(b,text).is_ok);}
fn void number(ref mut bytes::Buffer b,usize n){assert(bytes::append_usize(b,n).is_ok);}
fn void padded(ref mut bytes::Buffer b,ref u8[] prefix,usize i,usize length){
    let usize start=bytes::len(b);append(b,prefix);number(b,i);
    while(bytes::len(b)-start<length){append(b,b"a");}
}
fn bytes::Buffer generated(usize sources,usize requirements){
    var bytes::Buffer b=bytes::empty();
    append(ref mut b,b"{\"schema\":\"brownie.project/0.3\",\"name\":\"test\",\"entry\":{\"module\":\"m0\",\"function\":\"go\"},\"sources\":[");
    var usize i=0;
    while(i<sources){
        if(i!=0){append(ref mut b,b",");}
        append(ref mut b,b"{\"module\":\"m");number(ref mut b,i);append(ref mut b,b"\",\"path\":\"src/m");
        number(ref mut b,i);append(ref mut b,b".fy\"}");i+=1;
    }
    append(ref mut b,b"],\"requires\":[");i=0;
    while(i<requirements){
        if(i!=0){append(ref mut b,b",");}
        append(ref mut b,b"\"cap.c");number(ref mut b,i);append(ref mut b,b"\"");i+=1;
    }
    append(ref mut b,b"]}");return b;
}
@test fn void complete_manifest_owns_decoded_names_and_declares_without_granting(){
    var bytes::Buffer original=switch(bytes::copy(b"{\"requires\":[\"fs.read\",\"net.http\"],\"sources\":[{\"path\":\"src/main.fy\",\"module\":\"main\"}],\"entry\":{\"function\":\"go\",\"module\":\"main\"},\"name\":\"te\\u0073t\",\"schema\":\"brownie.project/0.3\"}")){
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}
    };
    let project::Project p=parsed(bytes::view(ref original));
    let ref mut u8[] raw=bytes::view_mut(ref mut original);var usize i=0;
    while(i<raw.len){raw[i]=0;i+=1;}
    assert(bytes::equal(project::name(ref p),b"test"));
    assert(bytes::equal(project::entry_module(ref p),b"main"));
    assert(bytes::equal(project::entry_function(ref p),b"go"));
    assert(project::count(ref p)==1 && project::requirements(ref p)==2);
    assert(switch(project::path(ref p,0)){case .ok(v):{bytes::equal(v,b"src/main.fy")}case .err(_):{false}});
    assert(switch(project::module_name(ref p,0)){case .ok(v):{bytes::equal(v,b"main")}case .err(_):{false}});
    assert(switch(project::requirement(ref p,1)){case .ok(v):{bytes::equal(v,b"net.http")}case .err(_):{false}});
    assert(!project::path(ref p,1).is_ok && !project::module_name(ref p,32).is_ok);
    assert(!project::requirement(ref p,2).is_ok);
}
@test fn void decoded_duplicate_keys_and_duplicate_values_are_rejected(){
    denied(b"{\"schema\":\"brownie.project/0.3\",\"\\u0073chema\":\"brownie.project/0.3\"}",.Duplicate);
    denied(b"{\"entry\":{\"module\":\"main\",\"\\u006dodule\":\"main\",\"function\":\"go\"}}",.Duplicate);
    denied(b"{\"sources\":[{\"module\":\"main\",\"path\":\"src/a.fy\"},{\"module\":\"\\u006dain\",\"path\":\"src/b.fy\"}]}",.Duplicate);
    denied(b"{\"sources\":[{\"module\":\"a\",\"path\":\"src/Main.fy\"},{\"module\":\"b\",\"path\":\"SRC/main.fy\"}]}",.Duplicate);
    denied(b"{\"requires\":[\"fs.read\",\"fs.\\u0072ead\"]}",.Duplicate);
}
@test fn void exact_object_array_and_single_root_grammar_are_required(){
    assert(rejected(b"{}") && rejected(b"[]") && rejected(b"null") && rejected(b""));
    denied(b"{\"schema\":\"wrong\"}",.Value);
    denied(b"{\"unknown\":{\"deep\":[[]]}}",.Unknown);
    denied(b"{\"entry\":{\"module\":\"main\",\"unknown\":\"go\"}}",.Unknown);
    denied(b"{\"entry\":{\"module\":\"main\",\"function\":\"go\",}}",.Json);
    denied(b"{\"sources\":[{\"module\":\"main\",\"path\":\"main.fy\"},]}",.Json);
    denied(b"{\"requires\":[\"fs.read\",]}",.Value);
    denied(b"{\"requires\":true}",.Json);denied(b"{\"name\":1}",.Value);
    denied(b"{\"sources\":[]}",.Missing);
    denied(b"{\"schema\":\"brownie.project/0.3\",\"name\":\"x\",\"entry\":{\"module\":\"absent\",\"function\":\"go\"},\"sources\":[{\"module\":\"main\",\"path\":\"main.fy\"}],\"requires\":[]}",.Value);
    var bytes::Buffer trailing=generated(1,0);append(ref mut trailing,b"{}");
    denied(bytes::view(ref trailing),.Json);
}
@test fn void member_namespaces_paths_utf8_and_escapes_are_authenticated(){
    denied(b"{\"sources\":[{\"module\":\"std::x\",\"path\":\"x.fy\"}]}",.Value);
    denied(b"{\"sources\":[{\"module\":\"main\",\"path\":\"../x.fy\"}]}",.Value);
    denied(b"{\"sources\":[{\"module\":\"main\",\"path\":\"C:/x.fy\"}]}",.Value);
    denied(b"{\"sources\":[{\"module\":\"main\",\"path\":\"src/NUL.fy\"}]}",.Value);
    denied(b"{\"sources\":[{\"module\":\"main\",\"path\":\"x\\u0000.fy\"}]}",.Value);
    denied(b"{\"name\":\"\\uD800\"}",.Json);denied(b"{\"name\":\"\\uDC00\"}",.Json);
    denied(b"{\"name\":\"\xff\"}",.Json);
}
@test fn void manifest_source_limit_is_32_independent_of_native_compiler_limit(){
    let bytes::Buffer maximum=generated(32,0);let project::Project p=parsed(bytes::view(ref maximum));
    assert(project::count(ref p)==32 && project::requirements(ref p)==0);
    assert(switch(project::module_name(ref p,31)){case .ok(v):{bytes::equal(v,b"m31")}case .err(_):{false}});
    let bytes::Buffer excessive=generated(33,0);
    assert(switch(project::parse(bytes::view(ref excessive))){case .err(e):{code(e.kind)==1}case .ok(_):{false}});
}
@test fn void all_256_requirements_are_retained_and_the_257th_fails(){
    let bytes::Buffer maximum=generated(1,256);let project::Project p=parsed(bytes::view(ref maximum));
    assert(project::requirements(ref p)==256);
    assert(switch(project::requirement(ref p,255)){case .ok(v):{bytes::equal(v,b"cap.c255")}case .err(_):{false}});
    let bytes::Buffer excessive=generated(1,257);
    assert(switch(project::parse(bytes::view(ref excessive))){case .err(e):{code(e.kind)==1}case .ok(_):{false}});
}
@test fn void simultaneous_maximum_counts_and_string_lengths_fit_the_exact_pool(){
    var bytes::Buffer b=bytes::empty();
    append(ref mut b,b"{\"schema\":\"brownie.project/0.3\",\"name\":\"");
    padded(ref mut b,b"n",0,80);append(ref mut b,b"\",\"entry\":{\"module\":\"");
    padded(ref mut b,b"m",0,128);append(ref mut b,b"\",\"function\":\"");
    padded(ref mut b,b"f",0,64);append(ref mut b,b"\"},\"sources\":[");var usize i=0;
    while(i<32){
        if(i!=0){append(ref mut b,b",");}
        append(ref mut b,b"{\"module\":\"");padded(ref mut b,b"m",i,128);
        append(ref mut b,b"\",\"path\":\"");padded(ref mut b,b"file",i,237);
        append(ref mut b,b".fy\"}");i+=1;
    }
    append(ref mut b,b"],\"requires\":[");i=0;
    while(i<256){
        if(i!=0){append(ref mut b,b",");}
        append(ref mut b,b"\"");padded(ref mut b,b"cap.c",i,128);append(ref mut b,b"\"");i+=1;
    }
    append(ref mut b,b"]}");let project::Project p=parsed(bytes::view(ref b));
    assert(project::count(ref p)==32 && project::requirements(ref p)==256);
    assert(project::decoded_bytes(ref p)==44816);
}
