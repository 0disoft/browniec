module runtime_seal_work;
import runtime_output as output;
import output_execution as execution;
import metadata_budget as budget;
import errors as errors;
import std::vec as vec;

// One owning terminal stage; no retained cursor or output-sized scan. The
// parent pins this transaction and its EMPTY, preallocated publication slot.
// A nonfresh dispatch defers before sampling Fuel or touching either owner.
// seal_metered moves the reserved Buffer and updates its fixed-size header;
// capacity authentication below makes the final Vec push allocation-free.
pub fn Result<bool,errors::Error> advance(ref mut output::Transaction transaction,
    ref mut vec::Vec<output::Published> published,ref mut usize remaining,
    ref mut budget::State allowance){
    if(allowance.last!=0){return .ok(false);}
    if(!budget::admit(allowance,4096,0)?){return .ok(false);}
    if(vec::len<output::Published>(published)!=0 || vec::capacity<output::Published>(published)==0){
        return .err(errors::make(5,0));
    }
    // Preserve raw errors and sampling: a fully admitted low-Fuel seal may
    // refresh the open observation's Fuel without publishing or debiting it.
    let output::Published sealed=switch(output::seal_metered(transaction,remaining)){
        case .ok(value):{value}case .err(e):{return .err(execution::failure(e,0));}
    };
    // Sole-owner, preallocated slot; every fallible check preceded sealing.
    assert(vec::push<output::Published>(published,sealed).is_ok);
    return .ok(true);
}
