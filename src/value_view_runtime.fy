module value_view_runtime;
import value_buffer_views as views;
import value_frames as frames;
import value_frame_layout as layouts;
import value_frame_meter as meter;
import value_roots as roots;
import buffer_growth as growth;
import cells as cells;
import ir as ir;
import std::bytes as bytes;
import std::vec as vec;

// Private descriptors occupy their own invocation-local vector, never canonical
// value slots or guest words. Only authenticated frame*16+id bindings select them.
pub fn bool present(ref ir::Program p){
    var usize pc=0;while(pc<p.count){let u8 op=p.code[pc*8];
        if(op>=105 && op<=112){return true;}pc+=1;}return false;
}
pub fn usize setup_cost(){return roots::read_lease_cost();}
pub fn usize metadata_charge(){return views::metadata_charge();}
pub fn frames::Error failure(views::Error e){return switch(e){
    case .Fuel:{.Fuel}case .Quota:{.Quota}case .Allocation:{.Allocation}
    case .Bounds:{.Bounds}case .Capacity:{.Quota}case .State:{.State}
    case .Binding:{.Owner}case .Stale:{.Owner}
};}
fn Result<usize,frames::Error> index(i64 value){return switch(cells::unpack(value,0)){
    case .ok(v):{.ok(v)}case .err(_):{.err(.Value)}
};}
pub fn Result<usize,frames::Error> setup(ref ir::Program p,ref mut vec::Vec<views::Pool> pools,
    ref vec::Vec<frames::State> states,ref mut vec::Vec<roots::State> owners,
    ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch,
    growth::Limits limits,ref mut usize fuel){
    if(vec::len<views::Pool>(pools)!=0){return .err(.State);}
    if(!present(p)){return .ok(0);}
    if(vec::len<frames::State>(states)!=1 || vec::len<roots::State>(owners)!=1){return .err(.State);}
    let growth::Limits remaining=switch(meter::remaining(vec::at<frames::State>(states,0).used,limits)){
        case .ok(v):{v}case .err(_):{return .err(.Quota);}
    };
    if(!vec::reserve<views::Pool>(pools,1).is_ok){return .err(.Allocation);}
    let ref mut roots::State store=vec::at_mut<roots::State>(owners,0);
    var views::Pool pool=switch(views::open(store,data,scratch,remaining,fuel)){
        case .ok(v):{v}case .err(e):{return .err(failure(e));}
    };
    switch(vec::push<views::Pool>(pools,pool)){
        case .ok(_):{}case .err(_):{
            let usize closed=switch(views::shutdown(ref mut pool,store,data,scratch)){
                case .ok(v):{v}case .err(e):{return .err(failure(e));}
            };return .err(.Allocation);
        }
    };return .ok(0);
}
// A caller's bindings survive ordinary calls. The departing activation must
// close every own binding before any return publication or frame reuse.
pub fn Result<usize,frames::Error> empty_frame(ref vec::Vec<views::Pool> pools,usize frame){
    if(frame>=32 || vec::len<views::Pool>(pools)>1){return .err(.State);}
    if(vec::len<views::Pool>(pools)==0){return .ok(0);}
    let ref views::Pool pool=vec::at<views::Pool>(pools,0);
    if(pool.closed){return .err(.State);}var usize i=0;
    while(i<32){let views::Row row=pool.rows[i];
        if(row.live && (row.binding>=512 || row.binding/16==frame)){return .err(.State);}i+=1;
    }return .ok(0);
}
pub fn Result<usize,frames::Error> shutdown(ref mut vec::Vec<views::Pool> pools,
    ref mut vec::Vec<roots::State> owners,ref vec::Vec<bytes::Buffer> data,ref vec::Vec<bytes::Buffer> scratch){
    if(vec::len<views::Pool>(pools)==0){return .ok(0);}
    if(vec::len<views::Pool>(pools)!=1 || vec::len<roots::State>(owners)!=1){return .err(.State);}
    return switch(views::shutdown(vec::at_mut<views::Pool>(pools,0),vec::at_mut<roots::State>(owners,0),data,scratch)){
        case .ok(v):{.ok(v)}case .err(e):{.err(failure(e))}
    };
}
pub fn Result<usize,frames::Error> instruction(u8 op,usize dst,usize a,usize b,usize hi,frames::Token current,
    ref layouts::Plan plan,ref frames::State state,ref vec::Vec<bytes::Buffer> data,
    ref mut vec::Vec<views::Pool> pools,ref mut roots::State store,
    ref vec::Vec<bytes::Buffer> roots,ref vec::Vec<bytes::Buffer> scratch,
    ref mut i64[] registers,ref mut usize fuel){
    if(registers.len!=128 || current.frame>=32 || current.generation==0 ||
        vec::len<views::Pool>(pools)!=1 || op<105 || op>111){return .err(.State);}
    let usize checked=frames::inspect_frame(plan,state,data,current)?;
    if(op<=106){if(dst>=16 || a>=16 || b>=128 || hi>=128){return .err(.Bounds);}}
    else if(op<=108){if(dst>=16 || a>=16 || b!=0 || hi!=0){return .err(.State);}}
    else if(op==109){if(dst>=16 || a!=0 || b!=0 || hi!=0){return .err(.State);}}
    else{if(dst>=128 || a>=16 || b>=128 || hi!=0 || (op==110 && b!=0)){return .err(.State);}}
    // Unpack every scalar endpoint before touching a descriptor or root lease.
    let usize lo=if(op==105 || op==106 || op==111){index(registers[b])?}else{0};
    let usize end=if(op==105 || op==106){index(registers[hi])?}else{0};
    let usize base=current.frame*16;let ref mut views::Pool pool=vec::at_mut<views::Pool>(pools,0);
    if(op==105){
        let frames::BufferKey key=frames::buffer_view_key(plan,state,data,
            frames::Address{.frame=current.frame,.generation=current.generation,.slot=a},store,roots,scratch,fuel)?;
        return switch(views::begin(pool,store,roots,scratch,key.serial,key.binding,base+dst,lo,end,fuel)){
            case .ok(_):{.ok(0)}case .err(e):{.err(failure(e))}
        };
    }
    let usize selected=base+if(op==109){dst}else{a};
    let views::Ticket source=switch(views::lookup(pool,store,roots,scratch,selected)){
        case .ok(v):{v}case .err(e):{return .err(failure(e));}
    };
    if(op==109){return switch(views::close(pool,store,roots,scratch,source,selected)){
        case .ok(v):{.ok(v)}case .err(e):{.err(failure(e))}
    };}
    if(op==110){
        let usize length=switch(views::length(pool,store,roots,scratch,source,selected,fuel)){
            case .ok(v):{v}case .err(e):{return .err(failure(e));}
        };
        registers[dst]=switch(cells::pack(length,0)){case .ok(v):{v}case .err(_):{return .err(.Value);}};
        return .ok(0);
    }
    if(op==111){
        let u8 value=switch(views::read(pool,store,roots,scratch,source,selected,lo,fuel)){
            case .ok(v):{v}case .err(e):{return .err(failure(e));}
        };registers[dst]=value as i64;return .ok(0);
    }
    let Result<views::Ticket,views::Error> result=if(op==106){
        views::range(pool,store,roots,scratch,source,selected,base+dst,lo,end,fuel)
    }else if(op==107){views::alias(pool,store,roots,scratch,source,selected,base+dst,fuel)}
    else{views::move(pool,store,roots,scratch,source,selected,base+dst,fuel)};
    return switch(result){case .ok(_):{.ok(0)}case .err(e):{.err(failure(e))}};
}
