module tests::m2::value_view_call_runtime;
import value_view_call_runtime as calls;
import value_buffer_views as views;
import value_frames as frames;
import value_frame_layout as layouts;
import value_properties as values;
import value_roots as roots;
import buffer_growth as growth;
import std::bytes as bytes;
import std::vec as vec;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn layouts::Plan plan(){
    var values::Catalog c=values::empty();c.count=1;
    c.nodes[0]=values::Node{.kind=4,.first=0,.second=0,.extent=0};
    let u8[16] types=[1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0];let u8[16] functions=[0;16];
    return switch(layouts::retain(ref c,ref types,ref functions,1)){
        case .ok(v):{v}case .err(_):{assert(false);plan()}
    };
}
fn usize ok(Result<usize,frames::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn usize viewed(Result<usize,views::Error> r){return switch(r){case .ok(v):{v}case .err(_):{assert(false);0}};}
fn views::Ticket ticket(Result<views::Ticket,views::Error> r){return switch(r){
    case .ok(v):{v}case .err(_):{assert(false);views::Ticket{.slot=32,.generation=0}}
};}
fn u8 code(frames::Error e){return switch(e){case .Fuel:{1}case .State:{2}case .Type:{3}case .Bounds:{4}
    case .Quota:{5}case .Allocation:{6}case .Value:{7}case .Owner:{8}};}
fn void fails(Result<usize,frames::Error> r,u8 expected){assert(switch(r){
    case .ok(_):{false}case .err(e):{code(e)==expected}
});}
fn roots::State root_open(ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> scratch,
    ref mut usize fuel){return switch(roots::open(data,scratch,limits(),fuel)){
        case .ok(v):{v}case .err(_):{assert(false);root_open(data,scratch,fuel)}
    };
}
fn frames::State opened(ref layouts::Plan p,ref mut vec::Vec<bytes::Buffer> data,
    ref mut vec::Vec<bytes::Buffer> scratch,ref roots::State store,ref mut usize fuel){
    return switch(frames::open(p,data,scratch,store,limits(),fuel)){
        case .ok(v):{v}case .err(_):{assert(false);opened(p,data,scratch,store,fuel)}
    };
}
fn views::Pool pool_open(ref mut roots::State store,ref vec::Vec<bytes::Buffer> data,
    ref vec::Vec<bytes::Buffer> scratch,ref mut usize fuel){return switch(views::open(store,data,scratch,limits(),fuel)){
        case .ok(v):{v}case .err(_):{assert(false);pool_open(store,data,scratch,fuel)}
    };
}
fn frames::Token enter(ref layouts::Plan p,ref mut frames::State state,
    ref mut vec::Vec<bytes::Buffer> data,ref roots::State store,ref mut usize fuel){
    return switch(frames::enter(p,state,data,0,store,limits(),fuel)){
        case .ok(v):{v}case .err(_):{assert(false);frames::Token{.frame=32,.generation=0}}
    };
}
fn frames::Address at(frames::Token t,usize slot){return frames::Address{.frame=t.frame,.generation=t.generation,.slot=slot};}
fn views::Ticket lookup(ref views::Pool pool,ref roots::State store,ref vec::Vec<bytes::Buffer> data,
    ref vec::Vec<bytes::Buffer> scratch,usize binding){return ticket(views::lookup(pool,store,data,scratch,binding));}
fn void close(ref mut views::Pool pool,ref mut roots::State store,ref vec::Vec<bytes::Buffer> data,
    ref vec::Vec<bytes::Buffer> scratch,usize binding){
    let views::Ticket t=lookup(pool,store,data,scratch,binding);
    let usize siblings=viewed(views::close(pool,store,data,scratch,t,binding));
}
fn void content(ref views::Pool pool,ref roots::State store,ref vec::Vec<bytes::Buffer> data,
    ref vec::Vec<bytes::Buffer> scratch,usize binding,ref u8[] expected){
    let views::Ticket t=lookup(pool,store,data,scratch,binding);var u8[16] out=[0;16];
    var usize fuel=viewed(views::copy_cost(expected.len));
    assert(viewed(views::copy_out(pool,store,data,scratch,t,binding,ref mut out[..expected.len],ref mut fuel))==expected.len);
    assert(fuel==0 && bytes::equal(ref out[..expected.len],expected));
}
// Full native bookkeeping snapshots, including descriptor generations, physical
// owner leases and initialization order. Rejected operations cannot hide leaks.
fn void unchanged(ref frames::State state,ref frames::State before,ref views::Pool pool,
    ref views::Pool previous,ref roots::State store,ref roots::State old){
    assert(state.depth==before.depth && state.next==before.next && state.used==before.used &&
        state.peak==before.peak && state.closed==before.closed && pool.closed==previous.closed);
    var usize i=0;while(i<32){let frames::Frame a=state.frames[i];let frames::Frame b=before.frames[i];
        assert(a.function==b.function && a.generation==b.generation && a.live==b.live && a.next==b.next && a.charge==b.charge);
        let views::Row x=pool.rows[i];let views::Row y=previous.rows[i];
        assert(x.generation==y.generation && x.live==y.live && x.binding==y.binding && x.serial==y.serial &&
            x.owner_binding==y.owner_binding && x.owner_slot==y.owner_slot && x.owner_generation==y.owner_generation &&
            x.start==y.start && x.length==y.length);i+=1;
    }
    i=0;while(i<512){assert(state.order[i]==before.order[i]);i+=1;}
    assert(store.next==old.next && store.closed==old.closed && store.external==old.external &&
        store.ledger.used==old.ledger.used && store.ledger.engine_used==old.ledger.engine_used &&
        store.ledger.peak==old.ledger.peak && store.ledger.engine_peak==old.ledger.engine_peak &&
        growth::settled(ref store.ledger));
    i=0;while(i<16){assert(store.rows[i].serial==old.rows[i].serial && store.rows[i].binding==old.rows[i].binding &&
        store.rows[i].slot==old.rows[i].slot && store.rows[i].generation==old.rows[i].generation);
        assert(store.table.slots[i].live==old.table.slots[i].live && store.table.slots[i].reading==old.table.slots[i].reading &&
            store.table.slots[i].generation==old.table.slots[i].generation && store.table.slots[i].length==old.table.slots[i].length &&
            store.table.slots[i].capacity==old.table.slots[i].capacity);i+=1;
    }
}
fn void frame_bytes(ref vec::Vec<bytes::Buffer> data,ref u8[] expected){
    assert(expected.len==vec::len<bytes::Buffer>(data)*16);var usize i=0;
    while(i<vec::len<bytes::Buffer>(data)){
        assert(bytes::equal(bytes::view(vec::at<bytes::Buffer>(data,i)),expected[i*16..i*16+16]));i+=1;
    }
}
fn void finish(ref mut frames::State state,ref mut views::Pool pool,ref mut roots::State store,
    ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> frame_scratch,
    ref mut vec::Vec<bytes::Buffer> backing,ref mut vec::Vec<bytes::Buffer> scratch){
    assert(viewed(views::shutdown(pool,store,backing,scratch))==0);
    assert(ok(frames::abort(state,data,frame_scratch,store,backing,scratch))==0);
    assert(pool.closed && views::snapshot(pool).live==0 && state.closed && state.depth==0 && state.used==0 &&
        store.closed && store.external==0 && store.ledger.used==0 && store.ledger.engine_used==0);
    assert(vec::len<bytes::Buffer>(data)==0 && vec::len<bytes::Buffer>(frame_scratch)==0 &&
        vec::len<bytes::Buffer>(backing)==0 && vec::len<bytes::Buffer>(scratch)==0);
}

@test fn void arguments_alias_eight_actuals_and_selected_range_returns_without_copy_or_early_unpin(){
    let layouts::Plan p=plan();var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> fs=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> backing=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var usize fuel=10000000;
    var roots::State store=root_open(ref mut backing,ref mut scratch,ref mut fuel);
    var frames::State state=opened(ref p,ref mut data,ref mut fs,ref store,ref mut fuel);
    let frames::Token caller=enter(ref p,ref mut state,ref mut data,ref store,ref mut fuel);
    let usize serial=ok(frames::buffer_value(ref p,ref mut state,ref mut data,at(caller,0),b"abcdef",
        ref mut store,ref mut backing,ref mut scratch,limits(),ref mut fuel));
    var views::Pool pool=pool_open(ref mut store,ref backing,ref scratch,ref mut fuel);
    let views::Ticket origin=ticket(views::begin(ref mut pool,ref mut store,ref backing,ref scratch,serial,0,0,1,5,ref mut fuel));
    let frames::Token callee=enter(ref p,ref mut state,ref mut data,ref store,ref mut fuel);
    let usize[8] actuals=[0;8];let usize[8] formals=[0,1,2,3,4,5,6,7];let frames::State before=state;
    let usize used=store.ledger.used;let usize peak=store.ledger.peak;let usize next=store.next;
    let usize owner_slot=store.rows[0].slot;let usize generation=store.rows[0].generation;
    fuel=4096;assert(ok(calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
        caller,callee,ref actuals,ref formals,ref mut fuel))==8 && fuel==0);
    assert(views::snapshot(ref pool).live==9 && views::snapshot(ref pool).roots==1);
    var usize i=0;while(i<8){content(ref pool,ref store,ref backing,ref scratch,16+i,b"bcde");i+=1;}
    assert(lookup(ref pool,ref store,ref backing,ref scratch,0).slot==origin.slot);
    let views::Ticket selected=lookup(ref pool,ref store,ref backing,ref scratch,23);fuel=512;
    let views::Ticket range=ticket(views::range(ref mut pool,ref mut store,ref backing,ref scratch,selected,23,25,1,3,ref mut fuel));
    assert(fuel==0);i=0;while(i<8){close(ref mut pool,ref mut store,ref backing,ref scratch,16+i);i+=1;}
    fuel=256;assert(ok(calls::result(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
        caller,callee,9,5,0,ref mut fuel))==5 && fuel==0);
    let views::Ticket returned=lookup(ref pool,ref store,ref backing,ref scratch,5);
    assert(returned.slot==range.slot && returned.generation==range.generation &&
        !views::lookup(ref pool,ref store,ref backing,ref scratch,25).is_ok);
    assert(state.depth==before.depth && state.used==before.used && state.next==before.next &&
        state.frames[0].live==before.frames[0].live && state.frames[1].live==0 && state.order[0]==before.order[0]);
    assert(store.ledger.used==used && store.ledger.peak==peak && store.next==next &&
        store.rows[0].generation==generation && vec::len<bytes::Buffer>(ref backing)==1);
    var u8[32] image=[0;32];image[0]=1;frame_bytes(ref data,ref image);
    let usize left=ok(frames::leave(ref p,ref mut state,ref mut data,callee,ref mut store,ref mut backing,ref mut scratch));
    close(ref mut pool,ref mut store,ref backing,ref scratch,0);assert(fuel==0);
    assert(views::snapshot(ref pool).live==1 && store.table.slots[owner_slot].reading);
    content(ref pool,ref store,ref backing,ref scratch,5,b"cd");
    var usize denied=100000;assert(!roots::write(ref store,ref mut backing,ref mut scratch,serial,0,0,b"X",limits(),ref mut denied).is_ok);
    content(ref pool,ref store,ref backing,ref scratch,5,b"cd");
    close(ref mut pool,ref mut store,ref backing,ref scratch,5);
    assert(fuel==0 && !store.table.slots[owner_slot].reading && views::snapshot(ref pool).live==0);
    finish(ref mut state,ref mut pool,ref mut store,ref mut data,ref mut fs,ref mut backing,ref mut scratch);assert(fuel==0);
}

