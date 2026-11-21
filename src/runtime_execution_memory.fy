module runtime_execution_memory;
import ir as ir;
import errors as errors;
import array_list_vm as lists;
import place_dispatch as places;

// SDK-requested heap payload for the pinned private Windows x64 runtime:
// word/i64 = 8, input Cell = 24, Published = 72. Inline/native-stack state,
// retained Programs/input and preallocated Engine control are counted elsewhere.
pub struct Plan { usize scratch; usize output; usize peak; }
fn errors::Error invalid(){return errors::make(5,0);}
fn Result<usize,errors::Error> add(usize a,usize b){
    if(b>18446744073709551615-a){return .err(invalid());}return .ok(a+b);
}
fn Result<usize,errors::Error> multiply(usize a,usize b){
    if(a!=0 && b>18446744073709551615/a){return .err(invalid());}return .ok(a*b);
}
// Fresh SDK Vec capacity starts at eight and doubles. No allocation or Fuel.
fn Result<usize,errors::Error> vector_bytes(usize length){
    if(length==0){return .ok(0);}
    var usize capacity=8;
    while(capacity<length){capacity=multiply(capacity,2)?;}
    return multiply(capacity,8);
}
fn Result<usize,errors::Error> place_bytes(ref places::Requirement plan){
    if(plan.width>16 || (plan.width==0 && (plan.aggregate || plan.slices || plan.records)) ||
        (plan.aggregate && (plan.slices || plan.records))){return .err(invalid());}
    if(plan.width==0){return .ok(0);}
    let usize row=if(plan.aggregate){18}else if(plan.slices || plan.records){14}else{9};
    let usize prefix=if(plan.aggregate){3}else if(plan.records){2}else if(plan.slices){1}else{0};
    let usize frame=add(multiply(row,plan.width)?,1)?;
    return vector_bytes(add(multiply(32,frame)?,prefix)?);
}
// Exact simultaneous reservation once setup reaches dispatch, not a claim that
// every failure allocates the full peak. Independent execution proof remains
// mandatory. The ordinary legacy default uses the same 65536-byte arena; custom
// run_with_array_limit and separately admitted typed-value execution are excluded.
pub fn Result<Plan,errors::Error> prepare(ref ir::Program body,bool input,bool output,usize output_limit){
    return prepare_until(body,input,output,output_limit,0);
}
pub fn Result<Plan,errors::Error> prepare_until(ref ir::Program body,bool input,bool output,usize output_limit,usize deadline){
    if(output_limit>1048576 || (!output && output_limit!=0) || body.count>256 ||
        body.arrays.count>16 || body.records.count>16 || body.list_used>4096){return .err(invalid());}
    // Keep original requirement errors, including their instruction offsets.
    let lists::Requirement list=lists::requirement_until(body,deadline)?;
    let places::Requirement place=places::requirement_until(body,deadline)?;
    if(list.length>4096 || list.bytes>32768 || (list.length==0)!=(list.bytes==0)){
        return .err(invalid());
    }
    var usize scratch=if(body.arrays.count!=0 || body.records.count!=0){65536}else{0};
    scratch=add(scratch,vector_bytes(list.length)?)?;
    scratch=add(scratch,list.bytes)?;
    scratch=add(scratch,place_bytes(ref place)?)?;
    // Input ABI always prepares Vec<Cell>: 768 initialized, capacity 1024.
    if(input){scratch=add(scratch,24576)?;}
    // Published Vec capacity 8 * 72 and fixed Transaction header 40. Reserved
    // payload is output_limit even for zero emits; seal moves it without a copy.
    let usize output_bytes=if(output){add(616,output_limit)?}else{0};
    return .ok(Plan{.scratch=scratch,.output=output_bytes,.peak=add(scratch,output_bytes)?});
}
