module tests::m2::output_return_signature_work;
import output_return_signature_work as work;
import output_return_ir as raw;
import static_call_ir as images;
import metadata_budget as budget;
import ir as ir;
import errors as errors;

fn void same_signature(raw::Signature expected,raw::Signature actual){
    assert(expected.borrowed==actual.borrowed);var usize i=0;
    while(i<16){assert(expected.elements[i]==actual.elements[i]);
        assert(expected.parameters[i]==actual.parameters[i]);i+=1;}
}
fn Result<raw::Signature,errors::Error> staged(ref images::Program unit){
    var work::State state=work::empty();
    switch(work::begin(ref mut state,unit)){case .ok(_):{}case .err(e):{return .err(e);}};
    var budget::State meter=budget::empty();var usize turns=0;
    while(turns<512){
        switch(budget::reset(ref mut meter,0)){case .ok(_):{}case .err(e):{return .err(e);}};
        let usize prior=state.work;let u8 phase=state.phase;
        let Result<bool,errors::Error> next=work::advance(ref mut state,unit,ref mut meter);
        assert(meter.last==4096);
        switch(next){
            case .err(e):{assert(state.work-prior<=16);return .err(e);}
            case .ok(done):{
                assert(state.work-prior<=16 &&
                    (done || state.work>prior || phase!=state.phase));
                if(done){let usize total=meter.total;
                    switch(work::advance(ref mut state,unit,ref mut meter)){
                        case .ok(v):{assert(v && meter.total==total);}
                        case .err(_):{assert(false);}
                    };
                    return .ok(state.output);
                }
            }
        };turns+=1;
    }assert(false);return .err(errors::make(5,0));
}
fn void same(images::Program unit){
    let Result<raw::Signature,errors::Error> expected=raw::signature(ref unit);
    let Result<raw::Signature,errors::Error> actual=staged(ref unit);
    switch(expected){
        case .ok(want):{switch(actual){case .ok(got):{same_signature(want,got);}
            case .err(_):{assert(false);}}}
        case .err(want):{switch(actual){case .ok(_):{assert(false);}
            case .err(got):{assert(want.kind==got.kind && want.offset==got.offset);}}}
    };
}
fn images::Program program(usize count,usize functions,usize entry){
    var images::Program unit=images::Program{.body=ir::empty(),.parameters=[0;128],
        .results=[0;16],.origins=[0;16]};
    unit.body.count=count;unit.body.function_count=functions;unit.body.entry=entry;return unit;
}
fn void borrowed(ref mut images::Program unit,usize f,usize start,usize end,u8 origin){
    unit.body.starts[f]=start;unit.body.ends[f]=end;unit.body.return_types[f]=12;
    unit.body.arities[f]=origin as usize;unit.origins[f]=origin;
}
fn images::Program entry(){var images::Program unit=program(1,1,0);
    unit.body.starts[0]=0;unit.body.ends[0]=1;unit.body.return_types[0]=1;
    unit.body.code[0]=8;return unit;}
fn images::Program view(){var images::Program unit=program(2,2,0);
    unit.body.starts[0]=0;unit.body.ends[0]=1;unit.body.return_types[0]=1;unit.body.code[0]=8;
    borrowed(ref mut unit,1,1,2,1);unit.body.code[8]=63;unit.body.code[10]=0;
    unit.body.slice_elements[0]=138;return unit;}
fn images::Program descending_chain(){var images::Program unit=entry();unit.body.count=4;
    unit.body.function_count=4;borrowed(ref mut unit,1,1,2,1);borrowed(ref mut unit,2,2,3,2);
    borrowed(ref mut unit,3,3,4,3);unit.body.code[8]=64;unit.body.code[10]=2;
    unit.body.code[16]=64;unit.body.code[18]=3;unit.body.code[24]=63;unit.body.code[26]=0;
    unit.body.slice_elements[0]=10;return unit;}
fn images::Program cycle(bool grounded){var images::Program unit=entry();unit.body.count=3;
    unit.body.function_count=3;borrowed(ref mut unit,1,1,2,1);borrowed(ref mut unit,2,2,3,2);
    unit.body.code[8]=if(grounded){63}else{64};unit.body.code[10]=if(grounded){0}else{2};
    if(grounded){unit.body.count=4;unit.body.ends[1]=3;unit.body.code[16]=64;unit.body.code[18]=2;
        unit.body.starts[2]=3;unit.body.ends[2]=4;unit.body.code[24]=64;unit.body.code[26]=1;
        unit.body.slice_elements[0]=10;}
    else{unit.body.code[16]=64;unit.body.code[18]=1;}
    return unit;}
fn images::Program conflicts(){var images::Program unit=entry();unit.body.count=6;
    unit.body.function_count=4;borrowed(ref mut unit,1,1,2,1);borrowed(ref mut unit,2,2,3,1);
    borrowed(ref mut unit,3,3,6,1);unit.body.code[8]=64;unit.body.code[10]=2;
    unit.body.code[16]=63;unit.body.code[18]=0;unit.body.code[24]=63;unit.body.code[26]=1;
    unit.body.code[32]=64;unit.body.code[34]=2;unit.body.slice_elements[0]=1;
    unit.body.slice_elements[1]=10;return unit;}

