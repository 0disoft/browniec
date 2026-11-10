module tests::m2::output_borrowed_origins_work;
import output_borrowed_origins_work as work;
import slice_result_origins as raw;
import functions as functions;
import ir as ir;
import errors as errors;
import metadata_budget as budget;

fn ir::Program direct(){
    var ir::Program p=ir::empty();p.count=2;p.function_count=1;p.arities[0]=1;
    p.ends[0]=2;p.registers=2;p.register_ends[0]=2;p.return_types[0]=12;
    p.slice_functions[0]=1;p.slice_elements[0]=10;p.slice_origins[0]=1;p.slice_parameters[0]=1;
    p.code[0]=57;p.code[1]=1;p.code[8]=8;p.code[10]=1;p.offsets[1]=42;return p;
}
fn functions::Table signature(){var functions::Table t=functions::empty();t.count=1;t.entry=0;
    t.arities[0]=1;t.return_slice_elements[0]=10;t.begins[0]=17;return t;}
fn Result<raw::Summary,errors::Error> staged(ref ir::Program p,ref functions::Table t,ref ir::Program recipes){
    var work::State w=work::empty();let usize begun=work::begin(ref mut w,p,t,recipes)?;
    var budget::State meter=budget::empty();var usize stages=0;
    while(!w.done){assert(stages<2000);assert(budget::reset(ref mut meter,0).is_ok);
        let u8 phase=w.phase;let usize pc=w.pc;let usize visits=w.work;let usize total=meter.total;
        assert(budget::admit(ref mut meter,1,0).is_ok);
        let bool deferred=work::advance(p,t,recipes,ref mut w,ref mut meter)?;
        assert(!deferred);assert(w.phase==phase);assert(w.pc==pc);assert(w.work==visits);assert(meter.total==total+1);assert(meter.last==1);
        assert(budget::reset(ref mut meter,0).is_ok);
        let Result<bool,errors::Error> next=work::advance(p,t,recipes,ref mut w,ref mut meter);
        assert(meter.last==4096);assert(w.work-visits<=16);stages+=1;
        switch(next){case .ok(done):{assert(done==w.done);}case .err(e):{return .err(e);}};
    }
    let usize total=meter.total;assert(work::advance(p,t,recipes,ref mut w,ref mut meter).is_ok && meter.total==total);
    return .ok(w.result);
}
fn void same(ref ir::Program p,ref functions::Table t,ref ir::Program recipes){
    switch(raw::inspect_output_admitted(p,t,recipes)){
        case .ok(expected):{switch(staged(p,t,recipes)){case .ok(actual):{assert(expected.rounds==actual.rounds);
            var usize f=0;while(f<16){assert(expected.parameters[f]==actual.parameters[f]);f+=1;}}
            case .err(e):{assert(false);}};}
        case .err(expected):{switch(staged(p,t,recipes)){case .ok(_):{assert(false);}
            case .err(actual):{assert(expected.kind==actual.kind);assert(expected.offset==actual.offset);}};}
    };
}
@test fn void grounded_origins_and_source_offsets_match_raw(){
    var ir::Program p=direct();var functions::Table t=signature();
    let raw::Summary positive=switch(raw::inspect_output_admitted(ref p,ref t,ref p)){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(positive.parameters[0]==1 && positive.rounds==2);same(ref p,ref t,ref p);
    var ir::Program recipes=p;recipes.code[0]=66;same(ref p,ref t,ref recipes);
    p=direct();p.code[8]=25;same(ref p,ref t,ref p);
    p=direct();p.code[10]=0;same(ref p,ref t,ref p);
    p=direct();p.slice_origins[0]=0;same(ref p,ref t,ref p);
    p=direct();t.count=2;same(ref p,ref t,ref p);
}
@test fn void sixteen_forwarding_edges_converge_on_round_seventeen(){
    var ir::Program p=ir::empty();var functions::Table t=functions::empty();
    p.count=32;p.function_count=16;p.registers=32;p.call_count=15;t.count=16;t.entry=0;
    var usize f=0;var u8 site=0;var u8 owner=1;var u8 identity=1;var u8 actual=160;
    while(f<16){let usize pc=f*2;let usize at=pc*8;
        p.starts[f]=pc;p.ends[f]=pc+2;p.register_starts[f]=pc;p.register_ends[f]=pc+2;
        p.arities[f]=1;p.return_types[f]=12;t.arities[f]=1;t.return_slice_elements[f]=10;
        p.slice_functions[f]=owner;p.slice_elements[f]=10;p.slice_origins[f]=owner;p.slice_parameters[pc]=owner;
        p.code[at]=if(f==15){57}else{9};p.code[at+1]=identity;
        p.code[at+2]=if(f==15){site}else{owner};
        if(f!=15){p.code[at+3]=site;p.call_arities[f]=1;p.call_args[f*8]=actual;}
        p.code[at+8]=8;p.code[at+10]=identity;
        f+=1;site+=1;owner+=1;identity+=2;actual+=1;
    }
    let raw::Summary positive=switch(raw::inspect_output_admitted(ref p,ref t,ref p)){
        case .ok(v):{v}case .err(_):{assert(false);return;}};
    assert(positive.rounds==17 && positive.parameters[0]==1);same(ref p,ref t,ref p);
    p.code[30*8]=9;p.code[30*8+2]=0;p.code[30*8+3]=0;same(ref p,ref t,ref p);
}
