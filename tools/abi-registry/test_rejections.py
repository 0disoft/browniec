"""Build-only negative controls. Never compiled into native production objects."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import types

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise RuntimeError('Use a fresh control output')
    output.mkdir(parents=True)
    builder_path = ROOT / 'tools/build-abi-registry.py'
    builder_bytes = builder_path.read_bytes()
    results = []
    original_run = subprocess.run
    original_argv = sys.argv[:]
    for control in ['transport-byte-change', 'kernel-byte-change', 'empty-LINK-override']:
        module = types.ModuleType('registry_build_control')
        module.__file__ = str(builder_path)
        exec(compile(builder_bytes, str(builder_path), 'exec'), module.__dict__)
        target = output / control
        before_link = os.environ.get('LINK')
        had_link = 'LINK' in os.environ
        try:
            if control == 'transport-byte-change':
                def altered(command, *a, **kw):
                    result = original_run(command, *a, **kw)
                    if 'emit-workspace-c' in list(map(str, command)) and result.returncode == 0:
                        result.stdout += b'/* negative control: altered complete transport */\n'
                    return result
                subprocess.run = altered
            elif control == 'kernel-byte-change':
                copy = output / 'changed-feature-root'
                for name in module.FEATURES:
                    dest = copy / name; dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_bytes((ROOT / name).read_bytes())
                path = copy / 'src/abi_handles.fy'; path.write_bytes(path.read_bytes() + b'\n')
                module.ROOT = copy
            else:
                os.environ['LINK'] = ''
            sys.argv = [str(builder_path), '--compiler', str(ROOT / 'build/toolchain/fairyc.exe'),
                        '--output', str(target)]
            try:
                module.main()
                raise AssertionError('Control unexpectedly accepted: ' + control)
            except RuntimeError as error:
                message = str(error)
                expected = {'transport-byte-change': 'Full private generated transport mismatch',
                            'kernel-byte-change': 'Reviewed kernel/retention mismatch',
                            'empty-LINK-override': 'Compiler/linker overrides must be absent'}[control]
                if expected not in message:
                    raise
                if list(target.rglob('*.obj')) or list(target.rglob('*.exe')):
                    raise AssertionError('Native artifact created before control rejection')
                receipt = target / 'receipt.json'
                results.append(dict(control=control, rejected=True, reason=message,
                                    nativeObjectsCreated=False,
                                    receiptSha256=hashlib.sha256(receipt.read_bytes()).hexdigest() if receipt.exists() else None))
        finally:
            subprocess.run = original_run
            sys.argv = original_argv
            if had_link:
                os.environ['LINK'] = before_link
            else:
                os.environ.pop('LINK', None)
    (output / 'receipt.json').write_text(json.dumps(dict(status='passed', controls=results,
        builderSha256=hashlib.sha256(builder_bytes).hexdigest(),
        controlScriptSha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()), indent=2) + '\n',
        encoding='utf-8', newline='\n')
    print('PASS registry builder: 3 fail-closed controls, zero native objects')


if __name__ == '__main__':
    main()
