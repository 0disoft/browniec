module tests::m2::place_syntax;
import place_syntax as places;
import lexer as lexer;
import std::bytes as bytes;

fn lexer::State first(ref u8[] source){var lexer::State s=lexer::empty();assert(lexer::next(source,ref mut s).is_ok);return s;}
fn places::Plan planned(ref u8[] source,ref lexer::State s){return switch(places::inspect(source,s)){
    case .ok(p):{p}case .err(_):{assert(false);let lexer::State retry=first(b"x=0;");return planned(b"x=0;",ref retry);}
};}
fn void unchanged(ref lexer::State a,ref lexer::State b){
    assert(a.cursor==b.cursor && a.begin==b.begin && a.end==b.end && a.tokens==b.tokens);
    assert(a.kind==b.kind && a.value==b.value && a.min_magnitude==b.min_magnitude && a.context==b.context);
}
fn void value(ref u8[] source,usize groups,usize selectors,u8 operation){
    let lexer::State s=first(source);let lexer::State before=lexer::snapshot(ref s);
    let places::Plan p=planned(source,ref s);unchanged(ref before,ref s);
    assert(p.valid && p.groups==groups && p.count==selectors && p.operation.kind==operation);
    assert(p.begin<p.end && p.end<=source.len && p.operation.begin>=p.end);
}
fn void absent(ref u8[] source){let lexer::State s=first(source);assert(!planned(source,ref s).valid);}
fn void error(ref u8[] source,ref lexer::State s,u8 kind){assert(switch(places::inspect(source,s)){
    case .ok(_):{false}case .err(e):{e.kind==kind}
});}
fn void bad(ref u8[] source,u8 kind){let lexer::State s=first(source);error(source,ref s,kind);}
fn void append(ref mut bytes::Buffer b,ref u8[] source){assert(bytes::append(b,source).is_ok);}

