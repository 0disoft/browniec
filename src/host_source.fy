module host_source;

import errors as errors;
import host_catalog as catalog;
import host_program as programs;
import ir as ir;
import lexer as lexer;
import module_index as modules;
import source_snapshot as sources;
import literal_source_work as decoding;
import metadata_budget as budget;
import runtime_clock as clock;
import locals as locals;
import argument_name_work as names_work;
import array_source as arrays;
import host_wire as wire;
import std::num as num;
import types as types;

pub struct Name { usize begin; usize scope_end; usize symbol; usize end; }
struct Alias { usize begin; usize end; usize imports; }
pub struct Call { u8 id; usize argc; u8 result; usize parameters; }
pub struct Invocation { Call call; usize first; usize at; }
pub struct Branch { usize request; usize success_jump; usize success; usize error; usize saved; }

// Private compile-only prefix of list_operands. No scratch is retained in Host IR.
// One row per catalog import, then sorted (source offset, import ID) records.
// An alias call uses at least six tokens, so 256 entries suffice.
fn usize rows(){return 64*34;}
fn usize scratch_bytes(){return 64*34+2+3*256;}

fn bool word(ref u8[] source,ref lexer::State s,ref u8[] text){
    return s.kind==2 && lexer::equal(source[s.begin..s.end],text);
}

pub fn Result<bool,errors::Error> qualified(ref u8[] source,ref lexer::State s,ref ir::Program code,usize deadline,ref mut usize fuel){
    if(s.kind!=2 && s.kind!=5){return .ok(false);}
    switch(lookup(code,s.begin,deadline,fuel)){
    case .ok(_):{return .ok(true);}
    case .err(e):{if(e.kind==4 || e.kind==errors::deadline_kind()){return .err(e);}}
    };
    if(s.kind==5 || !word(source,s,b"host")){return .ok(false);}
    var lexer::State next=lexer::snapshot(s);
    let usize read=lexer::next_with_budget(source,ref mut next,deadline,fuel)?;
    return .ok(next.kind==58);
}

pub fn Result<Name,errors::Error> name(ref u8[] source,ref mut lexer::State s,usize deadline,ref mut usize fuel){
    if(s.kind!=5){return raw_name(source,s,deadline,fuel);}
    var lexer::State raw=lexer::empty();raw.cursor=s.begin;
    discard lexer::next_with_budget(source,ref mut raw,deadline,fuel)?;
    let Name item=raw_name(source,ref mut raw,deadline,fuel)?;
    if(item.end!=s.end){return .err(errors::make(2,s.begin));}
    discard lexer::next_with_budget(source,s,deadline,fuel)?;
    if(s.kind!=40){return .err(errors::make(2,s.begin));}
    return .ok(item);
}
fn Result<Name,errors::Error> raw_name(ref u8[] source,ref mut lexer::State s,usize deadline,ref mut usize fuel){
    let usize begin=s.begin;
    let bool absolute=word(source,s,b"host");
    let usize first=lexer::next_with_budget(source,s,deadline,fuel)?;
    var usize segments=0;
    while(s.kind==58){
        let usize scope_end=s.begin;
        let usize colon=lexer::punctuation_with_budget(source,s,58,deadline,fuel)?;
        let usize separator=lexer::punctuation_with_budget(source,s,58,deadline,fuel)?;
        if(s.kind!=2){return .err(errors::make(2,s.begin));}
        let usize symbol=s.begin;
        let usize end=s.end;
        let usize next=lexer::next_with_budget(source,s,deadline,fuel)?;
        segments+=1;
        if(s.kind!=58){
            if((absolute && segments<2) || (!absolute && segments!=1) || s.kind!=40){
                return .err(errors::make(2,s.begin));
            }
            return .ok(Name{.begin=begin,.scope_end=scope_end,.symbol=symbol,.end=end});
        }
    }
    return .err(errors::make(2,s.begin));
}

fn Result<bool,errors::Error> binding_equal(ref u8[] left,ref u8[] right,
    usize at,usize deadline,ref mut usize fuel){
    if(left.len!=right.len){return .ok(false);}
    var usize begin=0;
    while(begin<left.len){
        discard budget::visit(fuel,deadline,at)?;
        let usize end=begin+if(left.len-begin<64){left.len-begin}else{64};
        if(!lexer::equal(left[begin..end],right[begin..end])){return .ok(false);}
        begin=end;
    }
    return .ok(true);
}

