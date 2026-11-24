"""Strumenti per le lingue dell'interfaccia di Mixora.

  python -I tools/l10n_tool.py wrap       avvolge in tr() i testi dell'interfaccia (solo contesti sicuri)
  python -I tools/l10n_tool.py fixconst   toglie i `const` resi invalidi da tr() (usa `flutter analyze`)
  python -I tools/l10n_tool.py todo       elenca i testi italiani rimasti fuori da tr()
  python -I tools/l10n_tool.py extract    scrive app/l10n/keys.json (tutte le chiavi tr) e segnala le traduzioni mancanti
  python -I tools/l10n_tool.py gen        genera app/lib/l10n/translations.g.dart da app/l10n/<lingua>.json

Le chiavi sono i testi italiani. Le traduzioni stanno in app/l10n/<lingua>.json come {"testo italiano": "traduzione"}.
I file JSON sono la fonte delle traduzioni: per un testo nuovo si aggiunge la riga in ogni <lingua>.json, poi gen.
(merge serve solo per importare un file .tsv numerato come quelli usati per la prima traduzione.)
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, 'app')
LIB = os.path.join(APP, 'lib')
L10N_DIR = os.path.join(APP, 'l10n')
LANGS = ['en', 'es', 'fr', 'de', 'pt']
SKIP_FILES = {'capture.dart', 'brand.g.dart', 'translations.g.dart', 'l10n.dart', 'version.dart'}
BS = chr(92)

TEXT_CALL = re.compile(r'(?:\b(?:Text|SelectableText|MxLabeled)\(\s*|\bTextSpan\(\s*text\s*:\s*)$')
NAMED = re.compile(r'\b(tooltip|message|label|title|subtitle|hintText|helperText|labelText|semanticLabel|description|caption|hint|header|helpText|emptyText|applicationLegalese|confirmLabel|cancelLabel|okLabel)\s*:\s*$')


# ------------------------------------------------------------------ lessico Dart (stringhe e commenti)

def lex_strings(src):
    """Restituisce le stringhe letterali: (inizio, fine, raw, quote, contenuto_sorgente, ha_interpolazione)."""
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith('//', i):
            j = src.find('\n', i)
            i = n if j < 0 else j
            continue
        if src.startswith('/*', i):
            j = src.find('*/', i + 2)
            i = n if j < 0 else j + 2
            continue
        raw = False
        if c in 'rR' and i + 1 < n and src[i + 1] in '\'"' and (i == 0 or not (src[i - 1].isalnum() or src[i - 1] == '_')):
            raw = True
            i += 1
            c = src[i]
        if c in '\'"':
            q = src[i:i + 3] if src[i:i + 3] in ("'''", '"""') else c
            start = i - (1 if raw else 0)
            j = i + len(q)
            interp = False
            depth = 0
            while j < n:
                if not raw and src[j] == BS:
                    j += 2
                    continue
                if not raw and src.startswith('${', j):
                    interp = True
                    # salta l'espressione interpolata (con stringhe annidate)
                    k, d = j + 2, 1
                    while k < n and d:
                        if src[k] == '{':
                            d += 1
                        elif src[k] == '}':
                            d -= 1
                        k += 1
                    j = k
                    continue
                if not raw and src[j] == '$' and j + 1 < n and (src[j + 1].isalpha() or src[j + 1] == '_'):
                    interp = True
                if src.startswith(q, j):
                    break
                if len(q) == 1 and src[j] == '\n':
                    break
                j += 1
            end = j + len(q)
            out.append((start, end, raw, q, src[i + len(q):j], interp))
            i = end
            continue
        i += 1
    return out


def groups(src, lits):
    """Raggruppa le stringhe adiacenti ('a' 'b'), separate solo da spazi o commenti."""
    gs, cur = [], []
    for lit in lits:
        if cur:
            between = src[cur[-1][1]:lit[0]]
            between = re.sub(r'//[^\n]*', '', between)
            if between.strip() == '':
                cur.append(lit)
                continue
            gs.append(cur)
        cur = [lit]
    if cur:
        gs.append(cur)
    return gs


