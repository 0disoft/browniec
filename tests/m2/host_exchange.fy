module tests::m2::host_exchange;
import host_exchange as exchange;
import host_catalog as catalog;
import host_wire as wire;
import std::bytes as bytes;
import std::process as process;

fn exchange::Limits limits(){return exchange::Limits{.request_bytes=1048576,.reply_bytes=1048576,
    .requests_total=8388608,.replies_total=8388608,.calls=256,.adapter_per_call=100,.adapter_total=1000};}
fn ref u8[] scalar_catalog(){return b"{\"schema\":\"brownie.catalog/1\",\"imports\":[{\"id\":0,\"module\":\"host::example\",\"symbol\":\"check\",\"parameters\":[\"i32\"],\"result\":\"Result<i32,u32>\",\"effect\":\"write\",\"capability\":\"example.check\",\"adapter_revision\":\"v1\"}]}";}
fn ref u8[] bytes_catalog(){return b"{\"schema\":\"brownie.catalog/1\",\"imports\":[{\"id\":0,\"module\":\"host::example\",\"symbol\":\"check\",\"parameters\":[\"ref u8[]\"],\"result\":\"Result<brownie::bytes::Buffer,u32>\",\"effect\":\"read\",\"capability\":\"example.check\",\"adapter_revision\":\"v1\"}]}";}
fn ref u8[] scalar_request(){return b"\x01\x00\x03\x00\x00\x00\x04\x00\x00\x00\x29\x00\x00\x00";}
fn ref u8[] scalar_reply(){return b"\x03\x00\x00\x00\x04\x00\x00\x00\x2a\x00\x00\x00";}
fn ref u8[] byte_request(){return b"\x01\x00\x07\x00\x00\x00\x03\x00\x00\x00a\x00b";}
fn ref u8[] byte_reply(){return b"\x07\x00\x00\x00\x03\x00\x00\x00a\x00b";}
fn catalog::Catalog admitted(ref u8[] source){return switch(catalog::parse(source)){
    case .ok(v):{v}case .err(_):{assert(false);admitted(scalar_catalog())}
};}
fn exchange::Exchange make(ref u8[] source,exchange::Limits l,usize fuel,usize deadline,bool grant){
    let bool[1] allowed=[grant];
    return switch(exchange::create(admitted(source),ref allowed,l,7,fuel,deadline)){
        case .ok(v):{v}case .err(_):{assert(false);make(scalar_catalog(),limits(),1000,0,true)}
    };
}
fn usize okay(Result<usize,exchange::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void rejected(Result<usize,exchange::Error> r,u8 code){
    switch(r){case .ok(_):{assert(false);}case .err(e):{switch(e){
        case .State:{assert(code==1);}case .Identity:{assert(code==2);}case .Catalog:{assert(code==3);}
        case .Denied:{assert(code==4);}case .Malformed:{assert(code==5);}case .Allocation:{assert(code==6);}
        case .Terminated:{assert(code==7);}
    };}};
}
fn exchange::Output take(ref mut exchange::Exchange e,usize now){return switch(exchange::take_reply(e,now,false)){
    case .ok(v):{v}case .err(_):{assert(false);take(e,now)}
};}
fn void same(exchange::Observation a,exchange::Observation b){
    assert(a.phase==b.phase && a.cause==b.cause && a.run==b.run && a.request==b.request && a.import_id==b.import_id);
    assert(a.calls==b.calls && a.requests==b.requests && a.replies==b.replies && a.adapter==b.adapter && a.fuel==b.fuel);
    assert(a.terminal_at==b.terminal_at && a.external_effects_unknown==b.external_effects_unknown);
}
fn void request_is(ref exchange::Exchange e,ref u8[] expected){
    switch(exchange::request_bytes(e)){case .ok(v):{assert(bytes::equal(v,expected));}case .err(_):{assert(false);}};
}

@test fn void fake_adapter_decodes_actual_request_and_encodes_reply_42(){
    var exchange::Exchange e=make(scalar_catalog(),limits(),100,0,true);
    assert(exchange::observe(ref e).phase==0);
    let usize id=okay(exchange::begin(ref mut e,0,scalar_request(),3,5,1,false));assert(id==1);
    let exchange::Observation waiting=exchange::observe(ref e);
    assert(waiting.phase==1 && waiting.calls==1 && waiting.fuel==97 && waiting.adapter==5 && waiting.requests==14);
    same(waiting,exchange::poll(ref mut e,2,false));request_is(ref e,scalar_request());
    let wire::Request args=switch(exchange::request_fields(ref e)){
        case .ok(v):{v}case .err(_):{assert(false);wire::Request{.fields=[wire::empty_field();32],.count=0}}
    };assert(args.count==1 && args.fields[0].scalar==41);
    var u8[12] response=[0;12];
    let Result<usize,wire::Error> encoded=wire::encode_reply(0,3,
        wire::Field{.tag=3,.scalar=args.fields[0].scalar+1,.start=0,.length=0},b"",ref mut response,12);
    assert(encoded.is_ok && bytes::equal(ref response,scalar_reply()));
    assert(okay(exchange::reply(ref mut e,7,id,0,ref response,2,3,false))==id);
    response[8]=0;assert(exchange::observe(ref e).phase==2);
    assert(!exchange::request_bytes(ref e).is_ok);
    let exchange::Output output=take(ref mut e,4);
    assert(exchange::output_field(ref output).scalar==42 && exchange::output_kind(ref output)==0);
    assert(exchange::output_run(ref output)==7 && exchange::output_request(ref output)==1);
    assert(exchange::output_bytes(ref output).len==0 && exchange::observe(ref e).fuel==95);
    assert(!exchange::take_reply(ref mut e,5,false).is_ok);
    assert(okay(exchange::begin(ref mut e,0,scalar_request(),3,5,6,false))==2);
    assert(exchange::output_field(ref output).scalar==42);
}

@test fn void immutable_catalog_request_snapshot_and_detached_observations(){
    var bytes::Buffer source=switch(bytes::copy(bytes_catalog())){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    var exchange::Exchange e=make(bytes::view(ref source),limits(),100,0,true);
    bytes::view_mut(ref mut source)[0]=0;
    assert(catalog::count(exchange::bound_catalog(ref e))==1);
    let exchange::Binding expected=exchange::binding(ref e);
    var exchange::Binding altered=expected;altered.words[0]=0;
    let exchange::Binding actual=exchange::binding(ref e);assert(actual.words[0]==expected.words[0]);
    var u8[13] input=[1,0,7,0,0,0,3,0,0,0,97,0,98];
    let usize id=okay(exchange::begin(ref mut e,0,ref input,1,0,1,false));input[10]=120;
    request_is(ref e,byte_request());
    var exchange::Observation forged=exchange::observe(ref e);forged.fuel=0;forged.phase=3;
    assert(exchange::observe(ref e).phase==1 && exchange::observe(ref e).fuel==99);
    let wire::Request args=switch(exchange::request_fields(ref e)){
        case .ok(v):{v}case .err(_):{assert(false);wire::Request{.fields=[wire::empty_field();32],.count=0}}
    };assert(args.fields[0].start==10 && args.fields[0].length==3 && id==1);
}

fn exchange::Output owned_output(){
    var exchange::Exchange e=make(bytes_catalog(),limits(),100,0,true);
    let usize id=okay(exchange::begin(ref mut e,0,byte_request(),2,0,1,false));
    var u8[11] input=[7,0,0,0,3,0,0,0,97,0,98];
    let usize replied=okay(exchange::reply(ref mut e,7,id,0,ref input,3,2,false));
    input[8]=120;
    let exchange::Output output=take(ref mut e,3);
    let exchange::Observation terminal=exchange::poll(ref mut e,4,true);
    assert(terminal.phase==3 && terminal.cause==1 && terminal.fuel==95 && replied==1);
    return output;
}
@test fn void output_owns_bytes_after_input_mutation_cancel_and_coordinator_drop(){
    let exchange::Output output=owned_output();
    assert(bytes::equal(exchange::output_bytes(ref output),b"a\x00b"));
    assert(exchange::output_field(ref output).tag==7 && exchange::output_kind(ref output)==0);
}

@test fn void duplicate_wrong_run_late_and_invalid_requests_preserve_pending(){
    var exchange::Exchange e=make(scalar_catalog(),limits(),100,0,true);
    rejected(exchange::begin(ref mut e,0,b"",9,9,1,false),5);
    rejected(exchange::begin(ref mut e,1,scalar_request(),9,9,1,false),3);
    assert(exchange::observe(ref e).request==0 && exchange::observe(ref e).fuel==100);
    let usize id=okay(exchange::begin(ref mut e,0,scalar_request(),3,5,1,false));
    let exchange::Observation before=exchange::observe(ref e);
    rejected(exchange::begin(ref mut e,0,scalar_request(),9,9,2,false),1);
    rejected(exchange::reply(ref mut e,8,id,0,scalar_reply(),20,2,false),2);
    rejected(exchange::reply(ref mut e,7,0,0,scalar_reply(),20,2,false),2);
    same(before,exchange::observe(ref e));request_is(ref e,scalar_request());
    let usize replied=okay(exchange::reply(ref mut e,7,id,0,scalar_reply(),2,3,false));
    let exchange::Observation committed=exchange::observe(ref e);
    rejected(exchange::reply(ref mut e,7,id,0,scalar_reply(),20,4,false),1);
    same(committed,exchange::observe(ref e));
    let exchange::Output output=take(ref mut e,5);
    let usize next=okay(exchange::begin(ref mut e,0,scalar_request(),3,5,6,false));assert(next==2 && replied==1);
    let exchange::Observation second=exchange::observe(ref e);
    rejected(exchange::reply(ref mut e,7,id,0,scalar_reply(),20,7,false),2);
    same(second,exchange::observe(ref e));
}

@test fn void malformed_type_header_kind_and_all_prefixes_retain_request_fuel_counters(){
    var exchange::Exchange e=make(scalar_catalog(),limits(),100,0,true);
    let usize id=okay(exchange::begin(ref mut e,0,scalar_request(),3,5,1,false));
    let exchange::Observation before=exchange::observe(ref e);let ref u8[] valid=scalar_reply();
    var usize i=0;while(i<valid.len){
        rejected(exchange::reply(ref mut e,7,id,0,valid[..i],200,2,false),5);
        same(before,exchange::observe(ref e));i+=1;
    }
    rejected(exchange::reply(ref mut e,7,id,0,b"\x01\x00\x00\x00\x01\x00\x00\x00\x02",200,2,false),5);
    rejected(exchange::reply(ref mut e,7,id,3,b"",200,2,false),5);
    rejected(exchange::reply(ref mut e,7,id,2,b"x",200,2,false),5);
    rejected(exchange::reply(ref mut e,7,id,1,valid,200,2,false),5);
    rejected(exchange::reply(ref mut e,7,id,0,b"\x03\x01\x00\x00\x04\x00\x00\x00\x2a\x00\x00\x00",200,2,false),5);
    rejected(exchange::reply(ref mut e,7,id,0,b"\x03\x00\x00\x00\xff\xff\xff\xff",200,2,false),5);
    same(before,exchange::observe(ref e));request_is(ref e,scalar_request());
    let usize replied=okay(exchange::reply(ref mut e,7,id,0,valid,2,3,false));assert(replied==id);
}

@test fn void typed_error_commits_u32_and_fatal_is_stable_host_failure(){
    var exchange::Exchange e=make(bytes_catalog(),limits(),100,0,true);
    let usize id=okay(exchange::begin(ref mut e,0,byte_request(),3,5,1,false));
    let usize replied=okay(exchange::reply(ref mut e,7,id,1,b"\x05\x00\x00\x00\x04\x00\x00\x00\xff\xff\xff\xff",2,2,false));
    let exchange::Output output=take(ref mut e,3);
    assert(exchange::output_kind(ref output)==1 && exchange::output_field(ref output).scalar==4294967295);
    assert(exchange::output_field(ref output).tag==5 && exchange::observe(ref e).phase==0);
    let usize next=okay(exchange::begin(ref mut e,0,byte_request(),3,5,4,false));
    assert(okay(exchange::reply(ref mut e,7,next,2,b"",2,5,false))==next && replied==1);
    let exchange::Observation terminal=exchange::observe(ref e);
    assert(terminal.phase==3 && terminal.cause==3 && terminal.terminal_at==5 && terminal.fuel==90);
    assert(terminal.calls==2 && terminal.replies==12 && terminal.external_effects_unknown);
    same(terminal,exchange::poll(ref mut e,100,true));
    rejected(exchange::reply(ref mut e,7,next,0,byte_reply(),1,101,false),7);
    same(terminal,exchange::observe(ref e));assert(!exchange::take_reply(ref mut e,102,false).is_ok);
}

@test fn void cancellation_deadline_first_cause_precede_malformed_identity_and_install(){
    var usize mode=0;while(mode<4){
        var exchange::Exchange e=make(scalar_catalog(),limits(),100,10,true);
        if(mode!=0){let usize id=okay(exchange::begin(ref mut e,0,scalar_request(),3,5,1,false));}
        if(mode==3){let usize replied=okay(exchange::reply(ref mut e,7,1,0,scalar_reply(),2,2,false));}
        if(mode==2){rejected(exchange::reply(ref mut e,0,0,3,b"bad",1000,10,false),7);}
        else if(mode==3){assert(!exchange::take_reply(ref mut e,3,true).is_ok);}
        else{rejected(exchange::reply(ref mut e,0,0,3,b"bad",1000,10,true),7);}
        let exchange::Observation terminal=exchange::observe(ref e);
        assert(terminal.phase==3 && terminal.cause==if(mode==2){2}else{1});
        assert(terminal.external_effects_unknown==(mode!=0));
        same(terminal,exchange::poll(ref mut e,1000,true));
        rejected(exchange::begin(ref mut e,0,scalar_request(),0,0,1001,false),7);
        same(terminal,exchange::observe(ref e));mode+=1;
    }
}

@test fn void per_call_cumulative_calls_adapter_and_fuel_limits_are_terminal(){
    var usize mode=0;while(mode<8){
        var exchange::Limits l=limits();
        if(mode==0){l.request_bytes=13;}if(mode==1){l.requests_total=13;}
        if(mode==2){l.calls=0;}if(mode==3){l.adapter_per_call=4;}if(mode==4){l.adapter_total=4;}
        if(mode==6){l.reply_bytes=11;}if(mode==7){l.replies_total=11;}
        var exchange::Exchange e=make(scalar_catalog(),l,if(mode==5){2}else{100},0,true);
        if(mode<6){rejected(exchange::begin(ref mut e,0,scalar_request(),3,5,1,false),7);}
        else{let usize id=okay(exchange::begin(ref mut e,0,scalar_request(),3,5,1,false));
            rejected(exchange::reply(ref mut e,7,id,0,scalar_reply(),2,2,false),7);}
        let exchange::Observation t=exchange::observe(ref e);
        assert(t.phase==3 && t.cause==if(mode==5){5}else{4});
        assert(t.calls==if(mode<6){0}else{1} && t.replies==0);
        assert(t.fuel==if(mode==5){2}else if(mode<6){100}else{97});mode+=1;
    }
    var exchange::Exchange denied=make(scalar_catalog(),limits(),100,0,false);
    rejected(exchange::begin(ref mut denied,0,scalar_request(),3,5,1,false),4);
    assert(exchange::observe(ref denied).phase==0 && exchange::observe(ref denied).calls==0);
    var exchange::Exchange low=make(scalar_catalog(),limits(),4,0,true);
    let usize id=okay(exchange::begin(ref mut low,0,scalar_request(),3,5,1,false));
    rejected(exchange::reply(ref mut low,7,id,0,scalar_reply(),2,2,false),7);
    assert(exchange::observe(ref low).cause==5 && exchange::observe(ref low).fuel==1);
}

fn bytes::Buffer backing(usize length){
    var bytes::Buffer out=switch(bytes::with_capacity(length)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    assert(bytes::resize_zeroed(ref mut out,length).is_ok);return out;
}
@test fn void actual_mebibyte_whole_envelopes_include_headers_and_return_owned_payload(){
    var exchange::Exchange e=make(bytes_catalog(),limits(),100,0,true);
    var bytes::Buffer input=backing(1048577);
    let wire::Field[1] fields=[wire::Field{.tag=7,.scalar=0,.start=0,.length=1048566}];
    let bytes::Buffer blob=backing(1048566);
    assert(wire::encode_request(ref fields,bytes::view(ref blob),bytes::view_mut(ref mut input)[..1048576],1048576).is_ok);
    let usize id=okay(exchange::begin(ref mut e,0,bytes::view(ref input)[..1048576],1,0,1,false));
    assert(exchange::observe(ref e).requests==1048576);
    var bytes::Buffer response=backing(1048576);let bytes::Buffer reply_blob=backing(1048568);
    assert(wire::encode_reply(0,7,wire::Field{.tag=7,.scalar=0,.start=0,.length=1048568},
        bytes::view(ref reply_blob),bytes::view_mut(ref mut response),1048576).is_ok);
    let usize replied=okay(exchange::reply(ref mut e,7,id,0,bytes::view(ref response),1,2,false));
    let exchange::Output output=take(ref mut e,3);
    assert(exchange::output_bytes(ref output).len==1048568 && exchange::observe(ref e).replies==1048576 && replied==id);
    rejected(exchange::begin(ref mut e,0,bytes::view(ref input),1,0,4,false),7);
    assert(exchange::observe(ref e).cause==4 && exchange::output_bytes(ref output)[1048567]==0);
}

@test fn void zero_length_bytes_and_zero_argument_requests_use_actual_codec(){
    var exchange::Exchange e=make(bytes_catalog(),limits(),100,0,true);
    let usize id=okay(exchange::begin(ref mut e,0,b"\x01\x00\x07\x00\x00\x00\x00\x00\x00\x00",0,0,1,false));
    let usize replied=okay(exchange::reply(ref mut e,7,id,0,b"\x07\x00\x00\x00\x00\x00\x00\x00",0,2,false));
    let exchange::Output output=take(ref mut e,3);assert(exchange::output_bytes(ref output).len==0 && replied==1);
    let ref u8[] noargs=b"{\"schema\":\"brownie.catalog/1\",\"imports\":[{\"id\":0,\"module\":\"host::example\",\"symbol\":\"check\",\"parameters\":[],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"example.check\",\"adapter_revision\":\"v1\"}]}";
    var exchange::Exchange n=make(noargs,limits(),100,0,true);
    let usize empty=okay(exchange::begin(ref mut n,0,b"\x00\x00",0,0,1,false));assert(empty==1);
    let wire::Request args=switch(exchange::request_fields(ref n)){
        case .ok(v):{v}case .err(_):{assert(false);wire::Request{.fields=[wire::empty_field();32],.count=0}}
    };assert(args.count==0);
}

fn bool injecting(){
    if(process::arg_count()<2){return false;}
    var u8[16] arg=[0;16];
    let usize n=switch(process::arg(1,ref mut arg)){case .ok(v):{v}case .err(_):{assert(false);0}};
    return bytes::equal(ref arg[..n],b"inject");
}
@test fn void allocator_request_preparation_retains_state_and_explicit_resubmission_uses_id_one(){
    var exchange::Exchange e=make(bytes_catalog(),limits(),100,0,true);
    var u8[320] payload=[0;320];let u8[310] data=[97;310];
    let wire::Field[1] fields=[wire::Field{.tag=7,.scalar=0,.start=0,.length=310}];
    assert(wire::encode_request(ref fields,ref data,ref mut payload,320).is_ok);
    let exchange::Observation before=exchange::observe(ref e);
    if(injecting()){
        rejected(exchange::begin(ref mut e,0,ref payload,3,5,1,false),6);
        same(before,exchange::observe(ref e));assert(!exchange::request_bytes(ref e).is_ok);
    }
    let usize id=okay(exchange::begin(ref mut e,0,ref payload,3,5,2,false));assert(id==1);
    assert(exchange::observe(ref e).calls==1 && exchange::observe(ref e).fuel==97);
    request_is(ref e,ref payload);
}
@test fn void allocator_reply_preparation_retains_backing_fuel_counters_and_never_replays_adapter(){
    var exchange::Exchange e=make(bytes_catalog(),limits(),100,0,true);
    let usize id=okay(exchange::begin(ref mut e,0,byte_request(),3,5,1,false));
    var u8[384] payload=[0;384];let u8[376] data=[98;376];
    assert(wire::encode_reply(0,7,wire::Field{.tag=7,.scalar=0,.start=0,.length=376},ref data,ref mut payload,384).is_ok);
    let exchange::Observation before=exchange::observe(ref e);
    if(injecting()){
        rejected(exchange::reply(ref mut e,7,id,0,ref payload,2,2,false),6);
        same(before,exchange::observe(ref e));request_is(ref e,byte_request());
    }
    let usize replied=okay(exchange::reply(ref mut e,7,id,0,ref payload,2,3,false));
    let exchange::Output output=take(ref mut e,4);
    assert(replied==id && exchange::observe(ref e).calls==1 && exchange::observe(ref e).adapter==5);
    assert(exchange::observe(ref e).fuel==95 && exchange::observe(ref e).replies==384);
    assert(bytes::equal(exchange::output_bytes(ref output),ref data));
}
@test fn void successful_exchange_totals_and_adapter_budgets_do_not_reset_between_calls(){
    var usize mode=0;while(mode<4){
        var exchange::Limits l=limits();
        if(mode==0){l.calls=1;}else if(mode==1){l.requests_total=27;}else if(mode==2){l.adapter_total=9;}else{l.replies_total=23;}
        var exchange::Exchange e=make(scalar_catalog(),l,100,0,true);
        let usize id=okay(exchange::begin(ref mut e,0,scalar_request(),3,5,1,false));
        let usize r=okay(exchange::reply(ref mut e,7,id,0,scalar_reply(),2,2,false));
        let exchange::Output output=take(ref mut e,3);
        if(mode<3){rejected(exchange::begin(ref mut e,0,scalar_request(),3,5,4,false),7);}
        else{let usize next=okay(exchange::begin(ref mut e,0,scalar_request(),3,5,4,false));
            rejected(exchange::reply(ref mut e,7,next,0,scalar_reply(),2,5,false),7);}
        let exchange::Observation t=exchange::observe(ref e);assert(t.cause==4 && t.replies==12 && r==1);
        assert(t.calls==if(mode<3){1}else{2} && t.requests==if(mode<3){14}else{28});
        assert(exchange::output_field(ref output).scalar==42);mode+=1;
    }
}
