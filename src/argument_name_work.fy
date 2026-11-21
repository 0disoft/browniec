module argument_name_work;
import locals as locals;
import functions as functions;
import source_context as context;
import errors as errors;
import metadata_budget as budget;
// Stable first-match lookup for acquisition. One row or <=64 bytes per stage.
pub struct State { usize begin; usize end; usize row; usize spelling; usize width;
    usize compared; usize result; u8 phase; bool done; }
pub fn State begin(usize a,usize b,usize absent){return State{.begin=a,.end=b,.row=0,
    .spelling=0,.width=0,.compared=0,.result=absent,.phase=0,.done=false};}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref usize[] starts,ref usize[] ends,
    usize count,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(!budget::admit(meter,4096,w.begin)?){return .ok(false);}
    if(w.phase==0){if(w.row==count){w.done=true;return .ok(true);}let usize a=starts[w.row];let usize b=ends[w.row];
        if(b-a!=w.end-w.begin){w.row+=1;return .ok(false);}w.spelling=a;w.width=b-a;w.compared=0;w.phase=1;return .ok(false);}
    var usize stop=w.compared+64;if(stop>w.width){stop=w.width;}
    while(w.compared<stop){if(source[w.begin+w.compared]!=source[w.spelling+w.compared]){w.row+=1;w.phase=0;return .ok(false);}w.compared+=1;}
    if(w.compared==w.width){w.result=w.row;w.done=true;return .ok(true);}return .ok(false);
}
fn Result<usize,errors::Error> drain(ref u8[] source,ref usize[] starts,ref usize[] ends,usize count,
    usize a,usize b,usize absent,usize deadline,ref mut usize fuel){
    var State w=begin(a,b,absent);var budget::State meter=budget::empty();
    while(!w.done){
        discard budget::visit(fuel,deadline,a)?;
        let usize allowance=budget::reset(ref mut meter,a)?;
        let bool done=advance(source,starts,ends,count,ref mut w,ref mut meter)?;
    }
    return .ok(w.result);
}
pub fn Result<usize,errors::Error> local(ref u8[] source,ref locals::Table names,usize a,usize b){
    var usize fuel=budget::unlimited();
    return local_metered(source,names,a,b,0,ref mut fuel);
}
pub fn Result<usize,errors::Error> local_metered(ref u8[] source,ref locals::Table names,
    usize a,usize b,usize deadline,ref mut usize fuel){
    return drain(source,ref names.begins,ref names.ends,names.count,a,b,64,deadline,fuel);
}
pub fn Result<usize,errors::Error> target(ref u8[] source,ref functions::Table t,usize a,usize b){
    if(t.count>16 || a>b || b>source.len){return .ok(16);}
    if(t.context.modules!=0){let usize id=context::lookup(source,ref t.context,a,b,false);return .ok(if(id<t.count){id}else{16});}
    var usize fuel=budget::unlimited();
    return drain(source,ref t.begins,ref t.ends,t.count,a,b,16,0,ref mut fuel);
}
