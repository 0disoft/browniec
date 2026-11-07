module tests::m2::value_void_bottom_source;
import value_source as source;
import value_ir as values;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;
import ir as ir;
import compiler as public_compiler;

fn values::Program compiled(ref u8[] input){return switch(source::compile(input)){
    case .ok(p):{p}case .err(_):{assert(false);compiled(input)}
};}
fn void executes(ref values::Program p){
    assert(verifier::inspect_values(p).is_ok);
    let growth::Limits limits=growth::Limits{.object=4096,.instance=1048576,.engine=1048576};
    assert(switch(vm::run_values(p,10000000,0,limits)){case .ok(v):{v==42}case .err(_):{false}});
}
fn void value(ref u8[] input){let values::Program p=compiled(input);executes(ref p);}
fn void rejected(ref u8[] input){assert(switch(source::compile(input)){
    case .ok(_):{false}case .err(e):{e.offset<=input.len}
});}
fn usize count(ref values::Program p,u8 op){let ref ir::Program body=ref p.body;
    var usize i=0;var usize n=0;while(i<body.count){if(body.code[i*8]==op){n+=1;}i+=1;}return n;
}
// Keep only the compared IR across compilations, rather than retaining two
// large Programs on the default native stack. Source offsets intentionally vary.
struct Snapshot {
    u8[2048] code; i64[128] constants; u8[128] tags; bool[128] slots;
    usize[64] positions; u8[256] arguments; u8[32] arities;
    u8[128] parameters; u8[16] types; u8[16] functions; u8[16] results;
    usize count; usize registers; usize constant_count; usize call_count;
    usize catalog_count; usize function_count;
    usize drops; usize closes; usize reads; usize captures;
}
fn Snapshot snapshot(ref u8[] input,usize returns){
    let values::Program p=compiled(input);executes(ref p);
    assert(count(ref p,82)==returns && count(ref p,26)==0);
    var Snapshot out=Snapshot{.code=[0;2048],.constants=[0;128],.tags=[0;128],.slots=[false;128],
        .positions=[0;64],.arguments=[0;256],.arities=[0;32],.parameters=[0;128],
        .types=[0;16],.functions=[0;16],.results=[0;16],.count=p.body.count,.registers=p.body.registers,
        .constant_count=p.body.constant_count,.call_count=p.body.call_count,
        .catalog_count=p.catalog.count,.function_count=p.body.function_count,
        .drops=count(ref p,90),.closes=count(ref p,109),.reads=count(ref p,96),.captures=count(ref p,97)};
    var usize i=0;while(i<p.body.count*8){out.code[i]=p.body.code[i];i+=1;}
    i=0;while(i<p.body.constant_count){out.constants[i]=p.body.constants[i];i+=1;}
    i=0;while(i<128){out.tags[i]=p.body.types[i];out.slots[i]=p.body.slots[i];out.parameters[i]=p.parameters[i];i+=1;}
    i=0;while(i<16){out.positions[i]=p.body.starts[i];out.positions[16+i]=p.body.ends[i];
        out.positions[32+i]=p.body.register_starts[i];out.positions[48+i]=p.body.register_ends[i];
        out.types[i]=p.types[i];out.functions[i]=p.functions[i];out.results[i]=p.results[i];i+=1;}
    i=0;while(i<256){out.arguments[i]=p.body.call_args[i];i+=1;}
    i=0;while(i<32){out.arities[i]=p.body.call_arities[i];i+=1;}
    return out;
}
fn void equivalent(ref u8[] outer,ref u8[] plain,usize returns,bool has_cleanup){
    let Snapshot a=snapshot(outer,returns);let Snapshot b=snapshot(plain,returns);
    assert(a.drops==b.drops && a.closes==b.closes && a.reads==b.reads && a.captures==b.captures);
    if(has_cleanup){assert(a.drops>0 && a.closes>0);}
    assert(a.count==b.count && a.registers==b.registers && a.constant_count==b.constant_count);
    assert(a.call_count==b.call_count && a.catalog_count==b.catalog_count && a.function_count==b.function_count);
    var usize i=0;while(i<2048){assert(a.code[i]==b.code[i]);i+=1;}
    i=0;while(i<128){assert(a.constants[i]==b.constants[i] && a.tags[i]==b.tags[i] && a.slots[i]==b.slots[i]);
        assert(a.parameters[i]==b.parameters[i]);i+=1;}
    i=0;while(i<64){assert(a.positions[i]==b.positions[i]);i+=1;}
    i=0;while(i<16){assert(a.types[i]==b.types[i] && a.functions[i]==b.functions[i] && a.results[i]==b.results[i]);i+=1;}
    i=0;while(i<256){assert(a.arguments[i]==b.arguments[i]);i+=1;}
    i=0;while(i<32){assert(a.arities[i]==b.arities[i]);i+=1;}
}

