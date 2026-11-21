module struct_value_source;
import struct_source as source_types;
import struct_layout as layouts;
import lexer as lexer;
import declaration_header_work as headers;
import locals as locals;
import ir as ir;
import errors as errors;
import source_context as context;
import aggregate_copy_source_work as copies;
import metadata_budget as budget;
import record_location_work as locations;
import struct_layout_work as layout_work;
import record_leaf_source_work as leaf_work;
import record_field_source_work as field_work;
import record_path_source_work as path_work;
import record_initializer_source_work as initializer_work;

// 144..159 are function-owned struct sites, disjoint from scalars and arrays.
pub fn bool binding(ref locals::Table names, usize index) {
    return index < names.count && names.registers[index] >= 144 && names.registers[index] < 160;
}
pub fn Result<usize, errors::Error> named_raw(ref u8[] source, ref lexer::State s,ref context::Table scope) {
    let source_types::Location found = source_types::locate_scoped(source,scope,s.begin,s.end,32)?;
    return .ok(found.record);
}
// The immutable catalog has already passed struct_source::scan. Reparse only
// bounded declaration names; path resolution converts field indices to leaf ordinals.
pub fn Result<usize, errors::Error> field_raw(ref u8[] source, ref ir::Program p, usize record, usize begin, usize end,ref context::Table scope) {
    let source_types::Location found = source_types::locate_scoped(source,scope,begin,end,record)?;
    if (record >= p.records.layouts.count || found.record != record) { return .err(errors::make(3, begin)); }
    var lexer::State s=context::state(source,scope,found.body)?;
    let usize first = lexer::next(source, ref mut s)?;
    var usize i = 0;
    while (i < p.records.layouts.fields[record] as usize) {
        let usize tag = lexer::next(source, ref mut s)?;
        if (lexer::equal(source[begin..end], source[s.begin..s.end])) { return .ok(i); }
        let usize name = lexer::next(source, ref mut s)?;
        let usize end_field = lexer::punctuation(source, ref mut s, 59)?; i += 1;
    }
    return .err(errors::make(3, begin));
}
pub struct Header { usize record; usize begin; usize end; bool mutable; }
pub fn Result<usize,errors::Error> declaration_limit_raw(ref ir::Program p,ref locals::Table names,
    usize record,u8 terminator,u8 result_type,usize at){
    if (names.function >= p.function_count || result_type == 0 || terminator != 59 || record >= p.records.layouts.count) { return .err(errors::make(3, at)); }
    let layouts::Plan plan = switch (layouts::plan(ref p.records.layouts, 18446744073709551615)) {
        case .ok(value): { value } case .err(_): { return .err(errors::make(3, at)); }
    };
    if (plan.bytes[record] > 128) { return .err(errors::make(4, at)); }
    return .ok(record);
}
pub fn Result<Header, errors::Error> header_raw(ref u8[] source, ref mut lexer::State s,
    ref ir::Program p, ref locals::Table names, usize record, bool mutable, u8 terminator, u8 result_type) {
    let usize at = s.begin;
    let usize checked=declaration_limit(p,names,record,terminator,result_type,at)?;
    let usize type_name = lexer::next(source, s)?;
    if (s.kind != 2 || locals::reserved(source[s.begin..s.end])) { return .err(errors::make(2, s.begin)); }
    let usize begin = s.begin; let usize end = s.end;
    if (locals::find(source, names, begin, end) != 64) { return .err(errors::make(3, begin)); }
    if (names.count >= 64 || p.records.count >= 16) { return .err(errors::make(4, begin)); }
    let usize name = lexer::next(source, s)?;
    let usize equals = lexer::punctuation(source, s, 61)?;
    return .ok(Header { .record = record, .begin = begin, .end = end,
        .mutable = mutable });
}
pub fn Result<Header,errors::Error> header(ref u8[] source,ref mut lexer::State s,ref ir::Program p,
    ref locals::Table names,usize record,bool mutable,u8 terminator,u8 result_type){
    if(source.len>4096){return header_raw(source,s,p,names,record,mutable,terminator,result_type);}
    var headers::State w=headers::begin(*s,4,mutable,terminator,result_type,p.records.count>=16);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,s.begin)?;let bool done=headers::advance(source,s,names,ref mut w,ref mut meter)?;
        if(w.request==1){let usize checked=declaration_limit(p,names,record,terminator,result_type,w.at)?;let usize resumed=headers::resume(ref mut w)?;}}
    let headers::Prepared h=headers::prepared(ref w)?;return .ok(Header{.record=record,.begin=h.begin,.end=h.end,.mutable=mutable});
}
pub struct Leaf { usize ordinal; u8 tag; usize record; }
// Resolve one already-tokenized field without requiring adjacent source bytes.
// Grouped prefixes keep the same nominal catalog and depth-first leaf order.
pub fn Result<Leaf,errors::Error> project_raw(ref u8[] source,ref ir::Program p,
    Leaf parent,usize begin,usize end,ref context::Table scope){
    if(parent.tag!=0 || parent.ordinal>=128 || begin>=end || end>source.len || parent.record>=p.records.layouts.count){return .err(errors::make(3,begin));}
    let usize selected=field_raw(source,p,parent.record,begin,end,scope)?;
    var usize ordinal=parent.ordinal;var usize i=0;
    while(i<selected){let usize slot=parent.record*16+i;
        let usize leaves=if(p.records.layouts.kinds[slot]==0){1}else{leaf_count_raw(p,p.records.layouts.types[slot] as usize,begin)?};
        if(leaves>127-ordinal){return .err(errors::make(3,begin));}ordinal+=leaves;i+=1;}
    let usize slot=parent.record*16+selected;let bool scalar=p.records.layouts.kinds[slot]==0;
    return .ok(Leaf{.ordinal=ordinal,.tag=if(scalar){p.records.layouts.types[slot]}else{0},
        .record=if(scalar){parent.record}else{p.records.layouts.types[slot] as usize}});
}
// Scalar ordinals are depth-first leaf positions, never field or byte offsets.
pub fn Result<Leaf, errors::Error> path_raw(ref u8[] source, ref mut lexer::State s,
    ref ir::Program p, usize root, usize at,ref context::Table scope) {
    var usize record = root; var usize ordinal = 0; var usize depth = 0;
    while (s.kind == 46) {
        if (depth >= 16) { return .err(errors::make(4, s.begin)); } depth += 1;
        let usize dot = lexer::next(source, s)?;
        if (s.kind != 2) { return .err(errors::make(2, s.begin)); }
        let usize selected = field_raw(source, p, record, s.begin, s.end,scope)?;
        var usize i = 0;
        while (i < selected) {
            let usize slot = record*16+i;
            if (p.records.layouts.kinds[slot] == 0) { ordinal += 1; }
            else { ordinal += leaf_count_raw(p, p.records.layouts.types[slot] as usize, at)?; }
            i += 1;
        }
        let usize slot = record*16+selected;
        let usize member = lexer::next(source, s)?;
        if (p.records.layouts.kinds[slot] == 0) {
            if (s.kind == 46) {
                var lexer::State look = lexer::snapshot(s);
                let usize next = lexer::next(source, ref mut look)?;
                if (look.kind != 46) { return .err(errors::make(2, s.begin)); }
            }
            return .ok(Leaf { .ordinal = ordinal, .tag = p.records.layouts.types[slot], .record = record });
        }
        record = p.records.layouts.types[slot] as usize;
    }
    return .ok(Leaf { .ordinal = ordinal, .tag = 0, .record = record });
}
// Type discovery uses a separate lexer snapshot and emits no IR. The selected
// initializer rechecks the same exact nominal path before any value is bound.
pub fn Result<usize,errors::Error> inferred_endpoint(ref u8[] source,ref mut lexer::State look,
    ref ir::Program p,usize root,usize at,ref context::Table scope){
    let Leaf leaf=path(source,look,p,root,at,scope)?;
    return .ok(if(leaf.tag==0){leaf.record+1}else{0});
}
pub fn Result<usize, errors::Error> read(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, usize id, usize at,ref context::Table scope) {
    if (id >= p.records.count || s.kind != 46) { return .err(errors::make(3, at)); }
    let Leaf leaf = path(source, s, p, p.records.records[id] as usize, at,scope)?;
    if (leaf.tag == 0) { return .err(errors::make(3, at)); }
    return ir::record_read(p, id, leaf.ordinal, at);
}
// Dotted final values remain expressions; assignment tokens after a bounded
// chain select a statement, including compounds inside value arms.
pub fn Result<bool, errors::Error> assigned(ref u8[] source, ref lexer::State state) {
    var lexer::State look = lexer::snapshot(state); var usize depth = 0;
    while (look.kind == 46) {
        if (depth >= 16) { return .err(errors::make(4, look.begin)); } depth += 1;
        let usize dot = lexer::next(source, ref mut look)?;
        if (look.kind != 2) { return .ok(false); }
        let usize member = lexer::next(source, ref mut look)?;
    }
    return .ok(depth != 0 && lexer::assignment(look.kind));
}
pub fn Result<Leaf, errors::Error> writable(ref u8[] source, ref mut lexer::State s,
    ref ir::Program p, usize id, usize at,ref context::Table scope) {
    if (id >= p.records.count || !p.records.mutable[id] || s.kind != 46) { return .err(errors::make(3, at)); }
    let Leaf leaf = path(source, s, p, p.records.records[id] as usize, at,scope)?;
    // Keep the exact operator pending for scalar/aggregate assignment lowering.
    return .ok(leaf);
}

