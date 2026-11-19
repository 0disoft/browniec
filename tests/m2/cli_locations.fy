module tests::m2::cli_locations;

import ir as ir;
import errors as errors;
import verifier as verifier;

@test
fn void rejects_first_instruction_with_its_index(){
    var ir::Program code=ir::empty();
    let usize r=switch(ir::literal(ref mut code,77,0)){case .ok(v):{v}case .err(_):{assert(false);0}};
    let usize ret=switch(ir::emit(ref mut code,8,r,0,0)){case .ok(v):{v}case .err(_):{assert(false);0}};
    code.function_count=1;
    code.return_types[0]=1;
    code.ends[0]=2;
    code.register_ends[0]=1;
    assert(verifier::verify(ref code).is_ok);
    code.code[0]=255;
    switch(verifier::verify(ref code)){
        case .ok(_):{assert(false);}
        case .err(e):{
            assert(e.kind==5 && e.offset==0);
            assert(e.location==errors::instruction_location());
        }
    };
}
