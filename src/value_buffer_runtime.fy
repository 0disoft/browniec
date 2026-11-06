module value_buffer_runtime;
import value_frames as frames;
import value_frame_layout as layouts;
import value_frame_meter as meter;
import value_codec as codec;
import value_properties as properties;
import value_roots as owners;
import buffer_growth as growth;
import scalar_codec as scalar;
import cells as cells;
import std::num as num;
import std::bytes as bytes;
import std::vec as vec;

// Private retained-IR adapter. All owning vectors remain invocation-local.
// No new guest authority, escaping native view or public source signature.
fn frames::Address at(frames::Token frame,usize slot){
    return frames::Address{.frame=frame.frame,.generation=frame.generation,.slot=slot};
}
fn Result<usize,frames::Error> index(i64 value){return switch(cells::unpack(value,0)){
    case .ok(v):{.ok(v)}case .err(_):{.err(.Value)}
};}
fn Result<u8,frames::Error> byte(i64 value){return switch(num::u8_from_i64(value)){
    case .ok(v):{.ok(v)}case .err(_):{.err(.Value)}
};}
fn Result<usize,frames::Error> publication_cost(){return switch(meter::operation_cost(16)){
    case .ok(v):{.ok(v)}case .err(_):{.err(.State)}
};}
// Validate a fresh exact Result<usize,u8> before any root mutation. Its canonical
// sixteen-byte representation contains no owner and needs no heap allocation.
fn Result<usize,frames::Error> destination(ref layouts::Plan plan,ref frames::State state,
    ref vec::Vec<bytes::Buffer> data,frames::Address output){
    let frames::Slot dst=frames::inspect_destination(plan,state,data,output)?;
    let properties::Node n=switch(codec::node(layouts::layout(plan),dst.type_id)){
        case .ok(v):{v}case .err(_):{return .err(.Type);}
    };
    if(n.kind!=6 || !dst.copyable || dst.width!=16){return .err(.Type);}
    let properties::Node success=switch(codec::node(layouts::layout(plan),n.first as usize)){
        case .ok(v):{v}case .err(_):{return .err(.Type);}
    };
    let properties::Node failure=switch(codec::node(layouts::layout(plan),n.second as usize)){
        case .ok(v):{v}case .err(_):{return .err(.Type);}
    };
    if(success.kind!=1 || success.first!=12 || failure.kind!=1 || failure.first!=10){return .err(.Type);}
    return .ok(dst.width);
}
pub fn Result<usize,frames::Error> instruction(u8 op,usize dst,usize a,usize b,frames::Token current,
    ref layouts::Plan plan,ref mut frames::State state,ref mut owners::State owned,
    ref mut vec::Vec<bytes::Buffer> data,ref mut vec::Vec<bytes::Buffer> roots,
    ref mut vec::Vec<bytes::Buffer> scratch,ref mut i64[] registers,growth::Limits limits,
    ref mut usize fuel){
    if(registers.len!=128 || dst>=128 || a>=128 || b>=128){return .err(.Bounds);}
    if(op==99){
        let usize length=frames::buffer_len(plan,state,data,at(current,a),owned,roots,scratch,fuel)?;
        registers[dst]=switch(cells::pack(length,0)){case .ok(v):{v}case .err(_):{return .err(.Value);}};
        return .ok(0);
    }
    if(op==100){
        let usize selected=index(registers[b])?;
        let u8 value=frames::buffer_read(plan,state,data,at(current,a),selected,owned,roots,scratch,fuel)?;
        registers[dst]=value as i64;return .ok(0);
    }
    if(op==101){
        let usize selected=index(registers[a])?;let u8 value=byte(registers[b])?;
        return frames::buffer_write(plan,state,data,at(current,dst),selected,value,owned,roots,scratch,limits,fuel);
    }
    if(op<102 || op>104){return .err(.State);}
    let usize publication=publication_cost()?;
    switch(meter::pay(publication,fuel)){case .ok(_):{}case .err(_):{return .err(.Fuel);}};
    let usize width=destination(plan,state,data,at(current,dst))?;
    let Result<usize,frames::Error> result=if(op==102){
        let u8 value=byte(registers[b])?;
        frames::buffer_push(plan,state,data,at(current,a),value,owned,roots,scratch,limits,fuel)
    }else if(op==103){
        let usize required=index(registers[b])?;
        frames::buffer_reserve(plan,state,data,at(current,a),required,owned,roots,scratch,limits,fuel)
    }else{
        frames::buffer_append_from(plan,state,data,at(current,a),at(current,b),owned,roots,scratch,limits,fuel)
    };
    var u8[16] representation=[0;16];
    switch(result){
        case .ok(length):{
            // Result.ok uses canonical tag zero (Option.some uses one).
            // Exact usize encoding cannot fail on the admitted 64-bit target.
            let i64 value=switch(cells::pack(length,0)){case .ok(v):{v}case .err(_):{assert(false);0}};
            assert(scalar::encode(12,value,ref mut representation[8..16]).is_ok);
        }
        case .err(e):{switch(e){
            case .Allocation:{representation[0]=1;representation[8]=1;}
            case .Fuel:{return .err(.Fuel);}case .Bounds:{return .err(.Bounds);}
            case .Quota:{return .err(.Quota);}case .State:{return .err(.State);}
            case .Type:{return .err(.Type);}case .Value:{return .err(.Value);}
            case .Owner:{return .err(.Owner);}
        }}
    };
    // All destination admission and Fuel preceded mutation. Root operations do
    // not change frame bytes/order; publication has no allocation or callback.
    // A violated trusted invariant cannot become a rejected but mutated result.
    var usize prepaid=publication;
    assert(frames::initialize(plan,state,data,at(current,dst),ref representation,ref mut prepaid).is_ok);
    assert(prepaid==0);return .ok(width);
}