// Constructor syntax and bare-name copies are separate initializer forms.
// Inspect the following token so a local sharing a type name stays unambiguous.
pub fn Result<bool, errors::Error> constructor_raw(ref u8[] source, ref mut lexer::State s, usize record,ref context::Table scope) {
    if ((s.kind!=2 && s.kind!=5)) { return .err(errors::make(3, s.begin)); }
    var lexer::State look = lexer::snapshot(s);
    let usize next = lexer::next(source, ref mut look)?;
    if (look.kind != 123) { return .ok(false); }
    if (named_raw(source, s,scope)? != record) { return .err(errors::make(3, s.begin)); }
    let usize name = lexer::next(source, s)?;
    let usize open = lexer::punctuation(source, s, 123)?;
    return .ok(true);
}
fn Result<usize, errors::Error> copy_source(ref u8[] source, ref mut lexer::State s,
    ref ir::Program p, ref locals::Table names, usize record) {
    if (s.kind != 2) { return .err(errors::make(3, s.begin)); }
    let usize at = s.begin;
    let usize index = locals::find(source, names, s.begin, s.end);
    if (!binding(names, index)) { return .err(errors::make(3, at)); }
    let usize id = names.registers[index] - 144;
    if (id >= p.records.count || p.records.records[id] as usize != record) { return .err(errors::make(3, at)); }
    let usize name = lexer::next(source, s)?;
    let usize end = lexer::punctuation(source, s, 59)?;
    return .ok(id);
}
pub fn Result<usize, errors::Error> copy(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref mut locals::Table names, Header header,ref context::Table scope) {
    var lexer::State look = lexer::snapshot(s);
    let usize next = lexer::next(source, ref mut look)?;
    if (look.kind == 46) { return extract(source,s,p,names,header,scope); }
    let usize from = copy_source(source, s, p, names, header.record)?;
    let usize id = ir::record_in(p, names.function, header.record, header.mutable, header.begin)?;
    let usize copied = ir::record_copy(p, id, from, header.begin)?;
    // The new binding becomes visible only after its complete initializer.
    return locals::declare(names, header.begin, header.end, 144 + id, header.mutable);
}
pub fn Result<usize, errors::Error> assign(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table names, usize id, usize at,ref context::Table scope) {
    if (id >= p.records.count || !p.records.mutable[id]) { return .err(errors::make(3, at)); }
    let usize equals = lexer::punctuation(source, s, 61)?;
    var lexer::State look = lexer::snapshot(s);
    let usize next = lexer::next(source,ref mut look)?;
    if (look.kind == 46) {
        let Leaf target = Leaf { .ordinal = 0, .tag = 0, .record = p.records.records[id] as usize };
        return assign_part(source,s,p,names,id,target,at,scope);
    }
    let usize from = copy_source(source, s, p, names, p.records.records[id] as usize)?;
    return ir::record_assign(p, id, from, at);
}

