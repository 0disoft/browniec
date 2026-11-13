module tests::m2::destination_place_lowering;
import destination_place_work as work;
import destination_record_work as metadata;
import place_source as places;
import locals as locals;
import ir as ir;
import compiler as compiler;
import verifier as verifier;
import vm as vm;
import errors as errors;
import metadata_budget as budget;
fn ir::Program fixture(){var ir::Program p=ir::empty();p.function_count=1;
    p.records.layouts.count=2;p.records.layouts.fields[0]=2;p.records.layouts.types[0]=2;
    p.records.layouts.kinds[1]=1;p.records.layouts.types[1]=1;
    p.records.layouts.fields[1]=2;p.records.layouts.types[16]=2;p.records.layouts.types[17]=1;
    p.records.count=1;p.records.mutable[0]=true;
    p.arrays.count=1;p.arrays.elements[0]=1;p.arrays.lengths[0]=2;p.arrays.mutable[0]=true;
    p.registers=1;p.types[0]=12;p.slice_roots[0]=1;p.slice_elements[0]=128;return p;}
fn void same(ref ir::Program a,ref ir::Program b){assert(a.count==b.count && a.registers==b.registers);
    var usize i=0;while(i<2048){assert(a.code[i]==b.code[i]);i+=1;}i=0;
    while(i<256){assert(a.offsets[i]==b.offsets[i]);i+=1;}i=0;
    while(i<128){assert(a.types[i]==b.types[i] && a.slots[i]==b.slots[i]);i+=1;}}
fn void result(Result<usize,errors::Error> x,Result<usize,errors::Error> y){switch(x){
    case .ok(a):{assert(switch(y){case .ok(b):{a==b}case .err(_):{false}});}
    case .err(a):{assert(switch(y){case .ok(_):{false}case .err(b):{a.kind==b.kind && a.offset==b.offset}});}};}
