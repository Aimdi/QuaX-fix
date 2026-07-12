import 'dart:io';

import 'package:dart_twitter_api/twitter_api.dart' show Media;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/ui/errors.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:pref/pref.dart';

/// Downloads every photo of a saved post straight to the configured download
/// folder, for folders with auto-download enabled. Silent-by-design: it never
/// prompts, so it needs a fixed download folder; without one it just tells the
/// user where to set it. Context-free (takes a [messenger]) since the save
/// sheet that triggers it has already been dismissed.
Future<void> autoDownloadTweetPhotos({
  required Map<String, dynamic> content,
  required BasePrefService prefs,
  required ScaffoldMessengerState messenger,
  required String downloadingLabel,
  required String doneLabel,
  required String needFolderLabel,
}) async {
  String username;
  List<Media> photos;
  try {
    final tweet = TweetWithCard.fromJson(content);
    username = tweet.user?.screenName ?? 'quax';
    final media = tweet.extendedEntities?.media ?? tweet.entities?.media ?? const <Media>[];
    photos = media.where((m) => m.type == 'photo' && m.mediaUrlHttps != null).toList();
  } catch (_) {
    return;
  }
  if (photos.isEmpty) {
    return;
  }

  final downloadType = prefs.get(optionDownloadType);
  final downloadPath = prefs.get<String>(optionDownloadPath);
  if (downloadType == optionDownloadTypeAsk || downloadPath == null || downloadPath.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(needFolderLabel)));
    return;
  }

  messenger.showSnackBar(SnackBar(content: Text(downloadingLabel)));
  const platform = MethodChannel('browser_resolver');
  var saved = 0;
  for (final media in photos) {
    try {
      final response = await http.get(Uri.parse('${media.mediaUrlHttps}:orig'));
      if (response.statusCode != 200) {
        continue;
      }
      final fileName = '$username-${p.basename(media.mediaUrlHttps!)}'.split('?')[0];
      final savedFile = p.join(downloadPath, fileName);
      await File(savedFile).writeAsBytes(response.bodyBytes);
      try {
        await platform.invokeMethod('scanMediaFile', {'path': savedFile});
      } catch (_) {}
      saved++;
    } catch (_) {}
  }
  if (saved > 0) {
    messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.hide);
    messenger.showSnackBar(SnackBar(content: Text(doneLabel)));
  }
}

Future<void> downloadUriToPickedFile(BuildContext context, Uri uri, String fileName,
    {required BasePrefService prefs, required Function() onStart, required Function() onSuccess}) async {
  var sanitizedFilename = fileName.split("?")[0];

  try {
    onStart();
    var responseTask = downloadFile(context, uri);

    var response = await responseTask;
    if (response == null) {
      return;
    }

    final downloadType = prefs.get(optionDownloadType);
    final downloadPath = prefs.get(optionDownloadPath);

    // If the user wants to pick a file every time a download happens
    if (downloadType == optionDownloadTypeAsk || downloadPath == '') {
      var fileInfo =
          await FlutterFileDialog.saveFile(params: SaveFileDialogParams(fileName: sanitizedFilename, data: response));
      if (fileInfo == null) {
        return;
      }

      onSuccess();
      return;
    }

    // Finally, save to the user-defined directory
    var savedFile = p.join(downloadPath, sanitizedFilename);
    await File(savedFile).writeAsBytes(response);

    // Notify Android's media scanner so the file appears in the gallery
    const platform = MethodChannel('browser_resolver');
    try {
      await platform.invokeMethod('scanMediaFile', {'path': savedFile});
    } catch (_) {}

    onSuccess();
  } catch (e) {
    showSnackBar(context, icon: '🙊', message: e.toString());
  }
}

class UnableToSaveMedia {
  final Uri uri;
  final Object e;

  UnableToSaveMedia(this.uri, this.e);

  @override
  String toString() {
    return 'Unable to save the media {uri: $uri, e: $e}';
  }
}

Future downloadFile(BuildContext context, Uri uri) async {
  var response = await http.get(uri);
  if (response.statusCode == 200) {
    return response.bodyBytes;
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        L10n.of(context).unable_to_save_the_media_twitter_returned_a_status_of_response_statusCode(response.statusCode),
      ),
    ));
  }

  return null;
}
