module host_program;

import host_catalog as catalog;
import ir as ir;
import runtime_policy as policy;
import runtime_run_config as runs;
import std::bytes as bytes;
import std::vec as vec;
import verifier as verifier;
import types as types;
import host_wire as wire;

// Private scalar host dialect. The ordinary verifier still rejects opcode 117.
pub enum Error { Code; Catalog; Binding; Authority; Allocation; }
struct Digest { u32[8] words; }
pub resource Program {
    vec::Vec<ir::Program> code;
    catalog::Catalog catalog;
    Digest digest;
    usize required;
    bytes::Buffer module_name;
    bytes::Buffer function_name;
    cleanup { }
}

pub fn u8 request_opcode(){return 117;}
pub fn u8 typed_request_opcode(){return 118;}
pub fn u8 result_request_opcode(){return 121;}
pub fn u8 copy_opcode(){return 122;}
pub fn u8 value_request_opcode(){return 123;}
pub fn u8 project_opcode(){return 124;}
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
    var usize pc=0;
    while(pc<code.count){if(typed_request(code.code[pc*8])){return true;}pc+=1;}
    return false;
}

// HOST_REQUEST: dst=i32 destination, a=i32 argument, b=catalog import ID.
// The independent scalar verifier checks the same input and output registers
// through an ADD proxy. The proxy is temporary and never executes.
fn Result<usize,Error> inspect(ref ir::Program code,ref catalog::Catalog imports){
    if(code.count==0 || code.count>256 || code.registers>128 ||
        code.function_count!=1 || code.entry!=0 || code.arrays.count!=0 ||
        code.records.count!=0 || code.list_used>4096){return .err(.Code);}
    var usize reg=0;
    while(reg<code.registers){
        if(!types::scalar(code.types[reg]) && (code.slots[reg] || (code.types[reg]!=14 && !types::host_storage(code.types[reg])))){return .err(.Code);}
        reg+=1;
    }
    var ir::Program scalar=*code;
    let bool typed_code=typed(code);
    var usize required=0;
    var usize pc=0;
    let usize one=1;
    while(pc<code.count){
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
            required|=one<<id;
        }else if(typed_request(op)){
            if(!typed_signature(code,imports,at)){return .err(.Catalog);}
            required|=one<<(code.code[at+3] as usize);
        }else if(op==17 || op==18 || op==119 || op==120 || op==copy_opcode() || op==project_opcode()){
            if(!typed_code){return .err(.Code);}
        }else if(op==2){
            let usize dst=code.code[at+1] as usize;
            if(dst>=code.registers || code.types[dst]!=1){return .err(.Code);}
        }else if(op!=1 && op!=7 && op!=8 && op!=19 && op!=20 && op!=21 && op!=22){
            return .err(.Code);
        }
        pc+=1;
    }
    if(typed_code){
        if(!verifier::inspect_host(ref scalar).is_ok){return .err(.Code);}
    }else{
        var usize r=0;
        while(r<code.registers){if(code.types[r]!=1 && code.types[r]!=2){return .err(.Code);}r+=1;}
        if(!verifier::verify(ref scalar).is_ok){return .err(.Code);}
    }
    return .ok(required);
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
    ref u32[] expected,ref policy::Policy ceiling,ref runs::RunConfig run){
    let u32[8] digest=switch(catalog::digest(ref imports)){
        case .ok(v):{v}case .err(_):{return .err(.Catalog);}
    };
    if(!same_digest(expected,ref digest)){return .err(.Binding);}
    let usize required=inspect(code,ref imports)?;
    if(!runs::narrowed_to(run,ceiling) || !allowed_imports(ref imports,required,run)){
        return .err(.Authority);
    }
    return publish(code,imports,digest,required,run);
}

fn Result<Program,Error> publish(ref ir::Program code,catalog::Catalog imports,u32[8] digest,
    usize required,ref runs::RunConfig run){
    let bytes::Buffer scope=switch(bytes::copy(runs::module_name(run))){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    let bytes::Buffer name=switch(bytes::copy(runs::function_name(run))){
        case .ok(v):{v}case .err(_):{return .err(.Allocation);}
    };
    var vec::Vec<ir::Program> retained=vec::empty<ir::Program>();
    if(!vec::reserve<ir::Program>(ref mut retained,1).is_ok){return .err(.Allocation);}
    if(!vec::push<ir::Program>(ref mut retained,*code).is_ok){return .err(.Allocation);}
    return .ok(Program{.code=retained,.catalog=imports,.digest=Digest{.words=digest},.required=required,
        .module_name=scope,.function_name=name});
}

pub fn usize heap_bytes(ref Program p,usize ir_stride){
    return vec::capacity<ir::Program>(ref p.code)*ir_stride+catalog::heap_bytes(ref p.catalog)+
        bytes::capacity(ref p.module_name)+bytes::capacity(ref p.function_name);
}
pub fn ref ir::Program code(ref Program p){return vec::at<ir::Program>(ref p.code,0);}
pub fn ref catalog::Catalog imports(ref Program p){return ref p.catalog;}
pub fn u32[8] binding(ref Program p){return p.digest.words;}
pub fn usize requirements(ref Program p){return p.required;}

pub fn bool allows(ref Program p,ref policy::Policy ceiling,ref runs::RunConfig run){
    return bytes::equal(bytes::view(ref p.module_name),runs::module_name(run)) &&
        bytes::equal(bytes::view(ref p.function_name),runs::function_name(run)) &&
        runs::narrowed_to(run,ceiling) && allowed_imports(imports(p),p.required,run);
}