def decode(content, raw):
    if raw:
        return content
    out, i = [], 0
    while i < len(content):
        c = content[i]
        if c == BS and i + 1 < len(content):
            d = content[i + 1]
            if d == 'n':
                out.append('\n')
            elif d == 't':
                out.append('\t')
            elif d == 'u':
                if content[i + 2] == '{':
                    k = content.index('}', i)
                    out.append(chr(int(content[i + 3:k], 16)))
                    i = k + 1
                    continue
                out.append(chr(int(content[i + 2:i + 6], 16)))
                i += 6
                continue
            else:
                out.append(d)
            i += 2
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def group_text(g):
    return ''.join(decode(l[4], l[2]) for l in g)


def looks_textual(s):
    return re.search(r'[A-Za-zÀ-ÿ]{3}', s) is not None and not re.fullmatch(r'[/\-a-z0-9_.{}%]+', s)


ITALIAN = re.compile(r'[àèéìòù]|\b(il|lo|la|le|gli|del|della|dei|delle|di|da|non|per|con|una|uno|che|sul|sulla|alla|nel|nella|questo|questa|nessun|nessuna|dopo|prima|tutti|tutte|solo|anche|oppure|quando|ancora|cerca|apri|chiudi|salva|annulla|conferma|elimina|rinomina|richiama|canale|canali|impostazioni|scena|scene|mandate|mandata)\b', re.I)


def dart_files():
    for dp, _, fs in os.walk(LIB):
        for f in fs:
            if f.endswith('.dart') and f not in SKIP_FILES:
                yield os.path.join(dp, f)


# ------------------------------------------------------------------ comandi

def cmd_wrap():
    total, manual = 0, []
    for p in dart_files():
        src = open(p, encoding='utf-8').read()
        lits = lex_strings(src)
        edits = []
        for g in groups(src, lits):
            text = group_text(g)
            if not looks_textual(text):
                continue
            before = src[max(0, g[0][0] - 80):g[0][0]]
            if before.rstrip().endswith('tr('):
                continue
            if not (TEXT_CALL.search(before) or NAMED.search(before)):
                continue
            if any(l[5] for l in g):
                manual.append(f'{os.path.relpath(p, ROOT)}: {text[:70]!r}')
                continue
            edits.append((g[0][0], g[-1][1]))
        if not edits:
            continue
        for s, e in sorted(edits, reverse=True):
            src = src[:s] + 'tr(' + src[s:e] + ')' + src[e:]
        src = re.sub(r'\bconst\s+(Text|SelectableText)\(tr\(', r'\1(tr(', src)
        if "l10n/l10n.dart'" not in src:
            rel = os.path.relpath(os.path.join(LIB, 'l10n', 'l10n.dart'), os.path.dirname(p)).replace(BS, '/')
            m = list(re.finditer(r"^import [^\n]+;\n", src, re.M))
            pos = m[-1].end() if m else 0
            src = src[:pos] + f"import '{rel}';\n" + src[pos:]
        open(p, 'w', encoding='utf-8', newline='\n').write(src)
        total += len(edits)
        print(f'{len(edits):4d}  {os.path.relpath(p, ROOT)}')
    print(f'avvolti: {total}')
    if manual:
        print('\ncon interpolazioni, da fare a mano:')
        print('\n'.join(manual))


SKIP_BEFORE = re.compile(r'(contains|startsWith|endsWith|RegExp|ValueKey|Key|indexOf|replaceAll|split|log|_log|writeln|write|_addLog|LogEntry\([^)]*)\(\s*$|(==|!=)\s*$|\bcase\s+$|/\*l10n\*/\s*$|\btr\(\s*$')


