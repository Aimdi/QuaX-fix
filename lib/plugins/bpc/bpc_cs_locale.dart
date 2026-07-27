import 'package:quax/plugins/bpc/bpc_links.dart';

/// Pick the BPC cs_local bundle for [articleUrl], mirroring background.js.
String bpcCsLocalAssetFor(String articleUrl) {
  final host = (bpcHostFor(articleUrl) ?? '').toLowerCase();
  final code = _localeCodeFor(host);
  return 'assets/bpc/cs_local/contentScript_$code.js';
}

String _localeCodeFor(String host) {
  if (host.startsWith('thelocal.')) return 'en';

  if (_endsWithAny(host, const ['.ar', '.br', '.cl', '.mx', '.pe', '.uy']) ||
      _isAny(host, _esPtNamed)) {
    return 'es.pt';
  }
  if ((_endsWithAny(host, const ['.de', '.at', '.ch']) && !_isAny(host, _notDe)) ||
      _isAny(host, _deNamed)) {
    return 'de';
  }
  if (_endsWithAny(host, const ['.dk', '.fi', '.se'])) return 'fi.se';
  if (_endsWithAny(host, const ['.es', '.pt', '.cat']) || _isAny(host, _esNamed)) {
    return 'es.pt';
  }
  if ((host.endsWith('.fr') && host != 'lemagit.fr') || _isAny(host, _frNamed)) {
    return 'fr';
  }
  if (host.endsWith('.it') || _isAny(host, _itNamed)) return 'it';
  if (_endsWithAny(host, const ['.nl', '.be']) || _isAny(host, _nlNamed)) {
    return 'nl';
  }
  if (host.endsWith('.pl') || _isAny(host, _plNamed)) return 'pl';
  return 'en';
}

bool _endsWithAny(String host, List<String> suffixes) =>
    suffixes.any(host.endsWith);

bool _isAny(String host, Set<String> domains) => domains.contains(host);

const _notDe = {'letemps.ch'};

const _deNamed = {
  'diepresse.com',
  'faz.net',
  'handelsblatt.com',
  'wochenblatt.com',
};

const _esPtNamed = {
  'abcmais.com',
  'clarin.com',
  'cronista.com',
  'elespectador.com',
  'elmercurio.com',
  'eltiempo.com',
  'eltribuno.com',
  'eluniverso.com',
  'exame.com',
  'globo.com',
  'lasegunda.com',
  'latercera.com',
  'milenio.com',
  'revistaoeste.com',
  'semana.com',
};

const _esNamed = {
  'diariocordoba.com',
  'diariovasco.com',
  'elconfidencial.com',
  'elcorreo.com',
  'elespanol.com',
  'elpais.com',
  'elperiodico.com',
  'elperiodicodearagon.com',
  'elperiodicoextremadura.com',
  'elperiodicomediterraneo.com',
  'emporda.info',
  'expansion.com',
  'larioja.com',
  'lavanguardia.com',
  'levante-emv.com',
  'marca.com',
  'mundodeportivo.com',
  'politicaexterior.com',
};

const _frNamed = {
  'aoc.media',
  'bienpublic.com',
  'connaissancedesarts.com',
  'courrierinternational.com',
  'jeuneafrique.com',
  'journaldunet.com',
  'la-croix.com',
  'lecho.be',
  'ledauphine.com',
  'legrandcontinent.eu',
  'lejsl.com',
  'lerevenu.com',
  'lesinrocks.com',
  'lesoir.be',
  'letemps.ch',
  'linforme.com',
  'loeildelaphotographie.com',
  'parismatch.com',
  'philomag.com',
  'philonomist.com',
  'pourleco.com',
  'reforme.net',
  'science-et-vie.com',
  'sudinfo.be',
  'valeursactuelles.com',
};

const _itNamed = {
  'eastwest.eu',
  'ilsole24ore.com',
  'italian.tech',
  'quotidiano.net',
  'tuttosport.com',
};

const _nlNamed = {
  'projectcargojournal.com',
  'railfreight.cn',
  'railfreight.com',
  'railtech.com',
};

const _plNamed = {
  'oko.press',
  'parkiet.com',
  'wyborcza.biz',
};