// Compare the canonical catalog spelling to lexer tokens from the original
// source, keeping byte offsets and ignoring trivia between path components.
fn Result<bool,errors::Error> scope_matches(ref u8[] source,usize begin,usize end,ref u8[] scope,usize deadline,ref mut usize fuel){
    if(binding_equal(source[begin..end],scope,begin,deadline,fuel)?){return .ok(true);}
    if(end-begin<=scope.len){return .ok(false);}
    var lexer::State part=lexer::empty();part.cursor=begin;
    let usize first=lexer::next_with_budget(source,ref mut part,deadline,fuel)?;
    var usize i=0;
    while(part.begin<end){
        let usize size=part.end-part.begin;
        if(size>scope.len-i || !binding_equal(source[part.begin..part.end],scope[i..i+size],part.begin,deadline,fuel)?){
            return .ok(false);
        }
        i+=size;
        let usize next=lexer::next_with_budget(source,ref mut part,deadline,fuel)?;
    }
    return .ok(i==scope.len);
}

fn Result<Alias,errors::Error> read_alias(ref u8[] source,ref mut lexer::State s,ref catalog::Catalog imports,ref mut usize fuel){
    let usize keyword=lexer::word(source,s,b"import")?;
    let usize start=s.begin;
    let usize root_end=s.end;
    let usize root=lexer::word(source,s,b"host")?;
    var usize end=root_end;
    while(s.kind==58){
        let usize colon=lexer::next(source,s)?;
        let usize separator=lexer::punctuation(source,s,58)?;
        if(s.kind!=2){return .err(errors::make(2,s.begin));}
        end=s.end;
        let usize next=lexer::next(source,s)?;
    }
    if(end==root_end){return .err(errors::make(2,s.begin));}
    let usize as_word=lexer::word(source,s,b"as")?;
    let usize alias=s.begin;
    let usize alias_end=s.end;
    if(s.kind!=2 || word(source,s,b"host") || locals::reserved(source[alias..alias_end])){
        return .err(errors::make(2,alias));
    }
    let usize next=lexer::next(source,s)?;
    let usize semicolon=lexer::punctuation(source,s,59)?;
    var usize mask=0;
    var usize i=0;
    let usize one=1;
    while(i<catalog::count(imports)){
        let ref u8[] scope=switch(catalog::module_name(imports,i)){case .ok(v):{v}case .err(_):{assert(false);b""}};
        if(scope_matches(source,start,end,scope,0,fuel)?){mask|=one<<i;}
        i+=1;
    }
    if(mask==0){return .err(errors::make(3,start));}
    return .ok(Alias{.begin=alias,.end=alias_end,.imports=mask});
}

fn Result<u8,errors::Error> import_id(ref u8[] source,Name item,ref catalog::Catalog imports,bool absolute,usize mask,usize deadline,ref mut usize fuel){
    var u8 id=0;
    let usize one=1;
    while((id as usize)<catalog::count(imports)){
        discard budget::visit(fuel,deadline,item.symbol)?;
        let usize i=id as usize;
        let ref u8[] symbol=switch(catalog::symbol(imports,i)){case .ok(v):{v}case .err(_):{assert(false);b""}};
        if(binding_equal(symbol,source[item.symbol..item.end],item.symbol,deadline,fuel)?){
            if(absolute){
                let ref u8[] scope=switch(catalog::module_name(imports,i)){case .ok(v):{v}case .err(_):{assert(false);b""}};
                if(scope_matches(source,item.begin,item.scope_end,scope,deadline,fuel)?){return .ok(id);}
            }else if((mask&(one<<i))!=0){return .ok(id);}
        }
        id+=1;
    }
    return .ok(64);
}

fn u8 small(usize value){
    let i64 n=switch(num::i64_from_usize(value)){case .ok(v):{v}case .err(_):{assert(false);0}};
    return switch(num::u8_from_i64(n)){case .ok(v):{v}case .err(_):{assert(false);0}};
}

