module runtime_pending_memory;
import errors as errors;

// Trusted native sizes and cached IR accounting, not guest authority.
// Caller-supplied ordinary execution scratch already includes input metadata,
// payload/list/place scratch. Existing Engine control and retained Snapshot
// backing bytes are charged elsewhere. No allocation or Fuel is consumed here.
pub struct Plan { usize retained; usize peak; }

fn errors::Error invalid(){return errors::make(5,0);}
fn Result<usize,errors::Error> add(usize a,usize b){
    if(b>18446744073709551615-a){return .err(invalid());}return .ok(a+b);
}
fn Result<usize,errors::Error> multiply(usize a,usize b){
    if(a!=0 && b>18446744073709551615/a){return .err(invalid());}return .ok(a*b);
}

pub fn Result<Plan,errors::Error> prepare(usize scratch,usize output_limit,usize core_size,usize machine_size){
    if(output_limit>1048576 || core_size==0 || machine_size==0){return .err(invalid());}
    // reserve(1) starts the Machine Vec at SDK capacity eight. Core is one
    // exact byte buffer, without Vec rounding or another transient copy.
    let usize machines=multiply(8,machine_size)?;
    // Published Vec8 * 72 plus staged header40; reserved output payload is
    // separate even with zero emits. All pending storage remains live together.
    var usize retained=add(scratch,616)?;
    retained=add(retained,output_limit)?;
    retained=add(retained,core_size)?;
    retained=add(retained,machines)?;
    return .ok(Plan{.retained=retained,.peak=retained});
}
