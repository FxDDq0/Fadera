/// Schema dei nodi X32/M32: per ogni percorso di nodo, l'elenco ordinato dei campi.
///
/// Fonti: doc 18 (routing), doc 19 (channel strip), Appendice D, Appendice C (FX),
/// formati delle righe confermati sulle 2127 righe reali di una X32P FW 4.15 (T01b).
/// I nodi senza schema documentato restano "opachi": il testo viene conservato
/// intatto (sync senza perdita di informazioni) ma non diventa un parametro.
library;

import '../fx/fx_types.dart';
import '../generated/fx_tables.g.dart';
import 'param.dart';

const kOffOn = ['OFF', 'ON'];
const kColors = ['OFF', 'RD', 'GN', 'YE', 'BL', 'MG', 'CY', 'WH', 'OFFi', 'RDi', 'GNi', 'YEi', 'BLi', 'MGi', 'CYi', 'WHi'];
const kRatios = ['1.1', '1.3', '1.5', '2.0', '2.5', '3.0', '4.0', '5.0', '7.0', '10', '20', '100'];
const kEqTypes6 = ['LCut', 'LShv', 'PEQ', 'VEQ', 'HShv', 'HCut'];
const kEqTypes14 = ['LCut', 'LShv', 'PEQ', 'VEQ', 'HShv', 'HCut', 'BU6', 'BU12', 'BS12', 'LR12', 'BU18', 'BU24', 'BS24', 'LR24'];
const kFilterTypes = ['LC6', 'LC12', 'HC6', 'HC12', '1.0', '2.0', '3.0', '5.0', '10.0'];
const kInsertSel = [
  'OFF', 'FX1L', 'FX1R', 'FX2L', 'FX2R', 'FX3L', 'FX3R', 'FX4L', 'FX4R', 'FX5L', 'FX5R', 'FX6L', 'FX6R', //
  'FX7L', 'FX7R', 'FX8L', 'FX8R', 'AUX1', 'AUX2', 'AUX3', 'AUX4', 'AUX5', 'AUX6'
];
const kSendTap6 = ['IN/LC', '<-EQ', 'EQ->', 'PRE', 'POST', 'GRP'];
const kSendTap5 = ['IN/LC', '<-EQ', 'EQ->', 'PRE', 'POST'];
const kOutPos = ['IN/LC', 'IN/LC+M', '<-EQ', '<-EQ+M', 'EQ->', 'EQ->+M', 'PRE', 'PRE+M', 'POST'];
const kFxSource = [
  'INS', 'MIX1', 'MIX2', 'MIX3', 'MIX4', 'MIX5', 'MIX6', 'MIX7', 'MIX8', 'MIX9', 'MIX10', 'MIX11', 'MIX12', //
  'MIX13', 'MIX14', 'MIX15', 'MIX16', 'M/C'
];
const kRoutingIn = [
  'AN1-8', 'AN9-16', 'AN17-24', 'AN25-32', 'A1-8', 'A9-16', 'A17-24', 'A25-32', 'A33-40', 'A41-48', 'B1-8', //
  'B9-16', 'B17-24', 'B25-32', 'B33-40', 'B41-48', 'CARD1-8', 'CARD9-16', 'CARD17-24', 'CARD25-32', 'UIN1-8', //
  'UIN9-16', 'UIN17-24', 'UIN25-32'
];
const kRoutingAux = [
  'AUX1-4', 'AN1-2', 'AN1-4', 'AN1-6', 'A1-2', 'A1-4', 'A1-6', 'B1-2', 'B1-4', 'B1-6', 'CARD1-2', 'CARD1-4', //
  'CARD1-6', 'UIN1-2', 'UIN1-4', 'UIN1-6'
];
const kRoutingAes = [
  ...kRoutingIn12, 'OUT1-8', 'OUT9-16', 'P161-8', 'P169-16', 'AUX/CR', 'AUX/TB', 'UOUT1-8', 'UOUT9-16', //
  'UOUT17-24', 'UOUT25-32', 'UOUT33-40', 'UOUT41-48', 'UIN1-8', 'UIN9-16', 'UIN17-24', 'UIN25-32'
];
const kRoutingIn12 = [
  'AN1-8', 'AN9-16', 'AN17-24', 'AN25-32', 'A1-8', 'A9-16', 'A17-24', 'A25-32', 'A33-40', 'A41-48', 'B1-8', //
  'B9-16', 'B17-24', 'B25-32', 'B33-40', 'B41-48', 'CARD1-8', 'CARD9-16', 'CARD17-24', 'CARD25-32'
];
const kRoutingOutA = [
  'AN1-4', 'AN9-12', 'AN17-20', 'AN25-28', 'A1-4', 'A9-12', 'A17-20', 'A25-28', 'A33-36', 'A41-44', 'B1-4', //
  'B9-12', 'B17-20', 'B25-28', 'B33-36', 'B41-44', 'CARD1-4', 'CARD9-12', 'CARD17-20', 'CARD25-28', 'OUT1-4', //
  'OUT9-12', 'P161-4', 'P169-12', 'AUX/CR', 'AUX/TB', 'UOUT1-4', 'UOUT9-12', 'UOUT17-20', 'UOUT25-28', //
  'UOUT33-36', 'UOUT41-44', 'UIN1-4', 'UIN9-12', 'UIN17-20', 'UIN25-28'
];
const kRoutingOutB = [
  'AN5-8', 'AN13-16', 'AN21-24', 'AN29-32', 'A5-8', 'A13-16', 'A21-24', 'A29-32', 'A37-40', 'A45-48', 'B5-8', //
  'B13-16', 'B21-24', 'B29-32', 'B37-40', 'B45-48', 'CARD5-8', 'CARD13-16', 'CARD21-24', 'CARD29-32', 'OUT5-8', //
  'OUT13-16', 'P165-8', 'P1613-16', 'AUX/CR', 'AUX/TB', 'UOUT5-8', 'UOUT13-16', 'UOUT21-24', 'UOUT29-32', //
  'UOUT37-40', 'UOUT45-48', 'UIN5-8', 'UIN13-16', 'UIN21-24', 'UIN29-32'
];
const kIqSpeaker = ['none', 'iQ8', 'iQ10', 'iQ12', 'iQ15', 'iQ15B', 'iQ18B'];
const kIqEq = ['Linear', 'Live', 'Speech', 'Playback', 'User'];