@test fn void five_kinds_preserve_raw_ir_masks_and_error_priority(){
    var u8 kind=0;while(kind<=4){var usize mode=0;while(mode<10){
        var ir::Program a=fixture();var locals::Table x=locals::empty();x.count=64;
        var usize root=0;var usize index=if(kind==2 || kind==4){1}else{0};
        if(mode==1){x.pending_places=5;}if(mode==2){x.pending_places=65535;}if(mode==3){x.pending_places=65536;}
        if(mode==4){root=16;}if(mode==5){index=128;}if(mode==6){a.records.mutable[0]=false;a.arrays.mutable[0]=false;a.slice_elements[0]=0;}
        if(mode==7){a.count=256;}if(mode==8){a.records.layouts.types[31]=1;}
        if(mode==9){a.code[4]=99;a.code[6]=88;a.code[7]=77;}
        var ir::Program b=a;var locals::Table y=locals::snapshot(ref x);
        let Result<usize,errors::Error> old=places::select_kind_raw(ref mut a,ref mut x,root,index,73,kind,1);
        let Result<usize,errors::Error> new=if(kind==0){places::select(ref mut b,ref mut y,root,index,73)}
            else if(kind==1){places::slice(ref mut b,ref mut y,root,index,73)}
            else if(kind==2){places::record(ref mut b,ref mut y,root,index,73)}
            else if(kind==3){places::array(ref mut b,ref mut y,root,73)}else{places::record_value(ref mut b,ref mut y,root,1,index,73)};
        result(old,new);same(ref a,ref b);assert(x.pending_places==y.pending_places && x.count==y.count && y.count==64);
        mode+=1;}kind+=1;}
}
@test fn void place_protocol_keeps_metadata_explicit_and_publishes_after_select(){
    var u8 kind=0;while(kind<=4){var ir::Program p=fixture();var locals::Table names=locals::empty();names.pending_places=3;
        var work::State w=work::begin(kind,0,if(kind==2 || kind==4){1}else{0},1,73);var budget::State meter=budget::empty();
        var usize turns=0;var bool asked=false;var bool selected=false;
        assert(!work::prepared(ref w).is_ok && !work::resume(ref mut w).is_ok);
        while(!w.done){assert(turns<100);let usize visits=w.visits;let usize id=w.id;let u8 phase=w.phase;let usize count=p.count;let usize mask=names.pending_places;
            assert(budget::reset(ref mut meter,73).is_ok && budget::admit(ref mut meter,1,73).is_ok);let usize total=meter.total;
            assert(work::advance(ref mut p,ref mut names,ref mut w,ref mut meter).is_ok && w.visits==visits && w.id==id && w.phase==phase && p.count==count && names.pending_places==mask && meter.total==total);
            assert(budget::reset(ref mut meter,73).is_ok && work::advance(ref mut p,ref mut names,ref mut w,ref mut meter).is_ok && p.count-count<=1);
            if(w.request==1){asked=true;let usize saved=w.visits;
                assert(budget::reset(ref mut meter,73).is_ok && work::advance(ref mut p,ref mut names,ref mut w,ref mut meter).is_ok && meter.last==0 && w.visits==saved && p.count==0 && names.pending_places==3);
                assert(metadata::prepare(ref p,kind,0,1,1,73).is_ok);
                assert(work::resume(ref mut w).is_ok && !work::resume(ref mut w).is_ok);}
            if(p.count==1 && !w.done){selected=true;assert(names.pending_places==3 && !work::prepared(ref w).is_ok);}
            turns+=1;}
        assert(selected && asked==(kind==2 || kind==4) && names.pending_places==7 && p.count==1);
        assert(switch(work::prepared(ref w)){case .ok(id):{id==2}case .err(_):{false}});
        let usize visits=w.visits;let usize total=meter.total;
        assert(work::advance(ref mut p,ref mut names,ref mut w,ref mut meter).is_ok && w.visits==visits && p.count==1 && names.pending_places==7 && meter.total==total && !work::resume(ref mut w).is_ok);
        kind+=1;}
}
@test fn void exhausted_places_and_late_ir_failure_do_not_publish_pending_bits(){
    var usize mode=0;while(mode<2){var ir::Program p=fixture();var locals::Table names=locals::empty();
        names.pending_places=if(mode==0){65535}else{32767};if(mode==1){p.count=256;}
        let usize initial=names.pending_places;var work::State w=work::begin(4,0,1,1,73);var budget::State meter=budget::empty();
        var usize turns=0;var bool failed=false;var bool asked=false;
        while(!failed){assert(turns<100);assert(budget::reset(ref mut meter,73).is_ok);
            switch(work::advance(ref mut p,ref mut names,ref mut w,ref mut meter)){
                case .err(e):{assert(e.kind==4 && e.offset==73);failed=true;}
                case .ok(_):{if(w.request==1){asked=true;assert(metadata::prepare(ref p,4,0,1,1,73).is_ok && work::resume(ref mut w).is_ok);}}
            };turns+=1;}
        assert(asked==(mode==1) && !w.done && names.pending_places==initial && p.count==if(mode==0){0}else{256});mode+=1;}
}

fn void executes(ref u8[] source){switch(compiler::compile(source)){
    case .err(_):{assert(false);}case .ok(p):{assert(verifier::verify(ref p).is_ok);
        assert(switch(vm::run(ref p,16000000)){case .ok(value):{value==42}case .err(_):{false}});}
};}
@test fn void source_assignments_preserve_captured_targets(){
    executes(b"module main;struct C{i32 x;}struct P{C a;C b;}fn i32 main(){var i32[2] a=[1;2];var i32[2] b=[2;2];a=b;a[0]+=1;{let ref mut i32[] s=ref mut a[0..2];s[1]+=1;}var P p=P{.a=C{.x=0},.b=C{.x=39}};p.a=p.b;p.a.x+=a[0];return p.a.x;}");
    executes(b"module main;struct C{i32 x;}struct P{C a;C b;}fn C value(){return C{.x=42};}fn i32 main(){var P p=P{.a=C{.x=0},.b=C{.x=1}};p.a=value();return p.a.x;}");
}
