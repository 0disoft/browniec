module tests::m2::destination_record_lowering;
import destination_record_work as work;
import record_place_ir as scalar;
import aggregate_place_ir as aggregate;
import ir as ir;
import errors as errors;
import metadata_budget as budget;
fn ir::Program fixture(){var ir::Program p=ir::empty();p.function_count=1;
    p.records.layouts.count=2;p.records.layouts.fields[0]=2;p.records.layouts.types[0]=2;
    p.records.layouts.kinds[1]=1;p.records.layouts.types[1]=1;
    p.records.layouts.fields[1]=2;p.records.layouts.types[16]=2;p.records.layouts.types[17]=1;
    p.records.count=1;p.records.mutable[0]=true;return p;}
fn void same(ref ir::Program a,ref ir::Program b){assert(a.count==b.count && a.registers==b.registers);
    var usize i=0;while(i<2048){assert(a.code[i]==b.code[i]);i+=1;}i=0;
    while(i<256){assert(a.offsets[i]==b.offsets[i]);i+=1;}i=0;
    while(i<128){assert(a.types[i]==b.types[i] && a.slots[i]==b.slots[i]);i+=1;}}
fn void result(Result<usize,errors::Error> x,Result<usize,errors::Error> y){switch(x){
    case .ok(a):{assert(switch(y){case .ok(b):{a==b}case .err(_):{false}});}
    case .err(a):{assert(switch(y){case .ok(_):{false}case .err(b):{a.kind==b.kind && a.offset==b.offset}});}};}
fn void compare(ir::Program p,u8 kind,usize place,usize root,usize nominal,usize ordinal){var ir::Program a=p;var ir::Program b=p;
    let Result<usize,errors::Error> x=if(kind==2){scalar::select_raw(ref mut a,place,root,ordinal,73)}else{aggregate::select_record_raw(ref mut a,place,root,nominal,ordinal,73)};
    let Result<usize,errors::Error> y=if(kind==2){scalar::select(ref mut b,place,root,ordinal,73)}else{aggregate::select_record(ref mut b,place,root,nominal,ordinal,73)};
    result(x,y);same(ref a,ref b);}
@test fn void scalar_and_nominal_destinations_keep_raw_errors_and_select_bytes(){
    var u8 kind=2;while(kind<=4){if(kind!=3){var usize mode=0;while(mode<12){var ir::Program p=fixture();
        var usize root=0;var usize nominal=1;var usize ordinal=1;var usize place=0;
        if(mode==1){root=16;}if(mode==2){p.records.mutable[0]=false;}if(mode==3){ordinal=128;}
        if(mode==4){p.records.layouts.types[31]=1;}if(mode==5){p.records.layouts.kinds[16]=1;p.records.layouts.types[16]=0;}
        if(mode==6){place=16;}if(mode==7){p.count=256;}if(mode==8){p.function_count=0;}
        if(mode==9){p.records.count=17;}if(mode==10){nominal=0;}if(mode==11){p.records.records[15]=1;}
        compare(p,kind,place,root,nominal,ordinal);mode+=1;}}kind+=1;}
}
@test fn void destination_metadata_yields_without_publishing_or_replaying(){
    let ir::Program p=fixture();var u8 kind=2;while(kind<=4){if(kind!=3){
        var work::State w=work::begin(kind,0,1,1,73);var budget::State meter=budget::empty();var usize turns=0;
        assert(!work::prepared(ref w).is_ok);
        while(!w.done){assert(turns<1000);let u8 phase=w.phase;let usize visits=w.visits;
            assert(budget::reset(ref mut meter,73).is_ok && budget::admit(ref mut meter,1,73).is_ok);let usize total=meter.total;
            assert(work::advance(ref p,ref mut w,ref mut meter).is_ok && w.phase==phase && w.visits==visits && meter.total==total);
            assert(budget::reset(ref mut meter,73).is_ok && work::advance(ref p,ref mut w,ref mut meter).is_ok);
            if(!w.done){assert(!work::prepared(ref w).is_ok);}turns+=1;}
        assert(work::prepared(ref w).is_ok && p.count==0 && p.registers==0);
        let usize visits=w.visits;let usize total=meter.total;assert(work::advance(ref p,ref mut w,ref mut meter).is_ok && w.visits==visits && meter.total==total);
    }kind+=1;}
}
@test fn void nominal_destination_walks_keep_internal_128_leaf_metadata(){
    var ir::Program p=fixture();p.records.layouts.fields[0]=16;p.records.layouts.fields[1]=8;
    var usize i=0;while(i<16){p.records.layouts.kinds[i]=1;p.records.layouts.types[i]=1;i+=1;}
    i=16;while(i<24){p.records.layouts.types[i]=2;i+=1;}
    compare(p,2,0,0,0,127);compare(p,4,0,0,1,120);compare(p,4,0,0,1,127);
    var work::State w=work::begin(4,0,1,120,73);var budget::State meter=budget::empty();var usize turns=0;var usize maximum=0;
    while(!w.done){assert(turns<1000);let usize visits=w.copy.range.visits;
        assert(budget::reset(ref mut meter,73).is_ok && work::advance(ref p,ref mut w,ref mut meter).is_ok);
        if(w.copy.range.visits>=visits){assert(w.copy.range.visits-visits<=16);}if(w.copy.range.visits>maximum){maximum=w.copy.range.visits;}turns+=1;}
    assert(maximum>16 && p.count==0 && work::prepared(ref w).is_ok);
}

@test fn void scalar_old_value_and_store_recheck_metadata_with_raw_prefixes(){
    var u8 operation=0;while(operation<2){var usize mode=0;while(mode<11){var ir::Program a=fixture();a.registers=1;a.types[0]=2;
        var usize place=0;var usize ordinal=0;var usize value=0;
        if(mode==1){place=16;}if(mode==2){ordinal=128;}if(mode==3){a.records.layouts.types[31]=2;}
        if(mode==4){a.registers=128;}if(mode==5){a.count=256;}if(mode==6){a.records.mutable[0]=false;}
        if(mode==7){value=128;}if(mode==8){a.slots[0]=true;}if(mode==9){a.records.records[15]=1;}if(mode==10){a.function_count=0;}
        var ir::Program b=a;
        let Result<usize,errors::Error> x=if(operation==0){scalar::read_raw(ref mut a,place,0,ordinal,73)}else{scalar::store_raw(ref mut a,place,0,ordinal,value,73)};
        let Result<usize,errors::Error> y=if(operation==0){scalar::read(ref mut b,place,0,ordinal,73)}else{scalar::store(ref mut b,place,0,ordinal,value,73)};
        result(x,y);same(ref a,ref b);mode+=1;}operation+=1;}
}
