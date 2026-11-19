module host_source;

import errors as errors;
import host_catalog as catalog;
import host_program as programs;
import ir as ir;
import lexer as lexer;
import literal_source as literals;
import locals as locals;
import host_wire as wire;
import std::num as num;
import types as types;

pub struct Name { usize begin; usize scope_end; usize symbol; usize end; }
pub struct Call { u8 id; usize argc; u8 result; usize parameters; }
pub struct Invocation { Call call; usize first; usize at; }
pub struct Branch { usize request; usize success_jump; usize success; usize error; usize saved; }

// Private compile-only prefix of list_operands. No scratch is retained in Host IR.
// One row per catalog import, then sorted (source offset, import ID) records.
// Every qualified call needs at least seven tokens, so 256 entries suffice.
fn usize rows(){return 64*34;}
fn usize scratch_bytes(){return 64*34+2+3*256;}

pub fn Result<bool,errors::Error> qualified(ref u8[] source,ref lexer::State s){
    if(s.kind!=2 || !lexer::equal(source[s.begin..s.end],b"host")){return .ok(false);}
    var lexer::State next=lexer::snapshot(s);
    let usize read=lexer::next(source,ref mut next)?;
    return .ok(next.kind==58);
}

pub fn Result<Name,errors::Error> name(ref u8[] source,ref mut lexer::State s){
    let usize begin=s.begin;
    let usize root=lexer::word(source,s,b"host")?;
    var usize scope_end=s.begin;
    var usize segments=0;
    while(s.kind==58){
        scope_end=s.begin;
        let usize colon=lexer::punctuation(source,s,58)?;
        let usize separator=lexer::punctuation(source,s,58)?;
        if(s.kind!=2){return .err(errors::make(2,s.begin));}
        let usize symbol=s.begin;
        let usize end=s.end;
        let usize next=lexer::next(source,s)?;
        segments+=1;
        if(s.kind!=58){
            if(segments<2 || s.kind!=40){return .err(errors::make(2,s.begin));}
            return .ok(Name{.begin=begin,.scope_end=scope_end,.symbol=symbol,.end=end});
        }
    }
    return .err(errors::make(2,s.begin));
}

fn u8 import_id(ref u8[] source,Name item,ref catalog::Catalog imports){
    var u8 id=0;
    while((id as usize)<catalog::count(imports)){
        let usize i=id as usize;
        let ref u8[] scope=switch(catalog::module_name(imports,i)){case .ok(v):{v}case .err(_):{assert(false);b""}};
        let ref u8[] symbol=switch(catalog::symbol(imports,i)){case .ok(v):{v}case .err(_):{assert(false);b""}};
        if(lexer::equal(scope,source[item.begin..item.scope_end]) && lexer::equal(symbol,source[item.symbol..item.end])){
            return id;
        }
        id+=1;
    }
    return 64;
}

fn u8 small(usize value){
    let i64 n=switch(num::i64_from_usize(value)){case .ok(v):{v}case .err(_):{assert(false);0}};
    return switch(num::u8_from_i64(n)){case .ok(v):{v}case .err(_):{assert(false);0}};
}

// Scan with the same initial lexer state as the single-source body lowerer.
// Binding is advisory: the retaining verifier rechecks the exact catalog.
pub fn Result<usize,errors::Error> prepare(ref u8[] source,usize body,ref mut ir::Program code,ref catalog::Catalog imports){
    if(code.list_used!=0){return .err(errors::make(5,body));}
    code.list_used=scratch_bytes();
    var usize i=0;
    while(i<catalog::count(imports)){
        let usize at=i*34;
        let usize argc=switch(catalog::parameter_count(imports,i)){case .ok(v):{v}case .err(_):{assert(false);0}};
        let u8 tag=switch(catalog::result_tag(imports,i)){case .ok(v):{v}case .err(_):{assert(false);0}};
        code.list_operands[at]=small(argc);code.list_operands[at+1]=wire::register_tag(tag);
        var usize j=0;
        while(j<argc){
            let u8 parameter=switch(catalog::parameter_tag(imports,i,j)){case .ok(v):{v}case .err(_):{assert(false);0}};
            code.list_operands[at+2+j]=wire::register_tag(parameter);j+=1;
        }
        i+=1;
    }
    var usize count=0;
    var lexer::State s=lexer::empty();s.cursor=body;
    let usize first=lexer::next(source,ref mut s)?;
    while(s.kind!=0){
        if(qualified(source,ref s)?){
            var lexer::State look=lexer::snapshot(ref s);
            switch(name(source,ref mut look)){
                case .ok(item):{
                    let u8 id=import_id(source,item,imports);
                    if(id<64){
                        if(count==256){return .err(errors::make(4,item.begin));}
                        let usize at=rows()+2+3*count;
                        code.list_operands[at]=small(item.begin%256);
                        code.list_operands[at+1]=small(item.begin/256);
                        code.list_operands[at+2]=id;
                        count+=1;
                    }
                    s=look;continue;
                }
                case .err(_):{}
            };
        }
        let usize next=lexer::next(source,ref mut s)?;
    }
    code.list_operands[rows()]=small(count%256);
    code.list_operands[rows()+1]=small(count/256);
    return .ok(code.list_used);
}