// Binding is advisory: the retaining verifier rechecks the exact catalog.
fn Result<usize,errors::Error> prepare_signatures(ref mut ir::Program code,ref catalog::Catalog imports,
    usize deadline,ref mut usize fuel){
    if(code.list_used!=0){return .err(errors::make(5,0));}
    var usize i=0;
    while(i<catalog::count(imports)){
        discard budget::visit(fuel,deadline,0)?;
        let usize at=i*34;
        let usize argc=switch(catalog::parameter_count(imports,i)){case .ok(v):{v}case .err(_):{assert(false);0}};
        let u8 tag=switch(catalog::result_tag(imports,i)){case .ok(v):{v}case .err(_):{assert(false);0}};
        code.list_operands[at]=small(argc);code.list_operands[at+1]=wire::register_tag(tag);
        var usize j=0;
        while(j<argc){
            discard budget::visit(fuel,deadline,0)?;
            let u8 parameter=switch(catalog::parameter_tag(imports,i,j)){case .ok(v):{v}case .err(_):{assert(false);0}};
            code.list_operands[at+2+j]=wire::register_tag(parameter);j+=1;
        }
        i+=1;
    }
    code.list_used=scratch_bytes();
    return .ok(i);
}

pub fn Result<usize,errors::Error> prepare(ref u8[] source,ref mut ir::Program code,ref catalog::Catalog imports,usize token_limit){
    var usize fuel=budget::unlimited();
    discard prepare_signatures(code,imports,0,ref mut fuel)?;
    var lexer::State s=lexer::empty();
    let usize first=lexer::next(source,ref mut s)?;
    let usize module_word=lexer::word(source,ref mut s,b"module")?;
    let usize module_name=lexer::word(source,ref mut s,b"main")?;
    let usize module_end=lexer::punctuation(source,ref mut s,59)?;
    var Alias[64] aliases=[Alias{.begin=0,.end=0,.imports=0};64];
    var usize aliases_used=0;
    while(word(source,ref s,b"import")){
        if(aliases_used==64){return .err(errors::make(4,s.begin));}
        let Alias item=read_alias(source,ref mut s,imports,ref mut fuel)?;
        if(alias_mask(source,ref aliases[..aliases_used],item.begin,item.end,0,ref mut fuel)?!=0){
            return .err(errors::make(3,item.begin));
        }
        aliases[aliases_used]=item;
        aliases_used+=1;
    }
    let usize declarations=s.begin;
    let usize count=collect_calls(source,ref mut s,code,imports,ref aliases[..aliases_used],0,0,0,ref mut fuel)?;
    // The lexer also counts its end-of-file marker. Policy counts source tokens.
    if(s.tokens-1>token_limit){return .err(errors::make(4,s.begin));}
    store_count(code,count);
    return .ok(declarations);
}

fn void store_count(ref mut ir::Program code,usize count){
    code.list_operands[rows()]=small(count%256);
    code.list_operands[rows()+1]=small(count/256);
}

fn Result<usize,errors::Error> collect_calls(ref u8[] source,ref mut lexer::State s,ref mut ir::Program code,
    ref catalog::Catalog imports,ref Alias[] aliases,usize base,usize initial,usize deadline,ref mut usize fuel){
    var usize count=initial;
    while(s.kind!=0){
        if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
        discard budget::prepay(fuel,s.begin)?;
        if(s.kind==2){
            let bool absolute=word(source,s,b"host");
            let usize mask=alias_mask(source,aliases,s.begin,s.end,deadline,fuel)?;
            if(absolute || mask!=0){
                var lexer::State look=lexer::snapshot(s);
                switch(raw_name(source,ref mut look,deadline,fuel)){
                case .ok(item):{
                    let u8 id=import_id(source,item,imports,absolute,mask,deadline,fuel)?;
                    if(id==64){return .err(errors::make(3,item.begin));}
                    if(count==256){return .err(errors::make(4,item.begin));}
                    let usize at=rows()+2+3*count;
                    let usize offset=base+item.begin;
                    code.list_operands[at]=small(offset%256);
                    code.list_operands[at+1]=small(offset/256);
                    code.list_operands[at+2]=id;
                    count+=1;
                    *s=look;
                    continue;
                }
                case .err(e):{if(e.kind==4 || e.kind==errors::deadline_kind()){return .err(e);}}
                };
            }
        }
        discard lexer::next_with_budget(source,s,deadline,fuel)?;
    }
    return .ok(count);
}

fn errors::Error binding_error(modules::Error error){return errors::make(5,error.at.start);}

