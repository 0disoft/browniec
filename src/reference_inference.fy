module reference_inference;
import lexer as lexer;
import locals as locals;
import ir as ir;
import functions as functions;
import errors as errors;
import static_source as statics;
import slice_source as slices;
import array_source as arrays;

// Advisory metadata only: 1 byte view, 2 text view, 3 native array loan.
// Original lowering still proves access, type, origin and every endpoint.
pub struct Shape { u8 kind; u8 element; bool exclusive; }
fn Shape none(){return Shape{.kind=0,.element=0,.exclusive=false};}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] text){
    return s.kind==2 && lexer::equal(source[s.begin..s.end],text);
}
// Skip tokens, never guest expressions. Only the matching delimiter affects
// depth; malformed cross-delimiters are rejected by the selected real parser.
fn Result<usize,errors::Error> skip(ref u8[] source,ref mut lexer::State s,u8 open,u8 close){
    let usize at=s.begin;let usize first=lexer::punctuation(source,s,open)?;
    var usize depth=1;
    while(depth!=0){
        if(s.kind==0){return .err(errors::make(2,at));}
        if(s.kind==open){depth+=1;}else if(s.kind==close){depth-=1;}
        let usize next=lexer::next(source,s)?;
    }return .ok(s.begin);
}
fn Result<Shape,errors::Error> atom(ref u8[] source,ref mut lexer::State s,
    ref ir::Program p,ref locals::Table names,ref functions::Table signatures,usize depth){
    if(depth>32){return .err(errors::make(4,s.begin));}
    let bool reference=word(source,s,b"ref");
    if(reference){let usize prefix=lexer::next(source,s)?;}
    let bool exclusive=reference && word(source,s,b"mut");
    if(exclusive){let usize access=lexer::next(source,s)?;}
    if(s.kind==40){
        let usize open=lexer::next(source,s)?;
        let Shape shape=view(source,s,p,names,signatures,depth+1)?;
        if(shape.kind==0 || s.kind!=41){return .ok(none());}
        let usize close=lexer::punctuation(source,s,41)?;
        // Grouping is already part of Static expressions, not native loans.
        if(shape.kind==3){return .ok(none());}
        return .ok(Shape{.kind=shape.kind,.element=shape.element,.exclusive=exclusive || shape.exclusive});
    }
    if(s.kind==3 || s.kind==4){
        let u8 kind=if(s.kind==3){1}else{2};let usize next=lexer::next(source,s)?;
        return .ok(Shape{.kind=kind,.element=10,.exclusive=exclusive});
    }
    if(s.kind!=2 && s.kind!=5){
        if(reference){return .err(errors::make(3,s.begin));}return .ok(none());
    }
    let usize index=locals::find(source,names,s.begin,s.end);
    let usize target=functions::find(source,signatures,s.begin,s.end);
    let bool text=word(source,s,b"text");let usize next=lexer::next(source,s)?;
    if(text && s.kind==58){
        let usize colon=lexer::next(source,s)?;let usize path=lexer::punctuation(source,s,58)?;
        if(!word(source,s,b"bytes")){return .ok(none());}
        let usize method=lexer::next(source,s)?;let usize end=skip(source,s,40,41)?;
        return .ok(Shape{.kind=1,.element=10,.exclusive=exclusive});
    }
    if(index==64 && target<signatures.count && s.kind==40){
        let u8 element=signatures.return_slice_elements[target];
        if(element==0 || (reference && element!=10)){return .ok(none());}
        let usize end=skip(source,s,40,41)?;
        return .ok(Shape{.kind=if(element==10 && signatures.reference_returns){1}else{3},
            .element=element&127,.exclusive=exclusive || (element&128)!=0});
    }
    if(statics::binding(names,index)){
        return .ok(Shape{.kind=statics::kind(names.registers[index]),.element=10,.exclusive=exclusive});
    }
    if(slices::binding(names,index)){
        let usize site=names.registers[index]-160;
        // An exclusive reference cannot be copied by implicit aliasing.
        if(!reference && ir::exclusive(p,site)){return .ok(none());}
        let u8 element=ir::slice_element(p,site,s.begin)?;
        return .ok(Shape{.kind=3,.element=element,.exclusive=exclusive});
    }
    if(reference && arrays::binding(names,index)){
        let usize root=names.registers[index]-128;
        if(root>=p.arrays.count || p.array_functions[root] as usize!=names.function){return .err(errors::make(3,s.begin));}
        return .ok(Shape{.kind=3,.element=p.arrays.elements[root],.exclusive=exclusive});
    }
    if(reference){return .err(errors::make(3,s.begin));}return .ok(none());
}
fn Result<Shape,errors::Error> view(ref u8[] source,ref mut lexer::State s,
    ref ir::Program p,ref locals::Table names,ref functions::Table signatures,usize depth){
    let Shape shape=atom(source,s,p,names,signatures,depth)?;
    if(shape.kind==0){return .ok(shape);}
    while(statics::range_follows(source,s)?){let usize end=skip(source,s,91,93)?;}
    return .ok(shape);
}
pub fn Result<Shape,errors::Error> inspect(ref u8[] source,ref lexer::State s,
    ref ir::Program p,ref locals::Table names,ref functions::Table signatures){
    var lexer::State look=lexer::snapshot(s);
    let Shape shape=view(source,ref mut look,p,names,signatures,0)?;
    // READ/LEN and other scalar continuations retain ordinary expression
    // lowering. No initializer is evaluated or emitted during classification.
    return .ok(if(look.kind==59){shape}else{none()});
}
