module tests::m2::source_name_work;
import source_name_work as work;
import source_context as raw;
import metadata_budget as budget;
fn u32 word(usize a,usize b,usize extra){var usize value=a|(b<<13)|extra;var u32 packed=0;var u32 bit=1;
    while(value!=0){if((value&1)!=0){packed|=bit;}value>>=1;if(value!=0){bit<<=1;}}return packed;}
fn raw::Table table(){var raw::Table t=raw::empty();t.modules=2;t.ends[0]=9;t.ends[1]=15;
    t.imports=1;t.aliases[0]=word(0,1,67108864);t.function_count=1;t.functions[0]=word(9,15,67108864);
    t.record_count=1;t.records[0]=word(9,15,67108864);return t;}
fn void same(ref u8[] source,ref raw::Table t,usize a,usize b,bool record){
    let usize expected=raw::lookup_raw(source,t,a,b,record);var work::State w=work::begin(a,b,record);
    assert(raw::lookup(source,t,a,b,record)==expected);
    var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<1500);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize row=w.row;let usize compared=w.compared;let usize visits=w.visits;
        let u8 lexical=w.scan.phase;let usize checked=w.check.cursor;
        assert(budget::admit(ref mut meter,1,0).is_ok);let usize total=meter.total;
        assert(work::advance(source,t,ref mut w,ref mut meter).is_ok);
        assert(w.phase==phase && w.row==row && w.compared==compared && w.visits==visits && w.scan.phase==lexical && w.check.cursor==checked && meter.total==total);
        assert(budget::reset(ref mut meter,0).is_ok);assert(work::advance(source,t,ref mut w,ref mut meter).is_ok);
        assert(meter.last==4096 && w.visits-visits<=64);turns+=1;
        if(!w.done){assert(w.result==if(record){32}else{16});}
    }
    assert(w.result==expected);let usize total=meter.total;
    assert(work::advance(source,t,ref mut w,ref mut meter).is_ok && meter.total==total);
}
@test fn void qualified_alias_visibility_and_first_private_match_keep_raw_order(){
    var raw::Table t=table();same(b"m::answeranswer",ref t,0,9,false);same(b"m::answeranswer",ref t,0,9,true);
    t.functions[0]=word(9,15,0);same(b"m::answeranswer",ref t,0,9,false);
    t.function_count=2;t.functions[1]=word(9,15,67108864);same(b"m::answeranswer",ref t,0,9,false);
    t=table();t.aliases[0]=word(0,1,0);same(b"m::answeranswer",ref t,0,9,false);
    t=table();t.aliases[0]=word(3,9,67108864);same(b"m::answeranswer",ref t,0,9,false);
}
fn void query(ref u8[] source,usize end){var raw::Table t=raw::empty();t.modules=1;t.ends[0]=word(source.len,0,0);
    t.imports=1;t.aliases[0]=word(0,1,0);t.function_count=1;t.functions[0]=word(source.len-6,source.len,0);
    same(source,ref t,0,end,false);}
@test fn void query_comments_lexer_errors_and_bounds_match_raw_absence(){
    let ref u8[] source=b"m /*x*/ :: answer answer";query(source,source.len-7);
    query(b"m::1 answer",4);query(b"m:answer answer",8);query(b"m::answer::x answer",12);
    query(b"m /*bad\r*/ :: answer answer",20);
    var raw::Table t=table();same(b"m::answeranswer",ref t,9,4,false);same(b"m::answeranswer",ref t,0,16,false);
    t=raw::empty();same(b"m::answeranswer",ref t,0,9,false);
}
@test fn void long_local_spelling_comparison_is_chunked_and_tail_fields_are_ignored(){
    var u8[4096] source=[65;4096];var raw::Table t=raw::empty();t.modules=1;t.ends[0]=4096;
    t.function_count=1;t.functions[0]=word(0,4096,0);t.aliases[63]=1073741824;
    same(ref source,ref t,0,4096,false);source[4095]=66;same(ref source,ref t,0,4096,false);
}
