#!/usr/bin/env python3
"""
MockTester Question Format Normalizer
=====================================
Purane/mile-jule format ke question JSON ko EK canonical format me
dhalta hai (docs/question_format.md dekho). Sirf vahi badlav hota hai
jo 100% surakshit (deterministic) hai — bachi hui shaq wali cheezein
report me FLAG hoti hain, chupke se "fix" nahi hoti.

Canonical keys: p_id, qe, qh, se, sh, oe, oh, a, e

Istemaal:
  python3 normalize_questions.py <input_folder> <output_folder>
  # report.json output folder me banti hai
"""
import json
import os
import re
import sys

SUB = str.maketrans('₀₁₂₃₄₅₆₇₈₉', '0123456789')
SUP = str.maketrans('⁰¹²³⁴⁵⁶⁷⁸⁹⁻⁺', '0123456789-+')
SUB_CHARS = '₀₁₂₃₄₅₆₇₈₉'
SUP_CHARS = '⁰¹²³⁴⁵⁶⁷⁸⁹'

REPORT = {
    'files_processed': 0, 'files_skipped': 0, 'files_parse_error': [],
    'files_repaired': [],
    'questions': 0, 'topic_stripped': 0, 'unicode_formula_wrapped': 0,
    'bare_latex_wrapped': 0, 'arrow_fixed': 0,
    'flags': [],
}


def flag(kind, where, detail):
    REPORT['flags'].append({'type': kind, 'where': where, 'detail': detail})


def strip_topic(text):
    """Shuruaat wala chipka topic hatao: <b>Topic:</b> ya **Topic:**"""
    if not text:
        return text, False
    t = text.lstrip()
    m = re.match(r'^<(b|strong)>(.*?)</\1>\s*:?\s*', t, re.I)
    if not m:
        m = re.match(r'^\*\*(.{2,90}?):?\*\*\s*:?\s*', t)
    if not m:
        return text, False
    inner = m.group(2).strip()
    if (not inner or len(inner) > 90 or '?' in inner
            or len(inner.split()) > 12):
        return text, False
    # Topic ki asal pehchan: andar ':' ho, ya shabd 'topic' se shuru ho.
    # Warna ye sawal ka hissa ho sakta hai (jaise <b>'FRUGAL'</b> ka vilom).
    low = inner.lower()
    if ':' not in inner and not low.startswith('topic'):
        return text, False
    rest = t[m.end():].lstrip()
    return (rest if rest else text), bool(rest)


def looks_math(inner):
    t = inner.strip()
    if not t or len(t) > 120:
        return False
    if any(c in t for c in '\\^_{}'):
        return True
    return bool(re.search(r'\d', t)) and bool(re.search(r'[=<>+\-*/×÷√π]', t))


def outside_math(text, fn):
    """$...$ ke bahar wale hisse par hi fn chalao, math ko haath mat lagao."""
    parts = text.split('$')
    for i in range(0, len(parts), 2):
        parts[i] = fn(parts[i])
    return '$'.join(parts)


def convert_unicode_formulas(seg):
    count = [0]

    def token_repl(m):
        tok = m.group(0)
        out, i = '', 0
        while i < len(tok):
            c = tok[i]
            if c in SUB_CHARS:
                j = i
                while j < len(tok) and tok[j] in SUB_CHARS:
                    j += 1
                out += '_' + tok[i:j].translate(SUB)
                i = j
            elif c in SUP_CHARS or c in SUP_PM:
                j = i
                while j < len(tok) and tok[j] in SUP_CHARS + SUP_PM:
                    j += 1
                out += '^' + tok[i:j].translate(SUP)
                i = j
            else:
                out += c
                i += 1
        count[0] += 1
        return '$' + out + '$'

    # subscript/superscript wala token (aksar chemistry/math): H₂SO₄, CO₂, x², cm²
    sup_all = SUP_CHARS + '\u207b\u207a'
    seg = re.sub(r'[A-Za-z0-9()]*[A-Za-z()][A-Za-z0-9()]*[' + SUB_CHARS + sup_all + r'][A-Za-z0-9()\u2080-\u2089\u2070-\u2079\u207a\u207b¹²³]*',
                 token_repl, seg)
    seg = re.sub(r'\d+[' + SUP_CHARS + r'][0-9' + SUP_CHARS + r']*', token_repl, seg)
    # E = $mc^2$ -> $E = mc^2$ (aadha formula bahar na rahe)
    seg = re.sub(r'(?<![\w$])([A-Za-z] (?:=|\+|-|\*|/) )\$([^\n$]+)\$',
                 r'$\1\2$', seg)
    seg, g = wrap_greek_chunks(seg)
    count[0] += g
    # $...$ ke theek baad chipka Greek akshar math ke andar le lo
    def _absorb(m):
        inner_g = ''.join(GREEK_MAP.get(ch, ch) for ch in m.group(2))
        return '$' + m.group(1) + inner_g + '$'
    greek_class = ''.join(GREEK_MAP.keys())
    seg = re.sub(r'\$([^$\n]{1,80})\$([' + greek_class + r'])', _absorb, seg)
    return seg, count[0]



