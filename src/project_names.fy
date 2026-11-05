module project_names;

import lexer as lexer;
import locals as locals;

// Pure spelling predicates for untrusted project metadata. These helpers do not
// open, resolve or anchor files and do not claim filesystem identity.
fn bool lower(u8 ch){return ch>=97 && ch<=122;}
fn bool upper(u8 ch){return ch>=65 && ch<=90;}
fn bool digit(u8 ch){return ch>=48 && ch<=57;}
fn u8 folded(u8 ch){return if(upper(ch)){ch+32}else{ch};}

pub fn bool project_name(ref u8[] name){
    if(name.len==0 || name.len>80 || (!lower(name[0]) && !digit(name[0]))){return false;}
    var usize i=1;while(i<name.len){
        let u8 ch=name[i];
        if(!lower(ch) && !digit(ch) && ch!=45){return false;}i+=1;
    }
    return true;
}

fn bool module_segment(ref u8[] segment){
    return lexer::simple(segment,0,segment.len) && !locals::reserved(segment);
}

fn bool module_root(ref u8[] segment){
    return lexer::equal(segment,b"std") || lexer::equal(segment,b"brownie");
}

pub fn bool module_name(ref u8[] name){
    if(name.len==0 || name.len>128){return false;}
    var usize begin=0;var usize i=0;
    while(i<name.len){
        if(name[i]==58){
            if(i+1>=name.len || name[i+1]!=58){return false;}
            let ref u8[] segment=name[begin..i];
            if(!module_segment(segment) || (begin==0 && module_root(segment))){return false;}
            i+=2;begin=i;
            if(begin==name.len){return false;}
        }else{i+=1;}
    }
    let ref u8[] segment=name[begin..name.len];
    return module_segment(segment) && !(begin==0 && module_root(segment));
}

pub fn bool function_name(ref u8[] name){
    return name.len>=1 && name.len<=64 && module_segment(name);
}

fn bool capability_segment(ref u8[] segment){
    if(segment.len==0 || !lower(segment[0])){return false;}
    var usize i=1;while(i<segment.len){
        if(!lower(segment[i]) && !digit(segment[i])){return false;}i+=1;
    }
    return true;
}

pub fn bool capability(ref u8[] name){
    if(name.len==0 || name.len>128){return false;}
    var usize begin=0;var usize i=0;var usize segments=0;
    while(i<name.len){
        if(name[i]==46){
            if(!capability_segment(name[begin..i])){return false;}
            segments+=1;begin=i+1;
        }else if(!lower(name[i]) && !digit(name[i])){return false;}
        i+=1;
    }
    if(!capability_segment(name[begin..name.len])){return false;}
    return segments+1>=2;
}

fn bool member_byte(u8 ch){
    return (ch>=65 && ch<=90) || lower(ch) || digit(ch) || ch==95 || ch==46 || ch==45;
}

fn bool device_stem(ref u8[] stem){
    if(stem.len==3){
        let u8 a=folded(stem[0]);let u8 b=folded(stem[1]);let u8 c=folded(stem[2]);
        return (a==99 && b==111 && c==110) || (a==112 && b==114 && c==110) ||
            (a==97 && b==117 && c==120) || (a==110 && b==117 && c==108);
    }
    if(stem.len==4){
        let u8 a=folded(stem[0]);let u8 b=folded(stem[1]);let u8 c=folded(stem[2]);
        let u8 d=stem[3];
        return ((a==99 && b==111 && c==109) || (a==108 && b==112 && c==116)) &&
            d>=49 && d<=57;
    }
    return false;
}

fn bool member_component(ref u8[] component){
    if(component.len==0){return false;}
    let usize last=component.len-1;
    if(component[last]==46){return false;}
    if(component.len==2 && component[0]==46 && component[1]==46){return false;}
    var usize stem_end=0;while(stem_end<component.len && component[stem_end]!=46){stem_end+=1;}
    return !device_stem(component[0..stem_end]);
}

fn bool member_suffix(ref u8[] path){
    let usize n=path.len;
    return (n>=4 && path[n-4]==46 && path[n-3]==98 && path[n-2]==114 && path[n-1]==99) ||
        (n>=3 && path[n-3]==46 && path[n-2]==102 && path[n-1]==121);
}

pub fn bool member_path(ref u8[] path){
    if(path.len==0 || path.len>240 || !member_suffix(path)){return false;}
    var usize begin=0;var usize i=0;
    while(i<path.len){
        let u8 ch=path[i];
        if(ch==47){
            if(!member_component(path[begin..i])){return false;}begin=i+1;
        }else if(!member_byte(ch)){return false;}
        i+=1;
    }
    return member_component(path[begin..path.len]);
}

pub fn bool same_path(ref u8[] a,ref u8[] b){
    if(!member_path(a) || !member_path(b) || a.len!=b.len){return false;}
    var usize i=0;while(i<a.len){
        if(folded(a[i])!=folded(b[i])){return false;}i+=1;
    }
    return true;
}
