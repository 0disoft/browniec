module tests::m2::output_verifier_tasks_work;
import output_verifier_tasks_work as work;
import array_verifier as arrays;
import struct_verifier as structs;
import aggregate_place_ir as places;
import copy_ir as copying;
import ir as ir;
import struct_meta as records;
import struct_layout as layouts;
import static_ir as statics;
import register_set as registers;
import errors as errors;
import metadata_budget as budget;

fn registers::Set defined(){return registers::Set{.low=3,.high=0};}
fn ir::Program array(){
    var ir::Program p=ir::empty();p.count=1;p.function_count=1;p.ends[0]=1;p.registers=2;p.register_ends[0]=2;p.types[0]=10;p.types[1]=1;
    p.arrays.count=1;p.arrays.elements[0]=10;p.arrays.lengths[0]=65;p.arrays.mutable[0]=true;p.list_used=65;p.code[0]=80;return p;
}
fn ir::Program record(){
    var ir::Program p=ir::empty();p.count=1;p.function_count=1;p.ends[0]=1;p.registers=2;p.register_ends[0]=2;p.types[0]=1;p.types[1]=10;
    p.records.layouts.count=1;p.records.layouts.fields[0]=1;p.records.layouts.types[0]=10;
    p.records.count=2;p.records.mutable[0]=true;p.records.mutable[1]=true;p.code[0]=47;p.code[2]=1;return p;
}
fn Result<usize,errors::Error> staged(ref ir::Program p,ref records::Prepared shapes,ref layouts::Plan plan,u8 kind,usize live){
    let statics::Sites sites=statics::empty();var work::State w=work::empty();
    let work::Request request=work::Request{.function=0,.pc=0,.live=live,.defined=defined(),.kind=kind};
    let usize started=work::begin(ref mut w,request)?;var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<1024);assert(budget::reset(ref mut meter,0).is_ok);
        let work::State saved=w;assert(budget::admit(ref mut meter,1,0).is_ok);let budget::State before=meter;
        let bool denied=work::advance(p,shapes,plan,ref sites,ref mut w,ref mut meter)?;
        assert(!denied && w.phase==saved.phase && w.index==saved.index && w.count==saved.count && w.output==saved.output);
        assert(meter.total==before.total && meter.stages==before.stages && meter.last==before.last);
        assert(budget::reset(ref mut meter,0).is_ok);
        let bool done=work::advance(p,shapes,plan,ref sites,ref mut w,ref mut meter)?;assert(done==w.done && meter.last==4096);turns+=1;
    }return .ok(w.output);
}
fn Result<usize,errors::Error> synchronous(ref ir::Program p,ref records::Prepared shapes,u8 kind,usize live){
    var registers::Set r=defined();var registers::Set written=defined();
    if(kind==3){return arrays::step(p,0,0,ref mut r,ref mut written,live);}
    if(kind==4){return copying::step(p,0,0,live);}
    if(kind==5){return structs::step(p,shapes,0,0,ref mut r,ref mut written,live);}
    return places::step(p,shapes,0,0,ref r,live);
}
fn void same(ref ir::Program p,u8 kind,usize live){
    let records::Prepared shapes=switch(records::prepare(ref p.records)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    let layouts::Plan plan=switch(layouts::plan(ref p.records.layouts,18446744073709551615)){case .ok(v):{v}case .err(_):{assert(false);return;}};
    switch(synchronous(p,ref shapes,kind,live)){
        case .ok(expected):{switch(staged(p,ref shapes,ref plan,kind,live)){case .ok(actual):{assert(actual==expected);}case .err(_):{assert(false);}};}
        case .err(expected):{switch(staged(p,ref shapes,ref plan,kind,live)){case .ok(_):{assert(false);}case .err(actual):{assert(actual.kind==expected.kind && actual.offset==expected.offset);}};}
    };
}
@test fn void array_lists_and_aggregate_list_replacement_match_raw(){
    var ir::Program p=array();same(ref p,3,0);p.code[0]=81;same(ref p,3,1);
    p.code[0]=87;p.code[4]=3;p.code[5]=1;same(ref p,6,1);
    p.list_operands[64]=127;same(ref p,6,0);same(ref p,3,0);
    p=array();p.code[0]=87;p.code[4]=3;p.code[3]=0;same(ref p,6,1);
}
@test fn void record_copy_and_subtree_assignment_match_raw(){
    var ir::Program p=record();same(ref p,4,196608);
    p.code[0]=42;same(ref p,4,131072);
    p=record();p.code[0]=49;p.code[2]=1;p.code[3]=0;same(ref p,5,65536);
    p.code[2]=0;same(ref p,5,65536);p.code[3]=2;same(ref p,5,65536);
}
@test fn void record_aggregate_select_store_and_replace_match_raw(){
    var ir::Program p=record();p.code[0]=83;p.code[2]=0;p.code[3]=0;p.code[4]=4;p.count=2;p.ends[0]=2;same(ref p,6,65536);
    p=record();p.code[0]=85;p.code[4]=4;p.code[3]=1;p.code[2]=0;same(ref p,6,196608);
    p=record();p.code[0]=87;p.code[4]=4;p.code[2]=0;p.code[3]=1;same(ref p,6,65536);
    p.code[3]=0;same(ref p,6,65536);
}
