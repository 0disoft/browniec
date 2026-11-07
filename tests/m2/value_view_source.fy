module tests::m2::value_view_source;
import value_source as source;
import value_ir as values;
import verifier as verifier;
import vm as vm;
import buffer_growth as growth;
import ir as ir;

fn growth::Limits limits(){return growth::Limits{.object=4096,.instance=1048576,.engine=1048576};}
fn values::Program compiled(ref u8[] input){return switch(source::compile(input)){
    case .ok(v):{v}case .err(_):{assert(false);compiled(input)}
};}
fn void executes(ref values::Program p){
    assert(verifier::inspect_values(p).is_ok);
    assert(switch(vm::run_values(p,10000000,0,limits())){case .ok(v):{v==42}case .err(_):{false}});
}
fn void value(ref u8[] input){let values::Program p=compiled(input);executes(ref p);}
fn void rejected(ref u8[] input){
    assert(switch(source::compile(input)){case .ok(_):{false}case .err(e):{e.kind==3 && e.offset<=input.len}});
}
fn void failure(ref u8[] input,u8 kind){
    let values::Program p=compiled(input);
    assert(verifier::inspect_values(ref p).is_ok);
    assert(switch(vm::run_values(ref p,10000000,0,limits())){
        case .ok(_):{false}case .err(e):{e.kind==kind && e.offset<=input.len}
    });
    // A fresh invocation after every failure must admit and release new views.
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);{let ref u8[] v=bytes::view(ref b);if(v[0]!=42){return 0;}}bytes::write(ref mut b,0,7);return 42;}");
}

// Each short guest independently fits the sixteen typed/view slots and 256
// instructions. No view-return/formal or conditional view-valued join is used.
@test fn void whole_qualified_nested_and_empty_ranges_read_actual_bytes(){
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);let v=bytes::view(ref b);let whole=v[..];let tail=v[1..];let head=v[..1];if(whole.len==2 && tail[0]==42 && head[0]==7){return 42;}return 0;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);_ = bytes::push(ref mut b,9);let ref u8[] v=bytes::view(ref b);let ref u8[] middle=v[1..3];let ref u8[] child=middle[0..1];let ref u8[] empty=middle[2..2];if(v.len==3 && v[0]==7 && v[1]==42 && v[2]==9 && middle.len==2 && middle[1]==9 && child.len==1 && child[0]==42 && empty.len==0){return 42;}return 0;}");
    // The statement's anonymous whole view closes; its named child retains it.
    value(b"module main;fn i32 main(){var b=brownie::bytes::empty();_ = brownie::bytes::push(ref mut b,7);_ = brownie::bytes::push(ref mut b,42);let ref u8[] child=brownie::bytes::view(ref b)[1..2];if(child.len==1 && child[0]==42){return 42;}return 0;}");
    value(b"module main;fn i32 main(){let b=bytes::empty();let ref u8[] v=bytes::view(ref b);let ref u8[] empty=v[0..0];if(v.len==0 && empty.len==0 && bytes::view(ref bytes::empty()).len==0){return 42;}return 0;}");
}

@test fn void alias_scopes_and_mutable_bindings_release_only_their_last_root_pin(){
    // Discarding a named view does not consume it; all aliases remain usable.
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);{let ref u8[] v=bytes::view(ref b);let ref u8[] child=v;_ = v;{let ref u8[] grandchild=child;if(grandchild[0]!=7){return 0;}}if(v.len!=1 || child[0]!=7){return 0;}}bytes::write(ref mut b,0,42);_ = bytes::reserve(ref mut b,8);_ = bytes::append(ref mut b,ref bytes::empty());let moved=b;if(bytes::read(ref moved,0)==42){return 42;}return 0;}");
    // Reassigning the binding closes its old view without mutating any payload.
    value(b"module main;fn i32 main(){var b=bytes::empty();var c=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut c,42);{var ref u8[] v=bytes::view(ref b);v=bytes::view(ref c);bytes::write(ref mut b,0,9);if(v[0]!=42 || bytes::read(ref b,0)!=9){return 0;}}bytes::write(ref mut c,0,7);return 42;}");
    // An unnamed discard closes immediately and must not keep the root pinned.
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::view(ref b);bytes::write(ref mut b,0,42);if(bytes::read(ref b,0)==42){return 42;}return 0;}");
}

