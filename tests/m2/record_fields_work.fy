module tests::m2::record_fields_work;
import record_fields_work as work;
import struct_source as raw;
import struct_layout as layouts;
import source_context as context;
import metadata_budget as budget;
import errors as errors;
fn raw::Table candidate(usize name){var raw::Table t=raw::Table{.context=context::empty(),.layouts=layouts::empty(),
    .begins=[0;32],.ends=[0;32],.bodies=[0;32]};t.layouts.count=1;t.begins[0]=name;t.ends[0]=name+1;return t;}
fn void equal(ref raw::Table a,ref raw::Table b){
    assert(a.layouts.count==b.layouts.count);var usize i=0;
    while(i<32){assert(a.layouts.fields[i]==b.layouts.fields[i] && a.begins[i]==b.begins[i] && a.ends[i]==b.ends[i] && a.bodies[i]==b.bodies[i]);i+=1;}
    i=0;while(i<512){assert(a.layouts.kinds[i]==b.layouts.kinds[i] && a.layouts.types[i]==b.layouts.types[i]);i+=1;}
}
fn Result<usize,errors::Error> run(ref u8[] source,ref mut raw::Table t,usize record){
    var work::State w=work::begin(record);var budget::State meter=budget::empty();var usize turns=0;
    assert(!work::prepared(ref w).is_ok);
    while(!w.done){assert(turns<6000);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize field=w.field;let usize row=w.row;let usize cursor=w.token.cursor;let usize compared=w.compared;let usize visits=w.visits;
        let u8 state=w.state.phase;let u8 name=w.name.phase;let u8 lexical=w.scan.phase;let u8 primitive=w.primitive.phase;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,t,ref mut w,ref mut meter).is_ok);
        assert(w.phase==phase && w.field==field && w.row==row && w.token.cursor==cursor && w.compared==compared && w.visits==visits &&
            w.state.phase==state && w.name.phase==name && w.scan.phase==lexical && w.primitive.phase==primitive && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);
        switch(work::advance(source,t,ref mut w,ref mut meter)){
            case .ok(done):{assert(done==w.done && meter.last==4096 && w.visits-visits<=64);}
            case .err(e):{return .err(e);}};turns+=1;
    }
    let usize total=meter.total;assert(work::advance(source,t,ref mut w,ref mut meter).is_ok && meter.total==total);
    return work::prepared(ref w);
}
fn void same(ref u8[] source,raw::Table initial){var raw::Table a=initial;var raw::Table b=initial;
    let Result<usize,errors::Error> expected=raw::resolve_untyped_raw(source,ref mut a,0);
    let Result<usize,errors::Error> actual=run(source,ref mut b,0);equal(ref a,ref b);
    switch(expected){case .ok(v):{switch(actual){case .ok(w):{assert(v==w);}case .err(_):{assert(false);}};}
        case .err(e):{switch(actual){case .ok(_):{assert(false);}case .err(f):{assert(e.kind==f.kind && e.offset==f.offset);}};}};
}
fn void plain(ref u8[] source){let raw::Table t=candidate(source.len-1);same(source,t);}
@test fn void scalar_nominal_zero_id_and_exact_field_failures_match(){
    plain(b"i32 x;bool y;u8 b;usize n;}R");plain(b"R self;}R");plain(b"i32 x;bool x;}R");
    plain(b"Q x;}R");plain(b"Option<i32> x;}R");plain(b"i32[2] x;}R");
    plain(b"i32 if;}R");plain(b"i32 x }R");plain(b"i32 x;\xff}R");
    let ref u8[] source=b"B first;i32 x;}A B";var raw::Table t=candidate(source.len-3);t.layouts.count=2;
    t.begins[1]=source.len-1;t.ends[1]=source.len;same(source,t);
    t=candidate(7);t.layouts.kinds[511]=9;same(b"i32 x;}R",t);
}
fn u32 word(usize a,usize b,usize extra){var usize value=a|(b<<13)|extra;var u32 result=0;var u32 bit=1;
    while(value!=0){if((value&1)!=0){result|=bit;}value>>=1;if(value!=0){bit<<=1;}}return result;}
@test fn void scoped_alias_visibility_keeps_nominal_and_missing_type_diagnostics(){
    let ref u8[] source=b"m::P x;}R P";var raw::Table t=candidate(source.len-3);t.layouts.count=2;
    t.begins[1]=source.len-1;t.ends[1]=source.len;t.context.modules=2;
    t.context.ends[0]=word(source.len-1,0,0);t.context.ends[1]=word(source.len,0,0);
    t.context.imports=1;t.context.aliases[0]=word(0,1,67108864);t.context.record_count=2;
    t.context.records[0]=word(source.len-3,source.len-2,0);t.context.records[1]=word(source.len-1,source.len,67108864);same(source,t);
    t.context.records[1]=word(source.len-1,source.len,0);same(source,t);
    // Packed prefix is i32 although the actual candidate name is i32X.
    // Raw scoped lookup resolves it nominally; an unscoped shortcut must not.
    let ref u8[] prefix=b"i32 x;}i32X";t=candidate(prefix.len-4);t.ends[0]=prefix.len;
    t.context.modules=1;t.context.ends[0]=word(prefix.len,0,0);t.context.record_count=1;
    t.context.records[0]=word(prefix.len-4,prefix.len-1,0);same(prefix,t);
}
@test fn void duplicate_field_names_compare_in_bounded_chunks(){
    var u8[4096] source=[32;4096];let ref u8[] prefix=b"i32 ";let ref u8[] middle=b";bool ";
    var usize i=0;while(i<prefix.len){source[i]=prefix[i];i+=1;}var usize j=0;
    while(j<1000){source[i]=65;i+=1;j+=1;}j=0;while(j<middle.len){source[i]=middle[j];i+=1;j+=1;}
    j=0;while(j<1000){source[i]=65;i+=1;j+=1;}source[i]=59;i+=1;source[i]=125;i+=1;
    source[i]=82;let raw::Table t=candidate(i);same(ref source,t);
}
