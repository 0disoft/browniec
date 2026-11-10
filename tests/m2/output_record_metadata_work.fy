module tests::m2::output_record_metadata_work;

import output_record_metadata_work as work;
import struct_meta as metadata;
import metadata_budget as budget;
import errors as errors;
import std::vec as vec;

struct Outcome { bool ok; u8 kind; usize offset; usize dispatches; }

// Large resumable and oracle values live in SDK-owned single-slot banks so the
// test driver frame remains below the default stack commit.
fn vec::Vec<work::State> work_bank(){
    var vec::Vec<work::State> bank=vec::empty<work::State>();
    assert(vec::reserve<work::State>(ref mut bank,1).is_ok);
    assert(vec::push<work::State>(ref mut bank,work::empty()).is_ok);
    return bank;
}
fn Result<vec::Vec<metadata::Prepared>,errors::Error> oracle_bank(ref metadata::Catalog c){
    let metadata::Prepared expected=metadata::prepare(c)?;
    var vec::Vec<metadata::Prepared> bank=vec::empty<metadata::Prepared>();
    assert(vec::reserve<metadata::Prepared>(ref mut bank,1).is_ok);
    assert(vec::push<metadata::Prepared>(ref mut bank,expected).is_ok);
    return .ok(bank);
}
fn usize reset(ref mut budget::State meter){
    return switch(budget::reset(meter,0)){case .ok(v):{v}case .err(_):{assert(false);0}};
}
fn bool pre_admit(ref mut budget::State meter){
    return switch(budget::admit(meter,1,0)){case .ok(v):{v}case .err(_):{assert(false);false}};
}
fn void same_prepared(ref metadata::Prepared a,ref metadata::Prepared b){
    var usize i=0;while(i<16){assert(a.leaves[i]==b.leaves[i]);i+=1;}
    i=0;while(i<2048){assert(a.tags[i]==b.tags[i]);i+=1;}
}
fn void same_state(ref work::State a,ref work::State b){
    assert(a.depth==b.depth && a.binding==b.binding && a.catalog_count==b.catalog_count &&
        a.layout_count==b.layout_count && a.phase==b.phase &&
        a.active==b.active && a.done==b.done);
    var usize i=0;while(i<16){assert(a.records[i]==b.records[i] && a.fields[i]==b.fields[i]);i+=1;}
    same_prepared(ref a.result,ref b.result);
}
fn Outcome continue_drive(ref mut work::State w,ref metadata::Catalog c,bool defers,
    ref mut budget::State meter,usize prior_dispatches){
    var usize dispatches=prior_dispatches;
    var vec::Vec<work::State> saved_storage=work_bank();
    let ref mut work::State saved=vec::at_mut<work::State>(ref mut saved_storage,0);
    while(dispatches<512){
        let usize ready=reset(meter);assert(ready==4096 && meter.last==0);
        if(defers){
            *saved=*w;let usize total=meter.total;let usize stages=meter.stages;
            assert(pre_admit(meter));
            switch(work::advance(w,c,meter)){
                case .ok(done):{assert(!done);}case .err(_):{assert(false);return Outcome{.ok=false,.kind=98,.offset=0,.dispatches=dispatches};}
            };
            same_state(w,saved);assert(meter.total==total+1 && meter.stages==stages+1);
            let usize fresh=reset(meter);assert(fresh==4096 && meter.last==0 && meter.total==total+1);
        }
        let usize total=meter.total;let usize stages=meter.stages;
        let Result<bool,errors::Error> progressed=work::advance(w,c,meter);
        dispatches+=1;
        assert(meter.total==total+4096 && meter.stages==stages+1 && meter.last==4096);
        switch(progressed){
            case .ok(done):{assert(done==w.done);if(done){assert(!w.active);return Outcome{.ok=true,.kind=0,.offset=0,.dispatches=dispatches};}}
            case .err(e):{assert(!w.active && !w.done);return Outcome{.ok=false,.kind=e.kind,.offset=e.offset,.dispatches=dispatches};}
        };
        assert(w.active && !w.done);
    }
    assert(false);return Outcome{.ok=false,.kind=97,.offset=0,.dispatches=dispatches};
}
fn Outcome drive_started(ref mut work::State w,ref metadata::Catalog c,bool defers){
    assert(w.active && !w.done);
    var budget::State meter=budget::empty();
    return continue_drive(w,c,defers,ref mut meter,0);
}
fn Outcome drive(ref mut work::State w,ref metadata::Catalog c,bool defers){
    switch(work::begin(w,c)){
        case .ok(v):{assert(v==0);}case .err(_):{assert(false);return Outcome{.ok=false,.kind=99,.offset=0,.dispatches=0};}
    };
    return drive_started(w,c,defers);
}
fn void same(ref metadata::Catalog c,bool defers){
    let Result<vec::Vec<metadata::Prepared>,errors::Error> raw=oracle_bank(c);
    var vec::Vec<work::State> storage=work_bank();
    let ref mut work::State w=vec::at_mut<work::State>(ref mut storage,0);
    let Outcome actual=drive(w,c,defers);
    switch(raw){
        case .ok(storage):{
            assert(actual.ok && actual.kind==0);
            let metadata::Prepared result=switch(work::prepared(w)){case .ok(v):{v}case .err(_):{assert(false);return;}};
            let ref metadata::Prepared expected=vec::at<metadata::Prepared>(ref storage,0);
            same_prepared(ref result,expected);
        }
        case .err(expected):{
            assert(!actual.ok && actual.kind==expected.kind && actual.offset==expected.offset);
        }
    };
}

