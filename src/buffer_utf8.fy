module buffer_utf8;
import std::bytes as bytes;
import std::text as text;
import buffer_owners as owners;

pub enum Error { Token; State; Utf8; }
// Read-only validation of initialized bytes, not a persistent text certificate.
// The caller binds the native root to this table-local token for the call.
pub fn Result<usize,Error> validate(ref owners::Table table,owners::Token source,
    ref bytes::Buffer buffer) {
    let owners::Owner owner=switch(owners::describe(table,source)) {
        case .ok(value):{value}
        case .err(e):{return .err(switch(e){case .Token:{.Token}
            case .Owners:{.State}case .State:{.State}case .Bounds:{.State}});}
    };
    if(bytes::len(buffer)!=owner.length || bytes::capacity(buffer)!=owner.capacity) {return .err(.State);}
    return switch(text::validate_utf8(bytes::view(buffer))) {
        case .ok(value):{.ok(value.len)}case .err(_):{.err(.Utf8)}
    };
}