// Keep source staging at sixteen scalar leaves; private VM roots allow 128.
pub fn Result<usize, errors::Error> leaf_count_raw(ref ir::Program p, usize root, usize at) {
    var usize count = 0;
    var usize[16] records = [0; 16]; var usize[16] fields = [0; 16];
    records[0] = root; var usize depth = 1; var usize visits = 0;
    while (depth > 0) {
        if (visits >= 4096) { return .err(errors::make(4, at)); } visits += 1;
        let usize level = depth-1; let usize record = records[level];
        if (record >= p.records.layouts.count) { return .err(errors::make(3, at)); }
        if (fields[level] >= p.records.layouts.fields[record] as usize) { depth -= 1; }
        else {
            let usize slot = record*16+fields[level]; fields[level] += 1;
            if (p.records.layouts.kinds[slot] == 0) {
                if (count >= 16) { return .err(errors::make(4, at)); }
                count += 1;
            } else {
                if (depth >= 16) { return .err(errors::make(4, at)); }
                records[depth] = p.records.layouts.types[slot] as usize; fields[depth] = 0; depth += 1;
            }
        }
    }
    return .ok(count);
}
pub struct Initializer {
    usize[16] records; usize[16] fields; usize depth;
    lexer::State shorthand; bool is_shorthand;
}
pub fn Initializer initializer(usize root) {
    var Initializer result = Initializer { .records = [0; 16], .fields = [0; 16], .depth = 1,
        .shorthand = lexer::empty(), .is_shorthand = false };
    result.records[0] = root; return result;
}
pub fn bool shorthand(ref Initializer state) { return state.is_shorthand; }
// The cursor already consumed the member name while deciding whether it was
// followed by '='. Restore that token so the ordinary scalar expression parser
// resolves the same-name local exactly once.
pub fn void rewind_shorthand(ref mut lexer::State s, ref Initializer state) {
    *s = state.shorthand;
}
pub fn void consumed_shorthand(ref mut Initializer state) {
    state.is_shorthand = false; state.shorthand = lexer::empty();
}
// A completed scalar or child constructor advances exactly one enclosing field.
pub fn Result<usize, errors::Error> advance_raw(ref u8[] source, ref mut lexer::State s,
    ref ir::Program p, ref mut Initializer state) {
    state.is_shorthand = false; state.shorthand = lexer::empty();
    let usize level = state.depth-1; state.fields[level] += 1;
    if (state.fields[level] < p.records.layouts.fields[state.records[level]] as usize) {
        let usize comma = lexer::punctuation(source, s, 44)?;
    }
    return .ok(0);
}
// Iteratively enter child constructors or close completed records. The caller
// parses/records one scalar expression at a time in depth-first source order.
pub fn Result<u8, errors::Error> next_leaf_raw(ref u8[] source, ref mut lexer::State s,
    ref ir::Program p, ref mut Initializer state, usize at,ref context::Table scope) {
    while (state.depth > 0) {
        let usize level = state.depth-1; let usize record = state.records[level];
        let usize selected = state.fields[level];
        if (selected >= p.records.layouts.fields[record] as usize) {
            if (s.kind == 44) { let usize comma = lexer::next(source, s)?; }
            let usize close = lexer::punctuation(source, s, 125)?; state.depth -= 1;
            if (state.depth > 0) { let usize finished = advance_raw(source,s,p,state)?; }
        } else {
            let usize dot = lexer::punctuation(source,s,46)?;
            let usize found = field_raw(source,p,record,s.begin,s.end,scope)?;
            if (s.kind != 2 || found != selected) { return .err(errors::make(3,s.begin)); }
            let lexer::State member = lexer::snapshot(s);
            let usize name = lexer::next(source,s)?;
            var bool short = false;
            if (s.kind == 61) { let usize equals = lexer::next(source,s)?; }
            else if (s.kind == 44 || s.kind == 125) { short = true; }
            else { return .err(errors::make(2,s.begin)); }
            let usize slot = record*16+selected;
            if (p.records.layouts.kinds[slot] == 0) {
                state.shorthand = member; state.is_shorthand = short;
                return .ok(p.records.layouts.types[slot]);
            }
            let usize child = p.records.layouts.types[slot] as usize;
            // 255 requests binding/path child staging, never a scalar tag.
            if (short) { state.shorthand = member; state.is_shorthand = true; return .ok(255); }
            if(s.kind==40){return .ok(255);}
            if(s.kind==2 || s.kind==5){var lexer::State value=lexer::snapshot(s);let usize next=lexer::next(source,ref mut value)?;
                if(value.kind==123 && named_raw(source,s,scope)?!=child){return .ok(255);}}
            if (!constructor_raw(source,s,child,scope)?) { return .ok(255); }
            if (state.depth >= 16) { return .err(errors::make(4,at)); }
            let usize depth = state.depth; state.records[depth] = child; state.fields[depth] = 0; state.depth += 1;
        }
    }
    return .ok(0);
}

