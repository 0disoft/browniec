module module_input_program;
import module_input_entry as entries;
import module_index as modules;
import source_snapshot as sources;
import compiler as compiler;
import source_error as diagnostics;
import errors as errors;
import ir as ir;
import static_call_ir as candidates;
import static_image as images;
import verifier as verifier;
import program_image as program_images;
import std::vec as vec;

// Separate admitted input ABI. No zero-argument Program or native execution
// authority can be manufactured from this resource's read-only accessors.
resource Stored { sources::Snapshot sources; candidates::Program code; images::Image image; cleanup { } }
pub resource Program { vec::Vec<Stored> stored; cleanup { } }
pub fn Result<Program,diagnostics::Error> compile(entries::InputEntry selected,usize image_limit){
    var images::Builder builder=switch(images::builder(4096)){
        case .ok(v):{v}case .err(e):{return .err(literal(e));}
    };
    var candidates::Program code=candidates::Program{.body=ir::empty(),.parameters=[0;128],.results=[0;16],.origins=[0;16]};
    let usize lowered=compiler::lower_input_modules(ref selected,ref mut builder,ref mut code)?;
    return finish(ref selected,ref builder,ref code,image_limit);
}
fn diagnostics::Error literal(images::Error e){
    return diagnostics::absent(compiler::public_error(program_images::Error{.kind=.Literal,.code=errors::make(0,0),.literal=e}));
}
fn diagnostics::Error map(ref entries::InputEntry selected,errors::Error e){
    return if(e.offset==0){diagnostics::absent(e)}else{diagnostics::map(modules::snapshot(entries::index(selected)),e,16)};
}
// Keep source lowering, full independent proof and the owning return slots on
// separate native stack frames. Quota is checked before retaining image/code.
fn Result<Program,diagnostics::Error> finish(ref entries::InputEntry selected,ref images::Builder builder,
    ref candidates::Program code,usize image_limit){
    let images::Image image=switch(images::freeze(builder,image_limit)){
        case .ok(v):{v}case .err(e):{return .err(literal(e));}
    };
    switch(verifier::inspect_input_returns(code,ref image)){
        case .ok(_):{}case .err(e):{
            if(e.offset==0 || e.offset>=code.body.count){return .err(diagnostics::absent(e));}
            return .err(map(selected,errors::make(e.kind,code.body.offsets[e.offset])));
        }
    };
    return retain(selected,code,image);
}
fn Result<Program,diagnostics::Error> retain(ref entries::InputEntry selected,ref candidates::Program code,images::Image image){
    var vec::Vec<Stored> stored=vec::empty<Stored>();
    if(!vec::reserve<Stored>(ref mut stored,1).is_ok){return .err(diagnostics::absent(errors::make(15,0)));}
    let sources::Snapshot snapshot=sources::duplicate(modules::snapshot(entries::index(selected)));
    if(!vec::push<Stored>(ref mut stored,Stored{.sources=snapshot,.code=*code,.image=image}).is_ok){
        return .err(diagnostics::absent(errors::make(15,0)));
    }
    return .ok(Program{.stored=stored});
}
fn ref Stored stored(ref Program p){return vec::at<Stored>(ref p.stored,0);}
pub fn ref sources::Snapshot snapshot(ref Program p){return ref stored(p).sources;}
pub fn ref candidates::Program code(ref Program p){return ref stored(p).code;}
pub fn ref images::Image literals(ref Program p){return ref stored(p).image;}
