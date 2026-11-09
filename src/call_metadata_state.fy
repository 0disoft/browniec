module call_metadata_state;
import slice_result_runtime as runtime;
import slice_result_owned_execution as owned;
import reference_execution as references;
import runtime_metadata_work as metadata;
import call_copy_cursor as copy;
import array_owners as owners;
import array_layout as layouts;
import array_slices as slices;
import call_context_work as context_work;

// Invocation-private: the parent pins the Program, bindings, live Runtime,
// input windows and source bytes, and executes no other guest work until done.
pub struct Context { runtime::Contract contract; owned::Prepared prepared; references::Arguments captured; bool generic; }
pub struct State {
    Context context; metadata::State metadata; copy::State copy;
    owners::Copies finished; usize child; u8 phase; bool active; bool done;
    context_work::State preparing;
}
pub fn State empty(){
    let owners::Token token=owners::Token{.slot=0,.generation=0};
    let slices::Ticket none=slices::Ticket{.slot=16,.generation=0};
    let layouts::Array shape=layouts::Array{.element=0,.length=0,.stride=0,.alignment=0,.bytes=0};
    let owners::CallArgument argument=owners::CallArgument{.source=token,.element=0,.length=0,.record=0};
    let owned::Prepared prepared=owned::Prepared{.captures=[runtime::capture(none,false,false);8],
        .sources=[token;8],.shapes=[shape;8],.arguments=[argument;8],.destinations=[0;8],
        .record_args=[false;8],.count=0,.owned=0,.records=false};
    return State{.context=Context{.contract=runtime::Contract{.tags=[0;8],.arity=0,.selected=0},
        .prepared=prepared,.captured=references::empty(0),.generic=false},.metadata=metadata::empty(),
        .copy=copy::empty(),.finished=owners::Copies{.tokens=[token;8],.count=0},
        .child=0,.phase=0,.active=false,.done=false,.preparing=context_work::empty()};
}
