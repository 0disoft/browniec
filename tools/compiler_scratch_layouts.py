"""Review private compiler scratch widths used by the heap reservation proof."""
import re


def reviewed_scratch(text):
    definitions = {m[2]: m[1] for m in re.finditer(
        r'typedef struct(?: \w+)? \{\s*([^}]+)\} (fy_\w+);', text)}
    sizes = {m[1]: int(m[2]) for m in re.finditer(
        r'_Static_assert\(sizeof\((fy_\w+)\) == UINT64_C\((\d+)\)', text)}

    def array(name, element, count):
        return bool(re.fullmatch(r'\s*' + element + r' data\[UINT64_C\(' + str(count) +
                                 r'\)\];\s*', definitions.get(name, '')))

    candidates = {'bank': [], 'expression': [], 'conditional': []}
    for name, body in definitions.items():
        fields = re.findall(r'(fy_\w+) f_\d+;', body)
        if len(fields) >= 2 and array(fields[0], 'uintptr_t', 272) and array(fields[1], 'uint8_t', 272):
            candidates['expression'].append(name)
        if len(fields) == 12 and array(fields[-1], 'uintptr_t', 1024):
            candidates['bank'].append(name)
        if len(fields) >= 2 and re.search(r'data\[UINT64_C\(35\)\]', definitions.get(fields[0], '')):
            rows = re.findall(r'(fy_\w+) f_\d+;', definitions.get(fields[1], ''))
            if len(rows) == 4 and all(array(t, 'uintptr_t', 64) for t in rows[:3]):
                candidates['conditional'].append(name)
    caps = {'bank': 40000, 'expression': 6000, 'conditional': 15000}
    result = {}
    for role, matches in candidates.items():
        assert len(matches) == 1, (role, matches)
        name = matches[0]
        assert sizes[name] <= caps[role], (role, sizes[name], caps[role])
        result[role] = dict(type=name, bytes=sizes[name], slotBound=caps[role])
    return result
