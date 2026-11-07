module main;
import project_source_loader as loader;
import project_manifest as project;
import project_program as programs;
import source_snapshot as sources;
import std::bytes as bytes;
import std::process as process;
unsafe extern C fn void psl_test_start();
unsafe extern C fn void psl_test_clean();
unsafe extern C fn void psl_test_failure(u32 mode);
unsafe extern C fn usize psl_heap_live();
unsafe extern C fn void psl_test_rewrite(ptr u8 root,usize length);
fn usize argument(usize at,ref mut u8[] out){
    return switch(process::arg(at,out)){case .ok(v):{v}case .err(_):{assert(false);0}};
}
fn void run(ref programs::Program p,usize fuel,i64 expected){
    switch(programs::run(p,fuel)){case .ok(v):{assert(v==expected);}case .err(_):{assert(false);}};
}
fn bool equal_name(ref sources::Snapshot s,usize id,ref u8[] expected){
    return switch(sources::name(s,id)){case .ok(v):{bytes::equal(v,expected)}case .err(_):{false}};
}
fn void rejected(loader::Error error,u8 mode){
    switch(error){
        case .Limit:{assert(mode==55);}
        case .Acquisition:{assert(mode==53 || mode==56 || mode==57 || mode==65);}
        case .Binding:{assert(mode==52);}
        case .Compile:{assert(mode==54);}
    };
}
fn void scenario(ref u8[] root,ref mut u8[] json,u8 mode){
    let project::Project metadata=switch(project::parse(json)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    // Metadata owns its decoded strings; the original caller buffer may change.
    json[0]=0;
    if(mode==56 || mode==57 || mode==65){unsafe {psl_test_failure(if(mode==56){1}else{if(mode==57){2}else{3}})};}
    switch(loader::compile(metadata,root,if(mode==55){4097}else{4096},65536)){
        case .err(e):{rejected(e,mode);}
        case .ok(p):{
            assert(mode>=48 && mode<=51);unsafe {psl_test_clean()};
            assert(sources::count(programs::snapshot(ref p))==2);
            assert(equal_name(programs::snapshot(ref p),0,b"src/main.fy") && equal_name(programs::snapshot(ref p),1,b"src/math.fy"));
            assert(bytes::equal(project::name(programs::metadata(ref p)),b"fixture"));
            if(mode==49 || mode==50){
                switch(programs::run(ref p,if(mode==49){0}else{16000000})){
                    case .ok(_):{assert(false);}case .err(e):{switch(e.kind){
                        case .Requirements:{assert(mode==49 && e.diagnostic.code.kind==11);}
                        case .Runtime:{assert(mode==50 && e.diagnostic.code.kind==7);}
                        case .Binding:{assert(false);}case .Compile:{assert(false);}
                    };}
                };
                if(mode==49){
                    switch(programs::run(ref p,16000000)){case .ok(_):{assert(false);}case .err(e):{
                        switch(e.kind){case .Requirements:{}case .Runtime:{assert(false);}case .Compile:{assert(false);}case .Binding:{assert(false);}};
                    }};
                }
            }else{
                run(ref p,16000000,if(mode==51){99}else{42});
                unsafe {psl_test_rewrite(root as ptr u8,root.len)};
                run(ref p,16000000,if(mode==51){99}else{42});
                let sources::Span all=switch(sources::whole(programs::snapshot(ref p),0)){
                    case .ok(v):{v}case .err(_):{assert(false);sources::no_source()}
                };
                switch(sources::view(programs::snapshot(ref p),all)){
                    case .ok(v):{assert(bytes::equal(v,b"module app;import lib as m;pub fn i32 start(){return m::answer();}pub fn i32 other(){return 99;}"));}
                    case .err(_):{assert(false);}
                };
            }
        }
    };
    unsafe {psl_test_failure(0)};
}
fn i32 main(){
    var u8[3072] root=[0;3072];var u8[4096] json=[0;4096];var u8[2] mode=[0;2];
    let usize rl=argument(1,ref mut root);let usize jl=argument(2,ref mut json);let usize ml=argument(3,ref mut mode);assert(ml==1);
    unsafe {psl_test_start()};assert(unsafe {psl_heap_live()}==0);
    scenario(ref root[..rl],ref mut json[..jl],mode[0]);
    unsafe {psl_test_clean()};assert(unsafe {psl_heap_live()}==0);return 0;
}