// Snapshot an exact nominal binding/path into the parent's scalar staging slots.
// A field path has no user expressions that can interleave these reads.
pub fn Result<usize, errors::Error> stage_child(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table names, ref mut Initializer state,
    ref mut usize[] slots, usize first, usize at,ref context::Table scope) {
    if (state.depth == 0 || s.kind != 2) { return .err(errors::make(3,s.begin)); }
    let usize index = locals::find(source,names,s.begin,s.end);
    if (!binding(names,index)) { return .err(errors::make(3,s.begin)); }
    let usize id = names.registers[index]-144;
    if (id >= p.records.count) { return .err(errors::make(3,s.begin)); }
    let usize name = lexer::next(source,s)?;
    let Leaf part = path(source,s,p,p.records.records[id] as usize,at,scope)?;
    return stage_part(source,s,p,state,slots,first,id,part,at);
}
// Resolve either a whole returned root or its dotted child without creating an
// independent child owner. The caller drops the root after staging completes.
pub fn Result<usize, errors::Error> stage_call_child(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,ref mut Initializer state,ref mut usize[] slots,
    usize first,usize id,usize at,ref context::Table scope) {
    if(id>=p.records.count) {return .err(errors::make(3,at));}
    let Leaf part=path(source,s,p,p.records.records[id] as usize,at,scope)?;
    return stage_part(source,s,p,state,slots,first,id,part,at);
}
// Snapshot a selected child into scalar staging slots before any later field
// expression. Call results and visible child bindings share this leaf encoder.
pub fn Result<usize, errors::Error> stage_part_raw(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref mut Initializer state, ref mut usize[] slots,
    usize first, usize id, Leaf part, usize at) {
    if(state.depth==0 || id>=p.records.count) {return .err(errors::make(3,at));}
    let usize level=state.depth-1;
    let usize child=p.records.layouts.types[state.records[level]*16+state.fields[level]] as usize;
    if (part.tag != 0 || part.record != child) { return .err(errors::make(3,at)); }
    if (s.kind != 44 && s.kind != 125) { return .err(errors::make(2,s.begin)); }
    let usize count = leaf_count(p,child,at)?;
    if (first > slots.len || count > slots.len-first) { return .err(errors::make(4,at)); }
    var usize i = 0;
    while (i < count) {
        let usize value = ir::record_read(p,id,part.ordinal+i,at)?;
        let u8 tag = p.types[value];
        let usize slot = ir::slot(p,tag,at)?;
        slots[first+i] = slot;
        let usize stored = ir::raw(p,18,slot,value,0,at)?;
        i += 1;
    }
    let usize finished = advance(source,s,p,state)?;
    return .ok(count);
}