fn Result<usize,errors::Error> module_calls(ref u8[] source,ref modules::Index index,usize file,usize base,
    ref mut ir::Program code,ref catalog::Catalog imports,usize calls,usize deadline,ref mut usize fuel){
    var Alias[64] aliases=[Alias{.begin=0,.end=0,.imports=0};64];
    var usize used=0;
    var usize row=0;
    while(row<modules::import_count(index)){
        discard budget::visit(fuel,deadline,0)?;
        let modules::Import item=switch(modules::import_at(index,row)){
            case .ok(v):{v}case .err(e):{return .err(binding_error(e));}
        };
        if(item.owner==file && item.target==16){
            let ref u8[] path=switch(modules::import_path(index,row)){
                case .ok(v):{v}case .err(e):{return .err(binding_error(e));}
            };
            let usize mask=scope_mask(imports,path,item.path.start,deadline,fuel)?;
            if(mask==0){return .err(errors::make(3,item.path.start));}
            aliases[used]=Alias{.begin=item.alias.start,.end=item.alias.end,.imports=mask};
            used+=1;
        }
        row+=1;
    }
    var lexer::State s=lexer::empty();
    discard lexer::next_with_budget(source,ref mut s,deadline,fuel)?;
    return collect_calls(source,ref mut s,code,imports,ref aliases[..used],base,calls,deadline,fuel);
}

fn Result<usize,errors::Error> scope_mask(ref catalog::Catalog imports,ref u8[] path,usize at,usize deadline,ref mut usize fuel){
    var usize mask=0;var usize i=0;let usize one=1;
    while(i<catalog::count(imports)){
        discard budget::visit(fuel,deadline,at)?;
        let ref u8[] scope=switch(catalog::module_name(imports,i)){
            case .ok(v):{v}case .err(_):{assert(false);b""}
        };
        if(binding_equal(path,scope,at,deadline,fuel)?){mask|=one<<i;}
        i+=1;
    }
    return .ok(mask);
}

pub fn Result<usize,errors::Error> prepare_project(ref modules::Index index,ref mut ir::Program code,
    ref catalog::Catalog imports,ref mut usize active,usize deadline,ref mut usize fuel){
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    discard prepare_signatures(code,imports,deadline,fuel)?;
    let ref sources::Snapshot snapshot=modules::snapshot(index);
    var usize base=0;var usize file=0;var usize count=0;
    while(file<modules::count(index)){
        *active=file;
        let sources::Span all=switch(sources::whole(snapshot,file)){
            case .ok(v):{v}case .err(_):{return .err(errors::make(5,base));}
        };
        let ref u8[] source=switch(sources::view(snapshot,all)){
            case .ok(v):{v}case .err(_):{return .err(errors::make(5,base));}
        };
        if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
        discard budget::prepay(fuel,base)?;
        count=switch(module_calls(source,index,file,base,code,imports,count,deadline,fuel)){
            case .ok(v):{v}
            case .err(e):{return .err(if(e.location==errors::absent_location()){e}else{errors::make(e.kind,base+e.offset)});}
        };
        base+=source.len;file+=1;
    }
    *active=16;
    store_count(code,count);
    return .ok(count);
}

fn Result<usize,errors::Error> alias_mask(ref u8[] source,ref Alias[] aliases,usize begin,usize end,usize deadline,ref mut usize fuel){
    var usize i=0;
    while(i<aliases.len){
        discard budget::visit(fuel,deadline,begin)?;
        let Alias item=aliases[i];
        if(binding_equal(source[item.begin..item.end],source[begin..end],begin,deadline,fuel)?){return .ok(item.imports);}
        i+=1;
    }
    return .ok(0);
}

fn Result<u8,errors::Error> lookup(ref ir::Program code,usize at,usize deadline,ref mut usize fuel){
    if(code.list_used<scratch_bytes()){return .err(errors::make(5,at));}
    var usize lo=0;
    var usize hi=code.list_operands[rows()] as usize+256*(code.list_operands[rows()+1] as usize);
    if(hi>256){return .err(errors::make(5,at));}
    while(lo<hi){
        discard budget::visit(fuel,deadline,at)?;
        let usize mid=lo+(hi-lo)/2;let usize entry=rows()+2+3*mid;
        let usize begin=code.list_operands[entry] as usize+256*(code.list_operands[entry+1] as usize);
        if(begin==at){return .ok(code.list_operands[entry+2]);}
        if(begin<at){lo=mid+1;}else{hi=mid;}
    }
    return .err(errors::make(3,at));
}