/// Sorgenti delle uscite `src` (77 valori, doc 18 par. 3.1).
final kOutputSources = <String>[
  'OFF', 'Main L', 'Main R', 'Main M/C', //
  for (var i = 1; i <= 16; i++) 'MixBus ${i.toString().padLeft(2, '0')}',
  for (var i = 1; i <= 6; i++) 'Matrix $i',
  for (var i = 1; i <= 32; i++) 'DirOut Ch ${i.toString().padLeft(2, '0')}',
  for (var i = 1; i <= 8; i++) 'DirOut Aux $i',
  'DirOut Fx 1L', 'DirOut Fx 1R', 'DirOut Fx 2L', 'DirOut Fx 2R', 'DirOut Fx 3L', 'DirOut Fx 3R', 'DirOut Fx 4L', 'DirOut Fx 4R',
  'Monitor L', 'Monitor R', 'Talkback'
];

/// Tipo di strip (doc 19 par. 0).
enum StripKind { ch, auxin, fxrtn, bus, mtx, mainSt, mainM, dca }

class StripRef {
  const StripRef(this.kind, this.number);
  final StripKind kind;

  /// Numero 1-based (per main st/m vale 1).
  final int number;

  static const prefixes = {
    StripKind.ch: 'ch',
    StripKind.auxin: 'auxin',
    StripKind.fxrtn: 'fxrtn',
    StripKind.bus: 'bus',
    StripKind.mtx: 'mtx',
    StripKind.mainSt: 'main/st',
    StripKind.mainM: 'main/m',
    StripKind.dca: 'dca',
  };

