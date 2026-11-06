"""Verify private typed value-expression joins in disjoint locked mirrors.

Source: three new groups plus four unchanged focused regressions. Native: at
most three value_source_joins helper groups. Each batch/profile has its own
build/value-joins/{source,native}/{development,release} output. --discover only
reads test identities; it does not build, execute, create outputs or receipts.
"""
import argparse
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('value_source_verifier', ROOT / 'tools/verify-value-source.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
SOURCE_MODULES = {
    'value_source_joins_source': None,
    'value_source_control': [
        'admitted_32_deep_conditionals_execute_and_33_reject_without_native_stack_override'],
    'value_source_must_use_source': [
        'continuing_branch_or_early_propagation_and_unpublished_call_captures_track_obligations'],
    'value_source_propagation_source': [
        'buffer_moves_pending_arguments_and_failed_invocations_cleanup_before_retry'],
    'value_source_predicates': [
        'parenthesized_named_predicates_allow_later_move_call_and_typed_return'],
}
NATIVE_MODULES = {'value_source_joins': None}


def discover(batch):
    runner.MODULES = dict(SOURCE_MODULES if batch == 'source' else NATIVE_MODULES)
    expected = runner.discover()
    if batch == 'source':
        prefix = 'tests::m2::value_source_joins_source::'
        assert sum(name.startswith(prefix) for name in expected) == 3
        assert sum(not name.startswith(prefix) for name in expected) == 4
        assert len(expected) == 7
    else:
        assert 0 < len(expected) <= 3, 'Native join helpers exceed three groups.'
    return expected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['development', 'release', 'all'], default='all')
    parser.add_argument('--batch', choices=['all', 'source', 'native'], default='all')
    parser.add_argument('--discover', action='store_true', help='List selected identities without writing or running anything.')
    args = parser.parse_args()
    if not __debug__:
        raise SystemExit('Run without Python -O: verification assertions must remain enabled.')
    profiles = ['development', 'release'] if args.profile == 'all' else [args.profile]
    batches = ['source', 'native'] if args.batch == 'all' else [args.batch]
    if not args.discover:
        for batch in batches:
            for profile in profiles:
                output = ROOT / 'build/value-joins' / batch / profile
                output.mkdir(parents=True, exist_ok=True)
                runner.write(output / 'receipt.json', dict(status='incomplete', profile=profile, batch=batch))
    selections = {batch: discover(batch) for batch in batches}
    assert sum(map(len, selections.values())) <= 10, 'Join selection exceeds ten groups.'
    if args.discover:
        print(json.dumps({batch: sorted(names) for batch, names in selections.items()}, indent=2))
        return
    for batch, expected in selections.items():
        runner.MODULES = dict(SOURCE_MODULES if batch == 'source' else NATIVE_MODULES)
        paths = sorted({path.relative_to(ROOT).as_posix() for path in (ROOT / 'src').rglob('*.fy')} |
                       {f'tests/m2/{name}.fy' for name in runner.MODULES} |
                       {'fairy.toml', 'fairy.lock', 'toolchain.json', 'tools/verify-value-source.py',
                        'tools/verify-value-joins.py'})
        inputs = [dict(path=path, sha256=runner.digest(ROOT / path)) for path in paths]
        for profile in profiles:
            runner.verify_profile(profile, False, expected, inputs, 'native', 'build/value-joins/' + batch)


if __name__ == '__main__':
    main()