@test fn void whole_image_scans_and_output_signature_match_raw_exactly(){
    same(entry());same(view());
    var images::Program large=program(256,2,0);large.body.starts[0]=0;large.body.ends[0]=128;
    large.body.return_types[0]=1;large.body.starts[1]=128;large.body.ends[1]=256;
    large.body.return_types[1]=1;same(large);
}
@test fn void already_grounded_borrowed_signature_uses_one_forwarding_round(){
    let images::Program unit=view();var work::State state=work::empty();
    switch(work::begin(ref mut state,ref unit)){case .ok(_):{}case .err(_):{assert(false);return;}};
    var budget::State meter=budget::empty();var usize turns=0;
    while(!state.done){
        switch(budget::reset(ref mut meter,0)){case .ok(_):{}case .err(_):{assert(false);return;}};
        switch(work::advance(ref mut state,ref unit,ref mut meter)){
            case .ok(done):{assert(done==state.done);}case .err(_):{assert(false);return;}
        };turns+=1;assert(turns<8);
    }
    assert(state.round==1 && state.phase==3 && state.output.parameters[1]==1);
    assert(state.output.elements[1]==138 && state.output.borrowed);
}
@test fn void malformed_headers_sites_tags_forwards_and_final_claims_match_raw(){
    same(program(0,0,0));same(program(257,1,0));same(program(1,17,0));same(program(1,1,1));
    var images::Program unit=view();unit.body.starts[1]=1;unit.body.ends[1]=1;same(unit);
    unit=view();unit.body.ends[1]=3;same(unit);
    unit=view();unit.body.code[10]=16;same(unit);
    unit=view();unit.body.slice_elements[0]=3;same(unit);
    unit=view();unit.body.count=3;unit.body.ends[1]=3;unit.body.code[16]=63;
    unit.body.code[18]=0;unit.body.slice_elements[0]=1;same(unit);
    same(conflicts());
    unit=descending_chain();unit.body.code[18]=4;same(unit);
    unit=view();unit.body.code[8]=64;unit.body.code[10]=0;same(unit);
    unit=view();unit.origins[1]=0;same(unit);
    unit=view();unit.origins[1]=9;same(unit);
    unit=view();unit.origins[1]=2;same(unit);
    unit=view();unit.body.arities[1]=0;same(unit);
    unit=view();unit.results[1]=1;same(unit);
    unit=view();unit.body.return_types[1]=1;same(unit);
    unit=view();borrowed(ref mut unit,0,0,1,1);unit.body.starts[1]=1;unit.body.ends[1]=2;
    unit.body.code[0]=63;unit.body.code[8]=63;unit.body.code[10]=0;same(unit);
}
@test fn void partial_room_is_an_unmodified_deferral_before_any_stage_work(){
    let images::Program unit=descending_chain();var work::State state=work::empty();
    switch(work::begin(ref mut state,ref unit)){case .ok(_):{}case .err(_):{assert(false);return;}};
    var budget::State meter=budget::empty();
    switch(budget::admit(ref mut meter,1,0)){case .ok(v):{assert(v);}case .err(_):{assert(false);return;}};
    let work::State saved=state;let budget::State prior=meter;let usize checked=state.work;
    switch(work::advance(ref mut state,ref unit,ref mut meter)){case .ok(v):{assert(!v);}case .err(_):{assert(false);}};
    assert(state.phase==saved.phase && state.function==saved.function && state.pc==saved.pc &&
        state.round==saved.round && state.changed==saved.changed && state.borrowed==saved.borrowed &&
        state.active==saved.active && state.done==saved.done && state.work==checked &&
        meter.total==prior.total && meter.last==prior.last && meter.stages==prior.stages);
    switch(budget::reset(ref mut meter,0)){case .ok(_):{}case .err(_):{assert(false);return;}};
    switch(work::advance(ref mut state,ref unit,ref mut meter)){case .ok(v):{assert(!v);}case .err(_):{assert(false);}};
    assert(meter.last==4096 && state.phase==1 && state.work==0);
    switch(budget::reset(ref mut meter,0)){case .ok(_):{}case .err(_):{assert(false);return;}};
    switch(work::advance(ref mut state,ref unit,ref mut meter)){case .ok(v):{assert(!v);}case .err(_):{assert(false);}};
    assert(meter.last==4096 && state.phase==2 && state.work==4);
    same(unit);
}
@test fn void forwarding_chains_use_bounded_rounds_and_exact_order(){
    let images::Program unit=descending_chain();same(unit);
    var work::State state=work::empty();
    switch(work::begin(ref mut state,ref unit)){case .ok(_):{}case .err(_):{assert(false);return;}};
    var budget::State meter=budget::empty();var usize turns=0;
    while(!state.done){switch(budget::reset(ref mut meter,0)){case .ok(_):{}case .err(_):{assert(false);return;}};
        let usize prior=state.work;switch(work::advance(ref mut state,ref unit,ref mut meter)){
            case .ok(_):{assert(state.work-prior<=16);}case .err(_):{assert(false);return;}
        };turns+=1;assert(turns<8);}
    assert(turns==4 && state.round==3);
    assert(state.output.elements[1]==10 && state.output.elements[2]==10 && state.output.elements[3]==10);
    assert(state.output.parameters[1]==1 && state.output.parameters[2]==2 && state.output.parameters[3]==3);
}
@test fn void grounded_and_ungrounded_cycles_match_the_raw_signature_oracle(){
    same(cycle(false));same(cycle(true));
}

@test fn void sixteen_function_chain_preserves_round_boundary_only_stages(){
    var images::Program unit=program(16,16,0);unit.body.ends[0]=1;unit.body.code[0]=8;
    var usize f=1;var u8 target=2;while(f<16){
        borrowed(ref mut unit,f,f,f+1,1);
        if(f==15){unit.body.code[f*8]=63;}else{unit.body.code[f*8]=64;unit.body.code[f*8+2]=target;target+=1;}
        f+=1;
    }unit.body.slice_elements[0]=10;same(unit);
}
