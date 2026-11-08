module tests::m2::call_copy_plan_work;
import array_owners as owners;
import array_layout as arrays;
import struct_layout as records;
import std::vec as vec;
import call_copy_plan_work as work;
import call_copy_cursor as cursor;
import call_copy_work as raw_copy;
import call_copy_prepared_work as prepared;
import struct_layout_work as layout_work;
import struct_nested_storage as storage;
import metadata_budget as budget;

// Invocation-private staged planner compared with the independent raw APIs.
// Payload errors belong to copy validation, never the metadata-only planner.
pub struct Fixture {
    owners::Table table; records::Catalog catalog; owners::CallArgument[8] arguments;
    u8[512] data; usize count; bool reserve_first;
    usize checked; usize copies; u8 plan_failure; u8 copy_failure;
}
pub fn u8 error_code(owners::Error e){return switch(e){
    case .Token:{1}case .Owners:{2}case .State:{3}case .Type:{4}case .Length:{5}case .Metadata:{6}
    case .Overflow:{7}case .Quota:{8}case .Bounds:{9}case .Alignment:{10}case .Value:{11}
};}
pub fn u8 failure_code(Option<owners::Error> failure){return switch(failure){case .none:{0}case .some(e):{error_code(e)}};}
fn owners::CallArgument arg(owners::Token source,u8 element,usize length,usize record){
    return owners::CallArgument{.source=source,.element=element,.length=length,.record=record};
}
fn owners::Token missing(){return owners::Token{.slot=16,.generation=0};}
fn records::Catalog small_catalog(){var records::Catalog c=records::empty();c.count=1;c.fields[0]=2;c.types[0]=2;c.types[1]=1;return c;}
// Reuse tests/m2/struct_layout_order.fy's two depth-16 chains: every one of the
// 32 records and 512 fields is populated. Select a 16-byte leaf (ID15/ID16),
// because the unused 241-byte roots are legal catalog layouts, not legal owned
// result sizes. Never reject this scan fixture by selecting an oversized owner.
pub fn records::Catalog dense_catalog(bool reversed){
    var records::Catalog c=records::empty();c.count=32;var usize record=0;
    while(record<32){let usize id=if(reversed){31-record}else{record};c.fields[id]=16;
        var usize field=0;while(field<16){c.types[id*16+field]=2;field+=1;}
        if(record%16!=15){c.kinds[id*16+15]=1;let usize target=if(reversed){30-record}else{record+1};
            var u8 child=0;while((child as usize)<target){child+=1;}c.types[id*16+15]=child;
        }record+=1;
    }return c;
}
fn Result<owners::Token,owners::Error> create_array(ref mut owners::Table table,ref mut u8[] data,u8 tag,usize length){
    let arrays::Array layout=switch(arrays::scalar(tag,length)){case .ok(v):{v}case .err(_):{return .err(.Metadata);}};
    return owners::create(ref layout,1,data,table);
}
// Cases and expected failure codes are documented in helpers/test-design.md.
// Construction uses separate locals to avoid sibling mutable loans. Fixtures
// are installed in SDK banks before any future staged Work is constructed.
fn Result<Fixture,owners::Error> make_fixture(usize id){
    if(id>18){return .err(.Bounds);}
    var records::Catalog catalog=small_catalog();var owners::Table table=owners::empty(if(id==3 || id==4){5}else if(id==13){23}else{512});
    var u8[512] data=[85;512];var owners::CallArgument[8] arguments=[arg(missing(),0,0,0);8];
    var usize count=2;var usize checked=1;var usize copies=1;var u8 plan_failure=0;var u8 copy_failure=0;
    let bool reserve_first=id==4 || id==6;
    if(id==16 || id==17){
        catalog=records::empty();catalog.count=if(id==16){3}else{2};
        if(id==16){
            catalog.fields[0]=3;catalog.kinds[0]=1;catalog.types[0]=2;catalog.kinds[1]=1;catalog.types[1]=1;catalog.types[2]=2;
            catalog.fields[1]=3;catalog.types[16]=10;catalog.types[17]=2;catalog.types[18]=1;
            catalog.fields[2]=2;catalog.types[32]=9;catalog.types[33]=2;
            let i64[6] fields=[42,1,7,1,42,1];
            let owners::Token source=owners::create_record(ref catalog,0,ref fields,ref mut data,ref mut table)?;
            arguments[0]=arg(source,0,0,0);arguments[1]=arguments[0];data[table.slots[source.slot].base+9]=85;
        }else{
            catalog.fields[0]=15;var usize i=0;while(i<14){catalog.types[i]=9;i+=1;}
            catalog.kinds[14]=1;catalog.types[14]=1;catalog.fields[1]=16;
            i=0;while(i<16){catalog.types[16+i]=2;i+=1;}
            let i64[30] fields=[1;30];
            let owners::Token source=owners::create_record(ref catalog,0,ref fields,ref mut data,ref mut table)?;
            arguments[0]=arg(source,0,0,0);arguments[1]=arguments[0];
        }
        return .ok(Fixture{.table=table,.catalog=catalog,.arguments=arguments,.data=data,.count=2,.reserve_first=false,
            .checked=2,.copies=2,.plan_failure=0,.copy_failure=0});
    }
    if(id==18){catalog=records::empty();catalog.types[511]=2;
        let owners::Token source=create_array(ref mut table,ref mut data,2,256)?;arguments[0]=arg(source,2,256,0);
        return .ok(Fixture{.table=table,.catalog=catalog,.arguments=arguments,.data=data,.count=1,.reserve_first=true,
            .checked=1,.copies=1,.plan_failure=0,.copy_failure=0});
    }
    if(id==15){catalog=records::empty();catalog.types[511]=2;
        return .ok(Fixture{.table=table,.catalog=catalog,.arguments=arguments,.data=data,.count=0,.reserve_first=false,
            .checked=0,.copies=0,.plan_failure=0,.copy_failure=0});
    }
    if(id==11 || id==12){catalog=dense_catalog(id==12);let usize leaf=if(id==12){16}else{15};let i64[16] fields=[1;16];
        let owners::Token source=owners::create_record(ref catalog,leaf,ref fields,ref mut data,ref mut table)?;
        var usize i=0;while(i<8){arguments[i]=arg(source,0,0,leaf);i+=1;}count=8;checked=8;copies=8;
    }else if(id==3 || id==4 || id==5 || id==6 || id==14){catalog=records::empty();
        let owners::Token source=create_array(ref mut table,ref mut data,2,3)?;
        if(id==5 || id==6 || id==14){let usize fillers=if(id==14){14}else{15};var usize i=0;
            while(i<fillers){let owners::Token filler=create_array(ref mut table,ref mut data,10,1)?;i+=1;}}
        arguments[0]=arg(source,2,3,0);arguments[1]=arguments[0];
        if(id==14){plan_failure=2;copy_failure=2;checked=2;copies=1;}
        else{count=1;checked=1;copies=0;data[table.slots[source.slot].base]=3;
            plan_failure=if(id==3 || id==4){8}else{2};copy_failure=if(reserve_first){plan_failure}else{11};}
    }else{
        let i64[2] fields=[1,42];let owners::Token record=owners::create_record(ref catalog,0,ref fields,ref mut data,ref mut table)?;
        let owners::Token boolean=create_array(ref mut table,ref mut data,2,3)?;
        // Noncanonical padding must not be read/normalized by metadata planning.
        data[table.slots[record.slot].base+1]=85;
        arguments[0]=arg(boolean,2,3,0);arguments[1]=arg(record,0,0,0);
        if(id==0){var usize i=0;while(i<8){arguments[i]=if(i%2==0){arg(record,0,0,0)}else{arg(boolean,2,3,0)};i+=1;}
            count=8;checked=8;copies=8;
        }else if(id==1){arguments[1].source.generation+=1;data[table.slots[boolean.slot].base]=3;plan_failure=1;copy_failure=11;}
        else if(id==2){arguments[0]=arg(record,0,0,0);arguments[1]=arg(boolean,2,3,0);arguments[1].source.generation+=1;
            data[table.slots[record.slot].base]=3;plan_failure=1;copy_failure=11;
        }else if(id==7){arguments[1].length=1;plan_failure=6;copy_failure=6;}
        else if(id==8 || id==9){catalog.types[511]=2;plan_failure=6;copy_failure=if(id==9){11}else{6};
            if(id==9){data[table.slots[boolean.slot].base]=3;}
        }else if(id==10){catalog.types[511]=2;count=1;checked=1;copies=1;}
        else if(id==13){checked=2;copies=1;plan_failure=8;copy_failure=8;}
    }
    return .ok(Fixture{.table=table,.catalog=catalog,.arguments=arguments,.data=data,.count=count,.reserve_first=reserve_first,
        .checked=checked,.copies=copies,.plan_failure=plan_failure,.copy_failure=copy_failure});
}
pub fn Result<vec::Vec<Fixture>,owners::Error> fixture_bank(usize id){
    let Fixture fixture=make_fixture(id)?;var vec::Vec<Fixture> bank=vec::empty<Fixture>();
    if(!vec::reserve<Fixture>(ref mut bank,1).is_ok || !vec::push<Fixture>(ref mut bank,fixture).is_ok){return .err(.Quota);}return .ok(bank);
}
pub fn void same_table(ref owners::Table a,ref owners::Table b){
    assert(a.depth==b.depth && a.arena.used==b.arena.used && a.arena.limit==b.arena.limit);var usize i=0;
    while(i<16){let owners::Owner x=a.slots[i];let owners::Owner y=b.slots[i];
        assert(a.order[i]==b.order[i] && x.generation==y.generation && x.occupied==y.occupied && x.live==y.live && x.reading==y.reading && x.writing==y.writing && x.read_generation==y.read_generation && x.mark==y.mark && x.base==y.base && x.end==y.end && x.element==y.element && x.length==y.length && x.record==y.record && x.alignment==y.alignment);i+=1;
    }
}
pub fn void same_original(ref Fixture a,ref Fixture b){
    same_table(ref a.table,ref b.table);assert(a.count==b.count && a.reserve_first==b.reserve_first && a.catalog.count==b.catalog.count);
    var usize i=0;while(i<32){assert(a.catalog.fields[i]==b.catalog.fields[i]);i+=1;}
    i=0;while(i<512){assert(a.catalog.kinds[i]==b.catalog.kinds[i] && a.catalog.types[i]==b.catalog.types[i] && a.data[i]==b.data[i]);i+=1;}
    i=0;while(i<8){let owners::CallArgument x=a.arguments[i];let owners::CallArgument y=b.arguments[i];
        assert(x.source.slot==y.source.slot && x.source.generation==y.source.generation && x.element==y.element && x.length==y.length && x.record==y.record);i+=1;}
}
pub fn void same_plan(ref owners::CallCopyPlan a,ref owners::CallCopyPlan b){
    assert(a.mark==b.mark && a.depth==b.depth && a.checked==b.checked && a.copies.count==b.copies.count && failure_code(a.failure)==failure_code(b.failure));
    same_table(ref a.planned,ref b.planned);var usize i=0;while(i<8){
        assert(a.copies.tokens[i].slot==b.copies.tokens[i].slot && a.copies.tokens[i].generation==b.copies.tokens[i].generation);
        let owners::CallCopyRange x=a.ranges[i];let owners::CallCopyRange y=b.ranges[i];
        assert(x.source==y.source && x.target==y.target && x.mark==y.mark && x.end==y.end && x.size==y.size);i+=1;
    }
}
pub fn Result<owners::CallCopyPlan,owners::Error> oracle_plan(ref Fixture fixture){
    return owners::plan_call_copy(ref fixture.table,ref fixture.catalog,ref fixture.arguments[..fixture.count],512);
}
// The second independent oracle checks the diagnostic consumer, not merely
// metadata plan equality. Mixed validates bools before reservation; arrays-only
// reserves first. Failed transactions must preserve all table/backing bytes.
fn Result<usize,owners::Error> copy_oracle(ref Fixture fixture,ref owners::CallCopyPlan plan){
    let ref owners::Table original=ref fixture.table;var owners::Table table=*original;
    var u8[512] data=fixture.data;
    let Result<owners::Copies,owners::Error> result=if(fixture.reserve_first){
        var owners::Token[8] sources=[missing();8];var arrays::Array[8] shapes=[arrays::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0};8];
        var usize i=0;while(i<fixture.count){let owners::CallArgument a=fixture.arguments[i];sources[i]=a.source;
            shapes[i]=switch(arrays::scalar(a.element,a.length)){case .ok(v):{v}case .err(_):{return .err(.Metadata);}};i+=1;}
        owners::copy_arguments(ref sources[..fixture.count],ref shapes[..fixture.count],ref mut data,ref mut table)
    }else{owners::copy_call_arguments(ref fixture.catalog,ref fixture.arguments[..fixture.count],ref mut data,ref mut table)};
    switch(result){case .err(e):{
        assert(error_code(e)==fixture.copy_failure && fixture.copy_failure!=0);same_table(ref fixture.table,ref table);
        var usize i=0;while(i<512){assert(data[i]==fixture.data[i]);i+=1;}
    }case .ok(copies):{
        assert(fixture.copy_failure==0 && copies.count==plan.copies.count);same_table(ref table,ref plan.planned);
        var usize i=0;while(i<8){assert(copies.tokens[i].slot==plan.copies.tokens[i].slot && copies.tokens[i].generation==plan.copies.tokens[i].generation);i+=1;}
    }};return .ok(0);
}