fn metadata::Catalog nested(){
    var metadata::Catalog c=metadata::empty();
    c.layouts.count=3;
    c.layouts.fields[0]=3;c.layouts.types[0]=10;c.layouts.types[1]=9;c.layouts.types[2]=2;
    c.layouts.fields[1]=2;c.layouts.kinds[16]=1;c.layouts.types[16]=0;c.layouts.types[17]=12;
    c.layouts.fields[2]=2;c.layouts.types[32]=1;c.layouts.kinds[33]=1;c.layouts.types[33]=1;
    c.count=3;c.records[0]=1;c.records[1]=2;c.records[2]=0;
    return c;
}
fn metadata::Catalog flats(){
    var metadata::Catalog c=metadata::empty();c.layouts.count=16;c.count=16;
    var usize i=0;var u8 id=0;while(i<16){c.layouts.fields[i]=16;c.records[i]=id;id+=1;
        var usize f=0;while(f<16){c.layouts.types[i*16+f]=if(f==0){10}else{9};f+=1;}i+=1;}
    return c;
}
fn metadata::Catalog over_limit(){
    var metadata::Catalog c=metadata::empty();c.layouts.count=2;c.layouts.fields[0]=16;
    var usize i=0;while(i<16){c.layouts.types[i]=9;i+=1;}
    c.layouts.fields[1]=2;c.layouts.kinds[16]=1;c.layouts.kinds[17]=1;
    c.count=1;c.records[0]=1;return c;
}

@test fn void empty_nested_and_sixteen_binding_flattening_match_raw_prepare(){
    let metadata::Catalog empty=metadata::empty();same(ref empty,true);
    let metadata::Catalog graph=nested();same(ref graph,true);
    let metadata::Catalog dense=flats();same(ref dense,true);
}

@test fn void layout_and_binding_errors_preserve_raw_kind_and_offset(){
    var metadata::Catalog c=metadata::empty();c.layouts.count=1;c.layouts.fields[0]=1;
    c.layouts.types[0]=3;same(ref c,false);
    c=metadata::empty();c.layouts.count=1;c.layouts.fields[0]=1;c.layouts.types[0]=10;c.count=17;same(ref c,false);
    c=metadata::empty();c.count=1;same(ref c,false);
    c=metadata::empty();c.layouts.count=1;c.layouts.fields[0]=1;c.layouts.types[0]=10;
    c.records[15]=1;same(ref c,false);
    c=metadata::empty();c.layouts.count=2;c.layouts.fields[0]=1;c.layouts.types[0]=10;
    c.layouts.fields[1]=1;c.layouts.types[16]=10;c.count=1;c.records[0]=2;same(ref c,false);
    let metadata::Catalog too_wide=over_limit();same(ref too_wide,false);
}

@test fn void partial_room_defers_without_state_or_credit_changes(){
    let metadata::Catalog c=nested();same(ref c,true);
    var vec::Vec<work::State> storage=work_bank();
    let ref mut work::State w=vec::at_mut<work::State>(ref mut storage,0);
    switch(work::begin(w,ref c)){case .ok(_):{}case .err(_):{assert(false);return;}};
    var budget::State meter=budget::empty();assert(budget::reset(ref mut meter,0).is_ok);
    var vec::Vec<work::State> saved_storage=work_bank();
    let ref mut work::State saved=vec::at_mut<work::State>(ref mut saved_storage,0);
    *saved=*w;assert(pre_admit(ref mut meter));
    switch(work::advance(w,ref c,ref mut meter)){case .ok(done):{assert(!done);}case .err(_):{assert(false);return;}};
    same_state(w,saved);assert(meter.last==1 && !w.done && w.active);
    assert(budget::reset(ref mut meter,0).is_ok);
    let usize resumed=continue_drive(w,ref c,false,ref mut meter,0).dispatches;
    assert(resumed>0);

    var metadata::Catalog invalid=metadata::empty();invalid.count=1;
    var vec::Vec<work::State> invalid_storage=work_bank();
    let ref mut work::State bad=vec::at_mut<work::State>(ref mut invalid_storage,0);
    switch(work::begin(bad,ref invalid)){case .ok(_):{}case .err(_):{assert(false);return;}};
    var budget::State invalid_meter=budget::empty();assert(budget::reset(ref mut invalid_meter,0).is_ok);
    var vec::Vec<work::State> invalid_storage_saved=work_bank();
    let ref mut work::State invalid_saved=vec::at_mut<work::State>(ref mut invalid_storage_saved,0);
    *invalid_saved=*bad;assert(pre_admit(ref mut invalid_meter));
    switch(work::advance(bad,ref invalid,ref mut invalid_meter)){case .ok(done):{assert(!done);}case .err(_):{assert(false);return;}};
    same_state(bad,invalid_saved);assert(invalid_meter.last==1 && bad.active);
    assert(budget::reset(ref mut invalid_meter,0).is_ok);
    switch(work::advance(bad,ref invalid,ref mut invalid_meter)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && !bad.active);}};
    assert(invalid_meter.last==4096);
}