// A bare subrecord path has no intervening user expressions: its SREAD results
// are consecutive scalar inputs to SINIT, without staging slots or a temporary owner.
fn Result<usize, errors::Error> extract(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref mut locals::Table names, Header header,ref context::Table scope) {
    let usize id=extracted(source,s,p,names,header.record,header.mutable,header.begin,scope)?;
    return locals::declare(names,header.begin,header.end,144+id,header.mutable);
}
// Declarations, returns and arguments share the independent leaf copy. Delimiter
// validation precedes emission; callers publish names only after complete creation.
pub fn Result<usize, errors::Error> extracted(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table names, usize record, bool mutable, usize offset,ref context::Table scope) {
    return extract_operand(source,s,p,names,record,mutable,offset,false,scope);
}
pub fn Result<usize, errors::Error> extracted_argument(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table names, usize record, usize offset,ref context::Table scope) {
    return extract_operand(source,s,p,names,record,false,offset,true,scope);
}
fn Result<usize, errors::Error> extract_operand(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table names, usize record, bool mutable, usize offset,
    bool argument,ref context::Table scope) {
    if (s.kind != 2) { return .err(errors::make(3,s.begin)); }
    let usize at = s.begin;
    let usize index = locals::find(source,names,s.begin,s.end);
    if (!binding(names,index)) { return .err(errors::make(3,at)); }
    let usize source_id = names.registers[index]-144;
    if (source_id >= p.records.count) { return .err(errors::make(3,at)); }
    let usize name = lexer::next(source,s)?;
    let Leaf part = path(source,s,p,p.records.records[source_id] as usize,at,scope)?;
    if (part.tag != 0 || part.record != record) { return .err(errors::make(3,at)); }
    if(argument) {
        if(s.kind!=44 && s.kind!=41) {return .err(errors::make(3,s.begin));}
    } else {let usize end=lexer::punctuation(source,s,59)?;}
    return extract_part(p,names.function,source_id,part,mutable,offset,at,false);
}
// A returned root has no guest name. Snapshot its child, release the root,
// then create an independent child so its extent can reuse reclaimed bytes.
pub fn Result<usize, errors::Error> extracted_call_argument(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,usize function,usize source_id,usize record,usize at,ref context::Table scope) {
    return extracted_call(source,s,p,function,source_id,record,false,at,true,scope);
}
pub fn Result<usize, errors::Error> extracted_call(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,usize function,usize source_id,usize record,bool mutable,usize at,bool argument,ref context::Table scope) {
    if(source_id>=p.records.count || s.kind!=46) {return .err(errors::make(3,at));}
    let Leaf part=path(source,s,p,p.records.records[source_id] as usize,at,scope)?;
    if(part.tag!=0 || part.record!=record) {return .err(errors::make(3,at));}
    if(argument) {
        if(s.kind!=44 && s.kind!=41) {return .err(errors::make(3,s.begin));}
    } else {let usize end=lexer::punctuation(source,s,59)?;}
    return extract_part(p,function,source_id,part,mutable,at,at,true);
}
pub fn Result<usize, errors::Error> extract_part_raw(ref mut ir::Program p,usize function,
    usize source_id,Leaf part,bool mutable,usize offset,usize at,bool consume) {
    let usize count = leaf_count(p,part.record,at)?;
    let usize first = p.registers;
    var usize i = 0;
    while (i < count) {
        let usize read = ir::record_read(p,source_id,part.ordinal+i,at)?; i += 1;
    }
    if(consume) {let usize dropped=ir::record_drop(p,source_id,at)?;}
    let usize id = ir::record_in(p,function,part.record,mutable,offset)?;
    let usize init = ir::record_init(p,id,first,offset)?;
    return .ok(id);
}