// Keep constructors, oracle return slots and persistent large values in separate
// frames/banks. The native runner uses its default stack and allocator.
fn vec::Vec<work::State> work_bank(){
    var vec::Vec<work::State> bank=vec::empty<work::State>();
    assert(vec::reserve<work::State>(ref mut bank,1).is_ok);
    assert(vec::push<work::State>(ref mut bank,work::empty()).is_ok);return bank;
}
fn Result<vec::Vec<owners::CallCopyPlan>,owners::Error> plan_bank(ref Fixture f){
    let owners::CallCopyPlan p=oracle_plan(f)?;
    var vec::Vec<owners::CallCopyPlan> bank=vec::empty<owners::CallCopyPlan>();
    assert(vec::reserve<owners::CallCopyPlan>(ref mut bank,1).is_ok);
    assert(vec::push<owners::CallCopyPlan>(ref mut bank,p).is_ok);return .ok(bank);
}
fn vec::Vec<owners::CallCopyPlan> completed_plan_bank(ref work::State w){
    let owners::CallCopyPlan p=work::owner_plan(w);
    var vec::Vec<owners::CallCopyPlan> bank=vec::empty<owners::CallCopyPlan>();
    assert(vec::reserve<owners::CallCopyPlan>(ref mut bank,1).is_ok);
    assert(vec::push<owners::CallCopyPlan>(ref mut bank,p).is_ok);return bank;
}
fn void same_layout(ref layout_work::State a,ref layout_work::State b){
    assert(a.root==b.root && a.depth==b.depth && a.checked==b.checked && a.limit==b.limit && a.phase==b.phase && a.active==b.active && a.done==b.done);
    let ref records::Plan x=ref a.plan;let ref records::Plan y=ref b.plan;assert(x.count==y.count);
    var usize i=0;while(i<32){
        assert(x.bytes[i]==y.bytes[i] && x.alignments[i]==y.alignments[i] && x.depths[i]==y.depths[i]);
        assert(a.records[i]==b.records[i] && a.fields[i]==b.fields[i] && a.visiting[i]==b.visiting[i]);i+=1;
    }
    i=0;while(i<512){assert(x.offsets[i]==y.offsets[i]);i+=1;}
}
fn void same_work(ref work::State a,ref work::State b){
    assert(a.count==b.count && a.capacity==b.capacity && a.index==b.index && a.depth==b.depth && a.reads==b.reads && a.read_left==b.read_left && a.bool_index==b.bool_index);
    assert(a.phase==b.phase && a.arrays_only==b.arrays_only && a.layout_ok==b.layout_ok && a.layout_bad==b.layout_bad && a.active==b.active && a.done==b.done && a.ready==b.ready);
    same_layout(ref a.layout,ref b.layout);
    let ref work::Plan x=ref a.plan;let ref work::Plan y=ref b.plan;
    assert(x.mark==y.mark && x.depth==y.depth && x.checked==y.checked && x.failed==y.failed && x.failure==y.failure && x.copies.count==y.copies.count);
    same_table(ref x.planned,ref y.planned);var usize i=0;
    while(i<8){assert(a.bools[i]==b.bools[i]);
        assert(x.copies.tokens[i].slot==y.copies.tokens[i].slot && x.copies.tokens[i].generation==y.copies.tokens[i].generation);
        let owners::CallCopyRange r=x.ranges[i];let owners::CallCopyRange t=y.ranges[i];
        assert(r.source==t.source && r.target==t.target && r.mark==t.mark && r.end==t.end && r.size==t.size);i+=1;
    }
    i=0;while(i<16){assert(a.records[i]==b.records[i] && a.fields[i]==b.fields[i] && a.bases[i]==b.bases[i]);i+=1;}
    i=0;while(i<1024){assert(a.masks[i]==b.masks[i] && a.positions[i]==b.positions[i]);i+=1;}
}
fn void same_cursor(ref cursor::State a,ref cursor::State b){
    assert(a.active==b.active && a.reserve_first==b.reserve_first && a.phase==b.phase && a.index==b.index && a.at==b.at);
    assert(a.mark==b.mark && a.end==b.end && a.depth==b.depth && a.count==b.count && a.written==b.written && a.total==b.total && a.last==b.last);
    assert(a.pending==b.pending && a.charged==b.charged && a.pc==b.pc && a.frame==b.frame && a.offset==b.offset && a.target==b.target && a.fuel_before==b.fuel_before && a.captured==b.captured && a.remaining==b.remaining);
    var usize i=0;while(i<8){
        assert(a.source_slots[i]==b.source_slots[i] && a.source_generations[i]==b.source_generations[i] && a.source_bases[i]==b.source_bases[i] && a.source_ends[i]==b.source_ends[i]);
        assert(a.target_slots[i]==b.target_slots[i] && a.target_generations[i]==b.target_generations[i]);i+=1;
    }
}
fn void masks_match(ref work::State w,ref Fixture f,ref owners::CallCopyPlan p){
    var usize reads=0;var usize i=0;
    while(i<p.checked){let usize size=p.ranges[i].size;let u8 element=f.arguments[i].element;
        if(element==0){
            var u8[128] mask=[0;128];assert(size<=128);
            assert(storage::byte_kinds(ref f.catalog,f.arguments[i].record,ref mut mask[..size]).is_ok);
            var usize at=0;var usize bools=0;
            while(at<128){assert(w.masks[i*128+at]==mask[at]);
                if(mask[at]==2){assert(w.positions[i*128+bools] as usize==at);bools+=1;}at+=1;
            }
            assert(w.bools[i]==bools);reads+=bools;
        }else{let usize bools=if(element==2){size}else{0};assert(w.bools[i]==bools);reads+=bools;}
        i+=1;
    }
    assert(w.reads==reads);
}
fn Result<usize,owners::Error> drive(ref mut work::State w,ref Fixture f,ref Fixture original,bool check_defer){
    let usize begun=work::begin(w,f.reserve_first)?;assert(begun==0 && w.active && !w.done);
    assert(!work::capture(w,ref f.arguments[..f.count]).is_ok);
    var budget::State allowance=budget::empty();var usize stages=0;
    var vec::Vec<work::State> saved_bank=work_bank();let ref mut work::State saved=vec::at_mut<work::State>(ref mut saved_bank,0);
    while(stages<1024){
        assert(budget::reset(ref mut allowance,0).is_ok);assert(allowance.last==0);
        if(check_defer){
            *saved=*w;let usize total=allowance.total;let usize count=allowance.stages;
            let bool admitted=switch(budget::admit(ref mut allowance,1,0)){case .ok(v):{v}case .err(_):{assert(false);false}};assert(admitted);
            let bool done=switch(work::advance(w,ref f.table,ref f.catalog,ref f.arguments[..f.count],512,ref mut allowance)){
                case .ok(v):{v}case .err(_):{assert(false);false}};
            assert(!done && allowance.last==1 && allowance.total==total+1 && allowance.stages==count+1);
            same_work(w,saved);same_original(original,f);
            assert(budget::reset(ref mut allowance,0).is_ok);assert(allowance.last==0 && allowance.total==total+1);
        }
        let usize total=allowance.total;let usize count=allowance.stages;
        let Result<bool,owners::Error> result=work::advance(w,ref f.table,ref f.catalog,ref f.arguments[..f.count],512,ref mut allowance);
        stages+=1;assert(allowance.last==4096 && allowance.total==total+4096 && allowance.stages==count+1);
        same_original(original,f);
        switch(result){case .err(e):{assert(!w.active && !w.done);return .err(e);}case .ok(done):{
            if(done){assert(w.done && !w.active && stages>=3);return .ok(stages);}
            assert(w.active && !w.done);
        }};
    }
    assert(false);return .err(.State);
}
fn Result<usize,owners::Error> example(usize id,bool check_defer){
    let vec::Vec<Fixture> original_bank=fixture_bank(id)?;let ref Fixture original=vec::at<Fixture>(ref original_bank,0);
    let vec::Vec<Fixture> live_bank=fixture_bank(id)?;let ref Fixture f=vec::at<Fixture>(ref live_bank,0);
    let vec::Vec<owners::CallCopyPlan> oracle_storage=plan_bank(f)?;let ref owners::CallCopyPlan expected=vec::at<owners::CallCopyPlan>(ref oracle_storage,0);
    assert(expected.checked==f.checked && expected.copies.count==f.copies && failure_code(expected.failure)==f.plan_failure);
    var vec::Vec<work::State> bank=work_bank();let ref mut work::State w=vec::at_mut<work::State>(ref mut bank,0);
    let usize stages=drive(w,f,original,check_defer)?;
    let vec::Vec<owners::CallCopyPlan> actual_storage=completed_plan_bank(w);let ref owners::CallCopyPlan actual=vec::at<owners::CallCopyPlan>(ref actual_storage,0);
    same_plan(expected,actual);masks_match(w,f,expected);
    var cursor::State raw=owners::capture_call_copy(expected,ref f.arguments[..f.count])?;raw.reserve_first=f.reserve_first;
    let cursor::State captured=work::capture(w,ref f.arguments[..f.count])?;same_cursor(ref raw,ref captured);
    if(id==0){assert(actual.mark==11 && actual.planned.arena.used==59 && w.reads==16);}
    if(id==11 || id==12){assert(actual.mark==16 && actual.planned.arena.used==144 && w.reads==128 && stages>32);}
    if(id==16){assert(actual.ranges[0].size==32 && w.bools[0]==3 && w.positions[0]==8 && w.positions[1]==17 && w.positions[2]==24);}
    if(id==17){assert(actual.ranges[0].size==128 && w.bools[0]==16 && w.positions[15]==127);}
    if(id==18){assert(w.reads==256 && captured.reserve_first && actual.planned.arena.used==512);}
    let usize copied=copy_oracle(f,expected)?;same_original(original,f);return .ok(stages);
}

