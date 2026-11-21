module host_program;

import host_catalog as catalog;
import ir as ir;
import runtime_policy as policy;
import runtime_run_config as runs;
import std::bytes as bytes;
import std::vec as vec;
import verifier as verifier;
import runtime_clock as clock;
import metadata_budget as budget;
import errors as errors;
import types as types;
import host_wire as wire;
import source_snapshot as sources;

// Private scalar host dialect. The ordinary verifier still rejects opcode 117.
pub enum Error { Code; Catalog; Binding; Authority; Allocation; Fuel; Deadline; }
struct Digest { u32[8] words; }
struct Authority { usize required; bool emits; }
pub struct SourceMap { usize[16] lengths; }
pub resource Program {
    vec::Vec<ir::Program> code;
    catalog::Catalog catalog;
    Digest digest;
    Authority authority;
    bytes::Buffer module_name;
    bytes::Buffer function_name;
    SourceMap sources;
    cleanup { }
}

pub fn u8 request_opcode(){return 117;}
pub fn u8 typed_request_opcode(){return 118;}
pub fn u8 result_request_opcode(){return 121;}
pub fn u8 copy_opcode(){return 122;}
pub fn u8 value_request_opcode(){return 123;}
pub fn u8 project_opcode(){return 124;}
pub fn u8 wrap_opcode(){return 125;}
pub fn u8 emit_opcode(){return 126;}
pub fn bool typed_request(u8 op){return op==typed_request_opcode() || op==result_request_opcode() || op==value_request_opcode();}

fn bool typed_signature(ref ir::Program p,ref catalog::Catalog imports,usize at){
    let usize dst=p.code[at+1] as usize;let usize first=p.code[at+2] as usize;
    let usize id=p.code[at+3] as usize;let usize argc=p.code[at+4] as usize;
    if(dst>=p.registers || first>p.registers || argc>p.registers-first){return false;}
    let usize count=switch(catalog::parameter_count(imports,id)){case .ok(v):{v}case .err(_):{return false;}};
    let u8 result=switch(catalog::result_tag(imports,id)){case .ok(v):{v}case .err(_):{return false;}};
    let u8 tag=wire::register_tag(result);
    if(argc!=count){return false;}
    if(p.code[at]==value_request_opcode()){
        if(dst+1>=p.registers || p.types[dst]!=types::host_result() || p.types[dst+1]!=128+tag){return false;}
    }else if(tag!=p.types[dst]){return false;}
    var usize i=0;
    while(i<count){
        let u8 tag=switch(catalog::parameter_tag(imports,id,i)){case .ok(v):{v}case .err(_):{return false;}};
        if(wire::register_tag(tag)!=p.types[first+i]){return false;}
        i+=1;
    }
    return true;
}

pub fn bool typed(ref ir::Program code){
    if(code.function_count>1 || code.call_count!=0 || (code.entry<16 && code.arities[code.entry]!=0)){return true;}
    var usize pc=0;
    while(pc<code.count){
        let u8 op=code.code[pc*8];if(typed_request(op) || op==emit_opcode()){return true;}pc+=1;
    }
    return false;
}