// The returned root must stay live through the atomic overwrite. No independent
// child owner or scalar staging registers are needed for an assignment.
pub fn Result<usize, errors::Error> assign_call_part(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program p,usize dst,usize from,Leaf target,usize at,ref context::Table scope) {
    if(dst>=p.records.count || from>=p.records.count || dst==from || !p.records.mutable[dst] ||
        target.tag!=0 || s.kind!=46 || p.record_functions[dst]!=p.record_functions[from]) {
        return .err(errors::make(3,at));
    }
    let Leaf origin=path(source,s,p,p.records.records[from] as usize,at,scope)?;
    if(origin.tag!=0 || origin.record!=target.record) {return .err(errors::make(3,at));}
    let usize end=lexer::punctuation(source,s,59)?;
    let usize copied=ir::record_subassign(p,dst,from,target.record,target.ordinal,origin.ordinal,at)?;
    return ir::record_drop(p,from,at);
}
// Resolve exact nominal endpoints; the VM prepays and snapshots their bytes
// before committing one atomic overwrite without any new owner or register.
pub fn Result<usize, errors::Error> assign_part(ref u8[] source, ref mut lexer::State s,
    ref mut ir::Program p, ref locals::Table names, usize dst, Leaf target, usize at,ref context::Table scope) {
    if (dst >= p.records.count || !p.records.mutable[dst] || target.tag != 0 || s.kind != 2) {
        return .err(errors::make(3,at));
    }
    let usize index = locals::find(source,names,s.begin,s.end);
    if (!binding(names,index)) { return .err(errors::make(3,s.begin)); }
    let usize from = names.registers[index]-144;
    if (from >= p.records.count) { return .err(errors::make(3,s.begin)); }
    let usize name = lexer::next(source,s)?;
    let Leaf origin = path(source,s,p,p.records.records[from] as usize,at,scope)?;
    if (origin.tag != 0 || origin.record != target.record) { return .err(errors::make(3,at)); }
    let usize end = lexer::punctuation(source,s,59)?;
    return ir::record_subassign(p,dst,from,target.record,target.ordinal,origin.ordinal,at);
}

