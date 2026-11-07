module return_work_execution;
import ir as ir;
import struct_work as records;
import array_vm as arrays;
import errors as errors;

// Metadata only. ARET scans bool payload, not ordinary scalar array bytes.
// SRET discards a canonical scratch snapshot: count its fixed initial clear,
// selected-size clear, scalar transfers and separate bool validation reads.
pub fn Result<usize,errors::Error> required(ref ir::Program p,usize pc){
    if(pc>=p.count || pc>=256){return .err(errors::make(5,0));}
    let u8 op=p.code[pc*8];let usize source=p.code[pc*8+2] as usize;
    if(op==39){
        if(source>=p.arrays.count || source>=16){return .err(errors::make(5,p.offsets[pc]));}
        return .ok(if(p.arrays.elements[source]==2){p.arrays.lengths[source]}else{0});
    }
    if(op==50){
        if(source>=p.records.count || source>=16){return .err(errors::make(5,p.offsets[pc]));}
        let usize nominal=p.records.records[source] as usize;
        let usize measured=switch(records::measure(ref p.records.layouts,nominal,false)){
            case .ok(n):{n}case .err(e):{return .err(arrays::failure(e,p.offsets[pc]));}
        };
        return .ok(128+measured);
    }
    return .ok(0);
}