@test fn void live_aliases_reject_root_writes_noop_growth_owning_calls_and_later_operand_effects(){
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);let ref u8[] v=bytes::view(ref b);bytes::write(ref mut b,0,42);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let ref u8[] v=bytes::view(ref b);_ = bytes::reserve(ref mut b,0);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let ref u8[] v=bytes::view(ref b);_ = bytes::append(ref mut b,ref bytes::empty());return 42;}");
    rejected(b"module main;fn void take(Buffer b){}fn i32 main(){let b=bytes::empty();let ref u8[] v=bytes::view(ref b);take(b);return 42;}");
    rejected(b"module main;fn i32 main(){let b=bytes::empty();let ref u8[] v=bytes::view(ref b);let moved=b;return 42;}");
    rejected(b"module main;fn i32 main(){let b=bytes::empty();let ref u8[] v=bytes::view(ref b);_ = b;return 42;}");
    // Neither named discard nor an inner alias's lexical close releases v.
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let ref u8[] v=bytes::view(ref b);{let ref u8[] child=v;_ = child;}_ = v;_ = bytes::reserve(ref mut b,0);return 42;}");
    // Rebinding the parent must not unpin the old root while its alias survives.
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let c=bytes::empty();_ = bytes::push(ref mut b,42);var ref u8[] v=bytes::view(ref b);let ref u8[] child=v;v=bytes::view(ref c);bytes::write(ref mut b,0,7);return 42;}");
    // The receiver must stay pinned through evaluation of later index/bounds.
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let ref u8[] v=bytes::view(ref b);_ = v[if(true){bytes::write(ref mut b,0,7);0}else{0}];return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let ref u8[] v=bytes::view(ref b);let ref u8[] child=v[0..if(true){let moved=b;1}else{1}];return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);_ = bytes::view(ref b)[if(true){_ = bytes::push(ref mut b,7);0}else{0}];return 42;}");
}

@test fn void unrelated_calls_and_ordered_endpoint_effects_preserve_caller_views(){
    // Capturing the receiver protects its old referent even when both index
    // branches reassign the lexical view before the actual READ executes.
    value(b"module main;fn i32 main(){var b=bytes::empty();var c=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut c,42);var ref u8[] v=bytes::view(ref b);let u8 old=v[if(true){v=bytes::view(ref c);0}else{v=bytes::view(ref c);0}];bytes::write(ref mut b,0,9);if(old==7 && v[0]==42){return 42;}return 0;}");
    // Both frames may use their first local view ID without clobbering either.
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let ref u8[] v=bytes::view(ref b);let n=other(bytes::empty());if(n==42 && v.len==1 && v[0]==42 && bytes::read(ref b,0)==42){return 42;}return 0;}fn i32 other(Buffer incoming){let ref u8[] v=bytes::view(ref incoming);if(v.len==0){return 42;}return 0;}");
    // Distinct-root effects prove each endpoint executes once, low before high.
    value(b"module main;fn i32 main(){var b=bytes::empty();var seen=bytes::empty();_ = bytes::push(ref mut b,7);_ = bytes::push(ref mut b,42);let ref u8[] v=bytes::view(ref b);let ref u8[] child=v[if(true){_ = bytes::push(ref mut seen,7);1}else{0}..if(true){if(bytes::len(ref seen)!=1){return 0;}_ = bytes::push(ref mut seen,42);2}else{0}];if(child.len==1 && child[0]==42 && bytes::len(ref seen)==2 && bytes::read(ref seen,0)==7 && bytes::read(ref seen,1)==42){return 42;}return 0;}");
    value(b"module main;fn usize index(){return 0;}fn i32 main(){var b=bytes::empty();var seen=bytes::empty();_ = bytes::push(ref mut b,42);let ref u8[] v=bytes::view(ref b);if(v[if(true){_ = bytes::push(ref mut seen,7);index()}else{0}]==42 && bytes::len(ref seen)==1){return 42;}return 0;}");
}

