import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/plugins/bpc/bpc_links.dart';
import 'package:quax/plugins/bpc/bpc_reader_screen.dart';
import 'package:quax/plugins/bpc/bpc_strategy.dart';
import 'package:quax/plugins/substack/substack_links.dart';
import 'package:quax/plugins/substack/substack_models.dart';
import 'package:quax/plugins/substack/substack_reader_screen.dart';
import 'package:quax/plugins/substack/substack_store.dart';

/// Opens [url] inside QuaX when an enabled plugin can read it, returning true
/// when it handled the link. Callers fall back to the browser on false.
///
/// Substack is tried first (specific post URLs). Bypass Paywalls Clean claims
/// known news domains next so a tweet's article link opens through the chosen
/// bypass strategy instead of the paywalled page.
Future<bool> openWithPlugins(BuildContext context, String url) async {
  if (await _openSubstack(context, url)) {
    return true;
  }
  if (await _openBpc(context, url)) {
    return true;
  }
  return false;
}

Future<bool> _openSubstack(BuildContext context, String url) async {
  final link = substackLinkFor(context, url);
  if (link == null) {
    return false;
  }

  final known = _knownPublications(context);
  final match = known.where((p) => Uri.tryParse(p.baseUrl)?.host == link.publicationBase.host).firstOrNull;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SubstackReaderScreen(
        post: substackPostStub(link, publicationName: match?.name),
      ),
    ),
  );
  return true;
}

Future<bool> _openBpc(BuildContext context, String url) async {
  final BasePrefService prefs;
  try {
    prefs = PrefService.of(context, listen: false);
  } catch (_) {
    return false;
  }

  if (prefs.get(optionPluginBpcEnabled) != true) {
    return false;
  }
  if (!isBpcSupportedUrl(url)) {
    return false;
  }

  final strategy = parseBpcStrategy(prefs.get(optionPluginBpcStrategy));
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BpcReaderScreen(articleUrl: url, strategy: strategy),
    ),
  );
  return true;
}

/// The Substack post [url] points at, or null when the plugin is off or the
/// link is not a readable post.
SubstackPostLink? substackLinkFor(BuildContext context, String url) {
  final BasePrefService prefs;
  try {
    prefs = PrefService.of(context, listen: false);
  } catch (_) {
    // No preferences in scope (isolated widget tests) — claim nothing.
    return null;
  }

  if (prefs.get(optionPluginSubstackEnabled) != true) {
    return null;
  }

  return parseSubstackPostLink(url, knownBaseUrls: _knownPublications(context).map((e) => e.baseUrl));
}

List<SubstackPublication> _knownPublications(BuildContext context) {
  try {
    return context.read<SubstackPublicationsStore>().state;
  } catch (_) {
    return const [];
  }
}