// Compare arrays-only descriptor priority with the existing owning boundary,
// which authenticates descriptors before invoking the raw metadata planner.
fn Result<usize,owners::Error> header_error(usize mode){
    var owners::Table table=owners::empty(512);table.depth=17;
    let owners::Token none=missing();var owners::CallArgument[9] args=[arg(none,2,3,0);9];
    let usize count=if(mode==0){9}else{1};let bool arrays_only=mode==2 || mode==3;
    if(mode==2){args[0].element=0;}if(mode==3){args[0].record=1;}
    let owners::Table before=table;let records::Catalog catalog=records::empty();
    let u8 expected=if(mode==0 || mode==3){6}else if(mode==2){4}else{3};
    if(arrays_only){
        switch(raw_copy::begin_arrays(ref table,ref catalog,ref args[..count],512)){
            case .ok(_):{assert(false);}case .err(e):{assert(error_code(e)==expected);}};
    }else if(!arrays_only){switch(owners::plan_call_copy(ref table,ref catalog,ref args[..count],512)){
        case .ok(_):{assert(false);}case .err(e):{assert(error_code(e)==expected);}};}
    var vec::Vec<work::State> bank=work_bank();let ref mut work::State w=vec::at_mut<work::State>(ref mut bank,0);
    let usize begun=work::begin(w,arrays_only)?;var budget::State allowance=budget::empty();
    assert(budget::reset(ref mut allowance,0).is_ok);
    switch(work::advance(w,ref table,ref catalog,ref args[..count],512,ref mut allowance)){
        case .ok(_):{assert(false);}case .err(e):{assert(error_code(e)==expected && !w.active && !w.done);}};
    assert(allowance.last==4096);same_table(ref before,ref table);return .ok(begun);
}

