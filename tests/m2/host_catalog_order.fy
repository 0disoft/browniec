module tests::m2::host_catalog_order;
import host_catalog as catalog;
import host_catalog_names as names;
import std::bytes as bytes;

struct Expected { u8 kind; usize row; }
fn void append(ref mut bytes::Buffer b,ref u8[] value){assert(bytes::append(b,value).is_ok);}
fn void number(ref mut bytes::Buffer b,usize value){assert(bytes::append_usize(b,value).is_ok);}
fn u8 code(catalog::Failure f){return switch(f){case .Json:{1}case .Limit:{2}case .Unknown:{3}
    case .Duplicate:{4}case .Missing:{5}case .Value:{6}case .Order:{7}case .Allocation:{8}case .Bounds:{9}};}
fn ref u8[] scope(usize row){
    let ref u8[] all=b"host::ahost::a0host::a::ahost::a_host::b";var usize begin=0;var usize end=7;
    if(row==1){begin=7;end=15;}else if(row==5){begin=15;end=25;}
    else if(row==6){begin=25;end=33;}else if(row==7){begin=33;end=40;}return all[begin..end];
}
fn ref u8[] symbol(usize row){
    let ref u8[] all=b"xaA_z";var usize begin=0;var usize end=1;
    if(row==2){begin=1;end=2;}else if(row==3){begin=2;end=3;}else if(row==4){begin=3;end=5;}return all[begin..end];
}
// Frozen original duplicate-first classification over decoded names. It is
// deliberately quadratic and independent of the new sorted-prefix fast path.
fn Expected original(ref usize[] rows){var usize i=0;while(i<rows.len){var usize j=0;
    while(j<i){if(bytes::equal(scope(rows[j]),scope(rows[i])) && bytes::equal(symbol(rows[j]),symbol(rows[i]))){
        return Expected{.kind=4,.row=i};}j+=1;}
    if(i>0 && !names::before(scope(rows[i-1]),symbol(rows[i-1]),scope(rows[i]),symbol(rows[i]))){return Expected{.kind=7,.row=i};}
    i+=1;}return Expected{.kind=0,.row=0};
}
fn void spelling(ref mut bytes::Buffer b,ref u8[] text,bool escaped){
    if(!escaped){append(b,text);return;}let ref u8[] digits=b"0123456789abcdef";let u8[4] prefix=[92,117,48,48];var usize i=0;
    while(i<text.len){let usize value=text[i] as usize;let u8[2] hex=[digits[value/16],digits[value%16]];
        append(b,ref prefix);append(b,ref hex);i+=1;}
}
fn void begin(ref mut bytes::Buffer b){append(b,b"{\"schema\":\"brownie.catalog/1\",\"imports\":[");}
fn usize entry(ref mut bytes::Buffer b,usize id,ref u8[] module_name,ref u8[] name,bool escaped,bool missing){
    if(id>0){append(b,b",");}let usize at=bytes::len(b);append(b,b"{\"id\":");number(b,id);
    append(b,b",\"module\":\"");spelling(b,module_name,escaped);append(b,b"\",\"symbol\":\"");spelling(b,name,escaped);
    append(b,b"\",\"parameters\":[],\"result\":\"Result<i32,u32>\",\"effect\":\"read\",\"capability\":\"a.b\"");
    if(!missing){append(b,b",\"adapter_revision\":\"1\"");}append(b,b"}");return at;
}
fn void check(ref u8[] source,u8 kind,usize offset,usize count){switch(catalog::parse(source)){
    case .err(e):{assert(kind!=0 && code(e.kind)==kind && e.offset==offset);}
    case .ok(c):{assert(kind==0 && catalog::count(ref c)==count);}
};}
fn void sequence(ref usize[] rows,bool escaped){
    var bytes::Buffer b=bytes::empty();begin(ref mut b);let Expected expected=original(rows);var usize offset=0;var usize i=0;
    while(i<rows.len){let usize at=entry(ref mut b,i,scope(rows[i]),symbol(rows[i]),escaped,false);
        if(i==expected.row){offset=at;}i+=1;}append(ref mut b,b"]}");
    check(bytes::view(ref b),expected.kind,offset,rows.len);
}
@test fn void all_three_entry_name_combinations_preserve_duplicate_order_kind_and_exact_offsets(){
    var usize a=0;while(a<8){var usize b=0;while(b<8){var usize c=0;while(c<8){let usize[3] rows=[a,b,c];
        sequence(ref rows,false);sequence(ref rows,true);c+=1;}b+=1;}a+=1;}
    let usize[1] one=[0];sequence(ref one,false);sequence(ref one,true);
    var bytes::Buffer empty=bytes::empty();begin(ref mut empty);append(ref mut empty,b"]}");check(bytes::view(ref empty),0,0,0);
}
fn bytes::Buffer prefix(usize count){var bytes::Buffer b=bytes::empty();begin(ref mut b);var usize i=0;
    while(i<count){var bytes::Buffer name=bytes::empty();append(ref mut name,b"s");if(i<10){append(ref mut name,b"0");}
        number(ref mut name,i);let usize at=entry(ref mut b,i,b"host::m",bytes::view(ref name),false,false);i+=1;}
    return b;
}
@test fn void maximum_sorted_prefix_keeps_early_late_and_decoded_duplicate_diagnostics(){
    var bytes::Buffer full=prefix(64);append(ref mut full,b"]}");assert(bytes::len(ref full)<catalog::byte_limit());
    check(bytes::view(ref full),0,0,64);var usize earlier=0;
    while(earlier<63){var bytes::Buffer b=prefix(63);var bytes::Buffer name=bytes::empty();append(ref mut name,b"s");
        if(earlier<10){append(ref mut name,b"0");}number(ref mut name,earlier);
        let usize at=entry(ref mut b,63,b"host::m",bytes::view(ref name),earlier%2==0,false);append(ref mut b,b"]}");
        check(bytes::view(ref b),4,at,0);earlier+=1;
    }
    var bytes::Buffer order=prefix(63);let usize at=entry(ref mut order,63,b"host::m",b"r99",false,false);
    append(ref mut order,b"]}");check(bytes::view(ref order),7,at,0);
}
@test fn void entry_failures_and_limits_still_precede_duplicate_and_order_checks(){
    var bytes::Buffer missing=prefix(2);let usize at=entry(ref mut missing,2,b"host::m",b"s00",true,true);
    let usize close=bytes::len(ref missing)-1;append(ref mut missing,b"]}");check(bytes::view(ref missing),5,close,0);
    var bytes::Buffer missing_order=prefix(2);let usize other=entry(ref mut missing_order,2,b"host::m",b"r99",false,true);
    let usize end=bytes::len(ref missing_order)-1;append(ref mut missing_order,b"]}");check(bytes::view(ref missing_order),5,end,0);
    var bytes::Buffer excessive=prefix(64);let usize limit=entry(ref mut excessive,64,b"host::m",b"s00",false,false);
    append(ref mut excessive,b"]}");check(bytes::view(ref excessive),2,limit,0);
}