@test fn void block_if_switch_and_loop_transfers_close_views_before_owner_cleanup(){
    // Both branches and both switch cases are compiled; neither leaks a pin.
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);if(true){let ref u8[] v=bytes::view(ref b);if(v[0]!=7){return 0;}}else{let ref u8[] other=bytes::view(ref b);_ = other.len;}switch(.some(1)){case .some(_):{let ref u8[] v=bytes::view(ref b);_ = v[0];}case .none:{let ref u8[] v=bytes::view(ref b);_ = v.len;}}bytes::write(ref mut b,0,42);if(bytes::read(ref b,0)==42){return 42;}return 0;}");
    // On continue, a body owner can only drop after its aliases have closed.
    value(b"module main;fn i32 main(){var n=0;while(n<42){let b=bytes::empty();let ref u8[] v=bytes::view(ref b);let ref u8[] child=v;if(child.len!=0){return 0;}n+=1;continue;}return n;}");
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);while(true){let local=bytes::empty();let ref u8[] a=bytes::view(ref local);let ref u8[] v=bytes::view(ref b);if(v[0]!=7 || a.len!=0){return 0;}break;}bytes::write(ref mut b,0,42);if(bytes::read(ref b,0)==42){return 42;}return 0;}");
    // A for continue closes the body view before the next iteration mutates b.
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);for(var n=0;n<42;n+=1){bytes::write(ref mut b,0,42);let ref u8[] v=bytes::view(ref b);if(v[0]!=42){return 0;}continue;}let moved=b;if(bytes::read(ref moved,0)==42){return 42;}return 0;}");
    // Inner break must preserve an enclosing view until the outer scope ends.
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);{let ref u8[] v=bytes::view(ref b);while(true){let local=bytes::empty();let ref u8[] child=bytes::view(ref local);break;}if(v[0]!=42){return 0;}}bytes::write(ref mut b,0,7);return 42;}");
    // Nonlocal endpoints close captured anonymous receivers before local owners.
    value(b"module main;fn i32 main(){while(true){let b=bytes::empty();let ref u8[] v=bytes::view(ref b);_ = v[0..if(true){break;}else{0}];}return 42;}");
    value(b"module main;fn i32 main(){var usize i=0;while(i<2){i+=1;let b=bytes::empty();let ref u8[] v=bytes::view(ref b);_ = v[if(true){continue;}else{0}];}return 42;}");
}

@test fn void return_and_result_propagation_close_views_before_capturing_or_dropping_owners(){
    // Return cleanup closes v before capturing the owning Buffer result.
    value(b"module main;fn Buffer make(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let ref u8[] v=bytes::view(ref b);_ = v[0];return b;}fn i32 main(){var b=make();bytes::write(ref mut b,0,7);if(bytes::read(ref b,0)==7){return 42;}return 0;}");
    // Failure in the later index expression exits with the receiver still live.
    value(b"module main;fn Result<usize,u8> fail(){return .err(7);}fn Result<usize,u8> f(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let ref u8[] v=bytes::view(ref b);_ = v[fail()?];return .ok(0);}fn i32 main(){switch(f()){case .ok(_):{return 0;}case .err(e):{if(e==7){return 42;}return 0;}}}");
    // Keep the success-path fixture inside the existing 16 monotonic typed slots.
    value(b"module main;fn Result<usize,u8> index(){return .ok(0);}fn Result<usize,u8> f(){var b=bytes::empty();_ = bytes::push(ref mut b,42);{let ref u8[] v=bytes::view(ref b);_ = v[index()?];}bytes::write(ref mut b,0,7);return .ok(bytes::len(ref b));}fn i32 main(){switch(f()){case .ok(n):{if(n==1){return 42;}return 0;}case .err(_):{return 0;}}}");
    // A nonlocal return from a range endpoint drains both lexical and anonymous views.
    value(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let ref u8[] v=bytes::view(ref b);let ref u8[] child=v[0..if(true){return 42;}else{1}];return 0;}");
}

@test fn void invalid_view_types_and_runtime_bounds_fail_without_poisoning_fresh_invocations(){
    rejected(b"module main;fn i32 main(){let n=42;let ref u8[] v=bytes::view(ref n);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let ref mut u8[] v=bytes::view(ref b);return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();let ref u8[] v=bytes::view(ref mut b);return 42;}");
    rejected(b"module main;fn i32 main(){let b=bytes::empty();let ref u8[] v=bytes::view(ref b);_ = v[true];return 42;}");
    rejected(b"module main;fn i32 main(){let b=bytes::empty();let ref u8[] v=bytes::view(ref b);let i32 n=0;let ref u8[] child=v[n..0];return 42;}");
    rejected(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,7);let ref u8[] v=bytes::view(ref b);v[0]=42;return 42;}");
    rejected(b"module main;fn i32 main(){let ref u8[] v=bytes::view(ref bytes::empty());return 42;}");
    failure(b"module main;fn i32 main(){let b=bytes::empty();let ref u8[] v=bytes::view(ref b);_ = v[0];return 42;}",14);
    failure(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let ref u8[] v=bytes::view(ref b);_ = v[1];return 42;}",14);
    failure(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let ref u8[] v=bytes::view(ref b);let ref u8[] child=v[1..0];return 42;}",14);
    failure(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let ref u8[] v=bytes::view(ref b);let ref u8[] child=v[0..2];return 42;}",14);
    // Endpoint arithmetic failure must not be replaced by an eager range check.
    failure(b"module main;fn usize bad(){var usize n=18446744073709551615;n+=1;return n;}fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let ref u8[] v=bytes::view(ref b);let ref u8[] child=v[2..bad()];return 42;}",6);
}

