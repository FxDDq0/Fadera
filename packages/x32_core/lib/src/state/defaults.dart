/// Valori iniziali dei nodi: risorsa init 11 di X32-Edit 4.4.0 (Appendice A, doc 19).
///
/// Servono alla modalità offline e al simulatore. Per i nodi senza schema il
/// testo è quello della risorsa init; dove la risorsa non lo riporta si usa il
/// formato osservato sul mixer reale in T01b (stessi campi, valori neutri).
library;

String _two(int n) => n.toString().padLeft(2, '0');

/// Testo dei valori (senza percorso) per un nodo della tabella di sync.
String defaultValuesFor(String path) {
  final p = path;
  RegExpMatch? m;

  m = RegExp(r'^/(ch|auxin|fxrtn|bus|mtx)/(\d\d)/(.+)$').firstMatch(p);
  if (m != null) {
    final kind = m.group(1)!;
    final n = int.parse(m.group(2)!);
    final rest = m.group(3)!;
    return _stripDefault(kind, n, rest) ?? '';
  }
  m = RegExp(r'^/main/(st|m)/(.+)$').firstMatch(p);
  if (m != null) return _stripDefault(m.group(1) == 'st' ? 'main/st' : 'main/m', 1, m.group(2)!) ?? '';
  m = RegExp(r'^/dca/(\d)(/config)?$').firstMatch(p);
  if (m != null) return m.group(2) == null ? 'ON   0.0' : '"DCA ${m.group(1)}" 70 WH';
  if (RegExp(r'^/headamp/\d{3}$').hasMatch(p)) return '+0.0 OFF';
  m = RegExp(r'^/fx/(\d)(/source|/par)?$').firstMatch(p);
  if (m != null) {
    final slot = int.parse(m.group(1)!);
    switch (m.group(2)) {
      case null:
        return slot <= 4 ? const ['HALL', 'PLAT', 'VRM', 'DLY'][slot - 1] : 'GEQ2';
      case '/source':
        return 'MIX${12 + slot} MIX${12 + slot}';
      default:
        return ''; // generato dal tipo (MixerState.resetFxParams)
    }
  }
  m = RegExp(r'^/outputs/(main|aux|p16|aes|rec)/(\d\d)(/delay|/iQ)?$').firstMatch(p);
  if (m != null) {
    final g = m.group(1)!;
    final n = int.parse(m.group(2)!);
    if (m.group(3) == '/delay') return 'OFF   0.3';
    if (m.group(3) == '/iQ') return 'OFF none Linear 0';
    switch (g) {
      case 'main':
        return '${n + 3} POST OFF';
      case 'aux':
        return '0 POST OFF';
      case 'p16':
        return '${25 + n} <-EQ OFF';
      case 'aes':
        return '$n POST OFF';
      case 'rec':
        return '$n <-EQ';
    }
  }
  if (RegExp(r'^/config/userrout/(in|out)$').hasMatch(p)) {
    return List.filled(p.endsWith('/in') ? 32 : 48, '0').join(' ');
  }
  return _globalDefaults[p] ?? '';
}

String? _stripDefault(String kind, int n, String rest) {
  final isCh = kind == 'ch';
  final busLike = kind == 'bus' || kind == 'mtx' || kind.startsWith('main');
  switch (rest) {
    case 'config':
      return switch (kind) {
        'ch' => '"" 1 YE $n',
        'auxin' => '"" 55 GN ${32 + n}',
        'fxrtn' => '"" 61 MG',
        'bus' => '"MixBus $n" 71 CY',
        'mtx' => '"" 72 MG',
        'main/st' => '"" 66 WH',
        _ => '"" 67 WH',
      };
    case 'delay':
      return 'OFF   0.3';
    case 'preamp':
      return switch (kind) { 'ch' => '+0.0 OFF OFF 24  20', 'auxin' => '+0.0 OFF', _ => 'OFF' };
    case 'gate':
      return 'OFF GATE -80.0 60.0 10 50.2  258 0';
    case 'gate/filter':
    case 'dyn/filter':
      return 'OFF 3.0 990.9';
    case 'dyn':
      if (isCh) return 'OFF COMP PEAK LOG 0.0 3.0 1 0.00 10 10.0  151 POST 0 100 OFF';
      if (kind == 'bus') return 'OFF COMP RMS LOG 0.0 3.0 1 0.00 10 10.0  151 POST 0 100 OFF';
      return 'OFF COMP RMS LOG 0.0 3.0 1 0.00 10 10.0  151 POST 100 OFF';
    case 'insert':
      return isCh ? 'OFF POST OFF' : 'OFF PRE OFF';
    case 'eq':
      return 'OFF';
    case 'mix':
      if (kind == 'fxrtn') return 'ON   0.0 ON -100 OFF   -oo';
      if (kind == 'bus') return 'ON   -oo OFF +0 OFF   -oo';
      if (kind == 'main/st') return 'ON   -oo +0';
      if (kind == 'mtx' || kind == 'main/m') return 'ON   -oo';
      return 'ON   -oo ON +0 OFF   -oo';
    case 'grp':
      return '%00000000 %000000';
    case 'automix':
      return 'OFF  +0.0';
  }
  final eq = RegExp(r'^eq/(\d)$').firstMatch(rest);
  if (eq != null) {
    final b = int.parse(eq.group(1)!);
    if (busLike) return const ['LShv 79.6 +0.00 2.0', 'PEQ 159.6 +0.00 2.0', 'PEQ 496.6 +0.00 2.0', 'PEQ 1k97 +0.00 2.0', 'PEQ 5k01 +0.00 2.0', 'HShv 10k02 +0.00 2.0'][b - 1];
    return const ['PEQ 124.7 +0.00 2.0', 'PEQ 496.6 +0.00 2.0', 'PEQ 1k97 +0.00 2.0', 'HShv 10k02 +0.00 2.0'][b - 1];
  }
  final send = RegExp(r'^mix/(\d\d)$').firstMatch(rest);
  if (send != null) {
    final s = int.parse(send.group(1)!);
    if (s.isEven) return 'ON   -oo';
    if (kind == 'fxrtn') return 'ON   -oo -100 POST 0';
    if (busLike) return 'ON   -oo +0 POST 0';
    return 'ON   -oo +0 ${s <= 8 ? 'EQ->' : 'POST'} 0';
  }
  return null;
}

