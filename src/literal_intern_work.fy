module literal_intern_work;
import static_image as images;
import source_utf8_work as utf8;
import metadata_budget as budget;

// Intern into owner-private builder scratch only. Pin payload and all existing
// builder contents until done. Every fallible image check precedes staged tail
// writes; no caller-visible builder/image is published by this continuation.
pub struct State { utf8::State check; usize length; usize row; usize prior; usize start;
    usize cursor; usize id; usize visits; u8 phase; bool text; bool done; }
pub fn State begin(bool text){return State{.check=utf8::empty(),.length=0,.row=0,.prior=0,.start=0,
    .cursor=0,.id=16,.visits=0,.phase=0,.text=text,.done=false};}
pub fn Result<usize,images::Error> prepared(ref State w){if(!w.done){return .err(.State);}return .ok(w.id);}
pub fn Result<bool,images::Error> advance(ref mut images::Builder builder,ref u8[] payload,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    if(w.phase==3){switch(utf8::advance(payload,ref mut w.check,meter)){
            case .ok(done):{if(done){w.row=0;w.phase=4;}}
            case .err(e):{if(e.kind==1){return .err(.Utf8);}return .err(.State);}};return .ok(false);}
    let bool admitted=switch(budget::admit(meter,4096,0)){case .ok(v):{v}case .err(_):{return .err(.State);}};
    if(!admitted){return .ok(false);}
    if(w.phase==0){if(builder.limit>4096 || builder.catalog.used>builder.limit || builder.catalog.count>16 || builder.catalog.used>4096){return .err(.State);}
        w.length=payload.len;w.phase=1;return .ok(false);}
    if(w.phase==1){if(w.row==16){if(w.prior!=builder.catalog.used){return .err(.State);}w.phase=2;return .ok(false);}
        let usize i=w.row;let usize a=builder.catalog.starts[i];let usize b=builder.catalog.ends[i];
        if(i<builder.catalog.count){if(a!=w.prior || b<a || b>builder.catalog.used){return .err(.State);}w.prior=b;}
        else if(a!=0 || b!=0 || builder.catalog.text[i]){return .err(.State);}w.row+=1;return .ok(false);}
    if(w.phase==2){if(w.length>4096){return .err(.Limit);}if(w.length>builder.limit){return .err(.Quota);}
        w.row=0;w.phase=if(w.text){3}else{4};return .ok(false);}
    if(w.phase==4){if(w.row==builder.catalog.count){w.phase=6;return .ok(false);}
        let usize i=w.row;let usize a=builder.catalog.starts[i];let usize b=builder.catalog.ends[i];
        if(builder.catalog.text[i]!=w.text || b-a!=w.length){w.row+=1;return .ok(false);}
        w.start=a;w.cursor=0;w.phase=5;return .ok(false);}
    if(w.phase==5){var usize stop=w.cursor+64;if(stop>w.length){stop=w.length;}
        while(w.cursor<stop){w.visits+=1;if(payload[w.cursor]!=builder.data[w.start+w.cursor]){w.row+=1;w.phase=4;return .ok(false);}w.cursor+=1;}
        if(w.cursor==w.length){w.id=w.row;w.done=true;return .ok(true);}return .ok(false);}
    if(w.phase==6){if(builder.catalog.count>=16){return .err(.Literals);}
        if(w.length>builder.limit-builder.catalog.used){return .err(.Quota);}
        w.start=builder.catalog.used;w.id=builder.catalog.count;w.cursor=0;w.phase=7;return .ok(false);}
    if(w.phase==7){var usize stop=w.cursor+64;if(stop>w.length){stop=w.length;}
        while(w.cursor<stop){let usize at=w.start+w.cursor;let u8 value=payload[w.cursor];builder.data[at]=value;w.cursor+=1;w.visits+=1;}
        if(w.cursor==w.length){w.phase=8;}return .ok(false);}
    if(w.phase==8){let usize id=w.id;let usize end=w.start+w.length;
        builder.catalog.starts[id]=w.start;builder.catalog.ends[id]=end;builder.catalog.text[id]=w.text;
        builder.catalog.used=end;builder.catalog.count+=1;w.done=true;return .ok(true);}
    return .err(.State);
}