fn Result<u8,errors::Error> lookup(ref ir::Program code,usize at){
    if(code.list_used<scratch_bytes()){return .err(errors::make(5,at));}
    var usize lo=0;
    var usize hi=code.list_operands[rows()] as usize+256*(code.list_operands[rows()+1] as usize);
    if(hi>256){return .err(errors::make(5,at));}
    while(lo<hi){
        let usize mid=lo+(hi-lo)/2;let usize entry=rows()+2+3*mid;
        let usize begin=code.list_operands[entry] as usize+256*(code.list_operands[entry+1] as usize);
        if(begin==at){return .ok(code.list_operands[entry+2]);}
        if(begin<at){lo=mid+1;}else{hi=mid;}
    }
    return .err(errors::make(3,at));
}

pub fn Result<Call,errors::Error> signature(ref ir::Program code,usize at){
    let u8 id=lookup(code,at)?;
    if(id>=64){return .err(errors::make(5,at));}
    let usize row=(id as usize)*34;
    let usize argc=code.list_operands[row] as usize;
    let u8 result=code.list_operands[row+1];
    if(argc>32){return .err(errors::make(5,at));}
    if(!types::scalar(result) && result!=14){return .err(errors::make(3,at));}
    return .ok(Call{.id=id,.argc=argc,.result=result,.parameters=row+2});
}

pub fn Result<usize,errors::Error> finish(ref u8[] source,ref mut ir::Program code){
    if(code.list_used!=scratch_bytes()){return .err(errors::make(3,0));}
    var usize i=0;while(i<code.list_used){code.list_operands[i]=0;i+=1;}
    code.list_used=0;
    var usize pc=0;
    while(pc<code.count){
        if(code.code[pc*8]==119){
            let usize at=code.offsets[pc];
            let usize packed=pack_literal(source,code,pc,at)?;
        }
        pc+=1;
    }
    return .ok(code.count);
}

// Literal offsets are authored by the compiler. Build the backing only after
// discarding binding scratch so it cannot reduce the admitted literal capacity.
fn Result<usize,errors::Error> pack_literal(ref u8[] source,ref mut ir::Program code,usize pc,usize at){
    let literals::Decoded decoded=literals::decode(source,at)?;
    let usize start=code.list_used;
    let usize length=decoded.length;
    if(decoded.text){return .err(errors::make(3,at));}
    if(length>4096-start){return .err(errors::make(4,at));}
    var usize i=0;
    while(i<length){code.list_operands[start+i]=decoded.data[i];i+=1;}
    code.code[pc*8+2]=small(start%256);code.code[pc*8+3]=small(start/256);
    code.code[pc*8+4]=small(length%256);code.code[pc*8+5]=small(length/256);
    code.list_used=start+length;
    return .ok(code.list_used);
}

pub fn Result<usize,errors::Error> byte_argument(ref u8[] source,ref mut lexer::State s,ref mut ir::Program code,ref locals::Table names){
    let usize at=s.begin;
    if(s.kind==3){
        let usize next=lexer::next(source,s)?;
        if(code.registers>=128){return .err(errors::make(4,at));}
        let usize dst=code.registers;
        let usize pc=ir::raw(code,119,dst,0,0,at)?;
        code.types[dst]=14;code.registers+=1;
        return .ok(dst);
    }
    let usize borrow=lexer::word(source,s,b"ref")?;
    if(s.kind!=2){return .err(errors::make(3,s.begin));}
    let usize index=locals::find(source,names,s.begin,s.end);
    if(index==64){return .err(errors::make(3,s.begin));}
    let usize value=names.registers[index];
    if(value>=128 || code.types[value]!=14){return .err(errors::make(3,s.begin));}
    let usize next=lexer::next(source,s)?;
    return .ok(value);
}

// Only a fresh reply can introduce a byte owner. Name-to-name copies and
// mutable bindings require the general value/ownership path.
pub fn bool fresh_bytes(ref ir::Program code,usize before,usize result){
    if(before>=code.count){return false;}
    let usize at=(code.count-1)*8;
    return code.code[at]==programs::typed_request_opcode() && code.code[at+1] as usize==result;
}

pub fn Result<Invocation,errors::Error> invoke(ref mut ir::Program code,Call call,ref usize[] args,usize at){
    let usize start=if(call.argc==0){0}else{args[0]};
    var usize i=0;
    while(i<call.argc && args[i]==start+i){i+=1;}
    let usize first=if(i==call.argc){start}else{code.registers};
    if(i!=call.argc){
        i=0;
        while(i<call.argc){let usize saved=ir::emit(code,programs::copy_opcode(),args[i],0,at)?;i+=1;}
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

pub fn Result<u8,errors::Error> annotation(ref u8[] source,ref mut lexer::State s){
    let usize head=lexer::word(source,s,b"Result")?;
    let usize open=lexer::punctuation(source,s,60)?;
    let u8 success=if(s.kind==2 && lexer::equal(source[s.begin..s.end],b"brownie")){
        let usize root=lexer::next(source,s)?;
        let usize a=lexer::punctuation(source,s,58)?;let usize b=lexer::punctuation(source,s,58)?;
        let usize module_name=lexer::word(source,s,b"bytes")?;
        let usize c=lexer::punctuation(source,s,58)?;let usize d=lexer::punctuation(source,s,58)?;
        let usize buffer=lexer::word(source,s,b"Buffer")?;
        14
    }else{types::parse_raw(source,s)?};
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
