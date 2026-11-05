module slice_result_source_origins;
import lexer as lexer;
import functions as functions;
import types as types;
import errors as errors;
import source_context as context;

// Advisory lowering hints, never admission. Final IR must independently ground
// the same origin through CALL and alias definitions before it can execute.
// 0 unresolved, 1..8 input position, 255 not an input-backed reference.
struct Names { usize[64] begins; usize[64] ends; usize[64] depths; u8[64] tags; u8[64] inputs; usize count; }
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] name){return s.kind==2 && lexer::equal(source[s.begin..s.end],name);}
fn u8 lookup(ref u8[] source,ref Names names,ref lexer::State s,u8 tag){
    var usize i=names.count;while(i>0){i-=1;if(lexer::equal(source[s.begin..s.end],source[names.begins[i]..names.ends[i]])){
        return if(names.tags[i]==tag){names.inputs[i]}else{255};
    }}return 255;
}
fn Result<usize,errors::Error> add(ref mut Names names,usize begin,usize end,usize depth,u8 tag,u8 input){
    if(names.count>=64){return .err(errors::make(4,begin));}let usize i=names.count;
    names.begins[i]=begin;names.ends[i]=end;names.depths[i]=depth;names.tags[i]=tag;names.inputs[i]=input;names.count+=1;return .ok(i);
}
// Skip one complete actual without evaluating it. The outer body walk still
// visits its tokens, including lexical blocks and returns in value expressions.
fn Result<usize,errors::Error> next_actual(ref u8[] source,ref mut lexer::State s){
    var usize parens=0;var usize brackets=0;var usize braces=0;
    while(s.kind!=0){
        if(parens==0 && brackets==0 && braces==0 && (s.kind==44 || s.kind==41)){return .ok(s.begin);}
        if(s.kind==40){parens+=1;}else if(s.kind==41){if(parens==0){return .err(errors::make(2,s.begin));}parens-=1;}
        else if(s.kind==91){brackets+=1;}else if(s.kind==93){if(brackets==0){return .err(errors::make(2,s.begin));}brackets-=1;}
        else if(s.kind==123){braces+=1;}else if(s.kind==125){if(braces==0){return .err(errors::make(2,s.begin));}braces-=1;}
        let usize advanced=lexer::next(source,s)?;
    }return .err(errors::make(2,s.begin));
}
fn Result<u8,errors::Error> expression(ref u8[] source,ref mut lexer::State s,
    ref functions::Table t,ref u8[] summaries,ref Names names,u8 tag,usize depth){
    if(depth>32){return .err(errors::make(4,s.begin));}
    if(t.reference_returns && (tag==10 || tag==0)){
        if(s.kind==40){let usize open=lexer::next(source,s)?;return expression(source,s,t,summaries,names,tag,depth+1);}
        if(word(source,s,b"ref")){let usize prefix=lexer::next(source,s)?;
            return expression(source,s,t,summaries,names,tag,depth+1);}
        if((tag==10 && s.kind==3) || (tag==0 && s.kind==4)){return .ok(9);}
        if(tag==10 && word(source,s,b"text")){
            var lexer::State look=lexer::snapshot(s);let usize next=lexer::next(source,ref mut look)?;
            if(look.kind==58){let usize module_name=lexer::next(source,s)?;
                let usize a=lexer::punctuation(source,s,58)?;let usize b=lexer::punctuation(source,s,58)?;
                let usize method=lexer::word(source,s,b"bytes")?;let usize open=lexer::punctuation(source,s,40)?;
                return expression(source,s,t,summaries,names,0,depth+1);
            }
        }
        if(s.kind==2){let u8 named=lookup(source,names,s,tag);if(named!=255){return .ok(named);}}
    }
    if(word(source,s,b"ref")){
        let usize reference=lexer::next(source,s)?;
        if((tag&128)!=0){let usize access=lexer::word(source,s,b"mut")?;}
        if(s.kind!=2){return .ok(255);}
        var lexer::State look=lexer::snapshot(s);let usize advanced=lexer::next(source,ref mut look)?;
        if(look.kind==40){return expression(source,s,t,summaries,names,tag,depth+1);}
        return .ok(lookup(source,names,s,tag));
    }
    if(s.kind!=2 && s.kind!=5){return .ok(255);}
    let usize target=functions::find(source,t,s.begin,s.end);
    if(target>=t.count || t.return_slice_elements[target]!=tag){return .ok(255);}
    let usize name=lexer::next(source,s)?;let usize open=lexer::punctuation(source,s,40)?;
    let usize chosen=summaries[target] as usize;if(chosen==0){return .ok(0);}
    if(t.reference_returns && chosen==9){return .ok(9);}
    var usize argument=1;
    while(argument<chosen){let usize skipped=next_actual(source,s)?;let usize comma=lexer::punctuation(source,s,44)?;argument+=1;}
    let usize parameter=target*8+chosen-1;
    if(!t.param_slices[parameter] || t.param_slice_elements[parameter]!=tag){return .ok(255);}
    if(!word(source,s,b"ref")){return .ok(255);}
    return expression(source,s,t,summaries,names,tag,depth+1);
}
// Advisory local type hints for inferred reference initializers. These do not
// grant a lifetime: final lowering and independent IR proof recheck everything.
// Text uses tag 0, so 255 is the distinct non-reference sentinel.
fn Result<u8,errors::Error> inferred_tag(ref u8[] source,ref mut lexer::State s,
    ref functions::Table t,ref Names names,usize depth){
    if(depth>32){return .err(errors::make(4,s.begin));}
    if(s.kind==40){let usize open=lexer::next(source,s)?;return inferred_tag(source,s,t,names,depth+1);}
    if(word(source,s,b"ref")){
        let usize prefix=lexer::next(source,s)?;let bool writer=word(source,s,b"mut");
        if(writer){let usize access=lexer::next(source,s)?;}
        let u8 tag=inferred_tag(source,s,t,names,depth+1)?;
        return .ok(if(tag==255){255}else{tag|if(writer){128}else{0}});
    }
    if(t.reference_returns && (s.kind==3 || s.kind==4)){return .ok(if(s.kind==3){10}else{0});}
    if(s.kind!=2 && s.kind!=5){return .ok(255);}
    if(t.reference_returns && word(source,s,b"text")){
        var lexer::State look=lexer::snapshot(s);let usize next=lexer::next(source,ref mut look)?;
        if(look.kind==58){let usize colon=lexer::next(source,ref mut look)?;
            let usize path=lexer::punctuation(source,ref mut look,58)?;
            if(word(source,ref look,b"bytes")){return .ok(10);}
        }
    }
    var usize i=names.count;while(i>0){i-=1;
        if(lexer::equal(source[s.begin..s.end],source[names.begins[i]..names.ends[i]])){return .ok(names.tags[i]);}
    }
    let usize f=functions::find(source,t,s.begin,s.end);
    return .ok(if(f<t.count && t.return_slice_elements[f]!=0){t.return_slice_elements[f]}else{255});
}
fn Result<u8,errors::Error> body(ref u8[] source,ref functions::Table t,ref u8[] summaries,usize f){
    var Names names=Names{.begins=[0;64],.ends=[0;64],.depths=[0;64],.tags=[0;64],.inputs=[0;64],.count=0};
    var usize i=0;while(i<t.arities[f]){let usize at=f*8+i;
        if(t.param_slices[at]){let u8 input=if(i==0){1}else if(i==1){2}else if(i==2){3}else if(i==3){4}else if(i==4){5}else if(i==5){6}else if(i==6){7}else{8};
            let usize added=add(ref mut names,t.param_begins[at],t.param_ends[at],0,t.param_slice_elements[at],input)?;}i+=1;
    }
    let usize parameters=names.count;var usize depth=0;var usize returns=0;var u8 selected=0;
    var lexer::State s=context::state(source,ref t.context,t.bodies[f])?;let usize first=lexer::next(source,ref mut s)?;
    while(s.kind!=0 && s.begin<t.body_ends[f]){
        if(s.kind==123){depth+=1;}
        else if(s.kind==125){
            if(depth==0){return .err(errors::make(2,s.begin));}
            while(names.count>parameters && names.depths[names.count-1]>=depth){names.count-=1;}depth-=1;
        }else if(word(source,ref s,b"let")){
            var lexer::State look=lexer::snapshot(ref s);let usize keyword=lexer::next(source,ref mut look)?;
            if(word(source,ref look,b"ref")){
                let usize reference=lexer::next(source,ref mut look)?;let bool writer=word(source,ref look,b"mut");
                if(writer){let usize access=lexer::next(source,ref mut look)?;}
                let bool text=t.reference_returns && word(source,ref look,b"str");
                let u8 element=if(text){let usize tag=lexer::next(source,ref mut look)?;0}else{types::parse(source,ref mut look)?};
                if(!text){let usize open=lexer::punctuation(source,ref mut look,91)?;let usize close=lexer::punctuation(source,ref mut look,93)?;}
                if(look.kind!=2){return .err(errors::make(2,look.begin));}
                let usize begin=look.begin;let usize end=look.end;let usize name=lexer::next(source,ref mut look)?;
                let usize equals=lexer::punctuation(source,ref mut look,61)?;let u8 tag=element|if(writer){128}else{0};
                let u8 input=expression(source,ref mut look,t,summaries,ref names,tag,0)?;
                let usize added=add(ref mut names,begin,end,depth,tag,input)?;
            }else if(look.kind==2){
                let usize begin=look.begin;let usize end=look.end;let usize name=lexer::next(source,ref mut look)?;
                if(look.kind==61){let usize equal=lexer::next(source,ref mut look)?;
                    var lexer::State shape=lexer::snapshot(ref look);
                    let u8 tag=inferred_tag(source,ref mut shape,t,ref names,0)?;
                    if(tag!=255){
                        let u8 input=expression(source,ref mut look,t,summaries,ref names,tag,0)?;
                        let usize added=add(ref mut names,begin,end,depth,tag,input)?;
                    }
                }
            }
        }else if(word(source,ref s,b"return")){
            var lexer::State look=lexer::snapshot(ref s);let usize keyword=lexer::next(source,ref mut look)?;
            let u8 found=expression(source,ref mut look,t,summaries,ref names,t.return_slice_elements[f],0)?;returns+=1;
            if(found==255){return .err(errors::make(3,s.begin));}
            if(found!=0){if(selected!=0 && selected!=found){return .err(errors::make(3,s.begin));}selected=found;}
        }
        let usize advanced=lexer::next(source,ref mut s)?;
    }
    if(returns==0){return .err(errors::make(3,t.begins[f]));}
    // A known branch can ground recursion; all pending paths are checked again.
    return .ok(selected);
}
pub fn Result<usize,errors::Error> infer(ref u8[] source,ref mut functions::Table t){
    if(t.count==0 || t.count>16){return .err(errors::make(3,0));}
    t.return_slice_inputs=[0;16];
    var usize checked=0;while(checked<t.count){
        if(t.arities[checked]>8 || t.bodies[checked]>t.body_ends[checked] || t.body_ends[checked]>source.len){return .err(errors::make(3,0));}checked+=1;
    }
    var usize rounds=0;
    while(rounds<17){rounds+=1;var bool changed=false;var usize unresolved=16;var usize f=0;
        while(f<t.count){if(t.return_slice_elements[f]!=0){
            let u8 found=body(source,t,ref t.return_slice_inputs,f)?;
            if(found==0){if(unresolved==16){unresolved=f;}}
            else if(t.return_slice_inputs[f]!=0 && t.return_slice_inputs[f]!=found){return .err(errors::make(3,t.begins[f]));}
            else if(t.return_slice_inputs[f]==0){t.return_slice_inputs[f]=found;changed=true;}
        }f+=1;}
        if(!changed){if(unresolved<16){return .err(errors::make(3,t.begins[unresolved]));}return .ok(rounds);}
    }return .err(errors::make(3,0));
}