@test fn void recursive_same_function_view_zero_is_isolated_and_reused_frames_require_empty_lanes(){
    let layouts::Plan p=plan();var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> fs=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> backing=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var usize fuel=10000000;
    var roots::State store=root_open(ref mut backing,ref mut scratch,ref mut fuel);
    var frames::State state=opened(ref p,ref mut data,ref mut fs,ref store,ref mut fuel);
    let frames::Token outer=enter(ref p,ref mut state,ref mut data,ref store,ref mut fuel);
    let usize serial=ok(frames::buffer_value(ref p,ref mut state,ref mut data,at(outer,0),b"nested",
        ref mut store,ref mut backing,ref mut scratch,limits(),ref mut fuel));
    var views::Pool pool=pool_open(ref mut store,ref backing,ref scratch,ref mut fuel);
    let views::Ticket original=ticket(views::begin(ref mut pool,ref mut store,ref backing,ref scratch,serial,0,0,0,6,ref mut fuel));
    let frames::Token middle=enter(ref p,ref mut state,ref mut data,ref store,ref mut fuel);let usize[1] zero=[0];
    assert(ok(calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
        outer,middle,ref zero,ref zero,ref mut fuel))==1);
    let frames::Token inner=enter(ref p,ref mut state,ref mut data,ref store,ref mut fuel);
    assert(ok(calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
        middle,inner,ref zero,ref zero,ref mut fuel))==1);
    let views::Ticket second=lookup(ref pool,ref store,ref backing,ref scratch,16);
    let views::Ticket third=lookup(ref pool,ref store,ref backing,ref scratch,32);
    assert(original.slot!=second.slot && second.slot!=third.slot && original.slot!=third.slot &&
        state.frames[0].function==state.frames[1].function && state.frames[1].function==state.frames[2].function);
    {let frames::State before=state;let views::Pool previous=pool;let roots::State old=store;
        fails(calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
            outer,middle,ref zero,ref zero,ref mut fuel),2);
        fails(calls::result(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
            outer,middle,0,1,0,ref mut fuel),2);
        fails(calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
            outer,inner,ref zero,ref zero,ref mut fuel),2);
        fails(calls::result(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
            inner,inner,0,1,0,ref mut fuel),2);
        unchanged(ref state,ref before,ref pool,ref previous,ref store,ref old);
    }
    fuel=256;assert(ok(calls::result(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
        middle,inner,0,1,0,ref mut fuel))==1 && fuel==0);
    let usize departed=ok(frames::leave(ref p,ref mut state,ref mut data,inner,ref mut store,ref mut backing,ref mut scratch));
    content(ref pool,ref store,ref backing,ref scratch,0,b"nested");content(ref pool,ref store,ref backing,ref scratch,16,b"nested");
    content(ref pool,ref store,ref backing,ref scratch,17,b"nested");close(ref mut pool,ref mut store,ref backing,ref scratch,16);
    fuel=256;assert(ok(calls::result(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
        outer,middle,1,1,0,ref mut fuel))==1 && fuel==0);
    let usize left=ok(frames::leave(ref p,ref mut state,ref mut data,middle,ref mut store,ref mut backing,ref mut scratch));
    fuel=100000;let frames::Token reused=enter(ref p,ref mut state,ref mut data,ref store,ref mut fuel);
    assert(reused.frame==middle.frame && reused.generation!=middle.generation);
    // Trusted native fault setup models an old descriptor surviving frame reuse.
    // A different formal ID must not bypass the empty-callee requirement.
    let views::Ticket stale=ticket(views::alias(ref mut pool,ref mut store,ref backing,ref scratch,original,0,16,ref mut fuel));
    let usize[1] seven=[7];
    {let frames::State before=state;let views::Pool previous=pool;let roots::State old=store;
        fails(calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
            outer,reused,ref zero,ref seven,ref mut fuel),2);
        fails(calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
            outer,middle,ref zero,ref seven,ref mut fuel),2);
        fails(calls::result(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
            outer,middle,0,2,0,ref mut fuel),2);
        unchanged(ref state,ref before,ref pool,ref previous,ref store,ref old);
    }
    close(ref mut pool,ref mut store,ref backing,ref scratch,16);
    fuel=512;assert(ok(calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
        outer,reused,ref zero,ref zero,ref mut fuel))==1 && fuel==0);
    close(ref mut pool,ref mut store,ref backing,ref scratch,16);
    let usize cleaned=ok(frames::leave(ref p,ref mut state,ref mut data,reused,ref mut store,ref mut backing,ref mut scratch));
    content(ref pool,ref store,ref backing,ref scratch,0,b"nested");content(ref pool,ref store,ref backing,ref scratch,1,b"nested");
    finish(ref mut state,ref mut pool,ref mut store,ref mut data,ref mut fs,ref mut backing,ref mut scratch);assert(fuel==0);
}