@test fn void root_field_and_index_groups_share_exact_source_locations_without_mutation(){
    value(b"x=42;",0,0,61);value(b"(x)+=42;",1,0,136);value(b"(((x)))>>=1;",3,0,142);
    value(b"((p).inner).x=42;",2,2,61);value(b"(((p.inner).x))+=42;",3,2,136);
    value(b"(a)[0]=42;",1,1,61);value(b"((a[0]))+=42;",2,1,136);value(b"(((s))[0])^=42;",3,1,144);
    let ref u8[] source=b" ((p).i).x += 22;";let lexer::State s=first(source);let places::Plan p=planned(source,ref s);
    assert(p.valid && p.begin==3 && p.end==4 && p.operation.begin==11 && p.operation.end==13);
    assert(p.kinds[0]==1 && p.begins[0]==6 && p.ends[0]==7 && p.kinds[1]==1 && p.begins[1]==9 && p.ends[1]==10);
}
@test fn void every_operator_is_recognized_without_turning_final_value_expressions_into_places(){
    value(b"(x)-=1;",1,0,137);value(b"(x)*=1;",1,0,138);value(b"(x)/=1;",1,0,139);
    value(b"(x)%=1;",1,0,140);value(b"(x)<<=1;",1,0,141);value(b"(x)&=1;",1,0,143);value(b"(x)|=1;",1,0,145);
    absent(b"x");absent(b"(x+1)");absent(b"((f()))");absent(b"(P{.x=1}).x=42;");
    absent(b"((x))==42");absent(b"a[0]");absent(b"(a).len");absent(b"(x+1)=42;");
    absent(b"(ref a)");absent(b"let x=1;");absent(b"(x+=1;");absent(b"x.=42;");
}
@test fn void index_operand_state_survives_nested_delimiters_literals_comments_and_later_selectors(){
    let ref u8[] source=b"((a[if (true) {let x=[1,2];x[0]} else {0}])) <<= 1;";
    let lexer::State s=first(source);let places::Plan p=planned(source,ref s);
    assert(p.valid && p.groups==2 && p.count==1 && p.kinds[0]==2 && p.operation.kind==141);
    assert(lexer::equal(source[p.operands[0].begin..p.operands[0].end],b"if"));
    assert(p.operands[0].begin==p.begins[0] && source[p.ends[0]]==93 && p.ends[0]<p.operation.begin);
    var lexer::State operand=lexer::snapshot(ref p.operands[0]);
    while(operand.begin<p.ends[0]){assert(lexer::next(source,ref mut operand).is_ok);}
    assert(operand.begin==p.ends[0] && operand.kind==93 && operand.tokens<p.operation.tokens);
    value(b"(a[b\" ] } ) \"[0] /* ] ) } */ + (1)]) |= 42;",1,1,145);
    value(b"((p).a[call([1;2],(3))]).b=42;",2,3,61);
}
@test fn void mismatched_empty_and_unclosed_index_delimiters_fail_with_original_offsets(){
    bad(b"a[]=1;",2);bad(b"a[(1]]=1;",2);bad(b"a[{1)]=1;",2);bad(b"a[(1)=1;",2);
    bad(b"a[if(true){0]=1;",2);bad(b"a[",2);
    let ref u8[] source=b"(a[(1]])=42;";let lexer::State s=first(source);
    assert(switch(places::inspect(source,ref s)){case .ok(_):{false}case .err(e):{e.kind==2 && e.offset==5}});
}
@test fn void grouping_selector_and_index_stacks_have_independent_exact_bounds(){
    var bytes::Buffer source=bytes::empty();var usize i=0;
    while(i<32){append(ref mut source,b"(");i+=1;}append(ref mut source,b"x");i=0;
    while(i<32){append(ref mut source,b")");i+=1;}append(ref mut source,b"+=42;");value(bytes::view(ref source),32,0,136);
    var bytes::Buffer deep=bytes::empty();i=0;while(i<33){append(ref mut deep,b"(");i+=1;}
    append(ref mut deep,b"x");i=0;while(i<33){append(ref mut deep,b")");i+=1;}append(ref mut deep,b"=42;");bad(bytes::view(ref deep),4);
    var bytes::Buffer fields=bytes::empty();append(ref mut fields,b"p");i=0;
    while(i<16){append(ref mut fields,b".x");i+=1;}append(ref mut fields,b"=42;");value(bytes::view(ref fields),0,16,61);
    var bytes::Buffer too_many=bytes::empty();append(ref mut too_many,b"p");i=0;
    while(i<17){append(ref mut too_many,b".x");i+=1;}append(ref mut too_many,b"=42;");bad(bytes::view(ref too_many),4);
    var bytes::Buffer index=bytes::empty();append(ref mut index,b"a[");i=0;while(i<31){append(ref mut index,b"(");i+=1;}
    append(ref mut index,b"0");i=0;while(i<31){append(ref mut index,b")");i+=1;}append(ref mut index,b"]=42;");value(bytes::view(ref index),0,1,61);
    var bytes::Buffer overflow=bytes::empty();append(ref mut overflow,b"a[");i=0;while(i<32){append(ref mut overflow,b"(");i+=1;}
    append(ref mut overflow,b"0");i=0;while(i<32){append(ref mut overflow,b")");i+=1;}append(ref mut overflow,b"]=42;");bad(bytes::view(ref overflow),4);
}
@test fn void scoped_fences_token_budgets_and_invalid_native_state_remain_checked(){
    let ref u8[] source=b"bad! (x)+=42; }";
    var lexer::State scoped=switch(lexer::scoped(source,5,13,false)){case .ok(s):{s}case .err(_):{assert(false);lexer::empty()}};
    assert(lexer::next(source,ref mut scoped).is_ok);let lexer::State before=lexer::snapshot(ref scoped);
    let places::Plan p=planned(source,ref scoped);unchanged(ref before,ref scoped);
    assert(p.valid && p.begin==6 && p.end==7 && p.operation.begin==8 && p.operation.context==scoped.context);
    var lexer::State fenced=switch(lexer::scoped(b"a[0] =42;",0,3,false)){case .ok(s):{s}case .err(_):{assert(false);lexer::empty()}};
    assert(lexer::next(b"a[0] =42;",ref mut fenced).is_ok);error(b"a[0] =42;",ref fenced,2);
    var lexer::State bad_state=first(b"x+=1;");bad_state.tokens=1024;error(b"x+=1;",ref bad_state,4);
    bad_state=first(b"x+=1;");bad_state.tokens=1025;error(b"x+=1;",ref bad_state,5);
    bad_state=first(b"x+=1;");bad_state.cursor=0;error(b"x+=1;",ref bad_state,5);
    bad_state=first(b"x+=1;");bad_state.context=1;error(b"x+=1;",ref bad_state,5);
    var bytes::Buffer huge=bytes::empty();var usize i=0;
    while(i<4097){append(ref mut huge,b" ");i+=1;}
    let lexer::State empty=lexer::empty();error(bytes::view(ref huge),ref empty,4);
}
