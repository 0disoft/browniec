module storage_checks;

import storage as storage;
import std::bytes as bytes;

fn storage::Limits limits(usize object, usize instance, usize engine) {
    return storage::Limits { .object = object, .instance = instance, .engine = engine };
}

fn void planned(usize old, usize required, storage::Limits policy, ref storage::Ledger ledger, usize expected) {
    switch (storage::plan(old, required, policy, ledger)) {
        case .ok(value): { assert(value == expected); }
        case .err(_): { assert(false); }
    };
}

fn void committed(usize capacity, ref mut storage::Ledger ledger) {
    switch (storage::commit(capacity, ledger)) {
        case .ok(value): { assert(value == capacity); }
        case .err(_): { assert(false); }
    };
}

fn bytes::Buffer initial(ref mut storage::Ledger ledger) {
    let bytes::Buffer old = bytes::empty();
    return switch (storage::prepare(ref old, 256, limits(4096, 8192, 8192), ledger)) {
        case .ok(value): { value }
        case .err(_): { assert(false); bytes::empty() }
    };
}

fn void seed(ref mut bytes::Buffer buffer) {
    switch (bytes::append(buffer, b"keep")) {
        case .ok(value): { assert(value == 4); }
        case .err(_): { assert(false); }
    };
}

fn void preserved(ref bytes::Buffer buffer) {
    assert(bytes::capacity(buffer) == 256);
    assert(bytes::len(buffer) == 4);
    assert(bytes::equal(bytes::view(buffer), b"keep"));
}

pub fn void run() {
    var storage::Ledger ledger = storage::empty_ledger();
    var bytes::Buffer buffer = initial(ref mut ledger);
    committed(bytes::capacity(ref buffer), ref mut ledger);
    assert(ledger.used == 320 && ledger.engine_used == 320 && ledger.peak == 384);
    seed(ref mut buffer);
    planned(256, 256, limits(4096, 8192, 8192), ref ledger, 256);
    planned(256, 257, limits(4096, 8192, 8192), ref ledger, 384);
    planned(256, 257, limits(352, 8192, 8192), ref ledger, 320);
    planned(256, 257, limits(4096, 736, 8192), ref ledger, 320);
    planned(256, 257, limits(4096, 8192, 736), ref ledger, 320);
    // Exact minimum plus replacement metadata fits; one byte less rejects before allocation.
    planned(256, 257, limits(4096, 704, 704), ref ledger, 320);
    let usize attempts = ledger.allocations;
    switch (storage::prepare(ref buffer, 257, limits(4096, 703, 8192), ref mut ledger)) {
        case .ok(_): { assert(false); }
        case .err(_): { }
    };
    preserved(ref buffer);
    assert(ledger.used == 320 && ledger.pending == 0 && ledger.allocations == attempts);
    switch (storage::plan(256, 18446744073709551615, limits(4096, 8192, 8192), ref ledger)) {
        case .ok(_): { assert(false); }
        case .err(_): { }
    };
    // The uncommitted replacement is dropped before releasing its reservation.
    {
        let bytes::Buffer abandoned = switch (storage::prepare(ref buffer, 257, limits(4096, 8192, 8192), ref mut ledger)) {
            case .ok(value): { value }
            case .err(_): { assert(false); bytes::empty() }
        };
        assert(bytes::capacity(ref abandoned) == 384);
        assert(ledger.used == 768 && ledger.pending == 448);
        assert(bytes::equal(bytes::view(ref abandoned), b"keep"));
        switch (storage::prepare(ref buffer, 300, limits(4096, 8192, 8192), ref mut ledger)) {
            case .ok(_): { assert(false); }
            case .err(_): { }
        };
    }
    switch (storage::cancel(ref mut ledger)) {
        case .ok(value): { assert(value == 320); }
        case .err(_): { assert(false); }
    };
    preserved(ref buffer);
    buffer = switch (storage::prepare(ref buffer, 257, limits(352, 704, 704), ref mut ledger)) {
        case .ok(value): { value }
        case .err(_): { assert(false); bytes::empty() }
    };
    assert(ledger.used == 704 && ledger.pending == 384);
    committed(bytes::capacity(ref buffer), ref mut ledger);
    assert(bytes::capacity(ref buffer) == 320);
    assert(bytes::equal(bytes::view(ref buffer), b"keep"));
    assert(ledger.used == 384 && ledger.engine_used == 384 && ledger.pending == 0);
    assert(ledger.peak == 768 && ledger.engine_peak == 768);
    // Move through a function result and reassignment retains one owning root.
    let bytes::Buffer moved = buffer;
    assert(bytes::equal(bytes::view(ref moved), b"keep"));
}

// The harness fails an actual target allocator request for 320 bytes, exactly once.
pub fn void oom() {
    var storage::Ledger ledger = storage::empty_ledger();
    var bytes::Buffer buffer = initial(ref mut ledger);
    committed(bytes::capacity(ref buffer), ref mut ledger);
    seed(ref mut buffer);
    switch (storage::prepare(ref buffer, 257, limits(352, 704, 704), ref mut ledger)) {
        case .ok(_): { assert(false); }
        case .err(error): {
            assert(switch(error) { case .Allocation: { true } case .Quota: { false } case .Overflow: { false } case .State: { false } case .NoGrowth: { false } case .Provider: { false } });
        }
    };
    preserved(ref buffer);
    assert(ledger.used == 320 && ledger.engine_used == 320 && ledger.pending == 0);
    assert(ledger.peak == 704 && ledger.allocations == 2);
    // Retry is explicit and local to allocation; the one-shot allocator now succeeds.
    buffer = switch (storage::prepare(ref buffer, 257, limits(352, 704, 704), ref mut ledger)) {
        case .ok(value): { value }
        case .err(_): { assert(false); bytes::empty() }
    };
    committed(bytes::capacity(ref buffer), ref mut ledger);
    assert(ledger.used == 384 && ledger.engine_used == 384 && ledger.allocations == 3);
    assert(bytes::equal(bytes::view(ref buffer), b"keep"));
}