GREEK_MAP = {
    'α': r'\alpha', 'β': r'\beta', 'γ': r'\gamma', 'δ': r'\delta',
    'Δ': r'\Delta', 'θ': r'\theta', 'Θ': r'\Theta', 'λ': r'\lambda',
    'μ': r'\mu', 'π': r'\pi', 'Π': r'\Pi', 'σ': r'\sigma',
    'Σ': r'\Sigma', 'φ': r'\phi', 'ϕ': r'\phi', 'Φ': r'\Phi',
    'ψ': r'\psi', 'Ψ': r'\Psi', 'ω': r'\omega', 'Ω': r'\Omega',
    'ρ': r'\rho', 'τ': r'\tau', '∞': r'\infty',
}
MATHY_EXTRA = set('=<>+-*/().,[]^_%°×÷·√≥≤')
SUP_PM = '\u207b\u207a'


def _is_mathy_token(tok):
    if not tok or len(tok) > 12:
        return False
    if any('\u0900' <= ch <= '\u097f' for ch in tok):
        return False  # Hindi shabd = sadharan text
    if tok.isalpha() and len(tok) >= 4 and not any(ch in GREEK_MAP for ch in tok):
        return False  # lamba English shabd math nahi
    return all(ch.isalnum() or ch in GREEK_MAP or ch in MATHY_EXTRA for ch in tok)


def wrap_greek_chunks(seg):
    """Akele khade Greek chinh wale hisse ko $...$ me band karo."""
    toks = list(re.finditer(r'\S+', seg))
    runs, cur, prev_end = [], [], None
    for m in toks:
        tok = m.group(0)
        if _is_mathy_token(tok) and (prev_end is None or seg[prev_end:m.start()] == ' '):
            cur.append(m)
        else:
            if cur:
                runs.append(cur)
            cur = [m] if _is_mathy_token(tok) else []
        prev_end = m.end()
    if cur:
        runs.append(cur)
    out, last, n = [], 0, 0
    for run in runs:
        text_run = seg[run[0].start():run[-1].end()]
        if not any(ch in GREEK_MAP for ch in text_run):
            continue
        if len(run) < 2 and not any(op in text_run for op in '=<>+-*/'):
            continue
        conv = ''
        for k, ch in enumerate(text_run):
            if ch in GREEK_MAP:
                conv += GREEK_MAP[ch]
                if k + 1 < len(text_run) and text_run[k + 1].isalnum():
                    conv += ' '
            elif ch == '√':
                conv += r'\sqrt '
            else:
                conv += ch
        conv = (conv.replace('≥', r'\geq').replace('≤', r'\leq')
                    .replace('×', r'\times').replace('÷', r'\div')
                    .replace('·', r'\cdot').replace('//', '/'))
        out.append(seg[last:run[0].start()])
        out.append('$' + conv + '$')
        last = run[-1].end()
        n += 1
    if not n:
        return seg, 0
    out.append(seg[last:])
    return ''.join(out), n


def clean_math_inner(part):
    """$...$ ke ANDAR bache unicode chinh ko LaTeX me badlo."""
    out, i = '', 0
    while i < len(part):
        c = part[i]
        if c in SUB_CHARS:
            j = i
            while j < len(part) and part[j] in SUB_CHARS:
                j += 1
            out += '_{' + part[i:j].translate(SUB) + '}'
            i = j
        elif c in SUP_CHARS or c in SUP_PM:
            j = i
            sign = ''
            if c in SUP_PM:
                sign = '-' if c == SUP_PM[0] else '+'
                j = i + 1
            while j < len(part) and part[j] in SUP_CHARS:
                j += 1
            digits = part[(i + 1 if sign else i):j].translate(SUP)
            out += '^{' + sign + digits + '}'
            i = j
        elif c in GREEK_MAP:
            out += GREEK_MAP[c]
            if i + 1 < len(part) and part[i + 1].isalnum():
                out += ' '
            i += 1
        else:
            out += c
            i += 1
    return out


