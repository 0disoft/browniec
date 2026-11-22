#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "brownie.h"

static bc_slice read_config(const char *name, uint8_t *buffer, size_t capacity) {
    FILE *input = NULL;
    assert(fopen_s(&input, name, "rb") == 0);
    const size_t size = fread(buffer, 1, capacity, input);
    assert(size > 0 && size < capacity && feof(input) && !ferror(input));
    assert(fclose(input) == 0);
    return (bc_slice){buffer, size};
}

int main(void) {
    bc_abi_info abi = {0};
    assert(bc_get_abi_info_v2(2, (uint32_t)sizeof(abi), &abi) == BC_OK);
    assert(abi.struct_size == sizeof(abi) && abi.abi_revision == 2 && abi.pointer_bits == 64);
    assert(abi.diagnostic_size == sizeof(bc_diagnostic) && abi.event_size == sizeof(bc_event));
    assert(abi.entry_info_size == sizeof(bc_entry_info) && abi.source_size == sizeof(bc_source));
    assert(abi.slice_size == sizeof(bc_slice));

    uint8_t policy[4096], config[2048];
    const bc_slice run = read_config("run.json", config, sizeof(config));
    const bc_slice empty = {0};
    const uint8_t name[] = "main";
    const uint8_t text[] = "module main;pub fn i32 main(){return 77;}";
    const bc_source source = {{name, sizeof(name) - 1}, {text, sizeof(text) - 1}};
    bc_handle engine = 0, program = 0, instance = 0;
    bc_diagnostic diagnostic = {.struct_size = sizeof(diagnostic)};
    assert(bc_engine_create(2, read_config("policy.json", policy, sizeof(policy)), &engine, &diagnostic) == BC_OK);
    assert(bc_compile(engine, &source, 1, empty, &program, &diagnostic) == BC_OK);
    bc_entry_info entry = {.struct_size = sizeof(entry)};
    assert(bc_program_entry_info(engine, program, source.module, source.module, &entry, &diagnostic) == BC_OK);
    assert(entry.abi_revision == 2 && entry.input_kind == BC_INPUT_NONE);
    assert(entry.required_capabilities_json.len == 2 && entry.required_capabilities_json.data);
    assert(memcmp(entry.required_capabilities_json.data, "[]", 2) == 0);
    assert(bc_instance_create(engine, program, empty, run, &instance, &diagnostic) == BC_OK);
    assert(bc_program_release(engine, program) == BC_OK);
    assert(bc_engine_destroy(engine) == BC_BUSY);

    bc_event event = {.struct_size = sizeof(event)};
    for (unsigned step = 0; step < 4096; ++step) {
        assert(bc_step(instance, 64, &event) == BC_OK);
        if (event.kind != BC_YIELD) break;
    }
    assert(event.kind == BC_DONE && event.return_i32 == 77 && event.trap_code == 0);
    assert(event.fuel_used > 0 && event.diagnostic.code == 0);
    assert(bc_instance_destroy(instance) == BC_OK);
    assert(bc_engine_destroy(engine) == BC_OK);
    puts("PASS ABI revision 2: 77");
    return 0;
}
