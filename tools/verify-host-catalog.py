"""Verify strict host catalog admission, canonical binding bytes and SHA-256."""
import ast
from collections import Counter
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import struct
import sys

ROOT = Path(__file__).resolve().parent.parent
REFERENCE = ROOT / 'tools/host-catalog/reference'
LITERAL = r'b"(?:\\.|[^"\\])*"'
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('bottom_runner', ROOT / 'tools/verify-value-bottom.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)
suite.DESCRIPTION = __doc__
suite.DIRECTORY = 'build/host-catalog'
suite.EXTRA_INPUTS = {
    'tools/verify-host-catalog.py', 'docs/engineering/host-catalog.md',
    *(p.relative_to(ROOT).as_posix() for p in REFERENCE.iterdir() if p.is_file()),
}
suite.MODULES = {'host_catalog': None}


def canonical(value):
    """Independent byte oracle; this is not the production admission parser."""
    out = bytearray(b'BRC-CATALOG-1\n' + struct.pack('<I', len(value['imports'])))

    def string(text):
        encoded = text.encode('ascii')
        out.extend(struct.pack('<I', len(encoded)))
        out.extend(encoded)

    for entry in value['imports']:
        out.extend(struct.pack('<I', entry['id']))
        for key in ['module', 'symbol', 'result', 'effect', 'capability', 'adapter_revision']:
            string(entry[key])
        out.extend(struct.pack('<I', len(entry['parameters'])))
        for parameter in entry['parameters']:
            string(parameter)
    return bytes(out)


def verify_reference():
    provenance = json.loads((REFERENCE / 'provenance.json').read_bytes())
    for entry in provenance['entries']:
        path = REFERENCE / Path(entry['path']).name
        if path.is_file():
            assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], path
    example = json.loads((REFERENCE / 'host-catalog.example.json').read_bytes())
    vector = json.loads((REFERENCE / 'catalog-vector.json').read_bytes())
    assert canonical(example).hex() == vector['canonical_hex']
    assert hashlib.sha256(canonical(example)).hexdigest() == vector['sha256']
    schema = json.loads((REFERENCE / 'host-catalog.schema.json').read_bytes())
    pattern = schema['properties']['imports']['items']['properties']['capability']['pattern']
    assert re.fullmatch(pattern, example['imports'][0]['capability']) is not None

    source = (ROOT / 'tests/m2/host_catalog.fy').read_text(encoding='utf-8')
    base = ast.literal_eval(re.search(r'fn ref u8\[\] base\(\)\{return (' + LITERAL + r');\}', source)[1])
    assert json.loads(base) == example
    native = {}
    calls = re.findall(r'\b(accepted_change|changed_failure|changed)\((\d+),(\d+),(' +
                       LITERAL + r')(?:,(.*))?\);', source)
    for function, begin, end, replacement, rest in calls:
        begin, end = int(begin), int(end)
        assert 0 <= begin <= end <= len(base)
        raw = base[:begin] + ast.literal_eval(replacement) + base[end:]
        literals = [ast.literal_eval(v) for v in re.findall(LITERAL, rest)]
        if function == 'accepted_change':
            assert len(literals) == 2
            expected, digest = literals
            assert expected == canonical(json.loads(raw))
            assert digest.decode('ascii') == hashlib.sha256(expected).hexdigest()
            signature = (raw.hex(), True, expected.hex(), digest.decode('ascii'), None)
        else:
            failure = rest.removeprefix('.') if function == 'changed_failure' else None
            signature = (raw.hex(), False, None, None, failure)
        native[signature] = native.get(signature, 0) + 1
    fixture = json.loads((REFERENCE / 'admission-vectors.json').read_bytes())
    assert fixture['schema'] == 'browniec.host-catalog-test-vectors/1'
    required = Counter((c['input_hex'], c['accepted'], c.get('canonical_hex'), c.get('sha256'), c.get('failure'))
                       for c in fixture['cases'])
    assert not (required - Counter(native)), 'Every corpus input must reach a native assertion unchanged.'
    assert len(calls) == len(fixture['cases']) + 1  # Additional simultaneous spelling maxima.
    answers = json.loads((REFERENCE / 'sha256-vectors.json').read_bytes())
    for answer in answers['cases']:
        assert hashlib.sha256(bytes([answers['fill_byte']]) * answer['length']).hexdigest() == answer['sha256']
        assert f'bytes::len(ref b)<{answer["length"]}' in source and answer['sha256'] in source
    assert 'admitted_catalog_tags_compose_with_real_wire_decoders' in source
    assert 'wire::decode_request(request,ref tags[..argc]' in source
    assert 'wire::decode_reply(0,result,reply,' in source
    result = dict(
        schema='browniec.host-catalog-reference-verification/v1', status='passed',
        admissionVectors=len(fixture['cases']), nativeLiteralCases=len(calls),
        sha256KnownAnswers=len(answers['cases']), referenceCanonicalHex=vector['canonical_hex'],
        referenceSha256=vector['sha256'],
        inputEncoding='All admission fixtures replay their exact input_hex bytes in native assertions.',
    )
    output = ROOT / suite.DIRECTORY
    output.mkdir(parents=True, exist_ok=True)
    (output / 'reference-receipt.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')


if __name__ == '__main__':
    if not __debug__:
        raise SystemExit('Run without Python -O: verification assertions must remain enabled.')
    verify_reference()
    suite.main()
