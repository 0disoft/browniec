"""Run selected public examples against an existing Brownie C binary."""

import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
EXAMPLES = {
    'examples/branches.brc': (256, 77),
    'examples/array-read.brc': (100_000, 42),
    'examples/mutable-slices.brc': (1_000_000, 42),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exe', type=Path, required=True)
    parser.add_argument('paths', nargs='+', choices=tuple(EXAMPLES))
    args = parser.parse_args()
    exe = args.exe.resolve(strict=True)
    for path in args.paths:
        fuel, expected = EXAMPLES[path]
        result = subprocess.run(
            [str(exe), 'run', str(ROOT / path), '--fuel', str(fuel), '--json'],
            capture_output=True, timeout=10,
        )
        assert result.returncode == 0 and result.stderr == b'', (path, result)
        assert len(result.stdout.splitlines()) == 1 and result.stdout.endswith(b'\n'), result.stdout
        payload = json.loads(result.stdout)
        assert isinstance(payload, dict) and payload.get('schema') == 'browniec.result/v1', payload
        assert payload.get('command') == 'run' and payload.get('status') == 'completed', payload
        assert type(payload.get('return_i32')) is int and payload['return_i32'] == expected, payload
        assert 'error' in payload and payload['error'] is None, payload
        print(f'PASS {path}: {expected}')


if __name__ == '__main__':
    main()
