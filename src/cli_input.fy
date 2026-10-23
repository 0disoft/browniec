module cli_input;

import errors as errors;
import std::fs as fs;
import std::process as process;
import std::text as text;

pub struct Source { u8[4096] data; usize length; }

// Read only a selected local disk file. This is not a restricted source collector.
@effects(filesystem)
pub fn Result<Source, errors::Error> read_source(usize argument) {
    var u8[4096] path = [0; 4096];
    let usize length = switch (process::arg(argument, ref mut path)) {
        case .ok(n): { n } case .err(_): { return .err(errors::make(9, 0)); }
    };
    let ref u8[] path_view = ref path;
    let ref str name = switch (text::validate_utf8(path_view[..length])) {
        case .ok(value): { value } case .err(_): { return .err(errors::make(9, 0)); }
    };
    var fs::File file = switch (fs::open_read_utf8(name)) {
        case .ok(value): { value } case .err(_): { return .err(errors::make(9, 0)); }
    };
    let bool disk = switch (fs::kind(ref file)) {
        case .ok(kind): { fs::kind_is_disk(kind) } case .err(_): { false }
    };
    if (!disk) { return .err(errors::make(9, 0)); }
    var Source source = Source { .data = [0; 4096], .length = 0 };
    var usize used = 0;
    while (used < 4096) {
        let usize read = switch (fs::read(ref mut file, ref mut source.data[used..])) {
            case .ok(n): { n } case .err(_): { return .err(errors::make(9, used)); }
        };
        if (read == 0) { source.length = used; return .ok(source); }
        used += read;
    }
    var u8[1] extra = [0; 1];
    let usize tail = switch (fs::read(ref mut file, ref mut extra)) {
        case .ok(n): { n } case .err(_): { return .err(errors::make(9, used)); }
    };
    if (tail != 0) { return .err(errors::make(4, used)); }
    source.length = used;
    return .ok(source);
}
