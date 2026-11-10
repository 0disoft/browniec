module output_program_copy_work;
import static_call_ir as programs;
import ir as ir;
import errors as errors;
import metadata_budget as budget;

// Construction only. Copy every fixed bank, including unused tails, before
// normalization. Source and target are distinct; source stays immutable. No
// analysis or executable receipt is created by this byte-for-byte builder.
// Variable banks copy <=256 entries; the fixed catalog copy has 1091 entries.
pub struct State { u8 phase; usize index; bool done; }
pub fn State empty(){return State{.phase=0,.index=0,.done=false};}
pub fn Result<bool,errors::Error> advance(ref programs::Program source,ref mut programs::Program target,
    ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}
    if(!budget::admit(meter,4096,0)?){return .ok(false);}
    let ref ir::Program p=ref source.body;
    if(w.phase==0){
        target.body.count=p.count;target.body.registers=p.registers;target.body.constant_count=p.constant_count;target.body.function_count=p.function_count;target.body.entry=p.entry;target.body.call_count=p.call_count;target.body.list_used=p.list_used;
        target.body.starts=p.starts;target.body.ends=p.ends;target.body.register_starts=p.register_starts;target.body.register_ends=p.register_ends;target.body.arities=p.arities;
        target.body.call_arities=p.call_arities;target.body.return_types=p.return_types;target.body.arrays=p.arrays;target.body.array_functions=p.array_functions;target.body.record_functions=p.record_functions;
        target.body.array_results=p.array_results;target.body.record_results=p.record_results;target.body.slice_roots=p.slice_roots;target.body.slice_origins=p.slice_origins;target.body.slice_functions=p.slice_functions;target.body.slice_elements=p.slice_elements;
        target.results=source.results;target.origins=source.origins;w.phase=1;return .ok(false);
    }
    if(w.phase==1){
        var usize i=w.index;let usize stop=i+16;
        while(i<stop){target.body.constants[i]=p.constants[i];target.body.types[i]=p.types[i];target.body.slots[i]=p.slots[i];
            target.body.array_parameters[i]=p.array_parameters[i];target.body.record_parameters[i]=p.record_parameters[i];target.body.slice_parameters[i]=p.slice_parameters[i];
            target.parameters[i]=source.parameters[i];i+=1;
        }w.index=i;if(i==128){w.phase=2;w.index=0;}return .ok(false);
    }
    if(w.phase==2){target.body.records=p.records;w.phase=3;return .ok(false);}
    var usize i=w.index;let usize stop=i+256;
    if(w.phase==3){while(i<stop){target.body.code[i]=p.code[i];i+=1;}w.index=i;if(i==2048){w.phase=4;w.index=0;}return .ok(false);}
    if(w.phase==4){while(i<stop){target.body.list_operands[i]=p.list_operands[i];i+=1;}w.index=i;if(i==4096){w.phase=5;w.index=0;}return .ok(false);}
    if(w.phase==5){target.body.call_args=p.call_args;w.phase=6;return .ok(false);}
    if(w.phase==6){target.body.offsets=p.offsets;w.done=true;return .ok(true);}
    return .err(errors::make(5,0));
}