@test fn void stale_ids_missing_bindings_leaks_owned_roots_wrong_origins_and_fuel_preserve_state(){
    let layouts::Plan p=plan();var vec::Vec<bytes::Buffer> data=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> fs=vec::empty<bytes::Buffer>();var vec::Vec<bytes::Buffer> backing=vec::empty<bytes::Buffer>();
    var vec::Vec<bytes::Buffer> scratch=vec::empty<bytes::Buffer>();var usize fuel=10000000;
    var roots::State store=root_open(ref mut backing,ref mut scratch,ref mut fuel);
    var frames::State state=opened(ref p,ref mut data,ref mut fs,ref store,ref mut fuel);
    let frames::Token caller=enter(ref p,ref mut state,ref mut data,ref store,ref mut fuel);
    let usize serial=ok(frames::buffer_value(ref p,ref mut state,ref mut data,at(caller,0),b"abcdef",
        ref mut store,ref mut backing,ref mut scratch,limits(),ref mut fuel));
    let usize other=ok(frames::buffer_value(ref p,ref mut state,ref mut data,at(caller,1),b"uvwxyz",
        ref mut store,ref mut backing,ref mut scratch,limits(),ref mut fuel));
    var views::Pool pool=pool_open(ref mut store,ref backing,ref scratch,ref mut fuel);
    let views::Ticket full=ticket(views::begin(ref mut pool,ref mut store,ref backing,ref scratch,serial,0,0,0,6,ref mut fuel));
    let views::Ticket narrow=ticket(views::range(ref mut pool,ref mut store,ref backing,ref scratch,full,0,1,1,5,ref mut fuel));
    let views::Ticket foreign=ticket(views::begin(ref mut pool,ref mut store,ref backing,ref scratch,other,1,2,0,6,ref mut fuel));
    let frames::Token callee=enter(ref p,ref mut state,ref mut data,ref store,ref mut fuel);
    let frames::Token stale_caller=frames::Token{.frame=caller.frame,.generation=caller.generation+1};
    let frames::Token stale_callee=frames::Token{.frame=callee.frame,.generation=callee.generation+1};
    let usize[1] zero=[0];let usize[2] two=[0,1];let usize[2] duplicate=[0,0];
    let usize[2] missing=[0,15];let usize[1] absent=[15];let usize[1] invalid=[16];let usize[9] many=[0;9];
    var u8[32] image=[0;32];image[0]=1;image[8]=2;
    {let frames::State before=state;let views::Pool previous=pool;let roots::State old=store;
        fuel=0;assert(ok(calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
            caller,callee,ref zero[..0],ref zero[..0],ref mut fuel))==0 && fuel==0);
        var usize mode=0;while(mode<10){fuel=if(mode==9){1023}else{100000};
            let Result<usize,frames::Error> attempt=if(mode==0 || mode==1){calls::arguments(ref p,ref state,ref data,
                ref mut pool,ref mut store,ref backing,ref scratch,if(mode==0){stale_caller}else{caller},
                if(mode==1){stale_callee}else{callee},ref zero,ref zero,ref mut fuel)}
            else if(mode==2){calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
                caller,callee,ref invalid,ref zero,ref mut fuel)}
            else if(mode==3){calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
                caller,callee,ref zero,ref invalid,ref mut fuel)}
            else if(mode==4){calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
                caller,callee,ref zero,ref two,ref mut fuel)}
            else if(mode==5){calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
                caller,callee,ref many,ref many,ref mut fuel)}
            else if(mode==6){calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
                caller,callee,ref absent,ref zero,ref mut fuel)}
            else if(mode==7){calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
                caller,callee,ref missing,ref two,ref mut fuel)}
            else if(mode==8){calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
                caller,callee,ref two,ref duplicate,ref mut fuel)}
            else{calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
                caller,callee,ref two,ref two,ref mut fuel)};
            fails(attempt,if(mode<2 || mode==4){2}else if(mode<6){4}else if(mode<9){8}else{1});
            if(mode==9){assert(fuel==1023);}
            unchanged(ref state,ref before,ref pool,ref previous,ref store,ref old);frame_bytes(ref data,ref image);mode+=1;
        }
        // With an empty callee lane, an absent result reaches source lookup.
        fuel=256;fails(calls::result(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
            caller,callee,15,3,0,ref mut fuel),8);assert(fuel==256);
        unchanged(ref state,ref before,ref pool,ref previous,ref store,ref old);frame_bytes(ref data,ref image);
    }
    fuel=512;assert(ok(calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
        caller,callee,ref zero,ref zero,ref mut fuel))==1 && fuel==0);
    {let frames::State before=state;let views::Pool previous=pool;let roots::State old=store;
        fuel=100000;fails(calls::arguments(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
            caller,callee,ref zero,ref two[..1],ref mut fuel),2);
        // A different live callee descriptor is rejected before source lookup.
        let u8[11] expected=[2,2,4,4,4,2,8,8,8,4,1];
        var usize mode=0;while(mode<11){fuel=if(mode==10){255}else{100000};
            let Result<usize,frames::Error> attempt=calls::result(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
                if(mode==0){stale_caller}else{caller},if(mode==1){stale_callee}else{callee},
                if(mode==2){16}else if(mode==5){15}else{0},if(mode==3){16}else if(mode==7){0}else{3},
                if(mode==4){16}else if(mode==6){15}else if(mode==8){2}else if(mode==9){1}else{0},ref mut fuel);
            fails(attempt,expected[mode]);
            if(mode==10){assert(fuel==255);}
            unchanged(ref state,ref before,ref pool,ref previous,ref store,ref old);frame_bytes(ref data,ref image);mode+=1;
        }
    }
    fuel=512;let views::Ticket source=lookup(ref pool,ref store,ref backing,ref scratch,16);
    let views::Ticket leak=ticket(views::alias(ref mut pool,ref mut store,ref backing,ref scratch,source,16,20,ref mut fuel));
    {let frames::State before=state;let views::Pool previous=pool;let roots::State old=store;
        fuel=256;fails(calls::result(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
            caller,callee,0,3,0,ref mut fuel),2);
        unchanged(ref state,ref before,ref pool,ref previous,ref store,ref old);assert(fuel==256);
    }
    close(ref mut pool,ref mut store,ref backing,ref scratch,20);fuel=100000;
    let usize local=ok(frames::buffer_value(ref p,ref mut state,ref mut data,at(callee,0),b"local",
        ref mut store,ref mut backing,ref mut scratch,limits(),ref mut fuel));image[16]=3;
    {let frames::State before=state;let views::Pool previous=pool;let roots::State old=store;
        fails(calls::result(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
            caller,callee,0,3,0,ref mut fuel),2);
        unchanged(ref state,ref before,ref pool,ref previous,ref store,ref old);frame_bytes(ref data,ref image);
    }
    close(ref mut pool,ref mut store,ref backing,ref scratch,16);
    let views::Ticket local_view=ticket(views::begin(ref mut pool,ref mut store,ref backing,ref scratch,local,16,16,0,5,ref mut fuel));
    {let frames::State before=state;let views::Pool previous=pool;let roots::State old=store;
        fails(calls::result(ref p,ref state,ref data,ref mut pool,ref mut store,ref backing,ref scratch,
            caller,callee,0,3,0,ref mut fuel),2);
        unchanged(ref state,ref before,ref pool,ref previous,ref store,ref old);frame_bytes(ref data,ref image);
    }
    content(ref pool,ref store,ref backing,ref scratch,0,b"abcdef");content(ref pool,ref store,ref backing,ref scratch,1,b"bcde");
    content(ref pool,ref store,ref backing,ref scratch,2,b"uvwxyz");content(ref pool,ref store,ref backing,ref scratch,16,b"local");
    fuel=0;close(ref mut pool,ref mut store,ref backing,ref scratch,16);
    let usize left=ok(frames::leave(ref p,ref mut state,ref mut data,callee,ref mut store,ref mut backing,ref mut scratch));
    assert(vec::len<bytes::Buffer>(ref backing)==2 && state.depth==1 && fuel==0);
    finish(ref mut state,ref mut pool,ref mut store,ref mut data,ref mut fs,ref mut backing,ref mut scratch);assert(fuel==0);
}
