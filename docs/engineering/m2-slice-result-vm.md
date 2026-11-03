# Private returned-view VM integration

The first integration slice adds invocation-private result destinations and
bounded VM frame/site bindings in `slice_result_frames`. Native Call receipts
use flat fixed columns: the adopted Fairy C toolchain does not admit mutating
array fields whose element records themselves contain fixed arrays.

Each frame records its caller continuation, CALL argument map and logical result
identity. Preparation stores a ticket outside scalar registers. Native handoff
must succeed before pop installs the fresh ticket in the caller destination and
updates named actuals from resumed tickets. Pop clears the consumed callee's
result/site bindings. A forward consumes the inner receipt through the outer
transaction; intermediate results never escape to a native client.

This slice alone does not execute op63/64/65. The next slice connects these
bindings to a private, independently admitted instruction loop. Public source
compilation, ordinary VM admission, capabilities and the public Fuel limit stay
closed to returned references.