  /// Percorso base, ad esempio `/ch/01`, `/main/st`, `/dca/3`.
  String get base => switch (kind) {
        StripKind.mainSt => '/main/st',
        StripKind.mainM => '/main/m',
        StripKind.dca => '/dca/$number',
        _ => '/${prefixes[kind]}/${number.toString().padLeft(2, '0')}',
      };

  /// Indice globale 0–79 (doc 19 par. 0).
  int get globalIndex => switch (kind) {
        StripKind.ch => number - 1,
        StripKind.auxin => 31 + number,
        StripKind.fxrtn => 39 + number,
        StripKind.bus => 47 + number,
        StripKind.mtx => 63 + number,
        StripKind.mainSt => 70,
        StripKind.mainM => 71,
        StripKind.dca => 71 + number,
      };

  /// Numero di `/-stat/solosw/NN` (indice globale + 1; verificato in T03 per il ch 31).
  int get soloIndex => globalIndex + 1;

  int get eqBands => switch (kind) {
        StripKind.ch || StripKind.auxin || StripKind.fxrtn => 4,
        StripKind.dca => 0,
        _ => 6,
      };

  int get sendCount => switch (kind) {
        StripKind.ch || StripKind.auxin || StripKind.fxrtn => 16,
        StripKind.bus || StripKind.mainSt || StripKind.mainM => 6,
        _ => 0,
      };

  bool get hasDelay => kind == StripKind.ch;
  bool get hasGate => kind == StripKind.ch;
  bool get hasHpf => kind == StripKind.ch;
  bool get hasTrim => kind == StripKind.ch || kind == StripKind.auxin;
  bool get hasInvert => kind == StripKind.ch || kind == StripKind.auxin || kind == StripKind.mtx;
  bool get hasDyn => kind == StripKind.ch || kind.index >= StripKind.bus.index && kind != StripKind.dca;
  bool get hasInsert => hasDyn;
  bool get hasSource => kind == StripKind.ch || kind == StripKind.auxin;
  bool get hasPanAndAssign => kind.index <= StripKind.bus.index;
  bool get hasBalance => kind == StripKind.mainSt;
  bool get hasGroups => kind != StripKind.dca;
  bool get hasAutomix => kind == StripKind.ch;

  /// Strip stereo (FX return e coppie linkate a parte): solo i FX return sono stereo per costruzione.
  bool get isStereo => kind == StripKind.mainSt;

  String get label => switch (kind) {
        StripKind.ch => 'Ch ${number.toString().padLeft(2, '0')}',
        StripKind.auxin => 'Aux ${number}',
        StripKind.fxrtn => 'FX Rtn ${number}',
        StripKind.bus => 'Bus ${number.toString().padLeft(2, '0')}',
        StripKind.mtx => 'Mtx ${number}',
        StripKind.mainSt => 'Main LR',
        StripKind.mainM => 'Mono/C',
        StripKind.dca => 'DCA ${number}',
      };

  @override
  bool operator ==(Object other) => other is StripRef && other.kind == kind && other.number == number;
  @override
  int get hashCode => Object.hash(kind, number);
  @override
  String toString() => base;
}

/// Specifica di un nodo: percorso e campi nell'ordine della riga di testo.
class NodeSpec {
  const NodeSpec(this.path, this.fields, {this.opaque = false, this.dynamicFx});
  final String path;
  final List<ParamSpec> fields;

  /// Nodo senza schema documentato: il testo viene conservato così com'è.
  final bool opaque;

  /// Per `/fx/N/par`: numero dello slot; i campi dipendono dal tipo corrente.
  final int? dynamicFx;

  String leaf(ParamSpec f) => '$path/${f.name}';
}

// ------------------------------------------------------------- costruttori

ParamSpec _onOff(String name) => ParamSpec.enumeration(name, kOffOn);

List<ParamSpec> _config(bool source) => [
      const ParamSpec.string('name', 12),
      // Range documentato 1…74 (doc 19 [A]); accettato 0…255 in lettura per conservare un
      // identificativo sconosciuto senza sostituirlo con un'altra icona (l'app lo mostra come tale).
      const ParamSpec.integer('icon', 0, 255),
      const ParamSpec.enumeration('color', kColors),
      if (source) const ParamSpec.integer('source', 0, 64),
    ];