BARE_CMD = re.compile(
    r'(\\(?:frac\s*\{[^{}]*\}\s*\{[^{}]*\}|sqrt\s*(?:\{[^{}]*\}|\[[^\]]*\]\s*\{[^{}]*\})|vec\s*\{[^{}]*\}'
    r'|theta|alpha|beta|pi|Delta|delta|lambda|mu|nu|times|div|le|ge|neq|approx|rightarrow|infty|pm|degree|circ))'
)


def wrap_bare_latex(seg):
    n = len(BARE_CMD.findall(seg))
    if n:
        seg = BARE_CMD.sub(lambda m: '$' + m.group(1).replace(' ', '') + '$', seg)
    return seg, n


def normalize_text(text, where):
    if not isinstance(text, str):
        return '', False
    changed = False
    t, stripped = strip_topic(text)
    if stripped:
        REPORT['topic_stripped'] += 1
        changed = True
    t = t.replace('\u00a0', ' ').replace('<br/>', '<br>').replace('<br />', '<br>')

    def clean_outside(seg):
        nonlocal changed
        seg2, c1 = convert_unicode_formulas(seg)
        bare_count = [0]
        def _bare(s2):
            r, n = wrap_bare_latex(s2)
            bare_count[0] += n
            return r
        seg2 = outside_math(seg2, _bare)
        c2 = bare_count[0]
        REPORT['unicode_formula_wrapped'] += c1
        REPORT['bare_latex_wrapped'] += c2
        if seg2 != seg:
            changed = True
        return seg2

    t = outside_math(t, clean_outside)

    # math ke andar -> ko \rightarrow
    parts = t.split('$')
    for i in range(1, len(parts), 2):
        if '->' in parts[i]:
            REPORT['arrow_fixed'] += 1
            parts[i] = parts[i].replace('->', r'\rightarrow')
        cleaned = clean_math_inner(parts[i])
        if cleaned != parts[i]:
            REPORT['unicode_formula_wrapped'] += 1
            parts[i] = cleaned
    t = '$'.join(parts)

    # $ ki jaanch (sirf report, khud nahi badalta)
    if t.count('$') % 2 == 1:
        flag('odd_dollar', where, 'Akela $ reh gaya — KaTeX atak sakta hai')
    else:
        for m in re.finditer(r'\$([^$\n]{1,120}?)\$', t):
            if not looks_math(m.group(1)):
                flag('nonmath_dollar', where,
                     'Ye $...$ ganit nahi lagta (reasoning chinh?) — haath se dekho')
                break
    return t, changed


def parse_answer(raw, n_opts, where):
    if isinstance(raw, int):
        idx = raw
    elif raw is None:
        idx = 0
        flag('answer_missing', where, 'a gayab tha, 0 mana')
    else:
        s = str(raw).strip().upper()
        mapping = {'A': 0, 'B': 1, 'C': 2, 'D': 3,
                   '(A)': 0, '(B)': 1, '(C)': 2, '(D)': 3,
                   '1': 0, '2': 1, '3': 2, '4': 3}
        idx = mapping.get(s)
        if idx is None:
            try:
                idx = int(s)
            except ValueError:
                idx = 0
                flag('answer_unparsed', where, f'a={raw!r} samajh nahi aaya')
    if idx < 0 or idx >= max(n_opts, 1):
        flag('answer_out_of_range', where, f'a={idx}, options={n_opts}')
        idx = min(max(idx, 0), max(n_opts - 1, 0))
    return idx


def normalize_question(q, where, file_stem, idx):
    qe, _ = normalize_text(str(q.get('qe') or q.get('q') or q.get('question') or ''), where)
    qh_raw = q.get('qh') or q.get('question_hindi')
    if qh_raw:
        qh, _ = normalize_text(str(qh_raw), where)
    else:
        qh = qe
    if not qe.strip() and qh.strip():
        qe = qh

    raw_opts = q.get('oe') or q.get('o') or q.get('options') or []
    if isinstance(raw_opts, list):
        oe = [normalize_text(str(x).split('|')[0].strip(), where)[0]
              if isinstance(x, str) else normalize_text(str(x), where)[0]
              for x in raw_opts]
    else:
        oe = []
        flag('options_not_list', where, 'options list nahi hai')
    oh_raw = q.get('oh')
    oh = ([normalize_text(str(x).split('|')[0].strip(), where)[0]
           if isinstance(x, str) else normalize_text(str(x), where)[0]
           for x in oh_raw]
          if isinstance(oh_raw, list) and oh_raw else list(oe))
    if len(oe) != 4:
        flag('options_count', where, f'{len(oe)} options mile (4 chahiye)')

    out = {
        'p_id': str(q.get('p_id') or f'{file_stem}_{idx + 1}'),
        'qe': qe,
        'qh': qh,
    }
    if isinstance(q.get('se'), list):
        out['se'] = [normalize_text(str(x), where)[0] for x in q['se']]
    if isinstance(q.get('sh'), list):
        out['sh'] = [normalize_text(str(x), where)[0] for x in q['sh']]
    out['oe'] = oe
    out['oh'] = oh
    out['a'] = parse_answer(q.get('a', q.get('answerIndex', q.get('answer'))),
                            len(oe), where)
    out['e'] = normalize_text(str(q.get('e') or q.get('explanation') or ''), where)[0]
    if not out['e'].strip():
        flag('explanation_empty', where, 'explanation khali hai')
    return out