def interp_parts(content):
    """Divide il contenuto di un letterale in testo e interpolazioni: [('t', testo) | ('e', espressione)]."""
    parts, i, buf = [], 0, []
    while i < len(content):
        c = content[i]
        if c == BS and i + 1 < len(content):
            buf.append(content[i:i + 2])
            i += 2
            continue
        if content.startswith('${', i):
            k, d = i + 2, 1
            while k < len(content) and d:
                if content[k] == '{':
                    d += 1
                elif content[k] == '}':
                    d -= 1
                k += 1
            parts.append(('t', ''.join(buf)))
            buf = []
            parts.append(('e', content[i + 2:k - 1]))
            i = k
            continue
        if c == '$' and i + 1 < len(content) and (content[i + 1].isalpha() or content[i + 1] == '_'):
            k = i + 1
            while k < len(content) and (content[k].isalnum() or content[k] == '_'):
                k += 1
            parts.append(('t', ''.join(buf)))
            buf = []
            parts.append(('e', content[i + 1:k]))
            i = k
            continue
        buf.append(c)
        i += 1
    parts.append(('t', ''.join(buf)))
    return parts


def human_text(g, src):
    """Terzo passaggio: testo leggibile (parole e spazi, o in una posizione d'interfaccia), non percorsi o chiavi."""
    plain = ''.join(''.join(v if k == 't' else '{x}' for k, v in interp_parts(l[4])) if l[5] else l[4] for l in g)
    if not re.search(r'[A-Za-zÀ-ÿ]{3}', plain.replace('{x}', '')):
        return False
    if plain.startswith(('/', 'dart:', 'package:', 'assets/', '#')) or re.search(r'\{x\}/|/\{x\}|/[a-z]+/', plain):
        return False
    if re.fullmatch(r'[\w.\-{}]+\.(dart|scn|txt|json|log|md)', plain) or ('_' in plain and ' ' not in plain):
        return False
    before = src[max(0, g[0][0] - 120):g[0][0]]
    return ' ' in plain.strip() or bool(TEXT_CALL.search(before) or NAMED.search(before))


def cmd_wrap2(broad=False):
    total = 0
    for p in dart_files():
        if broad and p.endswith(('prefs.dart', 'app_controller.dart')):
            continue  # dati salvati e registro tecnico: restano com'erano
        src = open(p, encoding='utf-8').read()
        edits = []
        for g in groups(src, lex_strings(src)):
            text = group_text(g)
            if not looks_textual(text):
                continue
            if not (human_text(g, src) if broad else ITALIAN.search(text)):
                continue
            before = src[max(0, g[0][0] - 120):g[0][0]]
            after = src[g[-1][1]:g[-1][1] + 3].lstrip()
            is_map_key = after.startswith(':') and before.rstrip()[-1:] in ('{', ',')
            if SKIP_BEFORE.search(before) or is_map_key:
                continue
            if any(l[2] or len(l[3]) == 3 for l in g):
                continue  # raw o a tre apici: a mano
            args, out_lits = [], []
            for (_, _, raw, q, content, has_interp) in g:
                if not has_interp:
                    out_lits.append(q + content + q)
                    continue
                s = ''
                for kind, val in interp_parts(content):
                    if kind == 't':
                        s += val
                    else:
                        s += '{p%d}' % len(args)
                        args.append(val)
                out_lits.append(q + s + q)
            sep = src[g[0][1]:g[1][0]] if len(g) > 1 else ''
            body = ('\n' if '\n' in sep else ' ').join(out_lits) if len(g) > 1 else out_lits[0]
            new = 'tr(' + body + (', {' + ', '.join("'p%d': %s" % (i, a) for i, a in enumerate(args)) + '}' if args else '') + ')'
            edits.append((g[0][0], g[-1][1], new))
        if not edits:
            continue
        for s, e, new in sorted(edits, reverse=True):
            src = src[:s] + new + src[e:]
        if "l10n/l10n.dart'" not in src:
            rel = os.path.relpath(os.path.join(LIB, 'l10n', 'l10n.dart'), os.path.dirname(p)).replace(BS, '/')
            m = list(re.finditer(r"^import [^\n]+;\n", src, re.M))
            pos = m[-1].end() if m else 0
            src = src[:pos] + f"import '{rel}';\n" + src[pos:]
        open(p, 'w', encoding='utf-8', newline='\n').write(src)
        total += len(edits)
        print(f'{len(edits):4d}  {os.path.relpath(p, ROOT)}')
    print(f'avvolti (secondo passaggio): {total}')


