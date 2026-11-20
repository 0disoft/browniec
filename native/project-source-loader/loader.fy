module project_source_loader;
import project_manifest as project;
import anchored_source_loader as anchored;
import source_snapshot as sources;
import project_sources as binding;
import module_entry as entries;
import project_program as programs;

// Private composition, not ambient discovery, a grant, or a public CLI feature.
// Detailed project parse/run errors remain with their existing owning APIs.
pub enum Error { Limit; Acquisition; Binding; Compile; }
pub fn Result<sources::Snapshot,Error> load(ref project::Project metadata,ref u8[] root,usize source_bytes){
    let usize count=project::count(metadata);
    if(count==0 || count>16 || source_bytes>4096){return .err(.Limit);}
    var u8[3840] names=[0;3840];var usize[16] ends=[0;16];var usize used=0;var usize i=0;
    while(i<count){
        let ref u8[] path=switch(project::path(metadata,i)){
            case .ok(v):{v}case .err(_):{return .err(.Binding);}
        };
        if(path.len==0 || path.len>240 || path.len>3840-used){return .err(.Limit);}
        var usize j=0;while(j<path.len){names[used+j]=path[j];j+=1;}
        used+=path.len;ends[i]=used;i+=1;
    }
    return switch(anchored::load(root,ref names[..used],ref ends[..count],source_bytes,3840)){
        case .ok(v):{.ok(v)}case .err(_):{.err(.Acquisition)}
    };
}
pub fn Result<entries::Entry,Error> select(ref project::Project metadata,ref u8[] root,usize source_bytes){
    let sources::Snapshot snapshot=load(metadata,root,source_bytes)?;
    return switch(binding::select(metadata,snapshot)){
        case .ok(v):{.ok(v)}case .err(_):{.err(.Binding)}
    };
}
// Consume the admitted metadata. Real project_program verification/compilation
// retains its requirements; its existing run API denies any requirement.
pub fn Result<programs::Program,Error> compile(project::Project metadata,ref u8[] root,
                                              usize source_bytes,usize image_limit){
    let entries::Entry selected=select(ref metadata,root,source_bytes)?;
    return switch(programs::compile(metadata,selected,image_limit)){
        case .ok(v):{.ok(v)}case .err(_):{.err(.Compile)}
    };
}
