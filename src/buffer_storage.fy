module buffer_storage;

import std::bytes as bytes;
import buffer_growth as growth;

// Private owning native storage; no guest descriptor, token table or VM access.
pub enum Error { State; Overflow; Quota; NoGrowth; Allocation; Provider; }

fn Error admission_error(growth::Error error) {
    return switch(error) {
        case .State: { .State } case .Overflow: { .Overflow }
        case .Quota: { .Quota } case .NoGrowth: { .NoGrowth }
    };
}

// On error the local replacement is dropped before the caller cancels its charge.
fn Result<bytes::Buffer,Error> prepare(ref bytes::Buffer old,usize capacity) {
    var bytes::Buffer replacement=switch(bytes::with_capacity(capacity)) {
        case .ok(value): { value } case .err(_): { return .err(.Allocation); }
    };
    if(bytes::capacity(ref replacement)!=capacity) {return .err(.Provider);}
    switch(bytes::append(ref mut replacement,bytes::view(old))) {
        case .ok(_): { } case .err(_): { return .err(.Provider); }
    };
    if(bytes::capacity(ref replacement)!=capacity || bytes::len(ref replacement)!=bytes::len(old)) {
        return .err(.Provider);
    }
    return .ok(replacement);
}

// Caller publishes by replacing its owning root, then invokes growth::commit.
// A discarded replacement must be dropped before growth::cancel is called.
pub fn Result<bytes::Buffer,Error> prepare_growth(ref bytes::Buffer buffer,usize required,
    growth::Limits limits,ref mut growth::Ledger ledger) {
    let usize old=bytes::capacity(buffer);
    if(bytes::len(buffer)>old) {return .err(.State);}
    let usize capacity=switch(growth::begin(old,required,limits,ledger)) {
        case .ok(value): { value } case .err(e): { return .err(admission_error(e)); }
    };
    let bytes::Buffer replacement=switch(prepare(buffer,capacity)) {
        case .ok(value): { value }
        case .err(e): {
            // The failed helper has dropped its unpublished allocation already.
            switch(growth::cancel(ledger)) {
                case .ok(_): { } case .err(_): { return .err(.State); }
            };
            return .err(e);
        }
    };
    return .ok(replacement);
}
