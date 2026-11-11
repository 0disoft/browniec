module source_context_check_work;
import source_context as context;
import errors as errors;
import metadata_budget as budget;
// Independent resumable mirror of context::valid, including forged analysis
// tables. Names are checked in <=64-byte chunks, not assumed to be sealed.
pub struct State { usize row; usize prior; usize cursor; usize end; usize visits;
    u8 phase; u8 resume; bool result; bool done; }
pub fn State empty(){return State{.row=0,.prior=0,.cursor=0,.end=0,.visits=0,.phase=0,.resume=0,.result=false,.done=false};}
fn bool letter(u8 ch){return (ch>=65 && ch<=90)||(ch>=97 && ch<=122)||ch==95;}
fn bool digit(u8 ch){return ch>=48 && ch<=57;}
fn usize owner(ref context::Table t,usize offset){var usize i=0;while(i<t.modules){if(offset<t.ends[i] as usize){return i;}i+=1;}return 16;}
fn Result<bool,errors::Error> reject(ref mut State w){w.result=false;w.done=true;return .ok(true);}
pub fn Result<bool,errors::Error> advance(ref u8[] source,ref context::Table t,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(!budget::admit(meter,4096,w.row)?){return .ok(false);}
    if(w.phase==0){
        if(t.modules==0||t.modules>16||t.imports>64||t.function_count>16||t.record_count>32||source.len>4096){return reject(w);}
        w.phase=1;return .ok(false);
    }
    if(w.phase==1){if(w.row==t.modules){if(w.prior!=source.len){return reject(w);}w.phase=2;w.row=0;return .ok(false);}
        let usize end=t.ends[w.row] as usize;if(end<=w.prior||end>source.len){return reject(w);}w.prior=end;w.row+=1;return .ok(false);}
    if(w.phase>=2&&w.phase<=4){let usize count=if(w.phase==2){t.imports}else if(w.phase==3){t.function_count}else{t.record_count};
        if(w.row==count){w.row=0;if(w.phase==4){w.done=true;w.result=true;return .ok(true);}w.phase+=1;return .ok(false);}
        let u32 item=if(w.phase==2){t.aliases[w.row]}else if(w.phase==3){t.functions[w.row]}else{t.records[w.row]};
        if((w.phase==2&&((item>>30)!=0||(item as usize>>26)>=t.modules))||(w.phase!=2&&(item>>27)!=0)){return reject(w);}
        let usize a=context::begin(item);let usize b=context::end(item);
        if(a>=b||b>source.len||owner(t,a)!=owner(t,b-1)||!letter(source[a])){return reject(w);}
        w.cursor=a+1;w.end=b;w.resume=w.phase;w.phase=5;return .ok(false);
    }
    if(w.phase==5){var usize stop=w.cursor+64;if(stop>w.end){stop=w.end;}
        while(w.cursor<stop){let u8 ch=source[w.cursor];w.visits+=1;if(!letter(ch)&&!digit(ch)){return reject(w);}w.cursor+=1;}
        if(w.cursor==w.end){w.row+=1;w.phase=w.resume;}return .ok(false);
    }
    return .err(errors::make(5,0));
}
