module main;
import std::bytes as bytes;
import std::io as io;
import std::process as process;
import buffer_growth as growth;
import buffer_storage as storage;
import buffer_owners as owners;
import buffer_replacement as tx;
import buffer_utf8_pool as pools;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=8192,.engine=8192};}
fn Result<bytes::Buffer,tx::Error> prepare(u8 mode,ref owners::Table table,owners::Token token,
    ref bytes::Buffer b,ref mut growth::Ledger ledger,ref mut tx::Plan plan){
    if(mode==2){let u8[253] suffix=[120;253];return tx::prepare_append(table,token,b,ref suffix[..],limits(),ledger,plan);}
    if(mode==3){return tx::prepare_resize(table,token,b,257,limits(),ledger,plan);}
    return tx::prepare(table,token,b,257,limits(),ledger,plan);
}
fn void unchanged(ref owners::Table table,ref owners::Table before,owners::Token token,ref bytes::Buffer b){
    assert(bytes::len(b)==4 && bytes::capacity(b)==256 && bytes::equal(bytes::view(b),b"keep"));
    assert(switch(owners::read(table,token,0,b)){case .ok(v):{v==107}case .err(_):{false}});
    var usize i=0;while(i<16){assert(table.slots[i].generation==before.slots[i].generation &&
        table.slots[i].live==before.slots[i].live && table.slots[i].reading==before.slots[i].reading &&
        table.slots[i].length==before.slots[i].length && table.slots[i].capacity==before.slots[i].capacity);i+=1;}
}
fn void run(u8 mode,bool injected){
    var growth::Ledger ledger=growth::empty();var bytes::Buffer b=bytes::empty();
    b=switch(storage::prepare_growth(ref b,256,limits(),ref mut ledger)){case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    switch(growth::commit(256,ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    switch(bytes::append(ref mut b,b"keep")){case .ok(_):{}case .err(_):{assert(false);}};
    ledger.engine_used+=32;ledger.engine_peak+=32;
    var owners::Table table=owners::empty();
    let owners::Token token=switch(owners::create(ref mut table,ref b)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    var pools::Pool pool=pools::empty();
    switch(pools::admit(ref mut pool,limits(),ref mut ledger)){case .ok(_):{}case .err(_):{assert(false);}};
    var usize fuel=256;let pools::Ticket ticket=switch(pools::begin(false,ref mut pool,ref mut table,token,ref b,ref ledger,ref mut fuel)){
        case .ok(v):{v}case .err(_):{assert(false);pools::Ticket{.slot=16,.generation=0}}};
    var tx::Plan plan=tx::empty();
    assert(switch(prepare(mode,ref table,token,ref b,ref mut ledger,ref mut plan)){
        case .ok(_):{false}case .err(e):{switch(e){case .State:{true}case .Provider:{false}case .Token:{false}case .Owners:{false}
            case .Overflow:{false}case .Quota:{false}case .NoGrowth:{false}case .Allocation:{false}}}});
    assert(pool.s0.live && pool.s0.session.held && table.slots[token.slot].reading && fuel==0);
    assert(ledger.used==2432 && ledger.engine_used==2464 && ledger.peak==2432 && ledger.engine_peak==2464 && ledger.pending==0 && !plan.active);
    switch(pools::abandon(ref mut pool,ticket,ref mut table)){case .ok(_):{}case .err(_):{assert(false);}};
    let owners::Table before=owners::Table{.slots=table.slots};
    if(injected){
        assert(switch(prepare(mode,ref table,token,ref b,ref mut ledger,ref mut plan)){
            case .ok(_):{false}case .err(e):{switch(e){case .Provider:{true}case .State:{false}case .Token:{false}case .Owners:{false}
                case .Overflow:{false}case .Quota:{false}case .NoGrowth:{false}case .Allocation:{false}}}});
        unchanged(ref table,ref before,token,ref b);
        assert(!plan.active && ledger.used==2432 && ledger.engine_used==2464 && ledger.peak==2880 && ledger.engine_peak==2912 &&
            ledger.pending==0 && ledger.old_capacity==0 && ledger.new_capacity==0 && ledger.before_used==0 && ledger.before_engine_used==0);
        assert(pool.admitted && pool.phase==0 && !pool.s0.live && pool.s0.generation==2 && fuel==0);
    }
    // Explicit caller retry; provider faults must never cause hidden replay.
    let bytes::Buffer ready=switch(prepare(mode,ref table,token,ref b,ref mut ledger,ref mut plan)){
        case .ok(v):{v}case .err(_):{assert(false);bytes::empty()}};
    unchanged(ref table,ref before,token,ref b);assert(bytes::capacity(ref ready)==384 && plan.active);
    assert(bytes::len(ref ready)==if(mode>=2){257}else{4});
    let ref u8[] view=bytes::view(ref ready);assert(bytes::equal(view[..4],b"keep"));
    if(mode>=2){var usize i=4;while(i<257){assert(view[i]==if(mode==2){120}else{0});i+=1;}}
    b=ready;let owners::Token fresh=switch(tx::commit(ref mut table,ref b,ref mut ledger,ref mut plan)){
        case .ok(v):{v}case .err(_):{assert(false);token}};
    assert(fresh.slot==token.slot && fresh.generation==token.generation+1 && !plan.active && ledger.pending==0);
    assert(ledger.used==2560 && ledger.engine_used==2592 && ledger.peak==2880 && ledger.engine_peak==2912);
    switch(pools::shutdown(ref mut pool,ref mut table,ref mut ledger)){case .ok(n):{assert(n==0);}case .err(_):{assert(false);}};
    assert(!pool.admitted && pool.phase==2 && ledger.used==448 && ledger.engine_used==480 && fuel==0);
}
@effects(console)
fn i32 main(){
    if(process::arg_count()!=2 && process::arg_count()!=3){return 2;}
    var u8[24] arg=[0;24];let usize n=switch(process::arg(1,ref mut arg[..])){case .ok(v):{v}case .err(_):{return 2;}};
    let ref u8[] mode=ref arg[..n];var u8 selected=0;
    if(bytes::equal(mode,b"capacity")){selected=0;}else if(bytes::equal(mode,b"copy")){selected=1;}
    else if(bytes::equal(mode,b"append")){selected=2;}else if(bytes::equal(mode,b"resize")){selected=3;}else{return 2;}
    let bool injected=process::arg_count()==2;
    if(!injected){var u8[8] flag=[0;8];let usize count=switch(process::arg(2,ref mut flag[..])){case .ok(v):{v}case .err(_):{return 2;}};
        if(!bytes::equal(ref flag[..count],b"control")){return 2;}}
    run(selected,injected);
    return switch(io::write("buffer-provider: passed\n")){case .ok(_):{0}case .err(_):{1}};
}
