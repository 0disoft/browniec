module output_verifier_metadata_work;
import ir as ir;
import errors as errors;
import types as types;
import array_meta as arrays;
import static_ir as statics;
import struct_layout as layouts;
import output_list_metadata_work as lists;
import output_record_metadata_work as records;
import output_record_copy_work as copies;
import copy_ir as copying;
import slice_parameters as slice_parameters;
import slice_reborrow_ir as reborrows;
import array_parameters as array_parameters;
import struct_parameters as struct_parameters;
import array_results as array_results;
import struct_results as struct_results;
import metadata_budget as budget;

// Canonical output metadata, in the raw verifier's exact order. The owning
// parent pins the Program/Sites. No CFG or executable admission is published.
// Remaining scalar parameter/result passes visit <=128 registers, <=16 sites
// or <=256 PCs plus two sixteen-site scans, each in its own fresh stage.
pub struct State {
    lists::State list; records::State records; copies::State copy;
    reborrows::Sites loans; usize function; usize pc; usize code_end; usize register_end;
    u8 phase; bool input; bool done;
}
pub fn State empty(bool input){return State{.list=lists::empty(),.records=records::empty(),.copy=copies::empty(),
    .loans=reborrows::Sites{.parents=[16;16],.newer=[0;16],.count=0},
    .function=0,.pc=0,.code_end=0,.register_end=0,.phase=0,.input=input,.done=false};}
fn errors::Error invalid(usize pc){return errors::make(5,pc);}
fn Result<usize,errors::Error> owners(ref ir::Program p,ref statics::Sites sites,bool input){
    var usize id=0;while(id<16){
        if((id<p.arrays.count && p.array_functions[id] as usize>=p.function_count) ||
            (id>=p.arrays.count && p.array_functions[id]!=0) ||
            (id<p.records.count && p.record_functions[id] as usize>=p.function_count) ||
            (id>=p.records.count && p.record_functions[id]!=0) || p.slice_roots[id] as usize>p.arrays.count){return .err(invalid(0));}
        id+=1;
    }
    if(p.return_types[p.entry]!=1){return .err(invalid(0));}
    if(input){if(p.arities[p.entry]!=1 || p.register_starts[p.entry]>=128 || sites.parameters[p.register_starts[p.entry]]!=3){return .err(invalid(0));}}
    else if(p.arities[p.entry]!=0){return .err(invalid(0));}
    return .ok(0);
}
fn Result<usize,errors::Error> partition(ref ir::Program p,ref statics::Sites sites,ref mut State w){
    let usize f=w.function;
    if(f==p.function_count){
        if(w.code_end!=p.count || w.register_end!=p.registers){return .err(invalid(0));}
        w.phase=6;w.function=0;w.pc=p.starts[0];return .ok(0);
    }
    if(p.record_results[f]==0 && sites.results[f]==0 && p.return_types[f]!=13 && !types::valid(p.return_types[f])){return .err(invalid(w.code_end));}
    if(p.starts[f]!=w.code_end || p.ends[f]<=w.code_end || p.ends[f]>p.count ||
        p.register_starts[f]!=w.register_end || p.register_ends[f]<w.register_end || p.register_ends[f]>p.registers ||
        p.arities[f]>8 || p.arities[f]>p.register_ends[f]-w.register_end){return .err(invalid(w.code_end));}
    w.code_end=p.ends[f];w.register_end=p.register_ends[f];w.function+=1;return .ok(0);
}
fn Result<usize,errors::Error> copy_header(ref ir::Program p,ref mut State w){
    let usize f=w.function;let usize pc=w.pc;
    if(f==p.function_count){w.phase=8;return .ok(0);}
    if(pc==p.ends[f]){w.function+=1;if(w.function<p.function_count){w.pc=p.starts[w.function];}return .ok(0);}
    let usize at=pc*8;let u8 op=p.code[at];
    if(!copying::operation(op)){w.pc+=1;return .ok(0);}
    if(op==34 || op==38){let copying::Plan checked=copying::instruction(p,pc,f)?;w.pc+=1;return .ok(0);}
    if(p.code[at+6]!=0 || p.code[at+7]!=0 ||
        (op!=47 && (p.code[at+3]!=0 || p.code[at+4]!=0 || p.code[at+5]!=0))){return .err(invalid(pc));}
    let copies::Arguments args=copies::Arguments{.destination=p.code[at+1] as usize,.source=p.code[at+2] as usize,
        .destination_function=f,.source_function=f,.fresh=op==42,.same_frame=true,.subtree=op==47,
        .nominal=p.code[at+3] as usize,.destination_leaf=p.code[at+4] as usize,.source_leaf=p.code[at+5] as usize,.pc=pc};
    let usize started=copies::begin(ref mut w.copy,args)?;w.phase=7;return .ok(0);
}
pub fn Result<bool,errors::Error> advance(ref ir::Program p,ref statics::Sites sites,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}
    if(meter.last!=0){return .ok(false);}
    if(w.phase==1){let bool done=lists::advance(p,ref mut w.list,meter)?;if(done){w.phase=2;}return .ok(false);}
    if(w.phase==3){let bool done=records::advance(ref mut w.records,ref p.records,meter)?;if(done){w.phase=4;}return .ok(false);}
    if(w.phase==7){
        // The fixed 609-entry plan copy belongs to the child's stage framing;
        // its only variable work is <=16 nominal DFS visits, below 4096 total.
        let layouts::Plan plan=w.records.layout.plan;
        let bool done=copies::advance(p,ref plan,ref mut w.copy,meter)?;
        if(done){w.pc+=1;w.phase=6;}return .ok(false);
    }
    if(!budget::admit(meter,4096,w.pc)?){return .ok(false);}
    if(w.phase==0){
        if(p.count==0 || p.count>256 || p.registers==0 || p.registers>128 || p.constant_count>128 ||
            p.function_count==0 || p.function_count>16 || p.entry>=p.function_count || p.call_count>32){return .err(invalid(0));}
        if(!arrays::valid(ref p.arrays)){return .err(invalid(0));}w.phase=1;
    }else if(w.phase==2){let usize started=records::begin(ref mut w.records,ref p.records)?;w.phase=3;}
    else if(w.phase==4){let usize checked=owners(p,sites,w.input)?;w.phase=5;}
    else if(w.phase==5){let usize checked=partition(p,sites,w)?;}
    else if(w.phase==6){let usize checked=copy_header(p,w)?;}
    else if(w.phase==8){let usize checked=if(w.input){slice_parameters::metadata_input(p)?}else{slice_parameters::metadata(p)?};w.phase=9;}
    else if(w.phase==9){let reborrows::Sites loans=reborrows::metadata(p)?;w.loans=loans;w.phase=10;}
    else if(w.phase==10){let usize checked=array_parameters::metadata(p)?;w.phase=11;}
    else if(w.phase==11){let usize checked=struct_parameters::metadata(p)?;w.phase=12;}
    else if(w.phase==12){let usize checked=array_results::metadata(p)?;w.phase=13;}
    else if(w.phase==13){let usize checked=struct_results::metadata(p)?;w.done=true;}
    else{return .err(invalid(0));}
    return .ok(w.done);
}
