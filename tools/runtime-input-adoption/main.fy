module main;
import runtime_input_adoption as adopt;
import runtime_input as input;
unsafe extern C fn usize ria_fixture(u32 kind,usize length);
unsafe extern C fn usize ria_path(ptr mut u8 out,usize capacity);
unsafe extern C fn void ria_release();
unsafe extern C fn void ria_remaining(usize count,u8 first);
unsafe extern C fn void ria_clean(usize heap);
unsafe extern C fn void ria_heap_fail();
unsafe extern C fn void ria_native_fail(u32 enabled);
unsafe extern C fn u32 ria_seams();
unsafe extern C fn void ria_begin();
unsafe extern C fn void ria_end();
fn void success(u32 kind,usize length,bool use_path){
    let usize h=unsafe{ria_fixture(kind,length)};var usize fuel=9;
    var u8[1024] path=[0;1024];let usize n=unsafe{ria_path(ref mut path[..] as ptr mut u8,1024)};
    let input::Snapshot s=switch(if(use_path){adopt::path_utf16le(ref path[..n],length,3,ref mut fuel)}else{adopt::handle(h,length,3,ref mut fuel)}){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    assert(fuel==6 && input::observe(ref s).length==length && input::observe(ref s).charged==3);
    unsafe{ria_clean(if(length==0){0}else{1});ria_release();}
    let ref u8[] bytes=input::view(ref s);var usize i=0;var u8 value=0;
    while(i<length){assert(bytes[i]==value);value=if(value==255){0}else{value+1};i+=1;}
    switch(input::range(ref s,length,0)){case .ok(v):{assert(v.len==0);}case .err(_):{assert(false);}};
}
fn i32 code(adopt::Error e){return switch(e){case .Limit:{1}case .Fuel:{2}case .Allocation:{3}case .Native:{4}};}
fn void expect(Result<input::Snapshot,adopt::Failure> r,adopt::Error kind){
    switch(r){case .ok(_):{assert(false);}case .err(e):{assert(code(e.kind)==code(kind));}};
}
fn void failures(u32 kind){
    var usize fuel=9;
    let input::Snapshot existing=switch(input::snapshot(b"keep",4,0,ref mut fuel)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    let usize h=unsafe{ria_fixture(kind,4)};
    expect(adopt::handle(h,4,10,ref mut fuel),.Fuel);
    expect(adopt::handle(h,1048577,0,ref mut fuel),.Limit);
    assert(fuel==9);unsafe{ria_remaining(4,0);ria_release();ria_clean(1);}
    let usize over=unsafe{ria_fixture(kind,4)};
    expect(adopt::handle(over,2,3,ref mut fuel),.Limit);
    assert(fuel==9);unsafe{ria_remaining(if(kind==0){4}else{1},if(kind==0){0}else{3});ria_release();ria_clean(1);}
    expect(adopt::handle(0,4,3,ref mut fuel),.Native);
    var u8[6] invalid=[65,0,0,0,92,0];expect(adopt::path_utf16le(ref invalid[..],4,3,ref mut fuel),.Native);
    if(unsafe{ria_seams()}!=0){
        let usize native=unsafe{ria_fixture(kind,4)};unsafe{ria_native_fail(1);}
        expect(adopt::handle(native,4,3,ref mut fuel),.Allocation);
        unsafe{ria_native_fail(0);ria_remaining(4,0);ria_release();ria_clean(1);}
        let usize fairy=unsafe{ria_fixture(kind,4)};unsafe{ria_heap_fail();}
        expect(adopt::handle(fairy,4,3,ref mut fuel),.Allocation);
        // Reader has consumed all bytes before the Fairy copy fails. No replay.
        unsafe{ria_remaining(0,0);ria_release();ria_clean(1);}
        var u8[1024] path=[0;1024];discard unsafe{ria_fixture(0,4)};
        let usize n=unsafe{ria_path(ref mut path[..] as ptr mut u8,1024)};
        unsafe{ria_heap_fail();}
        expect(adopt::path_utf16le(ref path[..n],4,3,ref mut fuel),.Allocation);
        unsafe{ria_release();ria_clean(1);}
    }
    assert(fuel==9 && input::view(ref existing)[0]==107 && input::view(ref existing)[3]==112);
}
fn i32 main(){
    // Warm pipe/thread/process bookkeeping before the stable-handle baseline.
    success(1,4,false);unsafe{ria_clean(0);ria_begin();}
    success(0,0,false);success(0,4,false);success(0,1048576,false);
    success(0,0,true);success(0,4,true);success(0,1048576,true);
    success(1,0,false);success(1,4,false);success(1,8193,false);success(1,1048576,false);
    var usize i=0;while(i<12){failures(0);failures(1);i+=1;}
    unsafe{ria_clean(0);ria_end();}return 0;
}