const _hold = ParamSpec.logf('hold', 0.02, 2000, 100, '%4.2f', unit: 'ms');
const _release = ParamSpec.logf('release', 5, 4000, 100, '%4.0f', unit: 'ms');
const _attack = ParamSpec.linf('attack', 0, 120, 120, '%.0f', unit: 'ms');

final _gate = <ParamSpec>[
  _onOff('on'),
  const ParamSpec.enumeration('mode', ['EXP2', 'EXP3', 'EXP4', 'GATE', 'DUCK']),
  const ParamSpec.linf('thr', -80, 0, 160, '%.1f', unit: 'dB'),
  const ParamSpec.linf('range', 3, 60, 57, '%.1f', unit: 'dB'),
  _attack,
  _hold,
  _release,
  const ParamSpec.integer('keysrc', 0, 64),
];

List<ParamSpec> _dyn(bool keysrc) => [
      _onOff('on'),
      const ParamSpec.enumeration('mode', ['COMP', 'EXP']),
      const ParamSpec.enumeration('det', ['PEAK', 'RMS']),
      const ParamSpec.enumeration('env', ['LIN', 'LOG']),
      const ParamSpec.linf('thr', -60, 0, 120, '%.1f', unit: 'dB'),
      const ParamSpec.enumeration('ratio', kRatios),
      const ParamSpec.linf('knee', 0, 5, 5, '%1f'),
      const ParamSpec.linf('mgain', 0, 24, 48, '%4.2f', unit: 'dB'),
      _attack,
      _hold,
      _release,
      const ParamSpec.enumeration('pos', ['PRE', 'POST']),
      if (keysrc) const ParamSpec.integer('keysrc', 0, 64),
      const ParamSpec.linf('mix', 0, 100, 20, '%.0f', unit: '%'),
      _onOff('auto'),
    ];

final _filter = <ParamSpec>[
  _onOff('on'),
  const ParamSpec.enumeration('type', kFilterTypes),
  const ParamSpec.logf('f', 20, 20000, 200, '%k1f', unit: 'Hz'),
];

List<ParamSpec> _eqBand(bool crossover) => [
      ParamSpec.enumeration('type', crossover ? kEqTypes14 : kEqTypes6),
      const ParamSpec.logf('f', 20, 20000, 200, '%k1f', unit: 'Hz'),
      const ParamSpec.linf('g', -15, 15, 120, '%+5.2f', unit: 'dB'),
      const ParamSpec.logf('q', 10, 0.3, 71, '%3.1f'),
    ];

const _fader = ParamSpec.level('fader', 1023);
const _pan = ParamSpec.linf('pan', -100, 100, 100, '%+.0f');

final _grp = <ParamSpec>[
  const ParamSpec.integer('dca', 0, 255, format: '%%%08b'),
  const ParamSpec.integer('mute', 0, 63, format: '%%%06b'),
];

List<ParamSpec> _outputs() => [
      const ParamSpec.integer('src', 0, 76),
      const ParamSpec.enumeration('pos', kOutPos),
      _onOff('invert'),
    ];

const _delayTime = ParamSpec.linf('time', 0.3, 500, 4997, '%5.1f', unit: 'ms');

/// Restituisce lo schema del nodo, oppure un nodo opaco se lo schema non è documentato.
NodeSpec nodeSpecFor(String path) => _cache.putIfAbsent(path, () => _build(path));

final Map<String, NodeSpec> _cache = {};

final _stripRe = RegExp(r'^/(ch|auxin|fxrtn|bus|mtx)/(\d\d)(/.*)?$');
final _mainRe = RegExp(r'^/main/(st|m)(/.*)?$');

