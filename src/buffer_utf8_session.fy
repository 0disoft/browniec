module buffer_utf8_session;
import std::bytes as bytes;
import buffer_owners as owners;
import buffer_growth as growth;
import buffer_utf8_scan as scan;
import buffer_utf8_meter as meter;

// Private lifecycle state, not a resource or authenticated guest handle.
pub struct Session { bool held; owners::Token source; scan::Cursor cursor; }
pub fn Session empty(){return Session{.held=false,.source=owners::Token{.slot=16,.generation=0},
    .cursor=scan::Cursor{.active=false,.source=owners::Token{.slot=16,.generation=0},
        .length=0,.capacity=0,.offset=0,.carry=[0;4],.have=0}};}
pub fn usize begin_cost(){return 256;}
pub fn usize step_cost(usize request){return 128+meter::step_cost(request);}
fn meter::ControlError owner_error(owners::Error e){return switch(e){case .Token:{.Token}
    case .State:{.State}case .Owners:{.State}case .Bounds:{.State}};}
fn meter::ControlError scan_error(scan::Error e){return switch(e){case .Token:{.Token}case .State:{.State}case .Utf8:{.Utf8}};}

// No Fuel or native root is required for bounded lifecycle cleanup.
// Keep held=true on failed release so repair/cleanup remains explicit and retryable.
pub fn Result<usize,meter::ControlError> abandon(ref mut owners::Table table,ref mut Session session){
    session.cursor.active=false;
    if(!session.held){return .ok(0);}
    switch(owners::end_read(table,session.source)){case .ok(_):{}case .err(_):{return .err(.State);}};
    session.held=false;return .ok(0);
}
fn Result<bool,meter::ControlError> terminate(ref mut owners::Table table,ref mut Session session,meter::ControlError error){
    let usize released=abandon(table,session)?;return .err(error);
}
pub fn Result<Session,meter::ControlError> begin(bool cancel_requested,ref mut owners::Table table,
    owners::Token source,ref bytes::Buffer b,ref growth::Ledger ledger,ref mut usize fuel){
    if(cancel_requested){return .err(.Cancelled);}
    let usize charged=begin_cost();let usize available=*fuel;
    if(available<charged){return .err(.Fuel);};
    *fuel=available-charged;
    // Construct progress before acquiring; no fallible operation follows the lease.
    let scan::Cursor cursor=switch(scan::begin(table,source,b)){case .ok(v):{v}case .err(e):{return .err(scan_error(e));}};
    let owners::Token lease=switch(owners::begin_read(table,source,b,ledger)){case .ok(v):{v}case .err(e):{return .err(owner_error(e));}};
    return .ok(Session{.held=true,.source=lease,.cursor=cursor});
}
pub fn Result<bool,meter::ControlError> step(bool cancel_requested,ref mut owners::Table table,
    ref bytes::Buffer b,usize max_bytes,ref mut Session session,ref mut usize fuel){
    if(cancel_requested){return terminate(table,session,.Cancelled);}
    let usize charged=step_cost(max_bytes);let usize available=*fuel;
    if(available<charged){return .err(.Fuel);};
    *fuel=available-charged;
    if(!session.held){return .err(.State);}
    let owners::Owner owner=switch(owners::describe(table,session.source)){
        case .ok(v):{v}case .err(e):{return terminate(table,session,owner_error(e));}
    };
    if(!owner.reading || session.cursor.source.slot!=session.source.slot ||
        session.cursor.source.generation!=session.source.generation){return terminate(table,session,.State);}
    let bool done=switch(scan::step(table,b,max_bytes,ref mut session.cursor)){
        case .ok(v):{v}case .err(e):{return terminate(table,session,scan_error(e));}
    };
    if(done){let usize released=abandon(table,session)?;}
    return .ok(done);
}