fn void private_metadata(ref values::Program p){
    let ref ir::Program body=ref p.body;
    var usize i=0;while(i<128){
        assert(body.types[i]!=65 && p.parameters[i]!=65 && body.slice_parameters[i]==0);i+=1;
    }
    i=0;while(i<16){
        assert(body.return_types[i]!=65 && p.results[i]!=65);
        assert(body.slice_roots[i]==0 && body.slice_origins[i]==0 && body.slice_functions[i]==0 && body.slice_elements[i]==0);i+=1;
    }
    // Views are not catalog nodes or canonical value slots.
    i=0;while(i<p.catalog.count){assert(p.catalog.nodes[i].kind>=1 && p.catalog.nodes[i].kind<=6);i+=1;}
    i=0;while(i<16){assert((p.types[i] as usize)<=p.catalog.count);i+=1;}
}
@test fn void source_views_remain_private_instructions_without_signature_or_scalar_handles(){
    var values::Program p=compiled(b"module main;fn i32 main(){var b=bytes::empty();_ = bytes::push(ref mut b,42);let ref u8[] v=bytes::view(ref b);let ref u8[] alias=v;let ref u8[] child=alias[0..1];if(child.len==1 && child[0]==42){return 42;}return 0;}");
    private_metadata(ref p);executes(ref p);
    // Independently identify the admitted source operations, not helper enums.
    var bool begin=false;var bool range=false;var bool alias=false;
    var bool length=false;var bool read=false;var bool close=false;
    var usize pc=0;while(pc<p.body.count){
        let u8 op=p.body.code[pc*8];
        if(op==105){
            begin=true;let usize lo=p.body.code[pc*8+3] as usize;let usize hi=p.body.code[pc*8+4] as usize;
            assert(p.body.types[lo]==12 && p.body.types[hi]==12);
            var bool zero=false;var bool bound=false;var usize before=0;
            while(before<pc){let usize at=before*8;
                if(p.body.code[at]==1 && p.body.code[at+1] as usize==lo){
                    let usize constant=p.body.code[at+2] as usize;zero=p.body.constants[constant]==0;
                }
                if(p.body.code[at]==99 && p.body.code[at+1] as usize==hi){
                    bound=p.body.code[at+2]==p.body.code[pc*8+2];
                }before+=1;
            }assert(zero && bound);
        }
        if(op==106){range=true;}if(op==107){alias=true;}if(op==109){close=true;}
        if(op==110){length=true;}if(op==111){read=true;}pc+=1;
    }
    assert(begin && range && alias && close && length && read);
    // A forged source sentinel is never an executable signature or scalar type.
    let u8 result=p.body.return_types[0];p.body.return_types[0]=65;
    assert(!verifier::inspect_values(ref p).is_ok);p.body.return_types[0]=result;
    let u8 scalar=p.body.types[0];p.body.types[0]=65;
    assert(!verifier::inspect_values(ref p).is_ok);p.body.types[0]=scalar;executes(ref p);
    // No conversion can smuggle a local view into a value/result/call payload.
    rejected(b"module main;fn Buffer bad(){let b=bytes::empty();let ref u8[] v=bytes::view(ref b);return v;}fn i32 main(){return 42;}");
    rejected(b"module main;fn void take(Buffer b){}fn i32 main(){let b=bytes::empty();let ref u8[] v=bytes::view(ref b);take(v);return 42;}");
    rejected(b"module main;fn i32 main(){let b=bytes::empty();let ref u8[] v=bytes::view(ref b);let usize handle=v;return 42;}");
}