def analyze_errors():
    r = subprocess.run(['flutter', 'analyze', '--no-fatal-infos', '--no-fatal-warnings'], cwd=APP, capture_output=True, text=True, shell=True, encoding='utf-8', errors='replace')
    errs = []
    for line in r.stdout.splitlines():
        m = re.match(r'\s*error - (.*) - (.+?\.dart):(\d+):(\d+) - (\S+)', line)
        if m:
            errs.append((os.path.join(APP, m.group(2)), int(m.group(3)), int(m.group(4)), m.group(5), m.group(1)))
    return errs


CONST_CODES = {'const_with_non_const', 'invalid_constant', 'non_constant_list_element', 'non_constant_map_element',
               'const_initialized_with_non_constant_value', 'const_constructor_param_type_mismatch',
               'non_constant_default_value', 'const_eval_method_invocation', 'const_with_non_constant_argument'}


def matching_end(src, i):
    """Fine dell'espressione che comincia in i (identificatore con argomenti, lista o mappa)."""
    j = i
    while j < len(src) and (src[j].isalnum() or src[j] in '_.<>, ?') and src[j] not in '([{':
        j += 1
    if j >= len(src) or src[j] not in '([{':
        return i
    open_c = src[j]
    close_c = {'(': ')', '[': ']', '{': '}'}[open_c]
    d = 0
    lits = [(s, e) for s, e, *_ in lex_strings(src[j:])]
    k = j
    while k < len(src):
        ch = src[k]
        if ch in '([{':
            d += 1
        elif ch in ')]}':
            d -= 1
            if d == 0:
                return k
        elif ch in '\'"':
            for s, e in lits:
                if s + j == k:
                    k = e + j - 1
                    break
        k += 1
    return k


def cmd_fixconst():
    for rnd in range(30):
        errs = [e for e in analyze_errors() if e[3] in CONST_CODES]
        if not errs:
            print('nessun errore di const rimasto')
            return
        by_file = {}
        for p, ln, col, code, msg in errs:
            by_file.setdefault(p, []).append((ln, col))
        fixed = 0
        for p, poss in by_file.items():
            src = open(p, encoding='utf-8').read()
            lines = src.split('\n')
            # tutte le posizioni sono calcolate sul testo originale e applicate dalla fine
            changes = {}  # inizio di `const` -> sostituzione ('' = toglie, 'final ' = campo/variabile)
            for ln, col in poss:
                off = sum(len(l) + 1 for l in lines[:ln - 1]) + col - 1
                best = None
                for m in re.finditer(r'\bconst\s+', src[:off]):
                    end = matching_end(src, m.end())
                    if end >= off:
                        best = m
                if best is not None:
                    changes.setdefault(best.start(), '')
                    continue
                line_start = src.rfind('\n', 0, off) + 1
                mm = re.search(r'\bconst\b', src[line_start:off])
                if mm:
                    changes.setdefault(line_start + mm.start(), 'final ')
            for s in sorted(changes, reverse=True):
                m = re.match(r'const\s*', src[s:])
                if m:
                    src = src[:s] + changes[s] + src[s + len(m.group(0)):]
                    fixed += 1
            open(p, 'w', encoding='utf-8', newline='\n').write(src)
        print(f'giro {rnd + 1}: corretti {fixed} su {len(errs)} errori')
        if not fixed:
            for e in errs[:20]:
                print('  ', os.path.relpath(e[0], ROOT), e[1], e[3], e[4][:90])
            return


def cmd_todo():
    for p in dart_files():
        src = open(p, encoding='utf-8').read()
        for g in groups(src, lex_strings(src)):
            text = group_text(g)
            before = src[max(0, g[0][0] - 40):g[0][0]].rstrip()
            if before.endswith('tr(') or before.endswith('/*l10n*/') or not looks_textual(text) or not ITALIAN.search(text):
                continue
            ln = src.count('\n', 0, g[0][0]) + 1
            print(f'{os.path.relpath(p, ROOT)}:{ln}: {text[:100]!r}')


