module tests::m2::cli_locations;

import ir as ir;
import errors as errors;
import verifier as verifier;
import render as render;

@effects(console)
fn void check_diagnostic(ref ir::Program code,usize index){
    switch(verifier::verify(code)){
        case .ok(_):{assert(false);}
        case .err(e):{
            assert(e.kind==5 && e.offset==index);
            assert(e.location==errors::instruction_location());
            assert(render::selected_outcome(.Text,false,true,0,e,0)==6);
            assert(render::selected_outcome(.Json,false,true,0,e,0)==6);
            assert(render::selected_outcome(.JsonV2,false,true,0,e,0)==6);
        }
    };
}

@effects(console)
@test
fn void renders_verifier_instruction_index(){
    var ir::Program code=ir::empty();
    // Neither source byte offset equals its instruction index.
    let usize r=switch(ir::literal(ref mut code,77,17)){case .ok(v):{v}case .err(_):{assert(false);0}};
    let usize ret=switch(ir::emit(ref mut code,8,r,0,42)){case .ok(v):{v}case .err(_):{assert(false);0}};
    code.function_count=1;
    code.return_types[0]=1;
    code.ends[0]=2;
    code.register_ends[0]=1;
    assert(verifier::verify(ref code).is_ok);
    let u8 first=code.code[0];
    code.code[0]=255;
    check_diagnostic(ref code,0);

    code.code[0]=first;
    code.code[8]=255;
    check_diagnostic(ref code,1);
}
