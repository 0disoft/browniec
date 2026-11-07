module slice_result_origin_walk;
import lexer as lexer;
import functions as functions;
import types as types;
import errors as errors;
import source_context as context;

// Advisory data flow only. The independent verifier must prove every result.
// 0 pending recursive summary, 1..8 formal, 9 Static, 255 unknown/local/conflict.
struct Value { u8 tag; u8 input; bool live; }
struct Names { usize[64] begins; usize[64] ends; u8[64] tags; u8[64] inputs; usize count; u8 result; u8 selected; usize returns; }
// Recursive joins copy only 64 origin bytes, never the large name/span table.
struct Origins { u8[64] inputs; }
fn Value unknown(){return Value{.tag=255,.input=255,.live=true};}
fn bool word(ref u8[] source,ref lexer::State s,ref u8[] text){return s.kind==2 && lexer::equal(source[s.begin..s.end],text);}
fn usize find(ref u8[] source,ref Names n,ref lexer::State s){
    var usize i=n.count;while(i>0){i-=1;if(lexer::equal(source[s.begin..s.end],source[n.begins[i]..n.ends[i]])){return i;}}return 64;
}
fn u8 merge(u8 a,u8 b){return if(a==b){a}else if(a==0){b}else if(b==0){a}else{255};}
fn Value joined(Value a,Value b){
    if(!a.live){return b;}if(!b.live){return a;}
    return Value{.tag=if(a.tag==b.tag){a.tag}else{255},.input=merge(a.input,b.input),.live=true};
}
fn Result<usize,errors::Error> add(ref mut Names n,usize begin,usize end,Value v){
    if(n.count==64){return .err(errors::make(4,begin));}let usize i=n.count;
    n.begins[i]=begin;n.ends[i]=end;n.tags[i]=v.tag;n.inputs[i]=v.input;n.count+=1;return .ok(i);
}
fn Origins snapshot(ref Names n){return Origins{.inputs=n.inputs};}
fn void restore(ref mut Names n,ref Origins saved,usize count){n.inputs=saved.inputs;n.count=count;}
fn void collect(ref Names n,ref mut Origins output,usize count,bool first){
    var usize i=0;while(i<count){let u8 input=if(first){n.inputs[i]}else{merge(output.inputs[i],n.inputs[i])};output.inputs[i]=input;i+=1;}
}
fn Result<usize,errors::Error> record(ref mut Names n,Value v,usize at,bool active){
    if(!active || !v.live){return .ok(0);}
    if(v.tag!=n.result || v.input==255){return .err(errors::make(3,at));}
    let u8 selected=merge(n.selected,v.input);n.returns+=1;n.selected=selected;
    if(n.selected==255){return .err(errors::make(3,at));}return .ok(0);
}
fn Result<usize,errors::Error> check_depth(usize depth,usize at){
    if(depth>32){return .err(errors::make(4,at));}return .ok(depth);
}
fn Result<Value,errors::Error> expression(ref u8[] source,ref mut lexer::State s,
    ref functions::Table t,ref u8[] summaries,ref mut Names n,usize depth,bool active){
    let usize checked=check_depth(depth,s.begin)?;
    var Value value=atom(source,s,t,summaries,n,depth,active)?;
    while(s.kind!=0 && s.kind!=59 && s.kind!=44 && s.kind!=41 && s.kind!=93 && s.kind!=125 && s.kind!=58){
        if(s.kind==91){
            let usize open=lexer::next(source,s)?;var bool range=false;
            while(s.kind!=93 && s.kind!=0){
                if(s.kind==46){range=true;let usize dot=lexer::next(source,s)?;}
                else{let Value index=atom(source,s,t,summaries,n,depth+1,active && value.live)?;value.live=value.live && index.live;}
            }let usize close=lexer::punctuation(source,s,93)?;if(!range){value.tag=255;value.input=255;}
        }else if(s.kind==46){
            let usize dot=lexer::next(source,s)?;if(s.kind==2){let usize member=lexer::next(source,s)?;}
            value.tag=255;value.input=255;
        }else if((s.kind>=128 && s.kind<=145) || s.kind==43 || s.kind==45 || s.kind==42 || s.kind==47 || s.kind==37 || s.kind==60 || s.kind==62 || s.kind==38 || s.kind==124 || s.kind==94 || word(source,s,b"as")){
            // Scalar operators/casts never carry a reference origin. Still walk
            // operands so nested returns in CALL actuals/value blocks are seen.
            let usize op=lexer::next(source,s)?;
            if(s.kind==59 || s.kind==44 || s.kind==41 || s.kind==93 || s.kind==125){break;}
            let Value rhs=atom(source,s,t,summaries,n,depth,active && value.live)?;
            value.live=value.live && rhs.live;value.tag=255;value.input=255;
        }else{break;}
    }return .ok(value);
}
fn Result<Value,errors::Error> call(ref u8[] source,ref mut lexer::State s,
    ref functions::Table t,ref u8[] summaries,ref mut Names n,usize target,bool text,usize depth,bool active){
    let usize open=lexer::punctuation(source,s,40)?;var usize ordinal=0;var Value result=unknown();var bool live=true;
    while(s.kind!=41 && s.kind!=0){
        let bool explicit_ref=word(source,s,b"ref");
        let Value actual=expression(source,s,t,summaries,n,depth+1,active && live)?;ordinal+=1;live=live && actual.live;
        if(text){result=Value{.tag=10,.input=if(actual.tag==0){actual.input}else{255},.live=true};}
        else if(target<t.count && summaries[target] as usize==ordinal){
            let usize parameter=target*8+ordinal-1;
            if(explicit_ref && t.param_slices[parameter] && t.param_slice_elements[parameter]==actual.tag){result=actual;}
        }
        if(s.kind==41){break;}let usize comma=lexer::punctuation(source,s,44)?;
    }let usize close=lexer::punctuation(source,s,41)?;
    if(target<t.count){
        result.tag=t.return_slice_elements[target];
        if(summaries[target]==0){result.input=0;}
        else if(t.reference_returns && summaries[target]==9){result.input=9;}
    }result.live=live;return .ok(result);
}
fn Result<Value,errors::Error> atom(ref u8[] source,ref mut lexer::State s,
    ref functions::Table t,ref u8[] summaries,ref mut Names n,usize depth,bool active){
    let usize checked=check_depth(depth,s.begin)?;
    if(word(source,s,b"if")){return conditional(source,s,t,summaries,n,depth,active);}
    if(word(source,s,b"switch")){return selection(source,s,t,summaries,n,depth,active);}
    if(s.kind==123){return block(source,s,t,summaries,n,depth+1,active);}
    if(s.kind==40){let usize open=lexer::next(source,s)?;
        let Value v=expression(source,s,t,summaries,n,depth+1,active)?;let usize close=lexer::punctuation(source,s,41)?;return .ok(v);}
    if(word(source,s,b"ref")){
        let usize prefix=lexer::next(source,s)?;let bool writer=word(source,s,b"mut");if(writer){let usize access=lexer::next(source,s)?;}
        var Value v=atom(source,s,t,summaries,n,depth+1,active)?;
        if(writer && v.tag!=255){v.tag|=128;}return .ok(v);
    }
    if(t.reference_returns && (s.kind==3 || s.kind==4)){
        let u8 tag=if(s.kind==3){10}else{0};let usize literal=lexer::next(source,s)?;return .ok(Value{.tag=tag,.input=9,.live=true});
    }
    if(s.kind==2 || s.kind==5){
        let usize local=find(source,n,s);let usize target=functions::find(source,t,s.begin,s.end);
        let bool text=word(source,s,b"text");let usize name=lexer::next(source,s)?;
        if(s.kind==58){
            let usize first=lexer::next(source,s)?;let usize second=lexer::punctuation(source,s,58)?;
            let bool bytes=text && word(source,s,b"bytes");if(s.kind==2){let usize member=lexer::next(source,s)?;}
            if(s.kind==40){return call(source,s,t,summaries,n,16,bytes,depth,active);}return .ok(unknown());
        }
        if(s.kind==40){return call(source,s,t,summaries,n,if(local==64){target}else{16},false,depth,active);}
        if(local<64){return .ok(Value{.tag=n.tags[local],.input=n.inputs[local],.live=true});}
        return .ok(unknown());
    }
    if(s.kind==91){
        let usize open=lexer::next(source,s)?;
        while(s.kind!=93 && s.kind!=0){if(s.kind==59 || s.kind==44){let usize separator=lexer::next(source,s)?;}
            else{let Value ignored=expression(source,s,t,summaries,n,depth+1,active)?;}}
        let usize close=lexer::punctuation(source,s,93)?;return .ok(unknown());
    }
    if(s.kind==33 || s.kind==45 || s.kind==126){let usize unary=lexer::next(source,s)?;
        let Value rhs=atom(source,s,t,summaries,n,depth+1,active)?;var Value v=unknown();v.live=rhs.live;return .ok(v);}
    if(s.kind==46){let usize dot=lexer::next(source,s)?;return atom(source,s,t,summaries,n,depth+1,active);}
    // Scalar or constructor punctuation. Always advance.
    let usize scalar=lexer::next(source,s)?;return .ok(unknown());
}
fn Result<Value,errors::Error> condition(ref u8[] source,ref mut lexer::State s,
    ref functions::Table t,ref u8[] summaries,ref mut Names n,usize depth,bool active){
    let usize open=lexer::punctuation(source,s,40)?;
    let Value test=expression(source,s,t,summaries,n,depth+1,active)?;
    let usize close=lexer::punctuation(source,s,41)?;return .ok(test);
}
fn Result<Value,errors::Error> conditional(ref u8[] source,ref mut lexer::State s,
    ref functions::Table t,ref u8[] summaries,ref mut Names n,usize depth,bool active){
    let usize keyword=lexer::next(source,s)?;let Value test=condition(source,s,t,summaries,n,depth,active)?;
    let usize count=n.count;let Origins before=snapshot(n);
    let Value left=block(source,s,t,summaries,n,depth+1,active && test.live)?;
    var Origins output=snapshot(n);restore(n,ref before,count);var Value right=unknown();
    if(word(source,s,b"else")){let usize alternative=lexer::next(source,s)?;
        right=if(word(source,s,b"if")){conditional(source,s,t,summaries,n,depth+1,active && test.live)?}
            else{block(source,s,t,summaries,n,depth+1,active && test.live)?};
    }
    if(right.live){collect(n,ref mut output,count,!left.live);}
    restore(n,ref output,count);var Value result=joined(left,right);result.live=result.live && test.live;return .ok(result);
}
fn Result<Value,errors::Error> selection(ref u8[] source,ref mut lexer::State s,
    ref functions::Table t,ref u8[] summaries,ref mut Names n,usize depth,bool active){
    let usize keyword=lexer::next(source,s)?;let Value test=condition(source,s,t,summaries,n,depth,active)?;
    let usize open=lexer::punctuation(source,s,123)?;let usize count=n.count;
    let Origins before=snapshot(n);var Origins output=snapshot(n);var Value result=unknown();result.live=false;var usize arms=0;
    while(s.kind!=125 && s.kind!=0){
        restore(n,ref before,count);let usize case_word=lexer::word(source,s,b"case")?;
        // Case payload bindings shadow outer names inside this arm only.
        var usize parens=0;
        while(s.kind!=58 && s.kind!=0){
            if(s.kind==40){parens+=1;}else if(s.kind==41){if(parens==0){return .err(errors::make(2,s.begin));}parens-=1;}
            else if(s.kind==2 && parens>0){let usize added=add(n,s.begin,s.end,unknown())?;}
            let usize pattern=lexer::next(source,s)?;
        }let usize colon=lexer::punctuation(source,s,58)?;
        let Value arm=block(source,s,t,summaries,n,depth+1,active && test.live)?;
        if(arm.live){collect(n,ref mut output,count,!result.live);}result=joined(result,arm);arms+=1;
    }let usize close=lexer::punctuation(source,s,125)?;
    if(arms==0){return .err(errors::make(2,s.begin));}restore(n,ref output,count);result.live=result.live && test.live;return .ok(result);
}
fn Result<Value,errors::Error> declaration(ref u8[] source,ref mut lexer::State s,
    ref functions::Table t,ref u8[] summaries,ref mut Names n,usize depth,bool active){
    let usize keyword=lexer::next(source,s)?;var u8 tag=255;
    if(word(source,s,b"ref")){
        let usize prefix=lexer::next(source,s)?;let bool writer=word(source,s,b"mut");if(writer){let usize access=lexer::next(source,s)?;}
        let bool text=t.reference_returns && word(source,s,b"str");
        tag=if(text){let usize text_word=lexer::next(source,s)?;0}else{types::parse(source,s)?};
        if(!text){let usize open=lexer::punctuation(source,s,91)?;let usize close=lexer::punctuation(source,s,93)?;}
        if(writer){tag|=128;}
    }
    var usize begin=s.begin;var usize end=s.end;
    // All declarations enter the table, including scalar/owner shadowing names.
    while(s.kind!=61 && s.kind!=0 && s.kind!=59){if(s.kind==2){begin=s.begin;end=s.end;}let usize token=lexer::next(source,s)?;}
    let usize equal=lexer::punctuation(source,s,61)?;
    var Value v=expression(source,s,t,summaries,n,depth,active)?;
    if(tag!=255){if(v.tag!=tag){v.input=255;}v.tag=tag;}
    let usize added=add(n,begin,end,v)?;return .ok(v);
}
fn Result<Value,errors::Error> block(ref u8[] source,ref mut lexer::State s,
    ref functions::Table t,ref u8[] summaries,ref mut Names n,usize depth,bool active){
    let usize checked=check_depth(depth,s.begin)?;let usize open=lexer::punctuation(source,s,123)?;
    let usize count=n.count;var bool live=true;var Value tail=unknown();
    while(s.kind!=125 && s.kind!=0){
        if(s.kind==59){let usize semicolon=lexer::next(source,s)?;continue;}
        if(word(source,s,b"return")){
            let usize at=s.begin;let usize keyword=lexer::next(source,s)?;
            let Value v=expression(source,s,t,summaries,n,depth,active && live)?;
            let usize saved=record(n,v,at,active && live)?;live=false;tail=unknown();
        }else if(word(source,s,b"let") || word(source,s,b"var")){
            let Value v=declaration(source,s,t,summaries,n,depth,active && live)?;live=live && v.live;tail=unknown();
        }else{
            var lexer::State look=lexer::snapshot(s);let usize local=find(source,n,ref look);
            if(look.kind==2){let usize name=lexer::next(source,ref mut look)?;}
            if(local<64 && look.kind==61){
                let usize name=lexer::next(source,s)?;let usize equal=lexer::next(source,s)?;
                let Value v=expression(source,s,t,summaries,n,depth,active && live)?;
                let u8 input=if(v.tag==n.tags[local]){v.input}else{255};n.inputs[local]=input;live=live && v.live;tail=unknown();
            }else{
                let Value v=expression(source,s,t,summaries,n,depth,active && live)?;live=live && v.live;
                tail=if(s.kind==59){unknown()}else{v};
            }
        }
        if(s.kind==59){let usize semicolon=lexer::next(source,s)?;}
    }let usize close=lexer::punctuation(source,s,125)?;n.count=count;tail.live=live;return .ok(tail);
}
pub fn Result<u8,errors::Error> body(ref u8[] source,ref functions::Table t,ref u8[] summaries,usize f){
    var Names n=Names{.begins=[0;64],.ends=[0;64],.tags=[255;64],.inputs=[255;64],.count=0,.result=t.return_slice_elements[f],.selected=0,.returns=0};
    var usize i=0;while(i<t.arities[f]){let usize at=f*8+i;
        let u8 input=if(i==0){1}else if(i==1){2}else if(i==2){3}else if(i==3){4}else if(i==4){5}else if(i==5){6}else if(i==6){7}else{8};
        let Value v=Value{.tag=if(t.param_slices[at]){t.param_slice_elements[at]}else{255},.input=input,.live=true};
        let usize added=add(ref mut n,t.param_begins[at],t.param_ends[at],v)?;i+=1;
    }
    // functions::Table.bodies points to the first token inside the outer body.
    var lexer::State s=context::state(source,ref t.context,t.bodies[f])?;
    // Synthetic opener: cursor still points to the first real body token. This
    // avoids a backwards search through comments for the outer opening brace.
    s.kind=123;s.begin=t.bodies[f];s.end=s.begin;
    let Value result=block(source,ref mut s,t,summaries,ref mut n,0,true)?;
    if(n.returns==0){return .err(errors::make(3,t.begins[f]));}return .ok(n.selected);
}
