"""Verify private Buffer roots/frames in two disjoint locked mirrors.

Each batch selects three new groups plus two unchanged regressions. Outputs are
build/value-buffer/roots|frames/profile. --discover never builds or writes.
"""
import argparse
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('value_source_verifier', ROOT / 'tools/verify-value-source.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
BATCHES = {
    'roots': {
        'value_buffer_roots': [
            'byte_operations_preserve_serial_binding_and_refresh_only_structural_tokens',
            'growth_fallback_and_transient_quotas_preserve_actual_roots_on_rejection',
            'fuel_authentication_generation_exhaustion_and_repeated_retirement_are_atomic'],
        'value_roots': [
            'allocated_root_moves_with_exact_token_charge_and_original_data',
            'quota_and_binding_failures_publish_nothing_and_serials_do_not_wrap'],
    },
    'frames': {
        'value_buffer_frames': [
            'addressed_byte_operations_preserve_frame_words_and_initialization_order',
            'move_tag_payload_and_cross_activation_keep_serial_but_reject_stale_addresses',
            'fuel_authentication_and_combined_quotas_reject_before_mutation_and_abort_frees'],
        'value_frames': [
            'recursive_buffer_moves_preserve_owner_token_charge_data_and_reject_copy_overwrite_double_drop',
            'combined_frame_root_quotas_and_exact_fuel_boundaries_do_not_publish_rejected_work'],
    },
}


def discover(batch):
    runner.MODULES = dict(BATCHES[batch])
    expected = runner.discover()
    module = 'value_buffer_' + batch
    # Enumerate all new annotations as well as selected identities, so additions
    # cannot silently escape the promised three-group batch.
    selection = runner.MODULES[module]
    runner.MODULES[module] = None
    complete = runner.discover()
    runner.MODULES[module] = selection
    assert expected == complete and len(expected) == 5, batch
    assert sum(name.startswith('tests::m2::' + module + '::') for name in expected) == 3
    return expected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--batch', choices=['roots', 'frames', 'all'], default='all')
    parser.add_argument('--discover', action='store_true', help='List identities without writing or running anything.')
    args = parser.parse_args()
    if not __debug__:
        raise SystemExit('Run without Python -O: verification assertions must remain enabled.')
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    batches = list(BATCHES) if args.batch == 'all' else [args.batch]
    if not args.discover:
        for batch in batches:
            for profile in profiles:
                output = ROOT / 'build/value-buffer' / batch / profile
                output.mkdir(parents=True, exist_ok=True)
                runner.write(output / 'receipt.json', dict(status='incomplete', batch=batch, profile=profile))
    selections = {batch: discover(batch) for batch in batches}
    assert sum(map(len, selections.values())) <= 10, 'Buffer selection exceeds ten groups.'
    if args.discover:
        print(json.dumps({batch: sorted(names) for batch, names in selections.items()}, indent=2))
        return
    for batch, expected in selections.items():
        runner.MODULES = dict(BATCHES[batch])
        paths = sorted({path.relative_to(ROOT).as_posix() for path in (ROOT / 'src').rglob('*.fy')} |
                       {f'tests/m2/{name}.fy' for name in runner.MODULES} |
                       {'fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-value-source.py',
                        'tools/verify-value-buffer.py'})
        inputs = [dict(path=path, sha256=runner.digest(ROOT / path)) for path in paths]
        for profile in profiles:
            runner.verify_profile(profile, False, expected, inputs, 'native', 'build/value-buffer/' + batch)


if __name__ == '__main__':
    main()