// HOST_REQUEST: dst=i32 destination, a=i32 argument, b=catalog import ID.
// The independent scalar verifier checks the same input and output registers
// through an ADD proxy. The proxy is temporary and never executes.
fn Result<usize,Error> prepay(ref mut usize fuel,usize deadline){
    if(clock::expired(deadline)){return .err(.Deadline);}
    if(!budget::prepay(fuel,0).is_ok){return .err(.Fuel);}
    return .ok(0);
}
fn Result<Authority,Error> inspect(ref ir::Program code,ref catalog::Catalog imports,usize deadline,ref mut usize fuel){
    if(code.count==0 || code.count>256 || code.registers>128 ||
        code.function_count==0 || code.function_count>16 || code.entry>=code.function_count || code.arrays.count!=0 ||
        code.records.count!=0 || code.list_used>4096){return .err(.Code);}
    discard prepay(fuel,deadline)?;
    var usize reg=0;
    while(reg<code.registers){
        if(!types::scalar(code.types[reg]) && (code.slots[reg] || (code.types[reg]!=14 && !types::host_storage(code.types[reg])))){return .err(.Code);}
        reg+=1;
    }
    var usize f=0;
    while(f<code.function_count){
        let usize first=code.register_starts[f];
        let usize arity=code.arities[f];
        if((!types::scalar(code.return_types[f]) && !types::host_result_type(code.return_types[f])) ||
            first>code.registers || arity>code.registers-first){
            return .err(.Code);
        }
        let bool input=f==code.entry && arity==1 && code.types[first]==14;
        if(f==code.entry && arity!=0 && !input){return .err(.Code);}
        var usize arg=0;
        while(arg<arity){
            if(!input && !types::scalar(code.types[first+arg])){return .err(.Code);}
            arg+=1;
        }
        f+=1;
    }
    var ir::Program scalar=*code;
    let bool typed_code=typed(code);
    var Authority authority=Authority{.required=0,.emits=false};
    var usize pc=0;
    let usize one=1;
    while(pc<code.count){
        discard prepay(fuel,deadline)?;
        let usize at=pc*8;
        let u8 op=code.code[at];
        if(op==request_opcode()){
            let usize dst=code.code[at+1] as usize;
            let usize arg=code.code[at+2] as usize;
            let usize id=code.code[at+3] as usize;
            if(dst>=code.registers || arg>=code.registers ||
                code.types[dst]!=1 || code.types[arg]!=1){return .err(.Code);}
            if(!scalar_signature(imports,id)){return .err(.Catalog);}
            scalar.code[at]=2;
            scalar.code[at+3]=code.code[at+2];
            authority.required|=one<<id;
        }else if(typed_request(op)){
            if(!typed_signature(code,imports,at)){return .err(.Catalog);}
            authority.required|=one<<(code.code[at+3] as usize);
        }else if(op==9 && code.arities[code.entry]!=0 && (code.code[at+2] as usize)==code.entry){
            return .err(.Code);
        }else if(op==emit_opcode() || op==9 || op==17 || op==18 || op==119 || op==120 || op==copy_opcode() || op==project_opcode() || op==wrap_opcode()){
            if(!typed_code){return .err(.Code);}
            authority.emits=authority.emits || op==emit_opcode();
        }else if(op==2){
            let usize dst=code.code[at+1] as usize;
            if(dst>=code.registers || code.types[dst]!=1){return .err(.Code);}
        }else if(op!=1 && op!=7 && op!=8 && op!=19 && op!=20 && op!=21 && op!=22){
            return .err(.Code);
        }
        pc+=1;
    }
    if(!typed_code){
        var usize r=0;
        while(r<code.registers){if(code.types[r]!=1 && code.types[r]!=2){return .err(.Code);}r+=1;}
    }
    switch(verifier::inspect_host_metered(ref scalar,typed_code,deadline,fuel)){
        case .ok(_):{}
        case .err(e):{
            if(e.kind==errors::deadline_kind()){return .err(.Deadline);}
            if(e.kind==4 && *fuel!=budget::unlimited()){return .err(.Fuel);}
            return .err(.Code);
        }
    };
    return .ok(authority);
}

pub fn bool scalar_signature(ref catalog::Catalog imports,usize id){
    if(id>=catalog::count(imports)){return false;}
    return switch(catalog::parameter_count(imports,id)){
        case .ok(count):{count==1 && i32_argument(imports,id) && i32_result(imports,id)}
        case .err(_):{false}
    };
}
fn bool i32_argument(ref catalog::Catalog imports,usize id){
    return switch(catalog::parameter_tag(imports,id,0)){case .ok(tag):{tag==3}case .err(_):{false}};
}
fn bool i32_result(ref catalog::Catalog imports,usize id){
    return switch(catalog::result_tag(imports,id)){case .ok(tag):{tag==3}case .err(_):{false}};
}
pub fn bool same_digest(ref u32[] expected,ref u32[] actual){
    if(expected.len!=8 || actual.len!=8){return false;}
    var usize i=0;
    while(i<8){if(expected[i]!=actual[i]){return false;}i+=1;}
    return true;
}

fn bool allowed_imports(ref catalog::Catalog imports,usize required,ref runs::RunConfig run){
    let usize one=1;
    var usize id=0;
    while(id<catalog::count(imports)){
        if((required&(one<<id))!=0){
            let ref u8[] cap=switch(catalog::capability(imports,id)){
                case .ok(v):{v}case .err(_):{return false;}
            };
            if(!runs::declares(run,cap) || !runs::grants(run,cap)){return false;}
        }
        id+=1;
    }
    return true;
}

pub fn Result<Program,Error> retain(ref ir::Program code,catalog::Catalog imports,
    ref u32[] expected,ref policy::Policy ceiling,ref runs::RunConfig run,SourceMap map){
    var usize fuel=budget::unlimited();
    return retain_metered(code,imports,expected,ceiling,run,map,0,ref mut fuel);
}

pub fn Result<Program,Error> retain_metered(ref ir::Program code,catalog::Catalog imports,
    ref u32[] expected,ref policy::Policy ceiling,ref runs::RunConfig run,SourceMap map,
    usize deadline,ref mut usize fuel){
    discard prepay(fuel,deadline)?;
    let u32[8] digest=switch(catalog::digest(ref imports)){
        case .ok(v):{v}case .err(_):{return .err(.Catalog);}
    };
    if(!same_digest(expected,ref digest)){return .err(.Binding);}
    let Authority authority=inspect(code,ref imports,deadline,fuel)?;
    discard prepay(fuel,deadline)?;
    if(!runs::narrowed_to(run,ceiling) || !allowed_imports(ref imports,authority.required,run) ||
        (authority.emits && !allows_output(run))){
        return .err(.Authority);
    }
    return publish(code,imports,digest,authority,runs::module_name(run),runs::function_name(run),map);
}