// Metadata children drain their own bounded protocols; the parent copy does
// not account whole source/catalog scans as one scalar/owner transition.
pub fn Result<usize,errors::Error> copy_work(ref mut ir::Program p,ref usize[] input,ref mut usize[] slots,ref mut copies::State w){
    var usize fuel=budget::unlimited();
    return copy_work_metered(p,input,slots,w,0,ref mut fuel);
}
pub fn Result<usize,errors::Error> copy_work_metered(ref mut ir::Program p,ref usize[] input,
    ref mut usize[] slots,ref mut copies::State w,usize deadline,ref mut usize fuel){
    var budget::State meter=budget::empty();
    while(!w.done){
        discard budget::visit(fuel,deadline,w.at)?;
        let usize allowance=budget::reset(ref mut meter,w.at)?;
        let bool done=copies::advance(p,input,slots,w,ref mut meter)?;
        if(w.request==1){let usize count=leaf_count_metered(p,w.record,w.at,deadline,fuel)?;let usize resumed=copies::resume(w,count)?;}
        else if(w.request==2){let usize source=w.source;let usize leaf=w.ordinal+w.row;let usize at=w.at;
            let usize value=ir::record_read(p,source,leaf,at)?;let usize resumed=copies::resume(w,value)?;}}
    return copies::prepared(w);
}
pub fn Result<usize,errors::Error> extract_part(ref mut ir::Program p,usize function,usize source_id,Leaf part,
    bool mutable,usize offset,usize at,bool consume){
    var copies::State w=copies::begin(7,source_id,part.record,part.ordinal,0,function,mutable,consume,offset,at);
    let usize[1] input=[0];var usize[1] slots=[0];return copy_work(p,ref input,ref mut slots,ref mut w);
}
pub fn Result<usize,errors::Error> stage_part(ref u8[] source,ref mut lexer::State s,ref mut ir::Program p,
    ref mut Initializer state,ref mut usize[] slots,usize first,usize id,Leaf part,usize at){
    if(state.depth==0 || id>=p.records.count){return .err(errors::make(3,at));}
    let usize level=state.depth-1;let usize child=p.records.layouts.types[state.records[level]*16+state.fields[level]] as usize;
    if(part.tag!=0 || part.record!=child){return .err(errors::make(3,at));}
    if(s.kind!=44 && s.kind!=125){return .err(errors::make(2,s.begin));}
    var copies::State w=copies::begin(1,id,child,part.ordinal,first,0,false,false,at,at);
    let usize[1] input=[0];let usize count=copy_work(p,ref input,slots,ref mut w)?;
    let usize finished=advance(source,s,p,state)?;return .ok(count);
}

