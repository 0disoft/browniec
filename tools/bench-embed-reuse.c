/* Measure an admitted Program through the Windows revision-2 ABI. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "brownie.h"

enum { samples = 201, batch_quantum = 64 };
static uint64_t frequency;

#ifdef BC_BENCH_ALLOCATIONS
__declspec(dllimport) size_t probe_attempts(void);
__declspec(dllimport) size_t probe_live(void);
#endif

static void require(int condition, const char *message) {
    if (condition) return;
    fprintf(stderr, "%s\n", message);
    exit(1);
}

static void ok(uint32_t status, const char *operation, const bc_diagnostic *diagnostic) {
    if (status == BC_OK) return;
    fprintf(stderr, "%s failed (%" PRIu32 "): %s\n", operation, status,
        diagnostic ? diagnostic->message : "");
    exit(1);
}

static uint64_t ticks(void) {
    LARGE_INTEGER value;
    require(QueryPerformanceCounter(&value), "QueryPerformanceCounter failed");
    return (uint64_t)value.QuadPart;
}

static bc_slice read_config(const char *path, uint8_t *bytes, size_t capacity) {
    FILE *file = NULL;
    require(fopen_s(&file, path, "rb") == 0 && file, path);
    const size_t length = fread(bytes, 1, capacity, file);
    require(length && feof(file) && !ferror(file) && fclose(file) == 0, path);
    return (bc_slice){bytes, length};
}

static int compare_ticks(const void *left, const void *right) {
    const uint64_t a = *(const uint64_t *)left, b = *(const uint64_t *)right;
    return (a > b) - (a < b);
}

static double us(uint64_t duration) {
    return (double)duration * 1000000.0 / (double)frequency;
}

static void report(const char *phase, uint64_t *durations, size_t count) {
    qsort(durations, count, sizeof(*durations), compare_ticks);
    const size_t p95 = (95 * count + 99) / 100 - 1;
    printf("%s %zu %.3f %.3f\n", phase, count, us(durations[count / 2]), us(durations[p95]));
}

static uint64_t compile(bc_handle engine, const bc_source *source, bc_handle *program) {
    bc_diagnostic diagnostic = {.struct_size = sizeof(diagnostic)};
    const uint64_t start = ticks();
    const uint32_t status = bc_compile(engine, source, 1, (bc_slice){0}, program, &diagnostic);
    const uint64_t elapsed = ticks() - start;
    ok(status, "bc_compile", &diagnostic);
    return elapsed;
}

int main(int argc, char **argv) {
    const bool empty = argc == 4 && strcmp(argv[3], "--empty") == 0;
    const bool loop = argc == 4 && strcmp(argv[3], "--loop") == 0;
    const bool call_loop = argc == 4 && strcmp(argv[3], "--calls") == 0;
    const bool scan = argc == 4 && strcmp(argv[3], "--scan") == 0;
    const bool paired_quanta = loop || call_loop || scan;
    require(argc == 3 || empty || paired_quanta,
        "usage: bench-embed-reuse POLICY RUN [--empty|--loop|--calls|--scan]");
    const bool order_input = !empty && !paired_quanta;
    LARGE_INTEGER qpc;
    require(QueryPerformanceFrequency(&qpc) && qpc.QuadPart > 0, "QPC unavailable");
    frequency = (uint64_t)qpc.QuadPart;
    const uint8_t name[] = "main";
    const uint8_t text[] = "module main; pub fn i32 main(ref u8[] order) {"
        " if ((order[0] as i32) < 128) { return 3000; } return 0; }";
    const uint8_t no_input[] = "module main; pub fn i32 main() { return 77; }";
    const uint8_t scalar_loop[] = "module main; pub fn i32 main() { var i32 total = 0;"
        " for (var i32 i = 0; i < 64; i = i + 1) { total = total + i; } return total; }";
    const uint8_t function_loop[] = "module main; fn i32 add(i32 a, i32 b) { return a + b; }"
        " pub fn i32 main() { var i32 total = 0;"
        " for (var i32 i = 0; i < 16; i = i + 1) { total = add(total, i); } return total; }";
    const uint8_t byte_scan[] = "module main; pub fn i32 main(ref u8[] data) { var i32 total = 0;"
        " for (var usize i = 0; i < data.len; i = i + 1) { total = total + (data[i] as i32); }"
        " return total; }";
    bc_slice source_bytes = {text, sizeof(text) - 1};
    if (empty) source_bytes = (bc_slice){no_input, sizeof(no_input) - 1};
    if (loop) source_bytes = (bc_slice){scalar_loop, sizeof(scalar_loop) - 1};
    if (call_loop) source_bytes = (bc_slice){function_loop, sizeof(function_loop) - 1};
    if (scan) source_bytes = (bc_slice){byte_scan, sizeof(byte_scan) - 1};
    const bc_source source = {{name, sizeof(name) - 1}, source_bytes};
    uint8_t policy_buffer[8192], config_buffer[8192];
    const bc_slice policy = read_config(argv[1], policy_buffer, sizeof(policy_buffer));
    const bc_slice config = read_config(argv[2], config_buffer, sizeof(config_buffer));
    bc_handle engine = 0, retained = 0;
    bc_diagnostic diagnostic = {.struct_size = sizeof(diagnostic)};
    ok(bc_engine_create(BC_ABI_REVISION, policy, &engine, &diagnostic), "bc_engine_create", &diagnostic);
    const uint64_t first = compile(engine, &source, &retained);
    uint64_t compilation[samples], setup[samples], steps[2][samples], destroy[samples];
    unsigned calls_per_quantum[2] = {0};
    uint64_t timer[samples];
    for (size_t i = 0; i < samples; ++i) {
        const uint64_t start = ticks();
        timer[i] = ticks() - start;
    }
    uint64_t fuel[2] = {0}, peak = 0;
    uint8_t scan_input[64];
    for (size_t i = 0; i < sizeof(scan_input); ++i) scan_input[i] = (uint8_t)i;

    /* Compile samples use the same live Engine. Release each result before the next sample. */
    for (size_t i = 0; i < samples; ++i) {
        bc_handle program = 0;
        compilation[i] = compile(engine, &source, &program);
        ok(bc_program_release(engine, program), "bc_program_release", NULL);
    }
    for (size_t i = 0; i < samples; ++i) {
        const size_t variant = i % 2;
        const size_t schedule = paired_quanta ? variant : 0;
        const uint32_t quantum = schedule ? 1 : batch_quantum;
        uint8_t order = (uint8_t)(127 + variant);
        bc_handle instance = 0;
        uint64_t start = ticks();
        bc_slice input = {0};
        if (order_input) input = (bc_slice){&order, 1};
        if (scan) input = (bc_slice){scan_input, sizeof(scan_input)};
        const uint32_t prepared = bc_instance_create(engine, retained, input, config, &instance,
            &diagnostic);
        setup[i] = ticks() - start;
        ok(prepared, "bc_instance_create", &diagnostic);
        bc_event event = {.struct_size = sizeof(event)};
#ifdef BC_BENCH_ALLOCATIONS
        const size_t before_step = probe_attempts();
#endif
        start = ticks();
        unsigned calls = 0;
        while (calls < 4096) {
            ++calls;
            ok(bc_step(instance, quantum, &event), "bc_step", NULL);
            if (event.kind != BC_YIELD) break;
        }
        steps[schedule][paired_quanta ? i / 2 : i] = ticks() - start;
#ifdef BC_BENCH_ALLOCATIONS
        require(probe_attempts() == before_step, "SDK allocation during stepping");
#endif
        const int32_t expected = call_loop ? 120 :
            (paired_quanta ? 2016 : (empty ? 77 : (variant ? 0 : 3000)));
        if (event.kind != BC_DONE || event.return_i32 != expected ||
            event.diagnostic.code || event.payload.len || !event.fuel_used ||
            !event.peak_accounted_bytes) {
            fprintf(stderr, "sample=%zu quantum=%u steps=%u event=%u expected=%d actual=%d "
                "fuel=%" PRIu64 " diagnostic=%u %s\n", i, quantum, calls, event.kind,
                expected, event.return_i32, event.fuel_used, event.diagnostic.code,
                event.diagnostic.message);
            return 1;
        }
        const size_t workload = order_input ? variant : 0;
        if (fuel[workload] == 0) fuel[workload] = event.fuel_used;
        if (i == 0) peak = event.peak_accounted_bytes;
        require(event.fuel_used == fuel[workload] && event.peak_accounted_bytes == peak,
            "workload Fuel or reservation changed between samples");
        if (calls_per_quantum[schedule] == 0) calls_per_quantum[schedule] = calls;
        if (paired_quanta) require(calls == calls_per_quantum[schedule], "step count changed between samples");
        start = ticks();
        const uint32_t dropped = bc_instance_destroy(instance);
        destroy[i] = ticks() - start;
        ok(dropped, "bc_instance_destroy", NULL);
    }

    ok(bc_program_release(engine, retained), "bc_program_release", NULL);
    ok(bc_engine_destroy(engine), "bc_engine_destroy", NULL);