@test fn void mixed_repeated_sources_nested_masks_and_bool_positions_match_raw_plan(){
    let usize[3] ids=[0,16,17];var usize i=0;while(i<3){assert(example(ids[i],true).is_ok);i+=1;}
}
@test fn void full_catalog_forward_and_reverse_layouts_resume_with_exact_plans(){
    assert(example(11,true).is_ok);assert(example(12,true).is_ok);
}
@test fn void malformed_catalog_and_stale_sources_keep_later_errors_deferred(){
    let usize[6] ids=[1,2,7,8,9,10];var usize i=0;while(i<6){assert(example(ids[i],true).is_ok);i+=1;}
}
@test fn void saturated_quotas_and_slots_preserve_mixed_and_array_reserve_first_order(){
    let usize[6] ids=[3,4,5,6,13,14];var usize i=0;while(i<6){assert(example(ids[i],true).is_ok);i+=1;}
}
@test fn void empty_arguments_and_long_bool_array_ignore_unused_bad_catalog(){
    assert(example(15,true).is_ok);assert(example(18,true).is_ok);
}
@test fn void arity_and_array_descriptors_precede_invalid_original_table(){
    var usize mode=0;while(mode<4){assert(header_error(mode).is_ok);mode+=1;}
}

struct Receipt {
    owners::Table table; u8[512] data; owners::Copies copies;
    u8 error; usize fuel; usize calls; usize charges; usize total; usize written;
}
fn owners::Copies no_copies(){return owners::Copies{.tokens=[owners::Token{.slot=0,.generation=0};8],.count=0};}
fn void same_copies(ref owners::Copies a,ref owners::Copies b){
    assert(a.count==b.count);var usize i=0;while(i<8){
        assert(a.tokens[i].slot==b.tokens[i].slot && a.tokens[i].generation==b.tokens[i].generation);i+=1;}
}
fn Result<Receipt,owners::Error> raw_payload(ref Fixture f){
    var owners::Table table=f.table;var u8[512] data=f.data;
    var cursor::State copy=if(f.reserve_first){raw_copy::begin_arrays(ref table,ref f.catalog,ref f.arguments[..f.count],512)?}
        else{raw_copy::begin(ref table,ref f.catalog,ref f.arguments[..f.count],512)?};
    var usize calls=0;var owners::Copies copies=no_copies();var u8 failure=0;var bool finished=false;
    while(calls<1024 && !finished){
        copy.last=0;calls+=1;
        switch(raw_copy::advance(ref mut copy,ref mut table,ref f.catalog,ref f.arguments[..f.count],ref mut data,7)){
            case .err(e):{failure=error_code(e);finished=true;}
            case .ok(result):{switch(result){case .none:{}case .some(v):{copies=v;finished=true;}};}
        };
    }
    assert(finished);return .ok(Receipt{.table=table,.data=data,.copies=copies,.error=failure,
        .fuel=0,.calls=calls,.charges=0,.total=copy.total,.written=copy.written});
}
fn Result<Receipt,owners::Error> prepared_payload(ref Fixture f,usize room,bool short_first){
    var vec::Vec<work::State> bank=work_bank();let ref mut work::State w=vec::at_mut<work::State>(ref mut bank,0);
    let usize planned=drive(w,f,f,false)?;
    var cursor::State copy=work::capture(w,ref f.arguments[..f.count])?;
    copy.captured=1000000;copy.remaining=900000;var usize remaining=1000000;
    var owners::Table table=f.table;var u8[512] data=f.data;
    var vec::Vec<work::State> saved_bank=work_bank();let ref mut work::State saved=vec::at_mut<work::State>(ref mut saved_bank,0);
    var budget::State allowance=budget::empty();var usize calls=0;var usize charges=0;
    var owners::Copies copies=no_copies();var u8 failure=0;var bool finished=false;
    while(calls<1024 && !finished){
        // A validation proof consumes its own dispatch. A partially occupied
        // dispatch cannot mutate the cached plan, continuation, or Fuel.
        assert(!w.ready);*saved=*w;let cursor::State prior=copy;let usize fuel=remaining;
        assert(budget::reset(ref mut allowance,0).is_ok);let usize total=allowance.total;let usize stages=allowance.stages;
        let bool admitted=switch(budget::admit(ref mut allowance,1,0)){case .ok(v):{v}case .err(_):{assert(false);false}};assert(admitted);
        let bool deferred=work::validate(w,ref table,ref f.arguments[..f.count],ref copy,512,ref mut allowance)?;
        assert(!deferred && allowance.last==1 && allowance.total==total+1 && allowance.stages==stages+1);
        same_work(w,saved);same_cursor(ref copy,ref prior);assert(remaining==fuel);same_table(ref f.table,ref table);
        assert(budget::reset(ref mut allowance,0).is_ok);
        let bool validated=work::validate(w,ref table,ref f.arguments[..f.count],ref copy,512,ref mut allowance)?;
        assert(validated && w.ready && allowance.last==4096);
        // The next dispatch supplies a fresh room shared by fixed metadata,
        // cached position/mask accesses, and actual payload work.
        assert(budget::reset(ref mut allowance,0).is_ok);copy.last=0;
        let cursor::State before=copy;let usize before_fuel=remaining;*saved=*w;
        let bool charged=copy.charged;calls+=1;
        let usize available=if(short_first && calls==1){1023}else{room};
        let Result<Option<owners::Copies>,owners::Error> result=prepared::advance(w,ref mut copy,ref mut table,
            ref f.arguments[..f.count],ref mut data,ref mut remaining,available,ref mut allowance);
        assert(copy.last+allowance.last<=available && copy.last+allowance.last<=4096);
        if(short_first && calls==1){
            assert(result.is_ok && allowance.last==0 && remaining==before_fuel);
            same_work(w,saved);same_cursor(ref before,ref copy);
            var usize i=0;while(i<512){assert(data[i]==f.data[i]);i+=1;}
        }else{assert(allowance.last>=1024);}
        w.ready=false;
        if(!charged && copy.charged){charges+=1;}
        assert(remaining==if(copy.charged){900000}else{1000000});
        if(copy.phase==0 && copy.count!=0){assert(!copy.charged && copy.written==0);}
        var usize at=0;while(at<copy.mark){assert(data[at]==f.data[at]);at+=1;}
        switch(result){
            case .err(e):{failure=error_code(e);finished=true;}
            case .ok(value):{switch(value){
                case .none:{same_table(ref f.table,ref table);}
                case .some(v):{copies=v;finished=true;assert(!copy.active);}
            };}
        };
    }
    assert(finished && planned>=3);
    if(failure==0){assert(charges==1 && copy.charged && remaining==900000);}
    else{assert(charges==0 && !copy.charged && remaining==1000000);same_table(ref f.table,ref table);}
    return .ok(Receipt{.table=table,.data=data,.copies=copies,.error=failure,.fuel=remaining,
        .calls=calls,.charges=charges,.total=copy.total,.written=copy.written});
}
fn Result<vec::Vec<Receipt>,owners::Error> receipt_bank(ref Fixture f,bool staged,usize room,bool short_first){
    let Receipt receipt=if(staged){prepared_payload(f,room,short_first)?}else{raw_payload(f)?};
    var vec::Vec<Receipt> bank=vec::empty<Receipt>();assert(vec::reserve<Receipt>(ref mut bank,1).is_ok);
    assert(vec::push<Receipt>(ref mut bank,receipt).is_ok);return .ok(bank);
}
fn Result<usize,owners::Error> payload_example(usize id,usize room,bool short_first){
    let vec::Vec<Fixture> fixtures=fixture_bank(id)?;let ref Fixture f=vec::at<Fixture>(ref fixtures,0);
    let vec::Vec<Receipt> raw_bank=receipt_bank(f,false,4096,false)?;let ref Receipt raw=vec::at<Receipt>(ref raw_bank,0);
    let vec::Vec<Receipt> staged_bank=receipt_bank(f,true,room,short_first)?;let ref Receipt staged=vec::at<Receipt>(ref staged_bank,0);
    assert(staged.error==raw.error && staged.error==f.copy_failure);same_table(ref staged.table,ref raw.table);
    same_copies(ref staged.copies,ref raw.copies);assert(staged.total==raw.total && staged.written==raw.written);
    var usize i=0;while(i<512){assert(staged.data[i]==raw.data[i]);i+=1;}
    if(short_first){assert(staged.calls>1);}return .ok(staged.calls);
}

