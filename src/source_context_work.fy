module source_context_work;
import source_context as context;
import module_index as modules;
import source_snapshot as sources;
import lexer as lexer;
import metadata_budget as budget;

// Private lowering scratch. The owner pins one immutable Index until done.
// Each fresh stage copies <=64 bytes, packs one import/symbol, or checks one
// <=64-byte sealed name. Fixed initial scratch construction is separate.
pub struct State {
    context::Input result; usize file; usize cursor; usize length;
    usize row; usize functions; usize records; usize imports; usize symbols;
    usize visits; u8 phase; bool done;
}
pub fn State empty(){return State{.result=context::Input{.data=[0;4096],.used=0,.context=context::empty()},
    .file=0,.cursor=0,.length=0,.row=0,.functions=0,.records=0,.imports=0,.symbols=0,
    .visits=0,.phase=0,.done=false};}
fn modules::Error invalid(sources::Span at){return modules::Error{.kind=.Bounds,.at=at};}
fn Result<u32,modules::Error> word(usize value,sources::Span at){
    if(value>1073741823){return .err(invalid(at));}
    var usize rest=value;var u32 packed=0;var u32 power=1;
    while(rest!=0){if((rest&1)!=0){packed|=power;}rest>>=1;if(rest!=0){power<<=1;}}
    return .ok(packed);
}
fn usize owner(ref context::Table t,usize at){
    var usize i=0;while(i<t.modules){if(at<t.ends[i] as usize){return i;}i+=1;}return 16;
}
fn bool name(ref context::Input input,u32 item){
    let ref context::Table t=ref input.context;let usize a=context::begin(item);let usize b=context::end(item);
    let ref u8[] data=ref input.data;
    // Index seals all declaration and alias spellings to at most 64 bytes.
    return a<b && b<=input.used && b-a<=64 && owner(t,a)==owner(t,b-1) && lexer::simple(data[..input.used],a,b);
}
pub fn Result<bool,modules::Error> advance(ref modules::Index index,ref mut State w,ref mut budget::State meter){
    if(w.done){return .ok(true);}if(meter.last!=0){return .ok(false);}
    let bool admitted=switch(budget::admit(meter,4096,0)){
        case .ok(v):{v}case .err(_):{return .err(invalid(sources::no_source()));}};
    if(!admitted){return .ok(false);}
    let usize count=modules::count(index);
    if(w.phase==0){
        if(count==0 || count>16 || modules::import_count(index)>64 || modules::symbol_count(index)>48){return .err(invalid(sources::no_source()));}
        w.result.context.modules=count;w.imports=modules::import_count(index);w.symbols=modules::symbol_count(index);
        w.phase=1;return .ok(false);
    }
    if(w.phase==1){
        if(w.file==count){w.phase=3;w.row=0;return .ok(false);}
        let sources::Span all=switch(sources::whole(modules::snapshot(index),w.file)){
            case .ok(v):{v}case .err(_):{return .err(invalid(sources::no_source()));}};
        let ref u8[] source=switch(sources::view(modules::snapshot(index),all)){
            case .ok(v):{v}case .err(_):{return .err(invalid(all));}};
        if(source.len==0 || source.len>4096-w.result.used){return .err(invalid(all));}
        w.cursor=0;w.length=source.len;w.phase=2;return .ok(false);
    }
    if(w.phase==2){
        let sources::Span all=switch(sources::whole(modules::snapshot(index),w.file)){
            case .ok(v):{v}case .err(_):{return .err(invalid(sources::no_source()));}};
        let ref u8[] source=switch(sources::view(modules::snapshot(index),all)){
            case .ok(v):{v}case .err(_):{return .err(invalid(all));}};
        if(source.len!=w.length){return .err(invalid(all));}
        var usize stop=w.cursor+64;if(stop>w.length){stop=w.length;}
        while(w.cursor<stop){let usize position=w.result.used+w.cursor;let u8 value=source[w.cursor];w.result.data[position]=value;w.cursor+=1;w.visits+=1;}
        if(w.cursor==w.length){w.result.used+=w.length;let usize file=w.file;let u32 packed=word(w.result.used,all)?;w.result.context.ends[file]=packed;w.file+=1;w.phase=1;}
        return .ok(false);
    }
    if(w.phase==3){
        if(w.row==w.imports){w.row=0;w.phase=4;return .ok(false);}
        let modules::Import item=modules::import_at(index,w.row)?;
        if(item.target==16){w.row+=1;return .ok(false);}
        if(item.owner>=count || item.target>=count){return .err(invalid(item.alias));}
        let ref context::Table t=ref w.result.context;
        let usize base=if(item.owner==0){0}else{t.ends[item.owner-1] as usize};
        let usize row=w.result.context.imports;
        let u32 packed=word((base+item.alias.start)|((base+item.alias.end)<<13)|(item.target<<26),item.alias)?;
        w.result.context.aliases[row]=packed;w.result.context.imports+=1;
        w.row+=1;return .ok(false);
    }
    if(w.phase==4){
        if(w.row==w.symbols){w.result.context.function_count=w.functions;w.result.context.record_count=w.records;w.row=0;w.phase=5;return .ok(false);}
        let modules::Symbol item=modules::symbol(index,w.row)?;
        if(item.owner>=count){return .err(invalid(item.name));}
        let ref context::Table t=ref w.result.context;
        let usize base=if(item.owner==0){0}else{t.ends[item.owner-1] as usize};
        let u32 packed=word((base+item.name.start)|((base+item.name.end)<<13)|if(item.exported){67108864}else{0},item.name)?;
        if(item.kind==1){if(w.functions==16){return .err(invalid(item.name));}let usize row=w.functions;w.result.context.functions[row]=packed;w.functions+=1;}
        else{if(item.kind!=2 || w.records==32){return .err(invalid(item.name));}let usize row=w.records;w.result.context.records[row]=packed;w.records+=1;}
        w.row+=1;return .ok(false);
    }
    let ref context::Table t=ref w.result.context;
    if(w.phase==5){
        // All ends were checked while copying; the table retains initialized
        // zeros in unused rows, exactly as context::collect.
        if(w.row==t.imports){w.row=0;w.phase=6;return .ok(false);}
        let u32 item=t.aliases[w.row];
        if((item>>30)!=0 || (item as usize>>26)>=count || !name(ref w.result,item)){return .err(invalid(sources::no_source()));}
        w.row+=1;return .ok(false);
    }
    if(w.phase==6 || w.phase==7){
        let usize rows=if(w.phase==6){w.functions}else{w.records};
        if(w.row==rows){w.row=0;if(w.phase==6){w.phase=7;}else{w.done=true;}return .ok(w.done);}
        let u32 item=if(w.phase==6){t.functions[w.row]}else{t.records[w.row]};
        if((item>>27)!=0 || !name(ref w.result,item)){return .err(invalid(sources::no_source()));}
        w.row+=1;return .ok(false);
    }
    return .err(invalid(sources::no_source()));
}
pub fn Result<context::Input,modules::Error> prepared(ref State w){
    if(!w.done){return .err(invalid(sources::no_source()));}return .ok(w.result);
}

fn Result<bool,modules::Error> next_batch(ref modules::Index index,ref mut State w,ref mut budget::State meter){
    let usize allowance=switch(budget::reset(meter,0)){
        case .ok(v):{v}case .err(_):{return .err(invalid(sources::no_source()));}
    };
    return advance(index,w,meter);
}

// Owning compiler compatibility adapter. No public Pending compile protocol.
pub fn Result<context::Input,modules::Error> collect(ref modules::Index index){
    var State w=empty();var budget::State meter=budget::empty();
    while(!w.done){let bool done=next_batch(index,ref mut w,ref mut meter)?;}
    return prepared(ref w);
}
