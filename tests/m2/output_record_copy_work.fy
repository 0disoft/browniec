module tests::m2::output_record_copy_work;
import output_record_copy_work as work;
import copy_ir as raw;
import struct_layout as layouts;
import metadata_budget as budget;
import ir as ir;
import errors as errors;

fn ir::Program program(){
    var ir::Program p=ir::empty();p.count=1;p.function_count=1;p.ends[0]=1;
    p.records.layouts.count=2;p.records.layouts.fields[0]=2;
    p.records.layouts.types[0]=10;p.records.layouts.types[1]=10;
    p.records.layouts.fields[1]=3;p.records.layouts.kinds[16]=1;p.records.layouts.kinds[17]=1;p.records.layouts.types[18]=10;
    p.records.count=2;p.records.records[0]=1;p.records.records[1]=1;p.records.mutable[0]=true;
    p.code[0]=47;p.code[2]=0;p.code[5]=2;return p;
}
fn work::Arguments arguments(ref ir::Program p){
    return work::Arguments{.destination=p.code[1] as usize,.source=p.code[2] as usize,
        .destination_function=0,.source_function=0,.fresh=p.code[0]==42,.same_frame=true,.subtree=p.code[0]==47,
        .nominal=p.code[3] as usize,.destination_leaf=p.code[4] as usize,.source_leaf=p.code[5] as usize,.pc=0};
}
fn Result<raw::Plan,errors::Error> staged(ref ir::Program p,ref layouts::Plan plan,bool defers){
    var work::State w=work::empty();let usize started=work::begin(ref mut w,arguments(p))?;
    var budget::State meter=budget::empty();var usize turns=0;
    while(!w.done){assert(turns<1024);assert(budget::reset(ref mut meter,0).is_ok);
        if(defers){let u8 phase=w.phase;let usize to=w.to;let usize from=w.from;
            assert(budget::admit(ref mut meter,1,0).is_ok);let budget::State saved=meter;
            let bool done=work::advance(p,plan,ref mut w,ref mut meter)?;
            assert(!done && w.phase==phase && w.to==to && w.from==from && !w.done);
            assert(meter.total==saved.total && meter.stages==saved.stages && meter.last==saved.last);
            assert(budget::reset(ref mut meter,0).is_ok);
        }
        let bool done=work::advance(p,plan,ref mut w,ref mut meter)?;
        assert(done==w.done && meter.last==4096);turns+=1;
    }return work::prepared(ref w);
}
fn void same(ref ir::Program p,bool defers){
    let layouts::Plan shapes=switch(layouts::plan(ref p.records.layouts,18446744073709551615)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    switch(raw::instruction(p,0,0)){
        case .ok(expected):{switch(staged(p,ref shapes,defers)){
            case .ok(actual):{
                assert(actual.destination==expected.destination && actual.source==expected.source && actual.bytes==expected.bytes &&
                    actual.destination_offset==expected.destination_offset && actual.source_offset==expected.source_offset &&
                    actual.fresh==expected.fresh && actual.same_frame==expected.same_frame);
                switch(actual.mode){case .Snapshot:{}case .Direct:{assert(false);}case .NoOp:{assert(false);}};
                let u8 want=switch(expected.relation){case .Disjoint:{0}case .Identical:{1}case .Overlap:{2}};
                let u8 got=switch(actual.relation){case .Disjoint:{0}case .Identical:{1}case .Overlap:{2}};assert(want==got);
            }case .err(_):{assert(false);}
        };}
        case .err(expected):{switch(staged(p,ref shapes,defers)){case .ok(_):{assert(false);}case .err(actual):{
            assert(actual.kind==expected.kind && actual.offset==expected.offset);
        }};}
    };
}
@test fn void subtree_and_whole_record_copy_plans_match_raw(){
    var ir::Program p=program();same(ref p,true);p.code[5]=0;same(ref p,true);
    p.code[2]=1;same(ref p,true);
    p.code[0]=42;p.code[3]=0;p.code[4]=0;p.code[5]=0;same(ref p,true);
    p.code[0]=46;same(ref p,true);
}
@test fn void wrong_nominal_ordinals_owner_domains_and_mutability_match_raw_errors(){
    var ir::Program p=program();p.code[3]=2;same(ref p,true);
    p=program();p.code[4]=1;same(ref p,true);
    p=program();p.code[5]=128;same(ref p,true);
    p=program();p.code[1]=2;same(ref p,true);
    p=program();p.record_functions[0]=1;same(ref p,true);
    p=program();p.records.mutable[0]=false;same(ref p,true);
}
@test fn void shared_deep_subtrees_suspend_inside_both_nominal_walks(){
    var ir::Program p=program();p.records.layouts=layouts::empty();p.records.layouts.count=16;
    p.records.layouts.fields[0]=1;p.records.layouts.types[0]=10;
    var usize i=1;var u8 child=0;while(i<16){
        p.records.layouts.fields[i]=if(i==14){8}else if(i==15){16}else{1};
        var usize field=0;while(field<p.records.layouts.fields[i] as usize){p.records.layouts.kinds[i*16+field]=1;p.records.layouts.types[i*16+field]=child;field+=1;}
        child+=1;i+=1;
    }
    p.records.records[0]=15;p.records.records[1]=15;p.code[4]=127;p.code[5]=0;same(ref p,true);
}
