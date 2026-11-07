module tests::m2::value_view_copy_execution;
import value_source as source;
import value_ir as values;
import value_flow as owner_flow;
import compiler as legacy_compiler;
import ir as ir;
import value_program as programs;
import value_runtime as runtime;
import value_view_runtime as view_runtime;
import value_view_copy_runtime as copy_runtime;
import value_buffer_runtime as buffers;
import value_buffer_views as views;
import value_frame_layout as layouts;
import value_frame_meter as meter;
import value_frames as frames;
import value_roots as roots;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;
import errors as errors;
import std::bytes as bytes;
import std::vec as vec;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn values::Program compiled(ref u8[] input){return switch(source::compile(input)){
    case .ok(v):{v}case .err(_):{assert(false);compiled(input)}
};}
fn values::Prepared prepared(ref values::Program p){return switch(values::prepare(p)){
    case .ok(v):{v}case .err(_):{assert(false);prepared(p)}
};}
fn ir::Program legacy(){return switch(legacy_compiler::compile(b"module main;fn i32 main(){return 42;}")){
    case .ok(v):{v}case .err(_):{assert(false);legacy()}
};}
fn values::Program fixture(){return compiled(b"module main;fn i32 main(){let b=bytes::empty();let v=bytes::view(ref b);_ = bytes::copy(ref v);return 42;}");}
fn usize find(ref values::Program p,u8 op){
    var usize pc=0;while(pc<p.body.count){if(p.body.code[pc*8]==op){return pc;}pc+=1;}
    assert(false);return 0;
}
fn void runs(ref values::Program p){
    assert(verifier::inspect_values(p).is_ok);
    assert(switch(vm::run_values(p,4000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
fn void rejected(ref values::Program p){assert(!verifier::inspect_values(p).is_ok);}

@test fn void private_append_view_executes_independent_copies_and_preserves_named_source_pin(){
    var ir::Program ordinary=legacy();assert(verifier::inspect(ref ordinary).is_ok);
    // Insert only112 after the valid scalar definition, preserving a completely
    // defined ordinary return so the new private opcode is the denial cause.
    let usize ret=ordinary.count-1;let usize last=ordinary.count;
    let usize return_offset=ordinary.offsets[ret];var usize byte=0;
    while(byte<8){let u8 word=ordinary.code[ret*8+byte];
        ordinary.code[last*8+byte]=word;ordinary.code[ret*8+byte]=0;byte+=1;
    }
    ordinary.code[ret*8]=112;ordinary.offsets[last]=return_offset;
    ordinary.count=last+1;ordinary.ends[0]=last+1;
    assert(!verifier::inspect(ref ordinary).is_ok);
    assert(switch(vm::run(ref ordinary,4000000)){case .ok(_):{false}case .err(e):{e.kind==5}});
    let values::Program empty=fixture();runs(ref empty);
    assert(!verifier::inspect(ref empty.body).is_ok && !vm::run(ref empty.body,4000000).is_ok);
    let values::Program selected=compiled(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);let v=bytes::view(ref b);switch(bytes::copy(ref v[1..2])){case .ok(owner):{var copy=owner;bytes::write(ref mut copy,0,9);if(v[1]==42 && bytes::read(ref copy,0)==9){return 42;}return 0;}case .err(_):{return 0;}}}");
    let usize pc=find(ref selected,112);assert(selected.body.code[pc*8+3]<16);runs(ref selected);
}

@test fn void malformed_append_view_fresh_result_dead_views_and_empty_root_pins_reject_independently(){
    var usize field=1;while(field<8){var values::Program p=fixture();let usize at=find(ref p,112)*8;
        p.body.code[at+field]=if(field<4){16}else{1};rejected(ref p);field+=1;
    }
    // Copy's capture is a view alias. Replacing ALIAS with MOVE retires the
    // named original, and replacing it with CLOSE leaves the copy source dead.
    var values::Program p=fixture();let usize at=find(ref p,112)*8;
    let usize alias=find(ref p,107)*8;let u8 original=p.body.code[alias+2];
    p.body.code[alias]=109;p.body.code[alias+1]=original;p.body.code[alias+2]=0;
    p.body.code[at+3]=original;rejected(ref p);
    p=fixture();let usize moved=find(ref p,107)*8;p.body.code[moved]=108;rejected(ref p);
    // Same-root rejection applies even to the fixture's zero-length window.
    p=fixture();let usize same=find(ref p,112)*8;let usize begin=find(ref p,105)*8;
    let u8 pinned_owner=p.body.code[begin+2];p.body.code[same+2]=pinned_owner;rejected(ref p);
    // A fresh Result cannot be overwritten. CLOSE immediately after APPEND is
    // replaced by a second identical APPEND with every reserved byte zero.
    p=fixture();let usize append=find(ref p,112)*8;let usize next=append+8;
    var usize i=0;while(i<8){let u8 copied=p.body.code[append+i];p.body.code[next+i]=copied;i+=1;}rejected(ref p);
    // Replace EMPTY with a valid separate-lane ALIAS. The owning CFG must fail
    // at APPEND112 itself, independently of scalar/view proof and later cleanup.
    p=fixture();let usize operation=find(ref p,112)*8;let usize previous=operation-8;
    let u8 parent=p.body.code[find(ref p,105)*8+1];
    p.body.code[previous]=107;p.body.code[previous+1]=15;p.body.code[previous+2]=parent;
    i=3;while(i<8){p.body.code[previous+i]=0;i+=1;}
    let values::Prepared proof=prepared(ref p);
    assert(switch(owner_flow::inspect(ref p,ref proof)){
        case .ok(_):{false}case .err(e):{e.kind==5 && e.offset==operation/8}
    });rejected(ref p);
    // Exact Result<usize,u8>, not a differently typed scalar or wrapper.
    p=fixture();let usize result=p.body.code[find(ref p,112)*8+1] as usize;
    let usize source_type=p.body.code[find(ref p,105)*8+2] as usize;
    let u8 wrong_type=p.types[source_type];p.types[result]=wrong_type;rejected(ref p);
    // No BEGIN/ALIAS can hide a dead view behind the no-view CFG fast path.
    var values::Program isolated=compiled(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);return 42;}");
    let usize push=find(ref isolated,102)*8;isolated.body.code[push]=112;isolated.body.code[push+3]=0;
    assert(view_runtime::present(ref isolated.body));rejected(ref isolated);
}

fn usize ok(Result<usize,errors::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize framed(Result<usize,frames::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn void fails(Result<usize,frames::Error> r,u8 kind){
    assert(switch(r){case .ok(_):{false}case .err(e):{runtime::failure(e,71).kind==kind}});
}
fn void content(ref roots::State s,ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,
    usize serial,usize binding,ref u8[] expected){
    var u8[8] actual=[0;8];var usize fuel=1000;
    assert(roots::copy_out(s,data,scratch,serial,binding,0,ref mut actual[..expected.len],ref mut fuel).is_ok);
    assert(bytes::equal(ref actual[..expected.len],expected));
}
fn programs::Program retained(ref values::Program p){return switch(programs::retain(p)){
    case .ok(v):{v}case .err(_):{assert(false);retained(p)}
};}

@test fn void append_view_adapter_prepays_publication_authenticates_quota_and_cleans_at_zero_fuel(){
    let values::Program u=fixture();let programs::Program p=retained(ref u);
    let usize at=find(ref u,112)*8;let usize dst=u.body.code[at+1] as usize;
    let usize owner=u.body.code[at+2] as usize;let usize view=u.body.code[at+3] as usize;
    let usize source_slot=u.body.code[find(ref u,105)*8+2] as usize;
    let runtime::Budget budget=switch(runtime::budget(ref p,0,limits(),4000000)){
        case .ok(v):{v}case .err(_):{assert(false);runtime::Budget{.values=limits(),.initial=0}}
    };
    var vec::Vec<frames::State> states=vec::empty<frames::State>();var vec::Vec<roots::State> stores=vec::empty<roots::State>();
    var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> backing=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> rs=vec::empty<bytes::Buffer>();
    var vec::Vec<views::Pool> pools=vec::empty<views::Pool>();
    var usize fuel=ok(runtime::setup(ref p,ref mut states,ref mut stores,ref mut data,ref mut scratch,
        ref mut backing,ref mut rs,budget.values,4000000));
    assert(view_runtime::setup(ref u.body,ref mut pools,ref states,ref mut stores,ref backing,ref rs,budget.values,ref mut fuel).is_ok);
    let frames::Token token=switch(runtime::token(ref states,0,71)){
        case .ok(v):{v}case .err(_):{assert(false);frames::Token{.frame=0,.generation=0}}
    };
    let ref mut frames::State state=vec::at_mut<frames::State>(ref mut states,0);
    let ref mut roots::State store=vec::at_mut<roots::State>(ref mut stores,0);
    let frames::Address src=frames::Address{.frame=0,.generation=token.generation,.slot=source_slot};
    let frames::Address target=frames::Address{.frame=0,.generation=token.generation,.slot=owner};
    let frames::Address output=frames::Address{.frame=0,.generation=token.generation,.slot=dst};
    let usize source_serial=framed(frames::buffer_value(programs::layout(ref p),state,ref mut data,src,b"abc",store,
        ref mut backing,ref mut rs,budget.values,ref mut fuel));
    let usize target_serial=framed(frames::buffer_value(programs::layout(ref p),state,ref mut data,target,b"x",store,
        ref mut backing,ref mut rs,budget.values,ref mut fuel));
    assert(views::begin(vec::at_mut<views::Pool>(ref mut pools,0),store,ref backing,ref rs,
        source_serial,source_slot,view,1,3,ref mut fuel).is_ok);
    let usize used=store.ledger.used;let usize peak=store.ledger.peak;
    let usize live=state.frames[0].live;let usize next=state.frames[0].next;
    let usize generation=store.rows[1].generation;
    // Independently fixed price: publication2112 + Buffer-key2080 + view256
    // + native append-from2316 for one old byte and the two-byte source window.
    var usize mode=0;while(mode<6){
        fuel=if(mode==0){2111}else if(mode==1){6763}else{100000};
        let growth::Limits selected=if(mode==2){growth::Limits{.object=4096,
            .instance=used+128,.engine=used+128}}else{budget.values};
        let usize destination=if(mode==3){source_slot}else{owner};
        let usize selected_view=if(mode==4){16}else if(mode==5){(view+1)%16}else{view};
        fails(copy_runtime::instruction(dst,destination,selected_view,token,programs::layout(ref p),state,store,
            ref mut data,ref pools,ref mut backing,ref mut rs,selected,ref mut fuel),
            if(mode<2){8}else if(mode==2){13}else if(mode==4){14}else{5});
        if(mode==0){assert(fuel==2111);}
        assert(store.ledger.used==used && store.ledger.peak==peak && store.rows[1].generation==generation);
        assert(state.frames[0].live==live && state.frames[0].next==next);
        content(store,ref backing,ref rs,source_serial,source_slot,b"abc");
        content(store,ref backing,ref rs,target_serial,owner,b"x");mode+=1;
    }
    let frames::Token stale=frames::Token{.frame=0,.generation=token.generation+1};fuel=100000;
    fails(copy_runtime::instruction(dst,owner,view,stale,programs::layout(ref p),state,store,
        ref mut data,ref pools,ref mut backing,ref mut rs,budget.values,ref mut fuel),5);
    fuel=6764;assert(framed(copy_runtime::instruction(dst,owner,view,token,programs::layout(ref p),state,store,
        ref mut data,ref pools,ref mut backing,ref mut rs,budget.values,ref mut fuel))==16 && fuel==0);
    content(store,ref backing,ref rs,target_serial,owner,b"xbc");content(store,ref backing,ref rs,source_serial,source_slot,b"abc");
    assert(views::snapshot(vec::at<views::Pool>(ref pools,0)).live==1);
    let usize offset=switch(layouts::offset(programs::layout(ref p),dst)){case .ok(v):{v}case .err(_):{assert(false);0}};
    var u8[16] expected=[0;16];expected[8]=3;
    assert(bytes::equal(bytes::view(vec::at<bytes::Buffer>(ref data,0))[offset..offset+16],ref expected));
    fuel=100000;fails(copy_runtime::instruction(dst,owner,view,token,programs::layout(ref p),state,store,
        ref mut data,ref pools,ref mut backing,ref mut rs,budget.values,ref mut fuel),5);
    assert(store.rows[1].generation==generation+1);content(store,ref backing,ref rs,target_serial,owner,b"xbc");
    // Exercise canonical err1 through the same prepaid publisher without an OOM
    // injection hook or an actual allocator failure claim.
    fuel=100000;assert(frames::drop(programs::layout(ref p),state,ref mut data,output,store,
        ref mut backing,ref mut rs,ref mut fuel).is_ok);
    let usize width=framed(buffers::destination(programs::layout(ref p),state,ref data,output));
    let usize publication=framed(buffers::publication_cost());
    assert(meter::pay(publication,ref mut fuel).is_ok);
    assert(buffers::publish(programs::layout(ref p),state,ref mut data,output,.err(.Allocation),publication,width).is_ok);
    expected=[0;16];expected[0]=1;expected[8]=1;
    assert(bytes::equal(bytes::view(vec::at<bytes::Buffer>(ref data,0))[offset..offset+16],ref expected));
    fuel=0;
    assert(switch(runtime::finish_views(ref mut states,ref mut stores,ref mut data,ref mut scratch,
        ref mut backing,ref mut rs,ref mut pools,.err(errors::make(8,71)))){
        case .ok(_):{false}case .err(e):{e.kind==8 && e.offset==71}
    });
    let views::Snapshot closed=views::snapshot(vec::at<views::Pool>(ref pools,0));
    assert(fuel==0 && closed.closed && closed.live==0 && closed.roots==0);
    assert(vec::at<roots::State>(ref stores,0).closed && vec::at<roots::State>(ref stores,0).external==0);
    assert(vec::at<roots::State>(ref stores,0).ledger.used==0 && vec::at<roots::State>(ref stores,0).ledger.engine_used==0);
    assert(vec::at<frames::State>(ref states,0).closed && vec::at<frames::State>(ref states,0).depth==0);
    assert(vec::len<bytes::Buffer>(ref data)==0 && vec::len<bytes::Buffer>(ref scratch)==0 &&
        vec::len<bytes::Buffer>(ref backing)==0 && vec::len<bytes::Buffer>(ref rs)==0);
}
