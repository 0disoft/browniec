module value_view_copy_runtime;
import value_buffer_runtime as buffers;
import value_buffer_views as views;
import value_view_runtime as view_runtime;
import value_frames as frames;
import value_frame_layout as layouts;
import value_frame_meter as meter;
import value_roots as roots;
import buffer_growth as growth;
import std::bytes as bytes;
import std::vec as vec;

// Private APPEND_VIEW112 adapter. The native registry retains the exact source
// lease/window; no payload staging or native view crosses this boundary.
pub fn Result<usize,frames::Error> instruction(usize dst,usize a,usize b,frames::Token current,
    ref layouts::Plan plan,ref mut frames::State state,ref mut roots::State store,
    ref mut vec::Vec<bytes::Buffer> data,ref vec::Vec<views::Pool> pools,
    ref mut vec::Vec<bytes::Buffer> backing,ref mut vec::Vec<bytes::Buffer> scratch,
    growth::Limits limits,ref mut usize fuel){
    if(dst>=16 || a>=16 || b>=16){return .err(.Bounds);}
    if(current.frame>=32 || current.generation==0 || vec::len<views::Pool>(pools)!=1){return .err(.State);}
    let usize checked=frames::inspect_frame(plan,state,data,current)?;
    let usize publication=buffers::publication_cost()?;
    switch(meter::pay(publication,fuel)){case .ok(_):{}case .err(_):{return .err(.Fuel);}};
    let frames::Address output=frames::Address{.frame=current.frame,.generation=current.generation,.slot=dst};
    let usize width=buffers::destination(plan,state,data,output)?;
    let frames::BufferKey destination=frames::buffer_view_key(plan,state,data,
        frames::Address{.frame=current.frame,.generation=current.generation,.slot=a},store,backing,scratch,fuel)?;
    let usize selected=current.frame*16+b;let ref views::Pool pool=vec::at<views::Pool>(pools,0);
    let views::Ticket source=switch(views::lookup(pool,store,backing,scratch,selected)){
        case .ok(v):{v}case .err(e):{return .err(view_runtime::failure(e));}
    };
    let growth::Limits remaining=switch(meter::remaining(state.used,limits)){
        case .ok(v):{v}case .err(_):{return .err(.Quota);}
    };
    let Result<usize,frames::Error> result=switch(views::append_to(pool,store,backing,scratch,
        source,selected,destination.serial,destination.binding,remaining,fuel)){
        case .ok(v):{.ok(v)}case .err(e):{.err(view_runtime::failure(e))}
    };
    return buffers::publish(plan,state,data,output,result,publication,width);
}
