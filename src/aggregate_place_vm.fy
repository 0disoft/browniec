module aggregate_place_vm;
import ir as ir;
import aggregate_place_ir as proof;
import aggregate_places as places;
import place_ir as graph;
import array_layout as arrays;
import array_owners as owners;
import array_vm as failures;
import array_list_ir as lists;
import struct_meta as records;
import struct_range as ranges;
import errors as errors;
import runtime_clock as clock;
import metadata_budget as budget;
import fuel as meter;
import std::vec as vec;
import std::bytes as bytes;

// Invocation-owned vector, bound by the trusted coordinator to one immutable
// Program and one table/backing lifetime. Tickets are monotonic WITHIN this
// vector, including frame reuse/abort, not global identities or owner pins.
// As with legacy native adapters, callers must never import/transplant rows.
pub struct Requirement { usize width; usize cost; }
fn errors::Error invalid(usize at){return errors::make(5,at);}
pub fn Result<Requirement,errors::Error> requirement(ref ir::Program p){
    return requirement_until(p,0);
}
pub fn Result<Requirement,errors::Error> requirement_until(ref ir::Program p,usize deadline){
    var usize fuel=budget::unlimited();
    return requirement_with_compile_fuel(p,deadline,ref mut fuel);
}
pub fn Result<Requirement,errors::Error> requirement_with_compile_fuel(ref ir::Program p,usize deadline,ref mut usize fuel){
    if(p.count>256){return .err(invalid(0));}
    var usize width=0;var bool aggregate=false;var usize pc=0;
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    discard budget::charge(fuel,p.count,0)?;
    while(pc<p.count){
        if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
        let usize at=pc*8;let u8 op=p.code[at];
        if(graph::operation(op)){
            let u8 kind=p.code[at+4];let usize id=p.code[at+if(op==84){2}else{1}] as usize;
            if(id>=16 || kind>4 || (op==84 && kind>=3) || (op==87 && kind<3)){
                return .err(invalid(pc));
            }
            if(op==86 && (p.code[at+2]!=0 || p.code[at+3]!=0 || kind!=0 ||
                p.code[at+5]!=0 || p.code[at+6]!=0 || p.code[at+7]!=0)){return .err(invalid(pc));}
            if(kind>=3){aggregate=true;}if(width<=id){width=id+1;}
        }pc+=1;
    }
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    let usize selected=if(aggregate){width}else{0};
    return .ok(Requirement{.width=selected,.cost=meter::aggregate_place_prepare(selected)});
}
// Validate the bounded plan before arithmetic/allocation; Fuel is checked before
// reserve/initialization. The coordinator debits cost once after successful setup.
pub fn Result<vec::Vec<usize>,errors::Error> prepare_metered(ref Requirement plan,usize fuel){
    if(plan.width>16 || plan.cost!=meter::aggregate_place_prepare(plan.width)){return .err(invalid(0));}
    if(fuel<plan.cost){return .err(errors::make(8,0));}
    var vec::Vec<usize> words=vec::empty<usize>();
    if(plan.width!=0){let usize count=3+32*(18*plan.width+1);
        let usize reserved=switch(vec::reserve<usize>(ref mut words,count)){
            case .ok(n):{n}case .err(_):{return .err(errors::make(15,0));}
        };
        var usize i=0;while(i<count){let usize pushed=switch(vec::push<usize>(ref mut words,0)){
            case .ok(n):{n}case .err(_):{return .err(errors::make(15,0));}
        };i+=1;}
        let ref mut usize[] data=vec::view_mut_usize(ref mut words);
        data[0]=22528+plan.width;data[1]=18;data[2]=1;
    }
    return .ok(words);
}
// Diagnostic view of invocation metadata. Its authenticated format length
// is 3 modulo32, disjoint from all three legacy vector formats (0,1,2 modulo32).
pub fn ref usize[] inspect(ref vec::Vec<usize> state){return vec::view_usize(state);}
fn Result<usize,errors::Error> width(ref vec::Vec<usize> state,usize at){
    let ref usize[] words=inspect(state);if(words.len==0){return .ok(0);}
    if(words.len<611 || words.len>9251 || words.len%32!=3 || ((words.len-3)/32-1)%18!=0){return .err(invalid(at));}
    let usize n=((words.len-3)/32-1)/18;
    if(words[0]!=22528+n || words[1]!=18 || words[2]==0){return .err(invalid(at));}return .ok(n);
}
pub fn Result<usize,errors::Error> empty_frame(ref vec::Vec<usize> state,usize frame,usize at){
    let usize n=width(state,at)?;if(frame>=32){return .err(invalid(at));}
    if(n!=0 && inspect(state)[3+frame*(18*n+1)]!=0){return .err(invalid(at));}return .ok(frame);
}
// Setup prepays bounded destruction. This touches no guest owner/backing and
// needs no remaining Fuel. Preserve the serial so abort never revives a ticket.
pub fn void abort(ref mut vec::Vec<usize> state){
    let ref mut usize[] words=vec::view_mut_usize(state);
    var usize i=3;while(i<words.len){words[i]=0;i+=1;}
}
// Fixed record prices need no catalog plan before prepayment. Array metadata
// arithmetic is bounded by scalar(); no payload, owner or binding is inspected.
pub fn Result<usize,errors::Error> cost(ref ir::Program p,usize pc,usize function){
    if(p.count>256 || pc>=p.count || p.function_count>16 || function>=p.function_count ||
        pc<p.starts[function] || pc>=p.ends[function]){return .err(invalid(pc));}
    let usize at=pc*8;let u8 op=p.code[at];let u8 kind=p.code[at+4];
    if(op==86){
        if(p.code[at+1]>=16 || p.code[at+2]!=0 || p.code[at+3]!=0 || kind!=0 ||
            p.code[at+5]!=0 || p.code[at+6]!=0 || p.code[at+7]!=0){return .err(invalid(pc));}
        return switch(meter::aggregate_place_instruction(op,false,0,0,false,false)){
            case .some(price):{.ok(price)}case .none:{.err(invalid(pc))}
        };
    }
    if((op!=83 && op!=85 && op!=87) || (kind!=3 && kind!=4) || p.code[at+1]>=16){return .err(invalid(pc));}
    let usize checked=encoding(p,pc)?;
    let usize root=p.code[at+2] as usize;var usize stride=0;var usize length=0;var bool boolean=false;
    if(kind==3){
        if(p.arrays.count>16 || root>=p.arrays.count || !p.arrays.mutable[root] ||
            p.array_functions[root] as usize!=function){return .err(invalid(pc));}
        let arrays::Array shape=switch(arrays::scalar(p.arrays.elements[root],p.arrays.lengths[root])){
            case .ok(v):{v}case .err(_):{return .err(invalid(pc));}
        };stride=shape.stride;length=shape.length;boolean=shape.element==2;
    }else if(p.records.count>16 || root>=p.records.count || !p.records.mutable[root] ||
        p.record_functions[root] as usize!=function){return .err(invalid(pc));}
    return switch(meter::aggregate_place_instruction(op,kind==4,stride,length,boolean,p.code[at+5]==1)){
        case .some(price):{.ok(price)}case .none:{.err(invalid(pc))}
    };
}
// Canonical admission has already proved scalar definitions, dense operands,
// exact nominal paths and owner/loan CFGs. Recheck the bounded dialect here;
// do not repeat catalog plans or O(length) proof scans at every execution.
fn Result<usize,errors::Error> encoding(ref ir::Program p,usize pc){
    let usize at=pc*8;let u8 op=p.code[at];let u8 kind=p.code[at+4];let usize input=p.code[at+3] as usize;
    if(kind==3){
        if(op==83 && input!=0){return .err(invalid(pc));}
        if(op!=87 && (p.code[at+5]!=0 || p.code[at+6]!=0 || p.code[at+7]!=0)){return .err(invalid(pc));}
        if(op==87 && (p.code[at+5]>1 || p.code[at+7]!=0 || (p.code[at+5]==0 && p.code[at+6]!=0))){return .err(invalid(pc));}
        if(op==85 && (input>=16 || input>=p.arrays.count)){return .err(invalid(pc));}
    }else{
        let usize nominal=if(op==83){input}else{p.code[at+6] as usize};
        if(p.records.layouts.count>32 || nominal>=p.records.layouts.count || p.code[at+5]>=128 ||
            (op==83 && (p.code[at+6]!=0 || p.code[at+7]!=0)) ||
            (op==85 && (input>=16 || input>=p.records.count || p.code[at+7]>=128)) ||
            (op==87 && p.code[at+7]!=0)){return .err(invalid(pc));}
    }
    return .ok(input);
}
fn places::Place decode(ref usize[] words,usize base){
    // Element is derived from the authenticated kind/catalog by the caller.
    return places::Place{.root=owners::Token{.slot=words[base],.generation=words[base+1]},
        .element=0,.length=words[base+3],.record=words[base+4],.nominal=words[base+5],
        .ordinal=words[base+6],.alignment=words[base+7],.mark=words[base+8],.base=words[base+9],
        .end=words[base+10],.offset=words[base+11],.size=words[base+12]};
}
// Trusted resumable repeated-array replacement. Authenticate the exact SELECT
// snapshot without reading/writing payload or consuming its ticket. The owning
// dispatcher freezes this row/Program/frame through the final chunk.
pub fn Result<places::Place,errors::Error> fill_selection(ref ir::Program p,usize pc,usize function,usize frame,
    ref vec::Vec<usize> state,ref owners::Table table,usize capacity){
    if(pc>=p.count || pc>=256 || p.code[pc*8]!=87 || p.code[pc*8+5]!=0){return .err(invalid(0));}
    return array_selection(p,pc,function,frame,state,table,capacity);
}
// Shared SELECT authentication for repeated/list replacement and array stores.
pub fn Result<places::Place,errors::Error> array_selection(ref ir::Program p,usize pc,usize function,usize frame,
    ref vec::Vec<usize> state,ref owners::Table table,usize capacity){
    let usize price=cost(p,pc,function)?;let usize at=pc*8;let usize offset=p.offsets[pc];
    if((p.code[at]!=87 && p.code[at]!=85) || p.code[at+4]!=3 ||
        (p.code[at]==85 && p.code[at+5]!=0) || p.code[at+5]>1){return .err(invalid(offset));}
    let usize n=width(state,offset)?;let usize id=p.code[at+1] as usize;
    if(frame>=32 || id>=n){return .err(invalid(offset));}
    let usize header=3+frame*(18*n+1);let usize base=header+1+18*id;
    let ref usize[] before=inspect(state);let usize root=p.code[at+2] as usize;
    if(before[header]==0 || before[header]>n || before[base+17]!=1 || before[base+13]!=root ||
        before[base+15]!=3 || before[base+16]==0 || before[base+16]>=before[2] ||
        !proof::same_selection(p,before[base+14],pc)){return .err(invalid(offset));}
    var places::Place selected=decode(before,base);selected.element=p.arrays.elements[root];
    if(before[base+2]!=selected.element as usize || selected.length!=p.arrays.lengths[root] ||
        selected.record!=0 || selected.nominal!=0 || selected.ordinal!=0){return .err(invalid(offset));}
    let usize checked=switch(places::validate_array(table,ref selected,capacity)){
        case .ok(v):{v}case .err(e):{return .err(failures::failure(e,offset));}
    };
    return .ok(selected);
}
pub fn Result<usize,errors::Error> finish_fill(ref ir::Program p,usize pc,usize function,usize frame,
    ref mut vec::Vec<usize> state,ref owners::Table table,usize capacity){
    let places::Place checked=array_selection(p,pc,function,frame,state,table,capacity)?;
    let usize n=width(state,p.offsets[pc])?;let usize id=p.code[pc*8+1] as usize;
    let ref mut usize[] words=vec::view_mut_usize(state);words[4+frame*(18*n+1)+18*id+17]=3;
    return .ok(checked.size);
}
// Authenticate the original nominal root/subtree selected before the RHS. The
// record recipe keeps this row unconsumed through staging and partial writes.
pub fn Result<places::Place,errors::Error> record_selection(ref ir::Program p,usize pc,usize function,usize frame,
    ref vec::Vec<usize> state,ref owners::Table table,usize capacity){
    let usize price=cost(p,pc,function)?;let usize at=pc*8;let usize offset=p.offsets[pc];
    if((p.code[at]!=85 && p.code[at]!=87) || p.code[at+4]!=4){return .err(invalid(offset));}
    let usize n=width(state,offset)?;let usize id=p.code[at+1] as usize;
    if(frame>=32 || id>=n){return .err(invalid(offset));}
    let usize header=3+frame*(18*n+1);let usize base=header+1+18*id;let usize root=p.code[at+2] as usize;
    let ref usize[] before=inspect(state);
    if(before[header]==0 || before[header]>n || before[base+17]!=1 || before[base+13]!=root ||
        before[base+15]!=4 || before[base+16]==0 || before[base+16]>=before[2] ||
        !proof::same_selection(p,before[base+14],pc)){return .err(invalid(offset));}
    let places::Place saved=decode(before,base);
    if(before[base+2]!=0 || saved.record!=p.records.records[root] as usize ||
        saved.nominal!=p.code[at+6] as usize || saved.ordinal!=p.code[at+5] as usize){return .err(invalid(offset));}
    let usize checked=switch(places::validate_record(ref p.records.layouts,table,ref saved,capacity)){
        case .ok(v):{v}case .err(e):{return .err(failures::failure(e,offset));}
    };
    return .ok(saved);
}
pub fn Result<usize,errors::Error> finish_record(ref ir::Program p,usize pc,usize function,usize frame,
    ref mut vec::Vec<usize> state,ref owners::Table table,usize capacity){
    let places::Place checked=record_selection(p,pc,function,frame,state,table,capacity)?;
    let usize n=width(state,p.offsets[pc])?;let usize id=p.code[pc*8+1] as usize;
    let ref mut usize[] words=vec::view_mut_usize(state);words[4+frame*(18*n+1)+18*id+17]=3;
    return .ok(checked.size);
}
// Native-only coordinator entry. It must independently admit ONE immutable
// Program/catalog and bind ONE table/backing lifetime to this vector. Current
// destination is read only on SELECT; source comes from the canonical frame map.
// Ordinary/image/returned-reference admission continues to reject these kinds.
pub fn Result<usize,errors::Error> step(ref ir::Program p,ref records::Prepared shapes,
    usize pc,usize function,usize frame,ref mut vec::Vec<usize> state,ref owners::Table table,
    owners::Token current,owners::Token source,ref mut u8[] data,ref i64[] registers,
    ref mut vec::Vec<i64> cells,ref mut bytes::Buffer scratch,usize fuel){
    let usize price=cost(p,pc,function)?;
    if(fuel<price){return .err(errors::make(8,p.offsets[pc]));}
    if(p.code[pc*8+4]==4){let usize root=p.code[pc*8+2] as usize;
        if(shapes.leaves[root]==0 || shapes.leaves[root]>128){return .err(invalid(p.offsets[pc]));}
    }
    return bound(p,pc,function,frame,state,table,current,source,data,registers,cells,scratch,fuel);
}
// Executable coordinators already hold complete immutable IR/catalog proof.
// Native owner transactions replan/revalidate actual layouts after prepayment;
// no Prepared copy or redundant catalog planning is needed per instruction.
pub fn Result<usize,errors::Error> bound(ref ir::Program p,usize pc,usize function,usize frame,
    ref mut vec::Vec<usize> state,ref owners::Table table,owners::Token current,owners::Token source,
    ref mut u8[] data,ref i64[] registers,ref mut vec::Vec<i64> cells,ref mut bytes::Buffer scratch,usize fuel){
    let usize price=cost(p,pc,function)?;let usize at=pc*8;let usize offset=p.offsets[pc];
    if(fuel<price){return .err(errors::make(8,offset));}
    let usize n=width(state,offset)?;let usize id=p.code[at+1] as usize;
    if(frame>=32 || id>=n){return .err(invalid(offset));}
    let usize header=3+frame*(18*n+1);let usize base=header+1+18*id;let u8 op=p.code[at];
    let ref usize[] before=inspect(state);let usize active=before[header];let usize phase=before[base+17];
    if(active>n || phase>3 || phase==2){return .err(invalid(offset));}
    if(op==86){
        let usize origin=before[base+14];let usize mode=before[base+15];
        if(active==0 || phase==0 || before[base+16]==0 || before[base+16]>=before[2] ||
            (mode!=3 && mode!=4) || origin<p.starts[function] || origin>=p.ends[function] ||
            origin>=p.count || p.code[origin*8]!=83 || p.code[origin*8+1] as usize!=id ||
            p.code[origin*8+4] as usize!=mode || p.code[origin*8+2] as usize!=before[base+13]){return .err(invalid(offset));}
        let ref mut usize[] words=vec::view_mut_usize(state);
        var usize i=0;while(i<18){words[base+i]=0;i+=1;}words[header]=active-1;return .ok(fuel-price);
    }
    let usize root=p.code[at+2] as usize;let u8 kind=p.code[at+4];
    if(op==83){
        if(active>=n || phase!=0 || before[2]==18446744073709551615){return .err(invalid(offset));}
        var usize i=0;while(i<18){if(before[base+i]!=0){return .err(invalid(offset));}i+=1;}
        let places::Place selected=switch(if(kind==3){places::select_array(table,current,data.len)}else{
            places::select_record(ref p.records.layouts,table,current,p.code[at+3] as usize,p.code[at+5] as usize,data.len)}){
            case .ok(v):{v}case .err(e):{return .err(failures::failure(e,offset));}
        };
        if(if(kind==3){selected.element!=p.arrays.elements[root] || selected.length!=p.arrays.lengths[root]}
            else{selected.record!=p.records.records[root] as usize}){return .err(invalid(offset));}
        let ref mut usize[] words=vec::view_mut_usize(state);
        words[base]=selected.root.slot;words[base+1]=selected.root.generation;words[base+2]=selected.element as usize;
        words[base+3]=selected.length;words[base+4]=selected.record;words[base+5]=selected.nominal;
        words[base+6]=selected.ordinal;words[base+7]=selected.alignment;words[base+8]=selected.mark;
        words[base+9]=selected.base;words[base+10]=selected.end;words[base+11]=selected.offset;words[base+12]=selected.size;
        words[base+13]=root;words[base+14]=pc;words[base+15]=kind as usize;
        words[base+16]=words[2];words[2]+=1;words[base+17]=1;words[header]=active+1;
        return .ok(fuel-price);
    }
    if(active==0 || phase!=1 || before[base+13]!=root || before[base+15]!=kind as usize ||
        before[base+16]==0 || before[base+16]>=before[2] || !proof::same_selection(p,before[base+14],pc)){
        return .err(invalid(offset));
    }
    var places::Place selected=decode(before,base);
    if(kind==3){
        selected.element=p.arrays.elements[root];
        if(before[base+2]!=selected.element as usize || selected.length!=p.arrays.lengths[root] ||
            selected.record!=0 || selected.nominal!=0 || selected.ordinal!=0){return .err(invalid(offset));}
    }else if(before[base+2]!=0 || selected.record!=p.records.records[root] as usize ||
        selected.nominal!=p.code[at+6] as usize || selected.ordinal!=p.code[at+5] as usize){return .err(invalid(offset));}
    let usize written=publish(p,pc,ref selected,table,source,data,registers,cells,scratch)?;
    let ref mut usize[] words=vec::view_mut_usize(state);words[base+17]=3;
    return .ok(fuel-price);
}
fn Result<usize,errors::Error> publish(ref ir::Program p,usize pc,ref places::Place selected,
    ref owners::Table table,owners::Token source,ref mut u8[] data,ref i64[] registers,
    ref mut vec::Vec<i64> cells,ref mut bytes::Buffer scratch){
    let usize at=pc*8;let usize offset=p.offsets[pc];let usize input=p.code[at+3] as usize;
    if(p.code[at]==85){return switch(if(p.code[at+4]==3){places::store_array(table,selected,source,data)}else{
        places::store_record(ref p.records.layouts,table,selected,source,p.code[at+7] as usize,data)}){
        case .ok(v):{.ok(v)}case .err(e):{.err(failures::failure(e,offset))}
    };}
    if(p.code[at+4]==3 && p.code[at+5]==0){
        if(input>=registers.len){return .err(invalid(offset));}
        return switch(places::fill_array(table,selected,registers[input],data)){
            case .ok(v):{.ok(v)}case .err(e):{.err(failures::failure(e,offset))}
        };
    }
    if(p.code[at+4]==4){
        let usize count=ranges::leaves(ref p.records.layouts,selected.nominal)?;
        if(input>registers.len || count>registers.len-input){return .err(invalid(offset));}
        return switch(places::replace_record(ref p.records.layouts,table,selected,registers[input..input+count],data)){
            case .ok(v):{.ok(v)}case .err(e):{.err(failures::failure(e,offset))}
        };
    }
    let usize start=lists::start(p,pc);let usize count=selected.length;
    if(p.list_used>4096 || start>p.list_used || count>p.list_used-start ||
        vec::len<i64>(cells)<count || bytes::len(scratch)<selected.size){return .err(invalid(offset));}
    // One gathering pass, as in the legacy list adapter. Scratch may change on
    // failure; destination publication still follows complete codec staging.
    let ref mut i64[] values=vec::view_mut_i64(cells);var usize i=0;
    while(i<count){let usize r=p.list_operands[start+i] as usize;
        if(r>=registers.len){return .err(invalid(offset));}values[i]=registers[r];i+=1;}
    return switch(places::replace_array(table,selected,values[..count],bytes::view_mut(scratch),data)){
        case .ok(v):{.ok(v)}case .err(e):{.err(failures::failure(e,offset))}
    };
}