pub fn Result<Call,errors::Error> signature(ref ir::Program code,usize at,usize deadline,ref mut usize fuel){
    let u8 id=lookup(code,at,deadline,fuel)?;
    if(id>=64){return .err(errors::make(5,at));}
    let usize row=(id as usize)*34;
    let usize argc=code.list_operands[row] as usize;
    let u8 result=code.list_operands[row+1];
    if(argc>32){return .err(errors::make(5,at));}
    if(!types::scalar(result) && result!=14){return .err(errors::make(3,at));}
    return .ok(Call{.id=id,.argc=argc,.result=result,.parameters=row+2});
}

pub fn Result<usize,errors::Error> finish_until(ref u8[] source,ref mut ir::Program code,usize deadline){
    var usize fuel=budget::unlimited();
    return finish_metered(source,code,deadline,ref mut fuel);
}
pub fn Result<usize,errors::Error> finish_metered(ref u8[] source,ref mut ir::Program code,usize deadline,ref mut usize fuel){
    var Finish w=begin_finish();
    var budget::State meter=budget::empty();
    while(!w.done){
        if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
        let usize allowance=budget::reset_metered(ref mut meter,fuel,0)?;
        let bool done=advance_finish(source,code,ref mut w,ref mut meter)?;
    }
    if(clock::expired(deadline)){return .err(errors::absent(errors::deadline_kind(),0));}
    return .ok(code.count);
}

// The owner pins the original source and lowered IR through all advances.
// Only the unpublished candidate can contain partially packed literal bytes.
pub struct Finish { decoding::State decoded; usize cursor; usize pc; u8 phase; bool done; }
pub fn Finish begin_finish(){return Finish{.decoded=decoding::empty(0),.cursor=0,.pc=0,.phase=0,.done=false};}

fn void start_literal(ref mut decoding::State w,usize at){
    w.result.begin=at;w.result.end=at;w.result.length=0;w.result.text=false;
    w.cursor=at;w.checked=0;w.visits=0;w.phase=0;w.done=false;
}
pub fn Result<bool,errors::Error> advance_finish(ref u8[] source,ref mut ir::Program code,
    ref mut Finish w,ref mut budget::State meter){
    if(w.done){return .ok(true);}
    if(meter.last!=0){return .ok(false);}
    if(w.phase==3){
        let bool ready=decoding::advance(source,ref mut w.decoded,meter)?;
        if(!ready){return .ok(false);}
        let usize at=w.decoded.result.begin;
        if(w.decoded.result.text){return .err(errors::make(3,at));}
        if(w.decoded.result.length>4096-code.list_used){return .err(errors::make(4,at));}
        w.cursor=0;w.phase=4;return .ok(false);
    }
    if(!budget::admit(meter,128,0)?){return .ok(false);}
    if(w.phase==0){
        if(code.list_used!=scratch_bytes() || code.count>256){return .err(errors::make(3,0));}
        w.phase=1;return .ok(false);
    }
    if(w.phase==1){
        let usize count=scratch_bytes()-w.cursor;
        let usize end=w.cursor+if(count<64){count}else{64};
        while(w.cursor<end){code.list_operands[w.cursor]=0;w.cursor+=1;}
        if(end==scratch_bytes()){code.list_used=0;w.phase=2;}
        return .ok(false);
    }
    if(w.phase==2){
        let usize count=code.count-w.pc;
        let usize end=w.pc+if(count<64){count}else{64};
        while(w.pc<end){
            if(code.code[w.pc*8]==119){
                let usize at=code.offsets[w.pc];start_literal(ref mut w.decoded,at);w.phase=3;return .ok(false);
            }
            w.pc+=1;
        }
        w.done=w.pc==code.count;return .ok(w.done);
    }
    if(w.phase==4){copy_literal(code,w);return .ok(false);}
    return .err(errors::make(5,0));
}

fn void copy_literal(ref mut ir::Program code,ref mut Finish w){
    let usize start=code.list_used;
    let usize length=w.decoded.result.length;
    let ref u8[] data=ref w.decoded.result.data;
    let usize left=length-w.cursor;
    let usize end=w.cursor+if(left<64){left}else{64};
    var usize i=w.cursor;
    while(i<end){code.list_operands[start+i]=data[i];i+=1;}
    w.cursor=end;
    if(end!=length){return;}
    let usize at=w.pc*8;
    code.code[at+2]=small(start%256);code.code[at+3]=small(start/256);
    code.code[at+4]=small(length%256);code.code[at+5]=small(length/256);
    code.list_used=start+length;
    w.pc+=1;w.phase=2;
}

