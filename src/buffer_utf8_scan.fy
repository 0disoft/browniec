module buffer_utf8_scan;
import std::bytes as bytes;
import std::text as text;
import buffer_owners as owners;

// Private progress, not a sealed handle. Keep the bound root immutable until done.
pub struct Cursor {
    bool active; owners::Token source; usize length; usize capacity; usize offset;
    u8[4] carry; usize have;
}
pub enum Error { Token; State; Utf8; }
fn Result<owners::Owner,Error> describe(ref owners::Table table,owners::Token source,ref bytes::Buffer b) {
    let owners::Owner owner=switch(owners::describe(table,source)) {
        case .ok(v):{v}case .err(e):{return .err(switch(e){case .Token:{.Token}
            case .Owners:{.State}case .State:{.State}case .Bounds:{.State}});}
    };
    if(bytes::len(b)!=owner.length || bytes::capacity(b)!=owner.capacity){return .err(.State);}
    return .ok(owner);
}
pub fn Result<Cursor,Error> begin(ref owners::Table table,owners::Token source,ref bytes::Buffer b) {
    let owners::Owner owner=describe(table,source,b)?;
    return .ok(Cursor{.active=true,.source=source,.length=owner.length,.capacity=owner.capacity,
        .offset=0,.carry=[0;4],.have=0});
}
fn bool continuation(u8 value) {return value>=128 && value<=191;}
fn usize width(u8 lead) {
    return if(lead>=194 && lead<=223){2}else{if(lead>=224 && lead<=239){3}else{if(lead>=240 && lead<=244){4}else{0}}};
}
fn bool valid(ref u8[] input) {
    return switch(text::validate_utf8(input)){case .ok(_):{true}case .err(_):{false}};
}
fn bool shaped(ref Cursor cursor) {
    if(cursor.offset>cursor.length || cursor.have>3 || cursor.have>cursor.offset){return false;}
    if(cursor.have>0) {
        if(cursor.offset==cursor.length || width(cursor.carry[0])<=cursor.have){return false;}
        var usize i=1;while(i<cursor.have){if(!continuation(cursor.carry[i])){return false;}i+=1;}
    }
    var usize i=cursor.have;while(i<4){if(cursor.carry[i]!=0){return false;}i+=1;}
    return true;
}
// Read at most min(max_bytes, 256, remaining) new bytes; true means complete.
// Preflight errors preserve progress. UTF-8 failure retires it without committing this step.
pub fn Result<bool,Error> step(ref owners::Table table,ref bytes::Buffer b,
    usize max_bytes,ref mut Cursor cursor) {
    if(!cursor.active){return .err(.State);}
    let owners::Owner owner=describe(table,cursor.source,b)?;
    if(owner.length!=cursor.length || owner.capacity!=cursor.capacity || !shaped(cursor) || max_bytes==0){return .err(.State);}
    var usize count=cursor.length-cursor.offset;
    if(count>max_bytes){count=max_bytes;}if(count>256){count=256;}
    let usize end=cursor.offset+count;
    let ref u8[] view=bytes::view(b);var Cursor next=*cursor;var usize at=next.offset;
    if(next.have>0) {
        let usize needed=width(next.carry[0]);
        while(next.have<needed && at<end){
            if(!continuation(view[at])){cursor.active=false;return .err(.Utf8);}
            let usize position=next.have;
            next.carry[position]=view[at];next.have+=1;at+=1;}
        if(next.have==needed) {
            if(!valid(ref next.carry[..needed])){cursor.active=false;return .err(.Utf8);}
            next.have=0;next.carry=[0;4];
        }
    }
    if(at<end) {
        var usize tail=end-1;var usize back=0;
        while(tail>at && continuation(view[tail]) && back<3){tail-=1;back+=1;}
        var usize cut=end;
        if(width(view[tail])>end-tail){cut=tail;}
        if(!valid(view[at..cut])){cursor.active=false;return .err(.Utf8);}
        if(cut<end) {
            next.have=end-cut;var usize i=0;
            while(i<next.have){next.carry[i]=view[cut+i];i+=1;}
        }
    }
    if(end==next.length && next.have>0){cursor.active=false;return .err(.Utf8);}
    next.offset=end;next.active=end<next.length;*cursor=next;
    return .ok(!next.active);
}