@test fn void prepared_payload_matches_raw_repeated_mixed_records_arrays_and_empty(){
    let usize[5] ids=[0,16,17,18,15];var usize i=0;
    while(i<5){assert(payload_example(ids[i],if(ids[i]==17){1030}else{4096},true).is_ok);i+=1;}
}
@test fn void prepared_bad_bool_precedes_later_catalog_source_and_reservation_errors(){
    let usize[5] ids=[1,2,3,5,9];var usize i=0;
    while(i<5){assert(payload_example(ids[i],4096,false).is_ok);i+=1;}
}
@test fn void prepared_array_reserve_first_and_late_valid_bool_errors_match_raw(){
    let usize[5] ids=[4,6,7,13,14];var usize i=0;
    while(i<5){assert(payload_example(ids[i],4096,false).is_ok);i+=1;}
}

fn Result<usize,owners::Error> recipe_guards(){
    let vec::Vec<Fixture> fixtures=fixture_bank(0)?;let ref Fixture f=vec::at<Fixture>(ref fixtures,0);
    var vec::Vec<work::State> bank=work_bank();let ref mut work::State w=vec::at_mut<work::State>(ref mut bank,0);
    let usize stages=drive(w,f,f,false)?;let cursor::State valid=work::capture(w,ref f.arguments[..f.count])?;
    var vec::Vec<work::State> saved_bank=work_bank();let ref mut work::State saved=vec::at_mut<work::State>(ref mut saved_bank,0);*saved=*w;
    var budget::State allowance=budget::empty();var usize mode=0;
    while(mode<8){var cursor::State bad=valid;var usize capacity=512;
        if(mode==0){bad.source_generations[0]+=1;}
        else if(mode==1){bad.target_generations[0]+=1;}
        else if(mode==2){bad.reserve_first=true;}
        else if(mode==3){bad.count+=1;}
        else if(mode==4){bad.phase=2;}
        else if(mode==5){bad.at=129;}
        else if(mode==6){capacity=511;}
        else{bad.mark+=1;}
        let cursor::State original=bad;assert(budget::reset(ref mut allowance,0).is_ok);
        switch(work::validate(w,ref f.table,ref f.arguments[..f.count],ref bad,capacity,ref mut allowance)){
            case .ok(_):{assert(false);}case .err(e):{assert(error_code(e)==3);}
        };
        assert(allowance.last==4096 && !w.ready);same_work(w,saved);same_cursor(ref original,ref bad);mode+=1;
    }
    return .ok(stages);
}
@test fn void validation_rejects_changed_recipe_and_capacity_without_ready_publication(){
    assert(recipe_guards().is_ok);
}