pub fn Result<usize,errors::Error> byte_argument_metered(ref u8[] source,ref mut lexer::State s,
    ref mut ir::Program code,ref locals::Table names,usize deadline,ref mut usize fuel){
    let usize at=s.begin;
    if(s.kind==3){
        discard lexer::next_with_budget(source,s,deadline,fuel)?;
        if(code.registers>=128){return .err(errors::make(4,at));}
        discard budget::visit(fuel,deadline,at)?;
        let usize dst=code.registers;
        discard ir::raw(code,119,dst,0,0,at)?;
        code.types[dst]=14;code.registers+=1;
        return .ok(dst);
    }
    if(!word(source,s,b"ref")){return .err(errors::make(2,at));}
    discard lexer::next_with_budget(source,s,deadline,fuel)?;
    if(s.kind!=2){return .err(errors::make(3,s.begin));}
    let usize index=names_work::local_metered(source,names,s.begin,s.end,deadline,fuel)?;
    if(index==64){return .err(errors::make(3,s.begin));}
    let usize value=names.registers[index];
    if(value>=128 || code.types[value]!=14){return .err(errors::make(3,s.begin));}
    discard lexer::next_with_budget(source,s,deadline,fuel)?;
    return .ok(value);
}

// Only a fresh reply can introduce a byte owner. Name-to-name copies and
// mutable bindings require the general value/ownership path.
pub fn bool fresh_bytes(ref ir::Program code,usize before,usize result){
    if(before>=code.count){return false;}
    let usize at=(code.count-1)*8;
    return (code.code[at]==programs::typed_request_opcode() || code.code[at]==programs::project_opcode())
        && code.code[at+1] as usize==result;
}

pub fn Result<Invocation,errors::Error> invoke(ref mut ir::Program code,Call call,ref usize[] args,usize at,usize deadline,ref mut usize fuel){
    let usize start=if(call.argc==0){0}else{args[0]};
    var usize i=0;
    while(i<call.argc){
        discard budget::visit(fuel,deadline,at)?;
        if(args[i]!=start+i){break;}
        i+=1;
    }
    let usize first=if(i==call.argc){start}else{code.registers};
    if(i!=call.argc){
        i=0;
        while(i<call.argc){
            discard budget::visit(fuel,deadline,at)?;
            discard ir::emit(code,programs::copy_opcode(),args[i],0,at)?;
            i+=1;
        }
    }
    return .ok(Invocation{.call=call,.first=first,.at=at});
}

fn Result<usize,errors::Error> request(ref mut ir::Program code,ref Invocation call,u8 op){
    if(code.registers>=128){return .err(errors::make(4,call.at));}
    let usize dst=code.registers;
    let usize pc=ir::raw(code,op,dst,call.first,call.call.id as usize,call.at)?;
    code.registers+=1;code.types[dst]=call.call.result;
    code.code[pc*8+4]=small(call.call.argc);
    return .ok(dst);
}

pub fn Result<usize,errors::Error> emit(ref mut ir::Program code,ref Invocation call){
    if(call.call.argc==1 && call.call.result==1 && code.types[call.first]==1){
        return ir::emit(code,programs::request_opcode(),call.first,call.call.id as usize,call.at);
    }
    return request(code,call,programs::typed_request_opcode());
}

fn Result<u8,errors::Error> buffer_type(ref u8[] source,ref mut lexer::State s){
    discard lexer::word(source,s,b"brownie")?;
    discard lexer::punctuation(source,s,58)?;
    discard lexer::punctuation(source,s,58)?;
    discard lexer::word(source,s,b"bytes")?;
    discard lexer::punctuation(source,s,58)?;
    discard lexer::punctuation(source,s,58)?;
    discard lexer::word(source,s,b"Buffer")?;
    return .ok(14);
}

fn Result<u8,errors::Error> host_success_type(ref u8[] source,ref mut lexer::State s){
    if(s.kind==5){
        // The indexed lexer folds a qualified name into one token. Parse the
        // original span without changing the scoped cursor or token counts.
        let ref u8[] spelling=source[s.begin..s.end];
        var lexer::State raw=lexer::empty();
        discard lexer::next(spelling,ref mut raw)?;
        let Result<u8,errors::Error> parsed=buffer_type(spelling,ref mut raw);
        if(!parsed.is_ok || raw.kind!=0){return .err(errors::make(3,s.begin));}
        discard lexer::next(source,s)?;
        return .ok(14);
    }
    if(word(source,s,b"brownie")){return buffer_type(source,s);}
    return types::parse_raw(source,s);
}

