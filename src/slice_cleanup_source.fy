module slice_cleanup_source;
import ir as ir;
import errors as errors;
import slice_reborrow_ir as reborrow;

// Source sites are unique. Recover the parent from emitted BEGIN, keeping
// recursive lexical snapshots unchanged; the verifier independently proves it.
pub fn Result<usize,errors::Error> close(ref mut ir::Program p,usize site,usize offset){
    var usize pc=0;
    while(pc<p.count && pc<256){
        if(p.code[pc*8]==61 && p.code[pc*8+1] as usize==site){
            let usize parent=p.code[pc*8+2] as usize;
            return reborrow::end(p,site,parent,offset);
        }
        pc+=1;
    }
    return ir::slice_close(p,site,offset);
}