// The raw loops remain independent parity oracles; owning metadata adapters
// drain private continuations and expose no partial result or guest authority.
pub fn Result<usize,errors::Error> named(ref u8[] source,ref lexer::State s,ref context::Table scope){
    var locations::State w=locations::begin(s.begin,s.end,32);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,s.begin)?;
        let bool done=locations::advance(source,scope,ref mut w,ref mut meter)?;}return .ok(w.record);
}
pub fn Result<usize,errors::Error> declaration_limit(ref ir::Program p,ref locals::Table names,
    usize record,u8 terminator,u8 result_type,usize at){
    if(names.function>=p.function_count || result_type==0 || terminator!=59 || record>=p.records.layouts.count){return .err(errors::make(3,at));}
    var layout_work::State w=layout_work::empty();let usize started=switch(layout_work::begin(ref mut w,18446744073709551615)){
        case .ok(v):{v}case .err(_):{return .err(errors::make(3,at));}};
    var budget::State meter=budget::empty();while(!w.done){let usize allowance=budget::reset(ref mut meter,at)?;
        switch(layout_work::advance(ref mut w,ref p.records.layouts,ref mut meter)){case .ok(_):{}case .err(_):{return .err(errors::make(3,at));}};}
    if(w.plan.bytes[record]>128){return .err(errors::make(4,at));}return .ok(record);
}
pub fn Result<usize,errors::Error> leaf_count(ref ir::Program p,usize root,usize at){
    var usize fuel=budget::unlimited();
    return leaf_count_metered(p,root,at,0,ref mut fuel);
}
pub fn Result<usize,errors::Error> leaf_count_metered(ref ir::Program p,usize root,usize at,usize deadline,ref mut usize fuel){
    var leaf_work::State w=leaf_work::begin(root,at);var budget::State meter=budget::empty();
    while(!w.done){
        discard budget::visit(fuel,deadline,at)?;
        let usize allowance=budget::reset(ref mut meter,at)?;
        let bool done=leaf_work::advance(p,ref mut w,ref mut meter)?;
    }
    return leaf_work::prepared(ref w);
}
pub fn Result<usize,errors::Error> field(ref u8[] source,ref ir::Program p,usize record,usize begin,usize end,ref context::Table scope){
    var field_work::State w=field_work::begin(record,begin,end);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,begin)?;let bool done=field_work::advance(source,p,scope,ref mut w,ref mut meter)?;}
    return field_work::prepared(ref w);
}
pub fn Result<Leaf,errors::Error> path(ref u8[] source,ref mut lexer::State s,ref ir::Program p,usize root,usize at,ref context::Table scope){
    var path_work::State w=path_work::begin_path(root,at);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,at)?;let bool done=path_work::advance(source,s,p,scope,ref mut w,ref mut meter)?;}
    return path_work::prepared(ref w);
}
pub fn Result<Leaf,errors::Error> project(ref u8[] source,ref ir::Program p,Leaf parent,usize begin,usize end,ref context::Table scope){
    var lexer::State s=lexer::empty();var path_work::State w=path_work::begin_project(parent,begin,end);var budget::State meter=budget::empty();
    while(!w.done){let usize allowance=budget::reset(ref mut meter,begin)?;let bool done=path_work::advance(source,ref mut s,p,scope,ref mut w,ref mut meter)?;}
    return path_work::prepared(ref w);
}

pub fn Result<bool, errors::Error> constructor(ref u8[] source, ref mut lexer::State s, usize record,ref context::Table scope) {
    if ((s.kind!=2 && s.kind!=5)) { return .err(errors::make(3, s.begin)); }
    var lexer::State look = lexer::snapshot(s);
    let usize next = lexer::next(source, ref mut look)?;
    if (look.kind != 123) { return .ok(false); }
    if (named(source, s,scope)? != record) { return .err(errors::make(3, s.begin)); }
    let usize name = lexer::next(source, s)?;
    let usize open = lexer::punctuation(source, s, 123)?;
    return .ok(true);
}
pub fn Result<u8,errors::Error> next_leaf(ref u8[] source,ref mut lexer::State s,ref ir::Program p,
    ref mut Initializer init,usize at,ref context::Table scope){
    var usize fuel=budget::unlimited();
    return next_leaf_metered(source,s,p,init,at,scope,0,ref mut fuel);
}
pub fn Result<u8,errors::Error> next_leaf_metered(ref u8[] source,ref mut lexer::State s,ref ir::Program p,
    ref mut Initializer init,usize at,ref context::Table scope,usize deadline,ref mut usize fuel){
    var initializer_work::State w=initializer_work::begin_next(at);
    return drive_initializer(source,s,p,init,scope,ref mut w,deadline,fuel);
}
fn Result<u8,errors::Error> drive_initializer(ref u8[] source,ref mut lexer::State s,ref ir::Program p,
    ref mut Initializer init,ref context::Table scope,ref mut initializer_work::State w,usize deadline,ref mut usize fuel){
    var budget::State meter=budget::empty();
    while(!w.done){
        discard budget::visit(fuel,deadline,s.begin)?;
        let usize allowance=budget::reset(ref mut meter,s.begin)?;
        let bool done=initializer_work::advance(source,s,p,init,scope,w,ref mut meter)?;
    }
    return initializer_work::prepared(w);
}
pub fn Result<usize,errors::Error> advance(ref u8[] source,ref mut lexer::State s,ref ir::Program p,ref mut Initializer init){
    var usize fuel=budget::unlimited();
    return advance_metered(source,s,p,init,0,ref mut fuel);
}
pub fn Result<usize,errors::Error> advance_metered(ref u8[] source,ref mut lexer::State s,ref ir::Program p,
    ref mut Initializer init,usize deadline,ref mut usize fuel){
    let context::Table scope=context::empty();var initializer_work::State w=initializer_work::begin_advance();
    let u8 ready=drive_initializer(source,s,p,init,ref scope,ref mut w,deadline,fuel)?;
    return .ok(0);
}
