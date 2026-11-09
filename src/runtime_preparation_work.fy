module runtime_preparation_work;
import ir as ir;
import static_ir as statics;
import call_capture_plan as captures;
import array_list_vm as lists;
import place_dispatch as places;
import fuel as fuel;
import metadata_budget as budget;
import errors as errors;

// Revalidate a retained immutable Program's execution cache, never source IR
// admission. The parent pins that exact Program and its input across all stages.
pub struct State { usize phase; usize index; bool done; }
pub fn State empty(){return State{.phase=0,.index=0,.done=false};}
fn errors::Error invalid(){return errors::make(5,0);}
fn Result<usize,errors::Error> stage(ref mut State w,ref ir::Program p,ref statics::Sites sites,
    ref u8[] parameters,ref lists::Requirement list,ref places::Requirement place,
    usize work,usize capacity,ref captures::Plan calls,bool input){
    if(w.phase==0){
        if(p.count==0 || p.count>256 || p.registers==0 || p.registers>128 || p.constant_count>128 ||
            p.function_count==0 || p.function_count>16 || p.entry>=p.function_count || p.call_count>32 ||
            p.arrays.count>16 || p.records.count>16 || p.records.layouts.count>32 || p.list_used>4096 ||
            sites.count>16 || parameters.len!=16 || !calls.ready ||
            capacity!=if(p.arrays.count!=0 || p.records.count!=0){65536}else{0}){return .err(invalid());}
        let usize f=p.entry;let usize start=p.register_starts[f];let usize end=p.register_ends[f];
        if(start>end || end>p.registers || p.arities[f]!=if(input){1}else{0} ||
            p.arities[f]>end-start || p.return_types[f]!=1 || p.array_results[f]!=0 ||
            p.record_results[f]!=0 || sites.results[f]!=0 || parameters[f]!=0 || work!=p.arities[f]){return .err(invalid());}
        if(input && (start>=128 || sites.parameters[start]!=3 || sites.formal_sites[start]==0 ||
            sites.formal_sites[start]>16 || p.array_parameters[start]!=0 || p.record_parameters[start]!=0 || p.slice_parameters[start]!=0)){return .err(invalid());}
        w.phase=1;w.index=0;return .ok(0);
    }
    if(w.phase==1){
        let usize f=w.index;let usize start=p.register_starts[f];let usize end=p.register_ends[f];
        if(p.starts[f]>=p.ends[f] || p.ends[f]>p.count || start>end || end>p.registers ||
            p.arities[f]>8 || p.arities[f]>end-start || parameters[f] as usize>p.arities[f]){return .err(invalid());}
        w.index+=1;if(w.index==p.function_count){w.phase=2;w.index=0;}return .ok(0);
    }
    if(w.phase==2){
        if(list.length>4096 || list.bytes>32768 || (list.length==0)!=(list.bytes==0) ||
            list.cost!=fuel::list_prepare(list.length,list.bytes) || place.width>16 ||
            (place.width==0 && (place.aggregate || place.records || place.slices)) ||
            (place.aggregate && (place.records || place.slices))){return .err(invalid());}
        let usize cost=if(place.aggregate){fuel::aggregate_place_prepare(place.width)}else if(place.records){fuel::record_place_prepare(place.width)}
            else if(place.slices){fuel::slice_place_prepare(place.width)}else{fuel::place_prepare(place.width)};
        if(cost!=place.cost){return .err(invalid());}w.phase=3;w.index=0;return .ok(0);
    }
    if(w.phase==3){
        let usize i=w.index;let usize pc=calls.pcs[i] as usize;
        if(pc>256 || calls.required[i]>65535 || calls.absent[i]>65535 || (calls.required[i]&calls.absent[i])!=0){return .err(invalid());}
        if(pc!=256){
            if(pc>=p.count || i>=p.call_count){return .err(invalid());}
            let usize at=pc*8;let u8 op=p.code[at];
            if((op!=9 && op!=64 && op!=66 && op!=78) || p.code[at+3] as usize!=i){return .err(invalid());}
        }else if(calls.required[i]!=0 || calls.absent[i]!=0){return .err(invalid());}
        var usize a=0;while(a<8){if(calls.ends[i*8+a]>16 || calls.parents[i*8+a]>16 ||
            (pc==256 && (calls.ends[i*8+a]!=0 || calls.parents[i*8+a]!=16))){return .err(invalid());}a+=1;}
        w.index+=1;if(w.index==32){w.phase=4;w.done=true;}return .ok(0);
    }return .err(invalid());
}
pub fn Result<bool,errors::Error> advance(ref mut State w,ref ir::Program p,ref statics::Sites sites,
    ref u8[] parameters,ref lists::Requirement list,ref places::Requirement place,
    usize work,usize capacity,ref captures::Plan calls,bool input,ref mut budget::State allowance){
    if(w.done || w.phase>3 || (w.phase==1 && w.index>=p.function_count) || (w.phase==3 && w.index>=32)){return .err(invalid());}
    if(allowance.last!=0){return .ok(false);}if(!budget::admit(allowance,4096,0)?){return .ok(false);}
    let usize checked=stage(w,p,sites,parameters,list,place,work,capacity,calls,input)?;return .ok(w.done);
}
