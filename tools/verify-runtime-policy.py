"""Verify typed policy/run admission against exact design inputs in native profiles."""
import ast
from collections import Counter
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
REFERENCE = ROOT / 'tools/runtime-policy/reference'
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('policy_bottom_runner', ROOT / 'tools/verify-value-bottom.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)
suite.DESCRIPTION = __doc__
suite.DIRECTORY = 'build/runtime-policy'
suite.MODULES = {'runtime_policy': None, 'runtime_run_config': None}
suite.EXTRA_INPUTS = {
    'tools/verify-runtime-policy.py', 'docs/engineering/runtime-policy.md',
    *(p.relative_to(ROOT).as_posix() for p in REFERENCE.iterdir() if p.is_file()),
}
LITERAL = r'b"(?:\\.|[^"\\])*"'
CODES = {None: 0, 'Json': 1, 'Limit': 2, 'Unknown': 3, 'Duplicate': 4,
         'Missing': 5, 'Value': 6, 'Relation': 7, 'Authority': 8}
POLICIES = ['policy.pure.json', 'policy.output.json', 'policy.host-test.json',
            'policy.fuel-test.json', 'policy.worker.json', 'max-policy.json']


def require(value, message):
    if not value:
        raise ValueError(message)


def strict(data):
    require(len(data) <= 65536, 'bytes')
    text = data.decode('utf-8', errors='strict')

    def pairs(items):
        out = {}
        for key, value in items:
            require(key not in out, 'duplicate')
            out[key] = value
        return out

    def integer(text):
        require(re.fullmatch(r'(0|[1-9][0-9]*)', text) and len(text) <= 20, 'integer')
        return int(text)

    def no_float(text):
        raise ValueError('fraction/exponent/constant')

    return json.loads(text, object_pairs_hook=pairs, parse_int=integer,
                      parse_float=no_float, parse_constant=no_float)


def shape(value, schema):
    if 'const' in schema:
        require(type(value) is type(schema['const']) and value == schema['const'], 'const')
        return
    kind = schema['type']
    if kind == 'object':
        require(type(value) is dict, 'object')
        require(set(value) == set(schema['required']) == set(schema['properties']), 'fields')
        for key, child in value.items():
            shape(child, schema['properties'][key])
    elif kind == 'array':
        require(type(value) is list and schema['minItems'] <= len(value) <= schema['maxItems'], 'array')
        for child in value:
            shape(child, schema['items'])
        require(len(value) == len(set(value)), 'unique')
    elif kind == 'integer':
        require(type(value) is int and schema['minimum'] <= value <= schema['maximum'], 'range')
    elif kind == 'string':
        require(type(value) is str, 'string')
        value.encode('utf-8', errors='strict')
        require(schema['minLength'] <= len(value) <= schema['maxLength'] and
                re.fullmatch(schema['pattern'], value, flags=re.ASCII), 'name')
    else:
        raise AssertionError(kind)


def relations(p):
    c, e, r, w = (p[k] for k in ['compile', 'engine', 'run', 'worker'])
    for key in ['object_bytes', 'input_bytes', 'output_bytes', 'host_request_bytes', 'host_response_bytes']:
        require(r[key] <= r['memory_bytes'], 'instance component')
    require(r['memory_bytes'] <= e['instances_bytes'], 'instance set')
    require(e['program_bytes'] <= e['total_program_bytes'], 'program set')
    for value in [c['working_bytes'], e['control_bytes'], e['total_program_bytes'], e['instances_bytes']]:
        require(value <= e['memory_bytes'], 'engine component')
    require(e['memory_bytes'] + w['transport_bytes'] + 37748736 <= w['memory_bytes'], 'worker headroom')
    require(c['source_bytes'] <= c['working_bytes'], 'compile source')
    require(max(w['startup_ms'], c['deadline_ms'], r['deadline_ms']) <= w['session_ms'], 'session')


def oracle(data, schema, policy=None):
    try:
        value = strict(data)
        shape(value, schema)
        if policy is None:
            relations(value)
        else:
            require(set(value['requires']) <= set(value['grants']) <= set(policy['capabilities']), 'authority')
            require(all(v <= policy['run'][k] for k, v in value['limits'].items()), 'narrowing')
            relations({**policy, 'run': value['limits']})
        return True
    except (ValueError, UnicodeError, TypeError, KeyError):
        return False


def verify_reference():
    provenance = json.loads((REFERENCE / 'provenance.json').read_bytes())
    for entry in provenance['entries']:
        path = REFERENCE / Path(entry['path']).name
        require(path.is_file() and suite.runner.digest(path) == entry['sha256'], f'provenance: {path}')
    pschema = json.loads((REFERENCE / 'policy.schema.json').read_bytes())
    rschema = json.loads((REFERENCE / 'run-config.schema.json').read_bytes())
    policies = [strict((REFERENCE / p).read_bytes()) for p in POLICIES]
    for name in POLICIES:
        require(oracle((REFERENCE / name).read_bytes(), pschema), name)
    require(oracle((REFERENCE / 'run-config.example.json').read_bytes(), rschema, policies[0]), 'run ZIP example')
    require(strict((REFERENCE / 'policy-base.json').read_bytes()) == policies[0], 'policy mutation base')
    require(strict((REFERENCE / 'run-base.json').read_bytes()) == strict((REFERENCE / 'run-config.example.json').read_bytes()), 'run mutation base')
    inputs = []
    for which, module in [('policy', 'runtime_policy'), ('run', 'runtime_run_config')]:
        source = (ROOT / f'tests/m2/{module}.fy').read_text(encoding='utf-8')
        for i, name in enumerate(POLICIES[:5]):
            match = re.search(r'if\(i==' + str(i) + r'\)\{return (' + LITERAL + r');\}', source)
            require(match and ast.literal_eval(match[1]) == (REFERENCE / name).read_bytes(), name)
        bases = re.findall(r'fn ref u8\[\] ' + which + r'_base\(\)\{return (' + LITERAL + r');\}', source)
        require(len(bases) == 1 and ast.literal_eval(bases[0]) == (REFERENCE / f'{which}-base.json').read_bytes(), 'native base')
        if which == 'run':
            fixture = re.search(r'fn ref u8\[\] run_fixture\(\)\{return (' + LITERAL + r');\}', source)
            require(fixture and ast.literal_eval(fixture[1]) == (REFERENCE / 'run-config.example.json').read_bytes(), 'exact native run fixture')
        required = Counter()
        for path in sorted(REFERENCE.glob(f'{which}-*-vectors.json')):
            corpus = json.loads(path.read_bytes())
            base = (REFERENCE / corpus['base']).read_bytes()
            for c in corpus['cases']:
                b, e = c['begin'], c['end']
                require(0 <= b <= e <= len(base), c['label'])
                replacement = bytes.fromhex(c['replacement_hex'])
                data = base[:b] + replacement + base[e:]
                policy = None if which == 'policy' else policies[c['policy']]
                require(oracle(data, pschema if which == 'policy' else rschema, policy) == c['accepted'], f'oracle: {c["label"]}')
                signature = (b, e, replacement, c['accepted'], CODES[c.get('failure')])
                if which == 'run':
                    signature += (c['policy'],)
                required[signature] += 1
                inputs.append(dict(module=module, label=c['label'], accepted=c['accepted'],
                                   inputSha256=hashlib.sha256(data).hexdigest(), bytes=len(data)))
        calls = re.findall(r'\b' + which + r'_case\((\d+),(\d+),(' + LITERAL +
                           r'),(true|false),(\d+)' + (r',(\d+)' if which == 'run' else '') + r'\);', source)
        actual = Counter()
        for call in calls:
            b, e, literal, ok, code, *policy = call
            signature = (int(b), int(e), ast.literal_eval(literal), ok == 'true', int(code))
            if policy:
                signature += (int(policy[0]),)
            actual[signature] += 1
        require(actual == required, f'native corpus equality: {module}')
    # Independent API manifest for the integrating owner, including common errors/types.
    source_paths = sorted(ROOT.glob('src/runtime_policy*.fy')) + [ROOT / 'src/runtime_run_config.fy']
    apis = {p.relative_to(ROOT).as_posix(): re.findall(r'^pub (?:fn|struct|resource|enum) .+', p.read_text(), re.M)
            for p in source_paths}
    changed = sorted({p.relative_to(ROOT).as_posix() for p in source_paths} |
                     {'tests/m2/runtime_policy.fy', 'tests/m2/runtime_run_config.fy',
                      'tools/verify-runtime-policy.py', 'docs/engineering/runtime-policy.md'} |
                     {p.relative_to(ROOT).as_posix() for p in REFERENCE.iterdir() if p.is_file()})
    for name in changed:
        data = (ROOT / name).read_bytes()
        if name.endswith(('.fy', '.py', '.md')) and not name.startswith('tools/runtime-policy/reference/'):
            require(b'\r' not in data and len(data) < 40960, f'LF/size: {name}')
    output = ROOT / suite.DIRECTORY
    output.mkdir(parents=True, exist_ok=True)
    result = dict(schema='browniec.runtime-policy-reference-verification/v1', status='passed',
                  base=provenance['base'], referenceArchiveSha256=provenance['archiveSha256'],
                  vectors=len(inputs), acceptedVectors=sum(c['accepted'] for c in inputs),
                  exactZipPolicies=5, exactZipRuns=1, changedPaths=changed, publicApi=apis,
                  nativeVectorInputs=inputs,
                  boundaries='Typed metadata only; no Engine/Program binding, reachable requirements, public gate or host dispatch.')
    suite.runner.write(output / 'reference-receipt.json', result)


if __name__ == '__main__':
    if not __debug__:
        raise SystemExit('Run without Python -O.')
    verify_reference()
    suite.main()
