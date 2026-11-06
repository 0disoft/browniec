module aggregate_copy;

// Checked byte-window facts, not type, lifetime, loan or ownership authority.
// Callers authenticate both values before proving their actual backing ranges.
pub enum Relation { Disjoint; Identical; Overlap; }
pub enum Mode { Direct; NoOp; Snapshot; }
pub enum Error { Bounds; Scratch; Alias; }

pub fn Result<Relation,Error> relation(usize destination,usize source,usize size,usize limit){
    // Subtraction guards also handle usize maximum without overflowing an end.
    if(destination>limit || size>limit-destination || source>limit || size>limit-source){
        return .err(.Bounds);
    }
    if(destination==source){return .ok(.Identical);}
    if(size==0 || (destination<source && size<=source-destination) ||
        (source<destination && size<=destination-source)){return .ok(.Disjoint);}
    return .ok(.Overlap);
}

// The result is consumed immediately against the same immutable metadata; no
// publication API accepts a caller-supplied Mode as an authority token.
// Snapshot callers finish canonical encoding in disjoint scratch before writing.
pub fn Result<Mode,Error> prove(usize destination,usize source,usize size,usize limit,
    bool staged,usize scratch,bool same_identity){
    let Relation checked=relation(destination,source,size,limit)?;
    if(staged){if(scratch<size){return .err(.Scratch);}return .ok(.Snapshot);}
    if(size==0){return .ok(.Direct);}
    return switch(checked){
        case .Disjoint:{.ok(.Direct)}
        case .Identical:{if(same_identity){.ok(.NoOp)}else{.err(.Alias)}}
        case .Overlap:{.err(.Alias)}
    };
}
