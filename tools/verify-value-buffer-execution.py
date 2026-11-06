"""Focused private Buffer VM execution; --discover never builds or writes."""
import argparse
import importlib.util
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('value_source_verifier', ROOT / 'tools/verify-value-source.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


def discover():
    runner.MODULES = {
        'value_buffer_execution': None,
        'value_tag_test': [
            'repeated_predicates_preserve_plain_nested_and_active_inactive_buffer_wrappers_in_vm',
            'independent_admission_rejects_reserved_operands_nonbool_definitions_and_dead_sources',
            'native_tag_meter_boundaries_authenticate_roots_and_preserve_source_on_failure'],
        'value_buffer_roots': [
            'byte_operations_preserve_serial_binding_and_refresh_only_structural_tokens',
            'growth_fallback_and_transient_quotas_preserve_actual_roots_on_rejection'],
    }
    expected = runner.discover()
    assert len(expected) == 10
    assert sum('::value_buffer_execution::' in name for name in expected) == 5
    return expected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--discover', action='store_true')
    args = parser.parse_args()
    if not __debug__:
        raise SystemExit('Run without Python -O: verification assertions must remain enabled.')
    expected = discover()
    if args.discover:
        print(json.dumps(sorted(expected), indent=2))
        return
    directory = 'build/value-buffer-execution'
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    for profile in profiles:
        output = ROOT / directory / profile
        output.mkdir(parents=True, exist_ok=True)
        runner.write(output / 'receipt.json', dict(status='incomplete', profile=profile))
    paths = sorted({path.relative_to(ROOT).as_posix() for path in (ROOT / 'src').rglob('*.fy')} |
                   {f'tests/m2/{name}.fy' for name in runner.MODULES} |
                   {'fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-value-source.py',
                    'tools/verify-value-buffer-execution.py'})
    inputs = [dict(path=path, sha256=runner.digest(ROOT / path)) for path in paths]
    for profile in profiles:
        runner.verify_profile(profile, False, expected, inputs, 'native', directory)


if __name__ == '__main__':
    main()
