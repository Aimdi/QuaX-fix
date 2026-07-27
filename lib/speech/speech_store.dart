import 'package:flutter_triple/flutter_triple.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:quax/speech/tts_settings.dart';

/// What is being read aloud, if anything.
class SpeechPlayback {
  /// The title of what is being read, for the bar to name it.
  final String? title;

  final bool speaking;

  const SpeechPlayback({this.title, this.speaking = false});

  static const idle = SpeechPlayback();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeechPlayback && other.title == title && other.speaking == speaking;

  @override
  int get hashCode => Object.hash(title, speaking);
}

/// Reading aloud, owned by the app rather than by the screen that started it.
///
/// It used to live in the reader's [State], so closing the article stopped the
/// voice mid-sentence — which is not what "read this to me" means. Here it
/// outlives the screen: leave the article, go anywhere, and it keeps reading
/// until it finishes or you stop it.
///
/// Leaving the *app* is a different matter. Android keeps speaking while QuaX
/// is in the background, but there is no media notification behind this and no
/// foreground service, so the system is free to reclaim the process.
class SpeechStore extends Store<SpeechPlayback> {
  final FlutterTts _tts;

  /// Long text is spoken in pieces: the platform silently truncates a very long
  /// utterance. Held so [stop] can abandon what has not been said yet.
  List<String> _queue = const [];
  int _spoken = 0;

  /// Bumped every time a new reading starts, so a chunk loop belonging to the
  /// previous one stops rather than talking over its successor.
  int _generation = 0;

  SpeechStore({FlutterTts? tts}) : _tts = tts ?? FlutterTts(), super(SpeechPlayback.idle) {
    _tts.awaitSpeakCompletion(true);
    _tts.setCancelHandler(_finished);
    _tts.setErrorHandler((_) => _finished());
  }

  FlutterTts get tts => _tts;

  bool get isSpeaking => state.speaking;

  void _finished() {
    _queue = const [];
    _spoken = 0;
    update(SpeechPlayback.idle);
  }

  /// Reads [text] aloud, replacing whatever was being read.
  Future<void> speak({required String title, required String text, required TtsChoice choice}) async {
    await stop();

    final chunks = chunkForSpeech(text);
    if (chunks.isEmpty) {
      return;
    }

    await _applyVoice(choice);

    final generation = ++_generation;
    _queue = chunks;
    _spoken = 0;
    update(SpeechPlayback(title: title, speaking: true));

    for (final chunk in chunks) {
      if (generation != _generation) {
        return;
      }
      await _tts.speak(chunk);
      _spoken++;
    }

    if (generation == _generation) {
      _finished();
    }
  }

  Future<void> stop() async {
    _generation++;
    _queue = const [];
    _spoken = 0;
    if (state.speaking) {
      update(SpeechPlayback.idle);
    }
    await _tts.stop();
  }

  /// The reader's chosen engine and voice, falling back to the app's language
  /// when they have not chosen one — or when what they chose has gone.
  Future<void> _applyVoice(TtsChoice choice) async {
    if (await applyTtsChoice(_tts, choice) && choice.hasVoice) {
      return;
    }

    try {
      await _tts.setLanguage(_languageForCurrentLocale());
    } catch (_) {
      await _tts.setLanguage('en-US');
    }
    await _tts.setSpeechRate(choice.rate);
  }
}

/// The BCP 47 tag the platform wants for the language the app is in.
String _languageForCurrentLocale() {
  final locale = Intl.shortLocale(Intl.getCurrentLocale());

  return switch (locale) {
    'zh' => 'zh-CN',
    'nb' => 'nb-NO',
    'pt' => 'pt-BR',
    _ => locale.contains('_') ? locale.replaceAll('_', '-') : '$locale-${locale.toUpperCase()}',
  };
}

/// Splits text into utterances the platform will actually finish.
///
/// Sentence boundaries first, so a break never lands mid-word; a single
/// sentence longer than the limit is cut where it has to be.
List<String> chunkForSpeech(String text, {int maxChars = 3500}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return const [];
  }
  if (trimmed.length <= maxChars) {
    return [trimmed];
  }

  final chunks = <String>[];
  final buffer = StringBuffer();

  for (final sentence in trimmed.split(RegExp(r'(?<=[.!?。！？])\s+'))) {
    if (sentence.length > maxChars) {
      if (buffer.isNotEmpty) {
        chunks.add(buffer.toString());
        buffer.clear();
      }
      for (var i = 0; i < sentence.length; i += maxChars) {
        chunks.add(sentence.substring(i, (i + maxChars).clamp(0, sentence.length)));
      }
      continue;
    }

    if (buffer.length + sentence.length + 1 > maxChars) {
      chunks.add(buffer.toString());
      buffer.clear();
    }
    if (buffer.isNotEmpty) {
      buffer.write(' ');
    }
    buffer.write(sentence);
  }

  if (buffer.isNotEmpty) {
    chunks.add(buffer.toString());
  }

  return chunks;
}