def try_repair(text):
    """Tuti JSON ki do jaani-pehchani galtiyaan theek karo (parse karke hi)."""
    attempts = []
    # R1: beech me ghusi adhuri line, jaise:  "o":3",
    lines = text.split('\n')
    kept = [ln for ln in lines
            if not re.match(r'^\s*"[A-Za-z_]+":\d+"\s*,?\s*$', ln)]
    if len(kept) != len(lines):
        attempts.append('\n'.join(kept))
    # R2: explanation ke aakhir me chipka faltu "]  ->  "..."]
    fixed = re.sub(r'(?m)^(\s*"e":.*)"\]\s*$', r'\1"', text)
    if fixed != text:
        attempts.append(fixed)
    fixed2 = re.sub(r'(?m)^(\s*"e":.*)"\]\s*$', r'\1"', '\n'.join(kept))
    attempts.append(fixed2)
    for cand in attempts:
        try:
            return json.loads(cand), True
        except Exception:
            continue
    return None, False


def is_question_bank(data):
    items = None
    if isinstance(data, list):
        items = data
    elif isinstance(data, dict):
        for k in ('questions', 'data', 'items'):
            if isinstance(data.get(k), list):
                items = data[k]
                break
    if not items or not isinstance(items[0], dict):
        return None
    if any(k in items[0] for k in ('qe', 'q', 'question', 'oe', 'o', 'options')):
        return items
    return None


def main():
    src, dst = sys.argv[1], sys.argv[2]
    for root, _, files in os.walk(src):
        for name in sorted(files):
            if not name.endswith('.json'):
                continue
            in_path = os.path.join(root, name)
            rel = os.path.relpath(in_path, src)
            out_path = os.path.join(dst, rel)
            os.makedirs(os.path.dirname(out_path), exist_ok=True)
            raw_text = ''
            try:
                with open(in_path, encoding='utf-8') as f:
                    raw_text = f.read()
                data = json.loads(raw_text)
            except Exception as e:
                data, repaired = try_repair(raw_text)
                if not repaired:
                    REPORT['files_parse_error'].append({'file': rel, 'error': str(e)[:90]})
                    # tuti file ko jaisa hai waisa aage badhao, kho na jaye
                    with open(in_path, 'rb') as fi, open(out_path, 'wb') as fo:
                        fo.write(fi.read())
                    continue
                REPORT['files_repaired'].append(rel)
            items = is_question_bank(data)
            if items is None:
                with open(in_path, 'rb') as fi, open(out_path, 'wb') as fo:
                    fo.write(fi.read())
                REPORT['files_skipped'] += 1
                continue
            stem = re.sub(r'\W+', '_', os.path.splitext(name)[0])
            new_items = []
            for idx, q in enumerate(items):
                where = f'{rel}#{idx + 1}'
                new_items.append(normalize_question(q, where, stem, idx))
                REPORT['questions'] += 1
            if isinstance(data, list):
                out_data = new_items
            else:
                out_data = dict(data)
                key = next(k for k in ('questions', 'data', 'items')
                           if isinstance(data.get(k), list))
                out_data[key] = new_items
            with open(out_path, 'w', encoding='utf-8') as f:
                json.dump(out_data, f, ensure_ascii=False, indent=2)
            REPORT['files_processed'] += 1

    with open(os.path.join(dst, 'normalization_report.json'), 'w', encoding='utf-8') as f:
        json.dump(REPORT, f, ensure_ascii=False, indent=2)
    print(json.dumps({k: v for k, v in REPORT.items() if k != 'flags'}, ensure_ascii=False, indent=2))
    print('flags:', len(REPORT['flags']))


if __name__ == '__main__':
    main()
