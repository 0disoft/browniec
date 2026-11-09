module runtime_setup_work;
import std::bytes as bytes;
import std::vec as vec;
import metadata_budget as budget;
import errors as errors;

// Private recipe: sizes are pinned by the owner, never guest authority.
// kind: 0 ordinary, 1 slice, 2 record, 3 aggregate.
pub struct Plan { usize core; usize payload; usize list_length; usize scratch;
    usize places; usize prefix; usize marker; u8 kind; }
pub struct State { Plan plan; usize phase; usize at; bool active; bool done; }
pub fn State empty(){return State{.plan=Plan{.core=0,.payload=0,.list_length=0,.scratch=0,
    .places=0,.prefix=0,.marker=0,.kind=0},.phase=0,.at=0,.active=false,.done=false};}
fn errors::Error invalid(){return errors::make(5,0);}
fn bool valid(ref Plan p){
    if(p.core>1048576 || p.payload>65536 || p.list_length>4096 || p.scratch>32768 ||
        p.places>9251 || p.kind>3){return false;}
    if(p.places==0){return p.kind==0 && p.prefix==0 && p.marker==0;}
    let usize prefix=if(p.kind==3){3}else if(p.kind==2){2}else if(p.kind==1){1}else{0};
    let usize row=if(p.kind==3){18}else if(p.kind==0){9}else{14};
    if(p.prefix!=prefix || p.places<prefix+32 || (p.places-prefix)%32!=0){return false;}
    let usize per=(p.places-prefix)/32;
    if(per<=1 || (per-1)%row!=0){return false;}
    let usize width=(per-1)/row;
    if(width==0 || width>16){return false;}
    let usize marker=if(p.kind==3){22528+width}else if(p.kind==2){18432+width}
        else if(p.kind==1){14336+width}else{0};
    return p.marker==marker;
}
pub fn Result<usize,errors::Error> begin(ref mut State w,Plan p){
    if(w.active || !valid(ref p)){return .err(invalid());}
    w.plan=p;w.phase=0;w.at=0;w.active=true;w.done=false;return .ok(0);
}
fn usize expected(usize phase,usize current,usize target,usize at){
    return if(phase>current){target}else if(phase==current){at}else{0};
}
fn Result<usize,errors::Error> append_zeros(ref mut bytes::Buffer target,usize count){
    let u8[1024] zero=[0;1024];
    if(!bytes::append(target,ref zero[..count]).is_ok){return .err(errors::make(15,0));}
    return .ok(count);
}
// One fresh batch performs one append/push chunk or the final prefix stores.
// Capacities are checked before any mutation, so these operations cannot grow.
pub fn Result<bool,errors::Error> advance(ref mut State w,ref mut bytes::Buffer core,
    ref mut bytes::Buffer payload,ref mut vec::Vec<i64> cells,ref mut bytes::Buffer scratch,
    ref mut vec::Vec<usize> places,ref mut budget::State allowance){
    if(allowance.last!=0){return .ok(false);}
    if(!w.active || w.done || w.phase>5 || (w.phase==5 && w.at!=0) || !valid(ref w.plan)){return .err(invalid());}
    let Plan p=w.plan;
    let usize n0=expected(w.phase,0,p.core,w.at);let usize n1=expected(w.phase,1,p.payload,w.at);
    let usize n2=expected(w.phase,2,p.list_length,w.at);let usize n3=expected(w.phase,3,p.scratch,w.at);
    let usize n4=expected(w.phase,4,p.places,w.at);
    if(n0>p.core || n1>p.payload || n2>p.list_length || n3>p.scratch || n4>p.places ||
        bytes::view(core).len!=n0 || bytes::view(payload).len!=n1 || vec::len<i64>(cells)!=n2 ||
        bytes::view(scratch).len!=n3 || vec::len<usize>(places)!=n4 ||
        bytes::capacity(core)<p.core || bytes::capacity(payload)<p.payload ||
        vec::capacity<i64>(cells)<p.list_length || bytes::capacity(scratch)<p.scratch ||
        vec::capacity<usize>(places)<p.places){return .err(invalid());}
    var usize phase=w.phase;var usize at=w.at;
    while(phase<5){let usize size=if(phase==0){p.core}else if(phase==1){p.payload}
        else if(phase==2){p.list_length}else if(phase==3){p.scratch}else{p.places};
        if(at<size){break;}phase+=1;at=0;
    }
    if(!budget::admit(allowance,4096,0)?){return .ok(false);}
    if(phase==5){
        if(p.prefix!=0){let ref mut usize[] words=vec::view_mut_usize(places);words[0]=p.marker;
            if(p.kind==2){words[1]=2;}else if(p.kind==3){words[1]=18;words[2]=1;}}
        w.phase=5;w.at=0;w.active=false;w.done=true;return .ok(true);
    }
    let usize size=if(phase==0){p.core}else if(phase==1){p.payload}
        else if(phase==2){p.list_length}else if(phase==3){p.scratch}else{p.places};
    // Leave room for SDK descriptor visits and the owning Cursor frame. These
    // are logical-entry bounds, not CPU, wall-time or peak-stack claims.
    let usize limit=if(phase==2 || phase==4){64}else{1024};
    let usize count=if(size-at<limit){size-at}else{limit};
    if(phase==0){let usize written=append_zeros(core,count)?;}
    else if(phase==1){let usize written=append_zeros(payload,count)?;}
    else if(phase==3){let usize written=append_zeros(scratch,count)?;}
    else if(phase==2){var usize i=0;while(i<count){assert(vec::push<i64>(cells,0).is_ok);i+=1;}}
    else{var usize i=0;while(i<count){assert(vec::push<usize>(places,0).is_ok);i+=1;}}
    w.phase=phase;w.at=at+count;return .ok(false);
}
