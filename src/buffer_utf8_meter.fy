module buffer_utf8_meter;
import std::bytes as bytes;
import buffer_owners as owners;
import buffer_utf8_scan as scan;

pub enum Error { Fuel; Token; State; Utf8; }
// Private logical prices, not elapsed time or a guest opcode schedule.
pub fn usize begin_cost(){return 128;}
pub fn usize step_cost(usize max_bytes){
    let usize bounded=if(max_bytes>256){256}else{max_bytes};
    return 128+4*bounded;
}
fn Error failure(scan::Error e){
    return switch(e){case .Token:{.Token}case .State:{.State}case .Utf8:{.Utf8}};
}
// Prepay before token/table/backing access; admitted errors do not refund work.
pub fn Result<scan::Cursor,Error> begin(ref owners::Table table,owners::Token source,
    ref bytes::Buffer b,ref mut usize fuel){
    let usize charged=begin_cost();let usize available=*fuel;
    if(available<charged){return .err(.Fuel);};
    *fuel=available-charged;
    return switch(scan::begin(table,source,b)){case .ok(v):{.ok(v)}case .err(e):{.err(failure(e))}};
}
pub fn Result<bool,Error> step(ref owners::Table table,ref bytes::Buffer b,
    usize max_bytes,ref mut scan::Cursor cursor,ref mut usize fuel){
    // Price only the bounded request, never unvalidated Cursor arithmetic.
    let usize charged=step_cost(max_bytes);let usize available=*fuel;
    if(available<charged){return .err(.Fuel);};
    *fuel=available-charged;
    return switch(scan::step(table,b,max_bytes,cursor)){case .ok(done):{.ok(done)}case .err(e):{.err(failure(e))}};
}

pub enum ControlError { Cancelled; Fuel; Token; State; Utf8; }
fn ControlError controlled(Error e){
    return switch(e){case .Fuel:{.Fuel}case .Token:{.Token}case .State:{.State}case .Utf8:{.Utf8}};
}
// The caller polls cancellation before each bounded operation. No callbacks/replay.
pub fn Result<scan::Cursor,ControlError> begin_cancellable(bool cancel_requested,
    ref owners::Table table,owners::Token source,ref bytes::Buffer b,ref mut usize fuel){
    if(cancel_requested){return .err(.Cancelled);}
    return switch(begin(table,source,b,fuel)){case .ok(v):{.ok(v)}case .err(e):{.err(controlled(e))}};
}
pub fn Result<bool,ControlError> step_cancellable(bool cancel_requested,
    ref owners::Table table,ref bytes::Buffer b,usize max_bytes,ref mut scan::Cursor cursor,ref mut usize fuel){
    // Cancellation is terminal even with zero Fuel or malformed backing/progress.
    if(cancel_requested){cursor.active=false;return .err(.Cancelled);}
    return switch(step(table,b,max_bytes,cursor,fuel)){case .ok(done):{.ok(done)}case .err(e):{.err(controlled(e))}};
}
