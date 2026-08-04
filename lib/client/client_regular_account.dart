import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:xta/client/headers.dart';
import 'package:xta/client/http_client.dart';
import 'dart:async';
import 'package:xta/database/repository.dart';

class XRegularAccount extends ChangeNotifier {
  static final log = Logger('XRegularAccount');

  XRegularAccount() : super();

  Future<http.Response> fetch(
    Uri uri, {
    Map<String, String>? headers,
    required Logger log,
    required Map<dynamic, dynamic> authHeader,
  }) async {
    log.info('Fetching $uri');

    final baseHeaders = await TwitterHeaders.getHeaders(uri, authHeader);

    var response = await xHttpClient.get(uri, headers: {...?headers, ...baseHeaders});

    return response;
  }

  Future<void> deleteAccount(String username) async {
    var database = await Repository.writable();
    database.delete(tableAccounts, where: 'id = ?', whereArgs: [username]);
  }
}