#ifdef BC_BENCH_ALLOCATIONS
    require(probe_live() == 0, "live SDK allocations after Engine destruction");
    puts("step_sdk_allocations=0 final_live_sdk_allocations=0");
#endif
    const size_t input_size = scan ? sizeof(scan_input) : (order_input ? 1 : 0);
    printf("source=%zu input=%zu iterations=%d", source.source_utf8.len, input_size, samples);
    if (paired_quanta) printf(" quantum=%d,1 calls=%u,%u", batch_quantum, calls_per_quantum[0], calls_per_quantum[1]);
    else printf(" quantum=%d", batch_quantum);
    printf(" first_compile_us=%.3f", us(first));
    if (!order_input) printf(" fuel=%" PRIu64, fuel[0]);
    else printf(" fuel_127=%" PRIu64 " fuel_128=%" PRIu64, fuel[0], fuel[1]);
    printf(" instance_peak_bytes=%" PRIu64 "\n", peak);
    puts("phase count median_us p95_us");
    report("timer_pair", timer, samples);
    report("compile", compilation, samples);
    report("reused_setup", setup, samples);
    if (paired_quanta) {
        report("step_to_done_q64", steps[0], (samples + 1) / 2);
        report("step_to_done_q1", steps[1], samples / 2);
    } else report("step_to_done", steps[0], samples);
    report("destroy", destroy, samples);
    return 0;
}
