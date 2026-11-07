"""Verify exact bounded host TLV codecs and the reused scalar codec natively."""
import importlib.util
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('bottom_runner', ROOT / 'tools/verify-value-bottom.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)
suite.DESCRIPTION = __doc__
suite.DIRECTORY = 'build/host-wire'
suite.EXTRA_INPUTS = {'tools/verify-host-wire.py', 'tools/host-wire/reference/host-wire-vectors.json'}
suite.MODULES = {'host_wire': None, 'scalar_codec': None}


def verify_reference():
    reference = json.loads((ROOT / 'tools/host-wire/reference/host-wire-vectors.json').read_bytes())
    source = (ROOT / 'tests/m2/host_wire.fy').read_text(encoding='utf-8')
    assert reference['schema'] == 'brownie.host-wire-vectors/1'
    assert reference['tag_map'] == dict(bool=1, u8=2, i32=3, i64=4, u32=5, usize=6, bytes=7)
    assert len(reference['vectors']) == 3
    for vector in reference['vectors']:
        raw = bytes.fromhex(vector['hex'])
        # Test literals may use printable ASCII; normalize that spelling only.
        spelled = ''.join(chr(byte) if byte in (97, 98) else f'\\x{byte:02x}' for byte in raw)
        assert f'b"{spelled}"' in source, vector['id']


if __name__ == '__main__':
    verify_reference()
    suite.main()