@test fn void bare_returns_and_both_conditional_and_switch_choices_execute(){
    value(b"module main;fn void work(){return;}fn i32 main(){work();return 42;}");
    // Each unselected arm would trap if selection or terminal control changed.
    value(b"module main;fn void work(bool c){return if(c){return;}else{let n=1/0;return;};}fn i32 main(){work(true);return 42;}");
    value(b"module main;fn void work(bool c){return if(c){let n=1/0;return;}else{return;};}fn i32 main(){work(false);return 42;}");
    value(b"module main;fn void work(Option<i32> o){return switch(o){case .some(n):{if(n!=42){let bad=1/0;}return;}case .none:{let bad=1/0;return;}};}fn i32 main(){work(.some(42));return 42;}");
    value(b"module main;fn void work(Option<i32> o){return switch(o){case .some(_):{let bad=1/0;return;}case .none:{return;}};}fn i32 main(){work(.none);return 42;}");
    equivalent(b"module main;fn void work(bool c){return if(c){return;}else{return;};}fn i32 main(){work(true);work(false);return 42;}",
        b"module main;fn void work(bool c){if(c){return;}else{return;}}fn i32 main(){work(true);work(false);return 42;}",2,false);
}

@test fn void nested_grouped_and_cast_bottoms_add_no_outer_return_or_capture(){
    equivalent(b"module main;fn void work(bool c){return ((if(c){return (switch(.some(1)){case .some(_):{return;}case .none:{return;}});}else{return if(false){return;}else{return;};})) as usize as bool as i32;}fn i32 main(){work(true);work(false);return 42;}",
        b"module main;fn void work(bool c){_ = ((if(c){return (switch(.some(1)){case .some(_):{return;}case .none:{return;}});}else{return if(false){return;}else{return;};})) as usize as bool as i32;}fn i32 main(){work(true);work(false);return 42;}",4,false);
    equivalent(b"module main;fn void work(Option<i32> o){return switch(o){case .some(_):{return;}case .none:{return;}};}fn i32 main(){work(.some(42));work(.none);return 42;}",
        b"module main;fn void work(Option<i32> o){switch(o){case .some(_):{return;}case .none:{return;}}}fn i32 main(){work(.some(42));work(.none);return 42;}",2,false);
}

@test fn void borrowed_buffer_and_earlier_call_arguments_clean_up_only_on_real_edges(){
    equivalent(b"module main;fn Buffer make(){var b=bytes::empty();_ = bytes::push(ref mut b,42);return b;}fn void never(Buffer b,i32 n,i32 x){let bad=1/0;}fn void work(bool c){let b=make();let v=bytes::view(ref b);var n=0;return never(make(),if(true){n+=1;n}else{0},if(c){if(n!=1 || v[0]!=42){let bad=1/0;}return;}else{if(n!=1 || v.len!=1){let bad=1/0;}return;});}fn i32 main(){work(true);work(false);return 42;}",
        b"module main;fn Buffer make(){var b=bytes::empty();_ = bytes::push(ref mut b,42);return b;}fn void never(Buffer b,i32 n,i32 x){let bad=1/0;}fn void work(bool c){let b=make();let v=bytes::view(ref b);var n=0;_ = never(make(),if(true){n+=1;n}else{0},if(c){if(n!=1 || v[0]!=42){let bad=1/0;}return;}else{if(n!=1 || v.len!=1){let bad=1/0;}return;});}fn i32 main(){work(true);work(false);return 42;}",3,true);
}

