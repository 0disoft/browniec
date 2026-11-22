/* Measure an admitted Program through the Windows revision-2 ABI. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include "brownie.h"

enum { samples = 201, quantum = 64 };
static uint64_t frequency;

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
    require(argc == 3, "usage: bench-embed-reuse POLICY RUN");
    LARGE_INTEGER qpc;
    require(QueryPerformanceFrequency(&qpc) && qpc.QuadPart > 0, "QPC unavailable");
    frequency = (uint64_t)qpc.QuadPart;
    const uint8_t name[] = "main";
    const uint8_t text[] = "module main; pub fn i32 main(ref u8[] order) {"
        " if ((order[0] as i32) < 128) { return 3000; } return 0; }";
    const bc_source source = {{name, sizeof(name) - 1}, {text, sizeof(text) - 1}};
    uint8_t policy_buffer[8192], config_buffer[8192];
    const bc_slice policy = read_config(argv[1], policy_buffer, sizeof(policy_buffer));
    const bc_slice config = read_config(argv[2], config_buffer, sizeof(config_buffer));
    bc_handle engine = 0, retained = 0;
    bc_diagnostic diagnostic = {.struct_size = sizeof(diagnostic)};
    ok(bc_engine_create(BC_ABI_REVISION, policy, &engine, &diagnostic), "bc_engine_create", &diagnostic);
    const uint64_t first = compile(engine, &source, &retained);
    uint64_t compilation[samples], setup[samples], steps[samples], destroy[samples];
    uint64_t timer[samples];
    for (size_t i = 0; i < samples; ++i) {
        const uint64_t start = ticks();
        timer[i] = ticks() - start;
    }
    uint64_t fuel[2] = {0}, peak = 0;

    /* Compile samples use the same live Engine. Release each result before the next sample. */
    for (size_t i = 0; i < samples; ++i) {
        bc_handle program = 0;
        compilation[i] = compile(engine, &source, &program);
        ok(bc_program_release(engine, program), "bc_program_release", NULL);
    }
    for (size_t i = 0; i < samples; ++i) {
        const size_t variant = i % 2;
        uint8_t order = (uint8_t)(127 + variant);
        bc_handle instance = 0;
        uint64_t start = ticks();
        const uint32_t prepared = bc_instance_create(engine, retained, (bc_slice){&order, 1},
            config, &instance, &diagnostic);
        setup[i] = ticks() - start;
        ok(prepared, "bc_instance_create", &diagnostic);
        bc_event event = {.struct_size = sizeof(event)};
        start = ticks();
        for (unsigned calls = 0; calls < 4096; ++calls) {
            ok(bc_step(instance, quantum, &event), "bc_step", NULL);
            if (event.kind != BC_YIELD) break;
        }
        steps[i] = ticks() - start;
        require(event.kind == BC_DONE && event.return_i32 == (variant ? 0 : 3000) &&
            event.diagnostic.code == 0 && event.payload.len == 0 && event.fuel_used &&
            event.peak_accounted_bytes, "unexpected workload result");
        if (i < 2) fuel[variant] = event.fuel_used;
        if (i == 0) peak = event.peak_accounted_bytes;
        require(event.fuel_used == fuel[variant] && event.peak_accounted_bytes == peak,
            "workload Fuel or reservation changed between samples");
        start = ticks();
        const uint32_t dropped = bc_instance_destroy(instance);
        destroy[i] = ticks() - start;
        ok(dropped, "bc_instance_destroy", NULL);
    }

    ok(bc_program_release(engine, retained), "bc_program_release", NULL);
    ok(bc_engine_destroy(engine), "bc_engine_destroy", NULL);
    printf("source=%zu input=1 iterations=%d quantum=%d first_compile_us=%.3f"
           " fuel_127=%" PRIu64 " fuel_128=%" PRIu64 " instance_peak_bytes=%" PRIu64 "\n",
        source.source_utf8.len, samples, quantum, us(first), fuel[0], fuel[1], peak);
    puts("phase count median_us p95_us");
    report("timer_pair", timer, samples);
    report("compile", compilation, samples);
    report("reused_setup", setup, samples);
    report("step_to_done", steps, samples);
    report("destroy", destroy, samples);
    return 0;
}