NodeSpec _build(String path) {
  NodeSpec n(List<ParamSpec> f) => NodeSpec(path, f);
  final opaque = NodeSpec(path, const [], opaque: true);

  var m = _stripRe.firstMatch(path);
  StripRef? strip;
  String rest = '';
  if (m != null) {
    final kind = StripKind.values.byName(m.group(1)!);
    strip = StripRef(kind, int.parse(m.group(2)!));
    rest = m.group(3) ?? '';
  } else if ((m = _mainRe.firstMatch(path)) != null) {
    strip = StripRef(m!.group(1) == 'st' ? StripKind.mainSt : StripKind.mainM, 1);
    rest = m.group(2) ?? '';
  }
  if (strip != null) {
    final k = strip.kind;
    switch (rest) {
      case '/config':
        return n(_config(strip.hasSource));
      case '/delay' when strip.hasDelay:
        return n([_onOff('on'), _delayTime]);
      case '/preamp':
        if (k == StripKind.ch) {
          return n([
            const ParamSpec.linf('trim', -18, 18, 144, '%+.1f', unit: 'dB'),
            _onOff('invert'),
            _onOff('hpon'),
            const ParamSpec.enumeration('hpslope', ['12', '18', '24']),
            const ParamSpec.logf('hpf', 20, 400, 100, '%3f', unit: 'Hz'),
          ]);
        }
        if (k == StripKind.auxin) return n([const ParamSpec.linf('trim', -18, 18, 144, '%+.1f', unit: 'dB'), _onOff('invert')]);
        if (k == StripKind.mtx) return n([_onOff('invert')]);
        return opaque;
      case '/gate' when strip.hasGate:
        return n(_gate);
      case '/gate/filter' when strip.hasGate:
        return n(_filter);
      case '/dyn' when strip.hasDyn:
        return n(_dyn(k == StripKind.ch || k == StripKind.bus));
      case '/dyn/filter' when strip.hasDyn:
        return n(_filter);
      case '/insert' when strip.hasInsert:
        return n([_onOff('on'), const ParamSpec.enumeration('pos', ['PRE', 'POST']), const ParamSpec.enumeration('sel', kInsertSel)]);
      case '/eq':
        return n([_onOff('on')]);
      case '/mix':
        if (strip.hasPanAndAssign) {
          return n([_onOff('on'), _fader, _onOff('st'), _pan, _onOff('mono'), const ParamSpec.level('mlevel', 160)]);
        }
        if (k == StripKind.mainSt) return n([_onOff('on'), _fader, _pan]);
        return n([_onOff('on'), _fader]);
      case '/grp' when strip.hasGroups:
        return n(_grp);
      case '/automix' when strip.hasAutomix:
        return n([
          ParamSpec.enumeration('group', strip.number <= 8 ? const ['OFF', 'X', 'Y'] : const ['OFF']),
          const ParamSpec.linf('weight', -12, 12, 48, '%+5.1f', unit: 'dB'),
        ]);
    }
    final eq = RegExp(r'^/eq/(\d)$').firstMatch(rest);
    if (eq != null) {
      final band = int.parse(eq.group(1)!);
      if (band < 1 || band > strip.eqBands) return opaque;
      final xover = (k == StripKind.mtx || k == StripKind.mainSt || k == StripKind.mainM) && (band == 1 || band == 6);
      return n(_eqBand(xover));
    }
    final send = RegExp(r'^/mix/(\d\d)$').firstMatch(rest);
    if (send != null) {
      final s = int.parse(send.group(1)!);
      if (s < 1 || s > strip.sendCount) return opaque;
      final level = const ParamSpec.level('level', 160);
      if (s.isEven) return n([_onOff('on'), level]);
      final tap = k.index <= StripKind.fxrtn.index ? kSendTap6 : kSendTap5;
      return n([_onOff('on'), level, _pan, ParamSpec.enumeration('type', tap), const ParamSpec.integer('panFollow', 0, 1)]);
    }
    return opaque;
  }

  m = RegExp(r'^/dca/([1-8])(/config)?$').firstMatch(path);
  if (m != null) {
    return m.group(2) == null ? n([_onOff('on'), _fader]) : n(_config(false));
  }
  m = RegExp(r'^/headamp/(\d{3})$').firstMatch(path);
  if (m != null && int.parse(m.group(1)!) < 128) {
    return n([const ParamSpec.linf('gain', -12, 60, 144, '%+.1f', unit: 'dB'), _onOff('phantom')]);
  }
  m = RegExp(r'^/fx/([1-8])(/source|/par)?$').firstMatch(path);
  if (m != null) {
    final slot = int.parse(m.group(1)!);
    switch (m.group(2)) {
      case null:
        return n([ParamSpec.enumeration('type', slot <= 4 ? kFxOrderSlots1to4 : kFxOrderSlots5to8)]);
      case '/source':
        return slot <= 4
            ? n([const ParamSpec.enumeration('l', kFxSource), const ParamSpec.enumeration('r', kFxSource)])
            : opaque;
      case '/par':
        return NodeSpec(path, const [], dynamicFx: slot);
    }
  }
  m = RegExp(r'^/outputs/(main|aux|p16|aes|rec)/(\d\d)(/delay|/iQ)?$').firstMatch(path);
  if (m != null) {
    final g = m.group(1)!;
    final sub = m.group(3);
    if (sub == '/delay') return g == 'main' ? n([_onOff('on'), _delayTime]) : opaque;
    if (sub == '/iQ') {
      return g == 'p16'
          ? n([
              const ParamSpec.enumeration('group', ['OFF', 'A', 'B']),
              const ParamSpec.enumeration('speaker', kIqSpeaker),
              const ParamSpec.enumeration('eq', kIqEq),
              const ParamSpec.integer('model', 0, 7),
            ])
          : opaque;
    }
    // /outputs/rec ha 2 campi sul firmware 4.15 (riga reale "/outputs/rec/01 1 <-EQ").
    if (g == 'rec') return n(_outputs().sublist(0, 2));
    return n(_outputs());
  }
  switch (path) {
    case '/config/routing':
      return n([const ParamSpec.enumeration('routswitch', ['REC', 'PLAY'])]);
    case '/config/routing/IN':
    case '/config/routing/PLAY':
      return n([
        for (final f in ['1-8', '9-16', '17-24', '25-32']) ParamSpec.enumeration(f, kRoutingIn),
        const ParamSpec.enumeration('AUX', kRoutingAux),
      ]);
    case '/config/routing/AES50A':
    case '/config/routing/AES50B':
      return n([for (final f in ['1-8', '9-16', '17-24', '25-32', '33-40', '41-48']) ParamSpec.enumeration(f, kRoutingAes)]);
    case '/config/routing/CARD':
      return n([for (final f in ['1-8', '9-16', '17-24', '25-32']) ParamSpec.enumeration(f, kRoutingAes)]);
    case '/config/routing/OUT':
      return n([
        const ParamSpec.enumeration('1-4', kRoutingOutA),
        const ParamSpec.enumeration('5-8', kRoutingOutB),
        const ParamSpec.enumeration('9-12', kRoutingOutA),
        const ParamSpec.enumeration('13-16', kRoutingOutB),
      ]);
    case '/config/userrout/in':
      return n([for (var i = 1; i <= 32; i++) ParamSpec.integer(i.toString().padLeft(2, '0'), 0, 168, confidence: Confidence.unverified)]);
    case '/config/userrout/out':
      return n([for (var i = 1; i <= 48; i++) ParamSpec.integer(i.toString().padLeft(2, '0'), 0, 209, confidence: Confidence.unverified)]);
  }
  return opaque;
}

/// Campi di `/fx/N/par` per il tipo indicato: 64 posizioni, quelle oltre il numero
/// di parametri del tipo sono opache (il mixer le trasmette come `0`).
List<ParamSpec> fxParFields(String typeCode) {
  final t = kFxTypes[typeCode];
  final byIndex = {for (final p in t?.params ?? const <FxParamDef>[]) p.index: p};
  return [
    for (var i = 1; i <= 64; i++) byIndex[i]?.toSpec() ?? ParamSpec.opaque(i.toString().padLeft(2, '0')),
  ];
}