@test fn void terminal_break_and_continue_operands_keep_while_and_for_transfers(){
    value(b"module main;fn void work(){var b=bytes::empty();_ = bytes::push(ref mut b,7);var n=0;while(n<2){let v=bytes::view(ref b);return if(n==0){n+=1;continue;}else{n+=41;break;};}bytes::write(ref mut b,0,42);if(n!=42 || bytes::read(ref b,0)!=42){let bad=1/0;}return;}fn i32 main(){work();return 42;}");
    value(b"module main;fn void work(){var n=0;for(var i=0;i<2;i+=1){let b=bytes::empty();let v=bytes::view(ref b);let Option<i32> o=if(i==0){.some(i)}else{.none};return (switch(o){case .some(_):{n+=21;continue;}case .none:{n+=21;break;}}) as i64;}if(n!=42){let bad=1/0;}return;}fn i32 main(){work();return 42;}");
}

@test fn void nonbottom_operands_and_malformed_or_trailing_source_still_reject(){
    // Keep one real compile -> verifier -> VM control in this negative group.
    value(b"module main;fn void noop(){}fn void work(){noop();return;}fn i32 main(){work();return 42;}");
    rejected(b"module main;fn void work(){return 42;}fn i32 main(){return 42;}");
    rejected(b"module main;fn void work(){return false;}fn i32 main(){return 42;}");
    rejected(b"module main;fn void work(){let u8 n=42;return n;}fn i32 main(){return 42;}");
    rejected(b"module main;fn void work(){return bytes::empty();}fn i32 main(){return 42;}");
    rejected(b"module main;fn void work(){let b=bytes::empty();return b;}fn i32 main(){return 42;}");
    rejected(b"module main;fn void work(){let b=bytes::empty();return bytes::view(ref b);}fn i32 main(){return 42;}");
    rejected(b"module main;fn void work(){let b=bytes::empty();let v=bytes::view(ref b);return v;}fn i32 main(){return 42;}");
    rejected(b"module main;fn void noop(){}fn void work(){return noop();}fn i32 main(){return 42;}");
    rejected(b"module main;fn void noop(){}fn void work(){return (noop());}fn i32 main(){return 42;}");
    rejected(b"module main;fn void work(){return if(true){42}else{0};}fn i32 main(){return 42;}");
    rejected(b"module main;fn void work(){return if(true){return;}else{42};}fn i32 main(){return 42;}");
    rejected(b"module main;fn void work(){return if(true){return;}else{return;}}fn i32 main(){return 42;}");
    rejected(b"module main;fn void work(){return (if(true){return;}else{return;});let n=0;}fn i32 main(){return 42;}");
    rejected(b"module main;fn void work(){return if(true){return;}else{return;} + 1;}fn i32 main(){return 42;}");
    rejected(b"module main;fn void work(){return if(true){return;}else{return;};garbage( ;}fn i32 main(){return 42;}");
    rejected(b"module main;fn void work(){return switch(.some(1)){case .some(_):{return;}case .some(_):{return;}};}fn i32 main(){return 42;}");
    rejected(b"module main;fn void work(){return if(true){return;};}fn i32 main(){return 42;}");
    rejected(b"module main;fn void work(){return (if(true){return;}else{return;}) as Buffer;}fn i32 main(){return 42;}");
    rejected(b"module main;fn void work(){return (if(true){return;}else{return;}) as;}fn i32 main(){return 42;}");
    rejected(b"module main;fn void work(){let Result<i32,u8> pending=.ok(1);return if(true){return;}else{return;};}fn i32 main(){return 42;}");
    assert(!public_compiler::compile(b"module main;fn void work(){return if(true){return;}else{return;};}fn i32 main(){work();return 42;}").is_ok);
}