pub fn Result<u8,errors::Error> annotation(ref u8[] source,ref mut lexer::State s){
    let usize head=lexer::word(source,s,b"Result")?;
    let usize open=lexer::punctuation(source,s,60)?;
    let u8 success=host_success_type(source,s)?;
    if(!types::host_success(success)){return .err(errors::make(3,head));}
    let usize separator=lexer::punctuation(source,s,44)?;
    let usize error=lexer::word(source,s,b"u32")?;
    let usize close=lexer::punctuation(source,s,62)?;
    return .ok(success);
}

pub fn Result<usize,errors::Error> save(ref mut ir::Program code,ref Invocation call){
    if(code.registers>126){return .err(errors::make(4,call.at));}
    let usize dst=request(code,call,programs::value_request_opcode())?;
    code.types[dst]=types::host_result();code.types[dst+1]=128+call.call.result;
    code.registers+=1;
    return .ok(dst);
}

pub fn bool is_saved(ref ir::Program code,usize r){
    return r<127 && r+1<code.registers && code.types[r]==types::host_result();
}

pub fn Result<usize,errors::Error> project(ref mut ir::Program code,usize value,u8 variant,usize at){
    if(!is_saved(code,value) || variant>2){return .err(errors::make(3,at));}
    let u8 tag=if(variant==2){2}else if(variant==0){11}else{code.types[value+1]-128};
    let usize dst=ir::emit(code,programs::project_opcode(),value,variant as usize,at)?;
    code.types[dst]=tag;
    return .ok(dst);
}

pub fn Result<usize,errors::Error> wrap(ref mut ir::Program code,u8 result,u8 variant,usize value,usize at){
    if(!types::host_result_type(result) || variant>1 || value>=code.registers ||
        code.types[value]!=if(variant==0){11}else{result-128}){return .err(errors::make(3,at));}
    let usize dst=code.registers;
    let usize pair=ir::host_pair(code,dst,result,at)?;
    let usize pc=ir::raw(code,programs::wrap_opcode(),dst,value,variant as usize,at)?;
    return .ok(pair);
}

pub fn Result<usize,errors::Error> propagate(ref mut ir::Program code,ref locals::Table names,usize value,u8 result,usize at){
    if(!types::host_result_type(result)){return .err(errors::make(3,at));}
    let Branch route=branch_saved(code,value,at)?;
    let usize error=enter_arm(code,ref route,0,true,at)?;
    let usize returned=wrap(code,result,0,error,at)?;
    let usize released=arrays::release_visible(names,code,at)?;
    let usize finished=ir::emit(code,8,returned,0,at)?;
    return enter_arm(code,ref route,1,true,at);
}

pub fn Result<Branch,errors::Error> branch_saved(ref mut ir::Program code,usize value,usize at){
    let usize predicate=project(code,value,2,at)?;
    let usize success=ir::raw(code,21,0,predicate,0,at)?;
    let usize failure=ir::raw(code,19,0,0,0,at)?;
    return .ok(Branch{.request=failure,.success_jump=success,.success=0,.error=0,.saved=value});
}

pub fn Result<Branch,errors::Error> branch(ref mut ir::Program code,ref Invocation call){
    if(code.registers>126){return .err(errors::make(4,call.at));}
    let usize pc=code.count;
    let usize success=request(code,call,programs::result_request_opcode())?;
    let usize error=code.registers;
    code.registers+=1;code.types[error]=11;
    code.code[pc*8+5]=small(error);
    let usize jump=ir::raw(code,19,0,0,0,call.at)?;
    return .ok(Branch{.request=pc,.success_jump=jump,.success=success,.error=error,.saved=256});
}

pub fn Result<usize,errors::Error> enter_arm(ref mut ir::Program code,ref Branch route,u8 variant,bool binding,usize at){
    let usize target=code.count;
    if(target>=256){return .err(errors::make(4,at));}
    if(route.saved!=256){
        let usize edge=if(variant==1){route.success_jump}else{route.request};
        let usize patched=ir::patch(code,edge,target,at)?;
        return if(binding){project(code,route.saved,variant,at)}else{.ok(0)};
    }
    if(variant==1){
        let usize patched=ir::patch(code,route.success_jump,target,at)?;
        return .ok(route.success);
    }
    code.code[route.request*8+6]=small(target);
    return .ok(route.error);
}