def all_keys():
    keys = []
    for p in dart_files():
        src = open(p, encoding='utf-8').read()
        for g in groups(src, lex_strings(src)):
            before = src[max(0, g[0][0] - 40):g[0][0]].rstrip()
            # tr('…') oppure /*l10n*/ '…' (testi in costanti, tradotti dove vengono mostrati con tr(variabile))
            if before.endswith('tr(') or before.endswith('/*l10n*/'):
                k = group_text(g)
                if k not in keys:
                    keys.append(k)
    return keys


def cmd_extract():
    keys = all_keys()
    os.makedirs(L10N_DIR, exist_ok=True)
    json.dump(keys, open(os.path.join(L10N_DIR, 'keys.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(f'chiavi: {len(keys)}')
    for lang in LANGS:
        p = os.path.join(L10N_DIR, f'{lang}.json')
        tr = json.load(open(p, encoding='utf-8')) if os.path.exists(p) else {}
        missing = [k for k in keys if not tr.get(k)]
        unused = [k for k in tr if k not in keys]
        print(f'{lang}: tradotte {len(keys) - len(missing)}/{len(keys)}, mancanti {len(missing)}, non usate {len(unused)}')


def cmd_merge():
    """app/l10n/<lingua>.tsv (numero <tab> traduzione, \\n = a capo) → <lingua>.json, con i controlli."""
    keys = json.load(open(os.path.join(L10N_DIR, 'keys.json'), encoding='utf-8'))
    ph = re.compile(r'\{p\d+\}')
    ok = True
    for lang in LANGS:
        p = os.path.join(L10N_DIR, f'{lang}.tsv')
        if not os.path.exists(p):
            continue
        rows = {}
        for n, line in enumerate(open(p, encoding='utf-8').read().split('\n'), 1):
            if not line.strip():
                continue
            idx, _, text = line.partition('\t')
            rows[int(idx)] = text.replace(BS + 'n', '\n')
        problems = [f'{lang}: manca il numero {i}' for i in range(len(keys)) if i not in rows]
        problems += [f'{lang}: numero in più {i}' for i in rows if i >= len(keys)]
        for i, k in enumerate(keys):
            if i in rows and sorted(ph.findall(k)) != sorted(ph.findall(rows[i])):
                problems.append(f'{lang} {i}: segnaposto diversi: {k[:50]!r} → {rows[i][:50]!r}')
        if problems:
            ok = False
            print('\n'.join(problems[:30]))
            continue
        json.dump({keys[i]: rows[i] for i in range(len(keys))}, open(os.path.join(L10N_DIR, f'{lang}.json'), 'w', encoding='utf-8'),
                  ensure_ascii=False, indent=1)
        print(f'{lang}: {len(keys)} traduzioni controllate')
    if not ok:
        sys.exit(1)


def dart_lit(s):
    return "'" + s.replace(BS, BS + BS).replace("'", BS + "'").replace('$', BS + '$').replace('\n', BS + 'n') + "'"


def cmd_gen():
    out = ['// GENERATO da tools/l10n_tool.py gen (da app/l10n/<lingua>.json): non modificare a mano.',
           '// ignore_for_file: lines_longer_than_80_chars', '',
           '/// Traduzioni per lingua: testo italiano → testo tradotto.',
           'const Map<String, Map<String, String>> kTranslations = {']
    for lang in LANGS:
        p = os.path.join(L10N_DIR, f'{lang}.json')
        tr = json.load(open(p, encoding='utf-8')) if os.path.exists(p) else {}
        out.append(f"  '{lang}': {{")
        for k in sorted(tr):
            if tr[k]:
                out.append(f'    {dart_lit(k)}: {dart_lit(tr[k])},')
        out.append('  },')
    out.append('};')
    open(os.path.join(LIB, 'l10n', 'translations.g.dart'), 'w', encoding='utf-8', newline='\n').write('\n'.join(out) + '\n')
    print('translations.g.dart generato')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    {'wrap': cmd_wrap, 'wrap2': cmd_wrap2, 'wrap3': lambda: cmd_wrap2(True), 'fixconst': cmd_fixconst, 'todo': cmd_todo, 'extract': cmd_extract, 'merge': cmd_merge, 'gen': cmd_gen}[sys.argv[1]]()