// Compilation binds the Engine ceiling and verified import set. Each Instance
// must independently declare and receive the required capabilities at admission.
pub fn Result<Program,Error> retain_for_entry(ref ir::Program code,catalog::Catalog imports,
    ref policy::Policy ceiling,ref u8[] module_name,ref u8[] function_name,SourceMap map){
    var usize fuel=budget::unlimited();
    let Authority authority=inspect(code,ref imports,0,ref mut fuel)?;
    let usize one=1;
    var usize id=0;
    while(id<catalog::count(ref imports)){
        if((authority.required&(one<<id))!=0){
            let ref u8[] cap=switch(catalog::capability(ref imports,id)){
                case .ok(v):{v}case .err(_):{return .err(.Catalog);}
            };
            if(!policy::contains_capability(ceiling,cap)){return .err(.Authority);}
        }
        id+=1;
    }
    if(authority.emits && !policy::contains_capability(ceiling,b"brownie.output.emit")){return .err(.Authority);}
    let u32[8] digest=switch(catalog::digest(ref imports)){
        case .ok(v):{v}case .err(_):{return .err(.Catalog);}
    };
    return publish(code,imports,digest,authority,module_name,function_name,map);
}

fn Result<Program,Error> publish(ref ir::Program code,catalog::Catalog imports,u32[8] digest,
    Authority authority,ref u8[] module_name,ref u8[] function_name,SourceMap map){
    let bytes::Buffer scope=switch(bytes::copy(module_name)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    let bytes::Buffer name=switch(bytes::copy(function_name)){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    var vec::Vec<ir::Program> retained=vec::empty<ir::Program>();
    if(!vec::reserve<ir::Program>(ref mut retained,1).is_ok){return .err(.Allocation);}
    if(!vec::push<ir::Program>(ref mut retained,*code).is_ok){return .err(.Allocation);}
    return .ok(Program{.code=retained,.catalog=imports,.digest=Digest{.words=digest},.authority=authority,
        .module_name=scope,.function_name=name,.sources=map});
}

// The compiler assigns instruction offsets in concatenated source order.
pub fn SourceMap unknown_sources(){return SourceMap{.lengths=[0;16]};}
pub fn SourceMap single_source(usize length){
    var SourceMap result=SourceMap{.lengths=[0;16]};
    result.lengths[0]=length;
    return result;
}
pub fn SourceMap source_set(ref sources::Snapshot snapshot){
    var SourceMap result=SourceMap{.lengths=[0;16]};
    var usize i=0;
    while(i<sources::count(snapshot)){
        let sources::Span source=switch(sources::whole(snapshot,i)){
            case .ok(value):{value}case .err(_):{assert(false);sources::no_source()}
        };
        result.lengths[i]=source.end;
        i+=1;
    }
    return result;
}
pub fn sources::Span instruction_span(ref Program p,usize pc){
    let ref ir::Program image=code(p);
    if(pc>=image.count){return sources::no_source();}
    var usize start=image.offsets[pc];
    var usize i=0;
    while(i<sources::file_limit()){
        let usize length=p.sources.lengths[i];
        if(start<length){return sources::Span{.source=i,.start=start,.end=start+1};}
        start-=length;
        i+=1;
    }
    return sources::no_source();
}

pub fn usize heap_bytes(ref Program p,usize ir_stride){
    return vec::capacity<ir::Program>(ref p.code)*ir_stride+catalog::heap_bytes(ref p.catalog)+
        bytes::capacity(ref p.module_name)+bytes::capacity(ref p.function_name);
}
pub fn ref ir::Program code(ref Program p){return vec::at<ir::Program>(ref p.code,0);}
pub fn ref catalog::Catalog imports(ref Program p){return ref p.catalog;}
pub fn u32[8] binding(ref Program p){return p.digest.words;}
pub fn usize requirements(ref Program p){return p.authority.required;}
pub fn bool accepts_input(ref Program p){let ref ir::Program image=code(p);return image.arities[image.entry]==1;}

pub fn bool emits(ref Program p){return p.authority.emits;}
fn bool allows_output(ref runs::RunConfig run){
    let ref u8[] cap=b"brownie.output.emit";
    return runs::declares(run,cap) && runs::grants(run,cap);
}
pub fn bool allows(ref Program p,ref policy::Policy ceiling,ref runs::RunConfig run){
    return bytes::equal(bytes::view(ref p.module_name),runs::module_name(run)) &&
        bytes::equal(bytes::view(ref p.function_name),runs::function_name(run)) &&
        runs::narrowed_to(run,ceiling) && allowed_imports(imports(p),p.authority.required,run) &&
        (!emits(p) || allows_output(run));
}
