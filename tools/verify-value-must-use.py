"""Verify private typed Result obligations in byte-identical locked mirrors.

Source and native batches are disjoint. Each profile records fresh input hashes
through verify-value-source.py; public compiler and CLI gates are not selected.
"""
import argparse
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('value_source_verifier', ROOT / 'tools/verify-value-source.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
SOURCE_MODULES = {
    'value_source_must_use_source': None,
    'value_source_control': [
        'admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
    'value_source_propagation_source': [
        'buffer_moves_pending_arguments_and_failed_invocations_cleanup_before_retry'],
    'value_source_predicates': [
        'parenthesized_named_predicates_allow_later_move_call_and_typed_return'],
    'value_source': [
        'empty_buffer_and_nested_tags_run_through_forward_mixed_calls_and_real_cleanup'],
}
NATIVE_MODULES = {'value_source_must_use': None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--batch', choices=['all', 'source', 'native'], default='all')
    args = parser.parse_args()
    runner.MODULES = (dict(SOURCE_MODULES) if args.batch == 'source' else
                      dict(NATIVE_MODULES) if args.batch == 'native' else
                      {**SOURCE_MODULES, **NATIVE_MODULES})
    directory = 'build/value-must-use' + ('' if args.batch == 'all' else '/' + args.batch)
    if not __debug__:
        raise SystemExit('Run without Python -O: verification assertions must remain enabled.')
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    for profile in profiles:
        output = ROOT / directory / profile
        output.mkdir(parents=True, exist_ok=True)
        runner.write(output / 'receipt.json', dict(status='incomplete', profile=profile, batch=args.batch))
    expected = runner.discover()
    source_prefix = 'tests::m2::value_source_must_use_source::'
    native_prefix = 'tests::m2::value_source_must_use::'
    if args.batch != 'native':
        assert sum(name.startswith(source_prefix) for name in expected) == 3
        assert sum(not name.startswith(source_prefix) and not name.startswith(native_prefix)
                   for name in expected) == 4
    if args.batch != 'source':
        assert 0 < sum(name.startswith(native_prefix) for name in expected) <= 3
    assert len(expected) <= 10, 'Must-use selection exceeds ten native groups.'
    paths = sorted({path.relative_to(ROOT).as_posix() for path in (ROOT / 'src').rglob('*.fy')} |
                   {f'tests/m2/{name}.fy' for name in runner.MODULES} |
                   {'fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-value-source.py',
                    'tools/verify-value-must-use.py'})
    inputs = [dict(path=path, sha256=runner.digest(ROOT / path)) for path in paths]
    for profile in profiles:
        runner.verify_profile(profile, False, expected, inputs, 'native', directory)


if __name__ == '__main__':
    main()