/// Nodi globali: testo della risorsa init 11 (Appendice A) o, dove assente, formato T01b.
final Map<String, String> _globalDefaults = {
  '/-prefs/rta/visibility': '70%',
  '/-prefs/rta/gain': '18',
  '/-prefs/rta/autogain': 'ON',
  '/-prefs/rta/source': '1',
  '/-prefs/rta/pos': 'POST',
  '/-prefs/rta/mode': 'BAR',
  '/-prefs/rta/options': '%000000',
  '/-prefs/rta/det': 'PEAK',
  '/-prefs/rta/decay': '1.00',
  '/-prefs/rta/peakhold': 'OFF',
  '/-urec': '0 0 0 0 0 NONE 0 0 0 0 NONE NONE "" "" "" 0',
  '/config/chlink': List.filled(16, 'OFF').join(' '),
  '/config/auxlink': 'OFF OFF OFF ON',
  '/config/fxlink': 'ON ON ON ON',
  '/config/buslink': List.filled(8, 'OFF').join(' '),
  '/config/mtxlink': 'OFF OFF OFF',
  '/config/mute': 'OFF OFF OFF OFF OFF OFF',
  '/config/linkcfg': 'ON ON ON ON',
  '/config/mono': 'LR+M OFF',
  '/config/solo': '  0.0 LRAFL 0.0 PFL PFL PFL OFF OFF OFF -20 OFF OFF OFF   0.3 OFF OFF OFF',
  '/config/talk': 'ON EXT',
  '/config/talk/A': '-12.0 OFF OFF %000000000000000000',
  '/config/talk/B': '-12.0 OFF ON %000000000000000000',
  '/config/osc': '-40.0 100.2 1k00 F1 PINK 0',
  '/config/routing': 'REC',
  '/config/routing/IN': 'AN1-8 AN9-16 AN17-24 AN25-32 AUX1-4',
  '/config/routing/AES50A': 'OUT1-8 OUT9-16 OUT1-8 OUT9-16 P161-8 P169-16',
  '/config/routing/AES50B': 'OUT1-8 OUT9-16 OUT1-8 OUT9-16 P161-8 P169-16',
  '/config/routing/CARD': 'AN1-8 AN9-16 AN17-24 AN25-32',
  '/config/routing/OUT': 'OUT1-4 OUT5-8 OUT9-12 OUT13-16',
  '/config/routing/PLAY': 'CARD1-8 CARD9-16 CARD17-24 CARD25-32 AUX1-4',
  '/config/userctrl/A': 'CY',
  '/config/userctrl/A/enc': '"X001" "X101" "X201" "X300"',
  '/config/userctrl/A/btn': '"O40" "O42" "X201" "X300" "P0051" "P0052" "P0053" "P0058"',
  '/config/userctrl/B': 'GN',
  '/config/userctrl/B/enc': '"DG" "DJ" "DK" "DL"',
  '/config/userctrl/B/btn': '"P0010" "P0011" "P0012" "P0013" "A0" "A1" "P0000" "P0000"',
  '/config/userctrl/C': 'YE',
  '/config/userctrl/C/enc': '"U2" "U1" "-" "U0"',
  '/config/userctrl/C/btn': '"U11" "U10" "P0036" "U09" "U00" "U06" "U02" "U05"',
  '/config/tape': '0.0 0.0 ON',
  '/config/amixenable': 'ON ON',
  '/config/dp48/assign': List.filled(48, '0').join(' '),
  '/config/dp48/grpname': List.filled(12, '""').join(' '),
  '/config/dp48': '%0000 0 AESA',
};

/// Nome a due cifre (utilità condivisa).
String two(int n) => _two(n);
