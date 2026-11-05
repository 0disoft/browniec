module tests::m2::reference_words;
import reference_words as words;
import reference_access as access;
import static_views as views;
import static_ir as statics;
import array_slices as slices;
import array_owners as owners;
import array_layout as layouts;
import errors as errors;

fn void failure(Result<access::Value,errors::Error> result,u8 expected){switch(result){
    case .ok(_):{assert(false);}case .err(e):{assert(e.kind==expected && e.offset==77);}
};}
fn i64 value(Result<access::Value,errors::Error> result){return switch(result){
    case .ok(v):{assert(v.remaining==0);v.value}case .err(_):{assert(false);-99}
};}
@test fn void runtime_words_roundtrip_all_logical_positions_and_empty_extreme_ranges(){
    let views::Span[4] spans=[views::Span{.start=0,.length=0},views::Span{.start=4096,.length=0},
        views::Span{.start=0,.length=4096},views::Span{.start=1,.length=1}];
    var usize a=0;while(a<8){var usize i=0;while(i<4){
        let u32 packed=switch(words::pack(a,spans[i],77)){case .ok(v):{v}case .err(_):{assert(false);0}};
        assert(words::runtime(packed));switch(words::unpack(packed,77)){
            case .ok(v):{assert(v.argument==a && v.span.start==spans[i].start && v.span.length==spans[i].length);}
            case .err(_):{assert(false);}
        };i+=1;
    }a+=1;}
    assert(!words::runtime(0) && !words::runtime(33558528));
}
@test fn void image_words_reserved_bits_bad_positions_and_oversized_spans_reject(){
    let u32[5] invalid=[0,67108864,2147483647,2684354560,4294967295];var usize i=0;
    while(i<5){switch(words::unpack(invalid[i],77)){case .ok(_):{assert(false);}case .err(e):{assert(e.kind==5 && e.offset==77);}};i+=1;}
    assert(!words::pack(8,views::Span{.start=0,.length=1},77).is_ok);
    assert(!words::pack(0,views::Span{.start=4096,.length=1},77).is_ok);
}
fn slices::Ticket setup(ref mut owners::Table table,ref mut slices::Pool pool,ref mut u8[] data){
    let layouts::Array shape=switch(layouts::scalar(10,4)){case .ok(v):{v}case .err(_):{assert(false);layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0}}};
    let owners::Token token=switch(owners::create(ref shape,24,data,table)){case .ok(v):{v}case .err(_):{assert(false);owners::Token{.slot=16,.generation=0}}};
    data[2]=42;return switch(slices::open(pool,table,token,1,4,4)){
        case .ok(v):{v}case .err(_):{assert(false);slices::Ticket{.slot=16,.generation=0}}
    };
}
@test fn void runtime_windows_read_only_the_selected_relative_bytes_without_new_leases(){
    var owners::Table table=owners::empty(4);var slices::Pool pool=slices::empty();var u8[4] data=[0;4];
    let slices::Ticket ticket=setup(ref mut table,ref mut pool,ref mut data);
    let access::Source source=access::loan_window(ticket,views::Span{.start=1,.length=1});
    let statics::Sites sites=statics::empty();let u32[16] unused=[0;16];let u8[1] payload=[0];
    assert(value(access::read(ref source,ref sites,0,ref unused,0,ref payload[..0],ref pool,ref table,ref data,0,4131,77))==42);
    assert(value(access::length(ref source,ref sites,0,ref unused,0,ref payload[..0],ref pool,ref table,4,4097,77))==1);
    failure(access::read(ref source,ref sites,0,ref unused,0,ref payload[..0],ref pool,ref table,ref data,1,4130,77),8);
    failure(access::read(ref source,ref sites,0,ref unused,0,ref payload[..0],ref pool,ref table,ref data,1,4131,77),14);
    var usize count=0;var usize i=0;while(i<16){if(pool.slots[i].live){count+=1;}i+=1;}assert(count==1);
    assert(slices::close(ref mut pool,ticket,ref mut table,4).is_ok);
}
@test fn void empty_invalid_and_stale_windows_keep_authentication_and_fuel_precedence(){
    var owners::Table table=owners::empty(4);var slices::Pool pool=slices::empty();var u8[4] data=[0;4];
    let slices::Ticket ticket=setup(ref mut table,ref mut pool,ref mut data);
    var access::Source source=access::loan_window(ticket,views::Span{.start=3,.length=0});
    let statics::Sites sites=statics::empty();let u32[16] unused=[0;16];let u8[1] payload=[0];
    assert(value(access::length(ref source,ref sites,0,ref unused,0,ref payload[..0],ref pool,ref table,4,4097,77))==0);
    failure(access::read(ref source,ref sites,0,ref unused,0,ref payload[..0],ref pool,ref table,ref data,0,4131,77),14);
    source=access::loan_window(ticket,views::Span{.start=3,.length=1});
    failure(access::length(ref source,ref sites,0,ref unused,0,ref payload[..0],ref pool,ref table,4,4097,77),5);
    assert(slices::close(ref mut pool,ticket,ref mut table,4).is_ok);
    failure(access::read(ref source,ref sites,0,ref unused,0,ref payload[..0],ref pool,ref table,ref data,0,4130,77),8);
    failure(access::read(ref source,ref sites,0,ref unused,0,ref payload[..0],ref pool,ref table,ref data,0,4131,77),5);
}
