module tests::m2::runtime_io;
import runtime_input as input;
import runtime_output as output;
import std::bytes as bytes;
import std::process as process;

fn input::Snapshot snapshot(ref u8[] data,usize limit,usize charge,ref mut usize fuel){
    return switch(input::snapshot(data,limit,charge,fuel)){
        case .ok(v):{v}case .err(_):{assert(false);snapshot(b"",0,0,fuel)}
    };
}
fn output::Transaction open(usize limit,bool allowed,usize fuel){
    return switch(output::open(limit,allowed,fuel)){
        case .ok(v):{v}case .err(_):{assert(false);open(0,false,0)}
    };
}
fn output::Published seal(ref mut output::Transaction t,usize charge){
    return switch(output::seal(t,charge)){
        case .ok(v):{v}case .err(_):{assert(false);seal(t,0)}
    };
}
fn usize emitted(Result<usize,output::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void same(output::Observation a,output::Observation b){
    assert(a.phase==b.phase && a.length==b.length && a.emits==b.emits && a.fuel==b.fuel && a.charged==b.charged);
}
fn void rejected(Result<usize,output::Error> r,u8 kind){
    switch(r){case .ok(_):{assert(false);}case .err(e):{switch(e){
        case .State:{assert(kind==1);}case .Denied:{assert(kind==2);}case .Limit:{assert(kind==3);}
        case .Fuel:{assert(kind==4);}case .Allocation:{assert(kind==5);}
    };}};
}
fn bytes::Buffer backing(usize length){
    var bytes::Buffer b=switch(bytes::with_capacity(length)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    assert(bytes::resize_zeroed(ref mut b,length).is_ok);return b;
}
fn bool injecting(){
    if(process::arg_count()<2){return false;}var u8[16] data=[0;16];
    let usize length=switch(process::arg(1,ref mut data)){case .ok(v):{v}case .err(_):{assert(false);0}};
    return bytes::equal(ref data[..length],b"inject");
}

@test fn void immutable_input_snapshots_preserve_nul_binary_and_caller_lifetime(){
    var usize fuel=10;var u8[4] source=[0,97,255,0];
    let input::Snapshot owned=snapshot(ref source,4,3,ref mut fuel);source[0]=1;source[2]=0;
    assert(bytes::equal(input::view(ref owned),b"\x00a\xff\x00") && fuel==7);
    let input::Observation seen=input::observe(ref owned);assert(seen.length==4 && seen.charged==3);
    switch(input::range(ref owned,1,2)){case .ok(v):{assert(bytes::equal(v,b"a\xff"));}case .err(_):{assert(false);}};
    assert(input::range(ref owned,4,0).is_ok);
    assert(!input::range(ref owned,5,0).is_ok && !input::range(ref owned,1,18446744073709551615).is_ok);
    let input::Snapshot empty=snapshot(b"",0,0,ref mut fuel);assert(input::view(ref empty).len==0 && fuel==7);
}

@test fn void input_preflight_rejects_limit_and_fuel_without_consuming_or_mutating(){
    var usize fuel=2;
    assert(!input::snapshot(b"\x00a",1,1,ref mut fuel).is_ok && fuel==2);
    assert(!input::snapshot(b"\x00a",2,3,ref mut fuel).is_ok && fuel==2);
    assert(!input::snapshot(b"",1048577,0,ref mut fuel).is_ok && fuel==2);
    assert(!input::snapshot(b"",18446744073709551615,0,ref mut fuel).is_ok && fuel==2);
    let input::Snapshot owned=snapshot(b"\x00a",2,2,ref mut fuel);assert(fuel==0 && input::view(ref owned)[0]==0);
}

fn output::Published transform_snapshot(){
    var usize fuel=30;var u8[3] source=[0,97,255];
    let input::Snapshot owned=snapshot(ref source,3,2,ref mut fuel);
    var output::Transaction t=open(32,true,fuel);
    assert(emitted(output::emit(ref mut t,b"\x00",2))==1);
    assert(emitted(output::emit(ref mut t,input::view(ref owned),3))==4);
    source[1]=0;
    let output::Published published=seal(ref mut t,1);
    let output::Observation terminal=output::observe(ref t);
    assert(terminal.phase==1 && terminal.length==4 && terminal.emits==2 && terminal.fuel==22 && terminal.charged==6);
    same(terminal,output::cancel(ref mut t));same(terminal,output::fail(ref mut t));
    rejected(output::emit(ref mut t,b"bad",0),1);assert(!output::seal(ref mut t,0).is_ok);
    assert(bytes::equal(output::view(ref published),b"\x00\x00a\xff"));return published;
}
@test fn void ordered_binary_emit_and_explicit_seal_own_output_after_all_other_owners_drop(){
    let output::Published published=transform_snapshot();
    assert(bytes::equal(output::view(ref published),b"\x00\x00a\xff"));
    assert(output::published_observation(ref published).fuel==22);
}

@test fn void rejected_append_and_seal_preflight_preserve_exact_staged_transaction(){
    var output::Transaction t=open(5,true,10);
    assert(emitted(output::emit(ref mut t,b"a\x00b",2))==3);
    let output::Observation before=output::observe(ref t);
    rejected(output::emit(ref mut t,b"xyz",1),3);same(before,output::observe(ref t));
    rejected(output::emit(ref mut t,b"z",9),4);same(before,output::observe(ref t));
    assert(!output::seal(ref mut t,9).is_ok);same(before,output::observe(ref t));
    assert(emitted(output::emit(ref mut t,b"\xff\x00",1))==5);
    rejected(output::emit(ref mut t,b"x",0),3);
    let output::Published published=seal(ref mut t,1);
    assert(bytes::equal(output::view(ref published),b"a\x00b\xff\x00"));
    assert(output::published_observation(ref published).fuel==6);
}

@test fn void cancellation_and_failure_discard_staging_and_freeze_first_terminal_state(){
    var usize mode=0;while(mode<2){
        var output::Transaction t=open(100,true,10);
        assert(emitted(output::emit(ref mut t,b"secret\x00unpublished",3))==18);
        let output::Observation terminal=if(mode==0){output::cancel(ref mut t)}else{output::fail(ref mut t)};
        assert(terminal.phase==if(mode==0){3}else{2});
        assert(terminal.length==0 && terminal.emits==1 && terminal.fuel==7 && terminal.charged==3);
        assert(!output::seal(ref mut t,0).is_ok);rejected(output::emit(ref mut t,b"again",0),1);
        same(terminal,output::fail(ref mut t));same(terminal,output::cancel(ref mut t));mode+=1;
    }
}

@test fn void deny_by_default_empty_output_and_full_usize_fuel_do_not_wrap(){
    assert(!output::open(1048577,true,0).is_ok && !output::open(18446744073709551615,true,0).is_ok);
    var output::Transaction denied=open(0,false,10);let output::Observation before=output::observe(ref denied);
    rejected(output::emit(ref mut denied,b"",0),2);same(before,output::observe(ref denied));
    let output::Published empty=seal(ref mut denied,0);assert(output::view(ref empty).len==0);
    var output::Transaction t=open(0,true,18446744073709551615);
    assert(emitted(output::emit(ref mut t,b"",18446744073709551614))==0);
    let output::Published p=seal(ref mut t,1);let output::Observation seen=output::published_observation(ref p);
    assert(seen.fuel==0 && seen.charged==18446744073709551615 && seen.emits==1);
    assert(output::view(ref p).len==0 && seen.phase==1);
}

@test fn void observations_are_detached_and_do_not_forge_publication_authority(){
    var output::Transaction t=open(32,true,10);assert(emitted(output::emit(ref mut t,b"\x00a",2))==2);
    var output::Observation forged=output::observe(ref t);forged.phase=1;forged.length=0;forged.fuel=0;
    let output::Observation actual=output::observe(ref t);assert(actual.phase==0 && actual.length==2 && actual.fuel==8);
    let output::Published p=seal(ref mut t,0);assert(bytes::equal(output::view(ref p),b"\x00a"));
}

@test fn void real_mebibyte_input_and_output_boundaries_are_binary_exact(){
    var bytes::Buffer source=backing(1048577);bytes::view_mut(ref mut source)[0]=255;bytes::view_mut(ref mut source)[1048575]=97;
    var usize fuel=10;
    assert(!input::snapshot(bytes::view(ref source),1048576,0,ref mut fuel).is_ok && fuel==10);
    let input::Snapshot owned=snapshot(bytes::view(ref source)[..1048576],1048576,2,ref mut fuel);
    var output::Transaction t=open(1048576,true,fuel);
    assert(emitted(output::emit(ref mut t,input::view(ref owned),2))==1048576);
    let output::Observation before=output::observe(ref t);rejected(output::emit(ref mut t,b"\x00",0),3);same(before,output::observe(ref t));
    let output::Published p=seal(ref mut t,1);
    assert(output::view(ref p).len==1048576 && bytes::equal(output::view(ref p),input::view(ref owned)));
    assert(output::view(ref p)[0]==255 && output::view(ref p)[1]==0 && output::view(ref p)[1048575]==97);
}

@test fn void allocator_input_snapshot_failure_preserves_existing_owner_bytes_and_fuel(){
    var usize fuel=100;let input::Snapshot existing=snapshot(b"keep\x00",5,1,ref mut fuel);
    let u8[320] source=[97;320];
    if(injecting()){
        switch(input::snapshot(ref source,320,3,ref mut fuel)){
            case .ok(_):{assert(false);}case .err(e):{switch(e){case .Allocation:{}case .Limit:{assert(false);}case .Fuel:{assert(false);}case .Bounds:{assert(false);}};}
        };assert(fuel==99 && bytes::equal(input::view(ref existing),b"keep\x00"));
    }
    let input::Snapshot added=snapshot(ref source,320,3,ref mut fuel);
    assert(fuel==96 && input::view(ref added).len==320 && bytes::equal(input::view(ref added),ref source));
    assert(bytes::equal(input::view(ref existing),b"keep\x00"));
}

@test fn void allocator_append_failure_preserves_prefix_observations_and_explicit_resubmission(){
    var output::Transaction t=open(384,true,100);let u8[320] prefix=[97;320];let u8[64] suffix=[0;64];
    assert(emitted(output::emit(ref mut t,ref prefix,3))==320);let output::Observation before=output::observe(ref t);
    if(injecting()){
        rejected(output::emit(ref mut t,ref suffix,2),5);same(before,output::observe(ref t));
    }
    assert(emitted(output::emit(ref mut t,ref suffix,2))==384);let output::Published p=seal(ref mut t,1);
    let ref u8[] data=output::view(ref p);assert(data.len==384 && bytes::equal(data[..320],ref prefix) && bytes::equal(data[320..],ref suffix));
    let output::Observation seen=output::published_observation(ref p);assert(seen.fuel==94 && seen.charged==6 && seen.emits==2);
}
