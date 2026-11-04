module tests::m2::image_text_dispatch;
import compiler as compiler;
import program_image as programs;
import slice_result_ir as ir;
import ir as ordinary;
import slice_result_runtime as runtime;
import array_owners as owners;
import array_slices as slices;

fn void value(ref u8[] source){
    let programs::Program p=switch(compiler::compile_image(source,576)){
        case .ok(v):{v}case .err(_):{assert(false);return;}
    };
    var runtime::State state=runtime::empty(64);var u8[64] data=[0;64];
    let runtime::Capture[1] captures=[runtime::capture(slices::Ticket{.slot=16,.generation=0},false,false)];
    let i64[1] values=[0];let owners::Token[1] inputs=[owners::Token{.slot=0,.generation=0}];
    let ref ir::Program code=programs::code(ref p);let ref ordinary::Program body=ref code.body;
    switch(programs::run_scalar(ref p,body.entry,ref captures[..0],ref values[..0],ref inputs[..0],
        ref mut state,ref mut data,1000000)){
        case .ok(v):{assert(v.value==42);}case .err(_):{assert(false);}
    };
    assert(state.runtime.authority.depth==0 && state.runtime.owners.depth==0 && state.runtime.owners.arena.used==0);
    var usize i=0;while(i<16){assert(!state.runtime.pool.slots[i].live);i+=1;}
}
@test fn void image_compilation_preserves_existing_utf8_and_plain_text_name_dispatch(){
    value(b"module main;fn i32 main(){let u8[1] a=[65;1];if(text::valid_utf8(a)){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let u8[1] a=[255;1];if(text::valid_utf8(a)){return 0;}return 42;}");
    value(b"module main;fn i32 main(){let i32 text=42;return text;}");
}
