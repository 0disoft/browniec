module host_catalog_names;
import std::bytes as bytes;

// Catalog schema spelling, independent of source keywords or capability grants.
fn bool lower(u8 c){return c>=97 && c<=122;}
fn bool digit(u8 c){return c>=48 && c<=57;}
fn bool alpha(u8 c){return lower(c) || (c>=65 && c<=90) || c==95;}
fn bool identifier(ref u8[] s){
    if(s.len==0 || !alpha(s[0])){return false;}
    var usize i=1;while(i<s.len){if(!alpha(s[i]) && !digit(s[i])){return false;}i+=1;}return true;
}
pub fn bool module_name(ref u8[] s){
    if(s.len<7 || s.len>128 || !bytes::equal(s[..6],b"host::")){return false;}
    var usize begin=6;var usize i=6;
    while(i<s.len){
        if(s[i]==58){
            if(i+1>=s.len || s[i+1]!=58 || !identifier(s[begin..i])){return false;}
            i+=2;begin=i;
        }else{i+=1;}
    }
    return identifier(s[begin..s.len]);
}
pub fn bool symbol(ref u8[] s){return s.len<=64 && identifier(s);}
pub fn bool capability(ref u8[] s){
    if(s.len<3 || s.len>128){return false;}
    var bool first=true;var bool dot=false;var usize i=0;
    while(i<s.len){
        let u8 c=s[i];
        if(first){if(!lower(c)){return false;}first=false;}
        else if(c==46){first=true;dot=true;}
        else if(!lower(c) && !digit(c)){return false;}
        i+=1;
    }
    return dot && !first;
}
pub fn bool revision(ref u8[] s){
    if(s.len==0 || s.len>64){return false;}
    var usize i=0;while(i<s.len){if(!alpha(s[i]) && !digit(s[i]) && s[i]!=46){return false;}i+=1;}return true;
}
pub fn ref u8[] parameter(u8 tag){
    let ref u8[] all=b"boolu8i32i64u32usizeref u8[]";var usize begin=0;var usize end=0;
    if(tag==1){begin=0;end=4;}
    else if(tag==2){begin=4;end=6;}
    else if(tag==3){begin=6;end=9;}
    else if(tag==4){begin=9;end=12;}
    else if(tag==5){begin=12;end=15;}
    else if(tag==6){begin=15;end=20;}
    else if(tag==7){begin=20;end=28;}
    return all[begin..end];
}
pub fn ref u8[] result(u8 tag){
    let ref u8[] all=b"Result<bool,u32>Result<u8,u32>Result<i32,u32>Result<i64,u32>Result<u32,u32>Result<usize,u32>Result<brownie::bytes::Buffer,u32>";var usize begin=0;var usize end=0;
    if(tag==1){begin=0;end=16;}
    else if(tag==2){begin=16;end=30;}
    else if(tag==3){begin=30;end=45;}
    else if(tag==4){begin=45;end=60;}
    else if(tag==5){begin=60;end=75;}
    else if(tag==6){begin=75;end=92;}
    else if(tag==7){begin=92;end=126;}
    return all[begin..end];
}
pub fn u8 type_tag(ref u8[] s,bool returns){
    var u8 tag=1;while(tag<=7){
        if(bytes::equal(s,if(returns){result(tag)}else{parameter(tag)})){return tag;}tag+=1;
    }return 0;
}
fn u8 qualified_byte(ref u8[] scope,ref u8[] name,usize i){
    if(i<scope.len){return scope[i];}if(i<scope.len+2){return 58;}return name[i-scope.len-2];
}
// Compare the complete qualified spelling, not a tuple of module and symbol:
// host::a0::x precedes host::a::x: '0' (48) precedes ':' (58).
pub fn bool before(ref u8[] a,ref u8[] x,ref u8[] b,ref u8[] y){
    let usize left=a.len+2+x.len;let usize right=b.len+2+y.len;var usize i=0;
    while(i<left && i<right){
        let u8 c=qualified_byte(a,x,i);let u8 d=qualified_byte(b,y,i);
        if(c!=d){return c<d;}i+=1;
    }return left<right;
}
