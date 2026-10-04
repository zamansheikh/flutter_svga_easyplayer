import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../errors.dart';

/// Downloads files for the parser, the precache manager and dynamic images.
///
/// All requests share one HTTP client so connections are reused, and
/// concurrent requests for the same URL share a single download.
class SVGAFetcher {
  SVGAFetcher._();

  static http.Client? _client;
  static final Map<String, Future<Uint8List>> _inFlight = {};

  static http.Client get client => _client ??= http.Client();

  /// Replaces the HTTP client, for example to add authentication, a proxy
  /// or a mock in tests. Pass `null` to go back to the default client.
  static set client(http.Client? value) => _client = value;

  /// Downloads [url] and returns the response body.
  ///
  /// Throws [SVGANetworkException] for an unusable URL, a failed request or
  /// a non-2xx status, and [SVGATimeoutException] when [timeout] elapses.
  static Future<Uint8List> fetch(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) {
    final running = _inFlight[url];
    if (running != null) return running;
    final download = _download(url, headers, timeout);
    _inFlight[url] = download;
    // Drop the entry whether the download succeeded or failed; the listeners
    // already hold the future, so the error still reaches them.
    download.then<void>((_) {}, onError: (_) {}).whenComplete(() {
      if (identical(_inFlight[url], download)) _inFlight.remove(url);
    });
    return download;
  }

  static Future<Uint8List> _download(
    String url,
    Map<String, String>? headers,
    Duration? timeout,
  ) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw SVGANetworkException('Not a valid http(s) URL', source: url);
    }

    final http.Response response;
    try {
      final request = client.get(uri, headers: headers);
      response = await (timeout == null ? request : request.timeout(timeout));
    } on TimeoutException {
      throw SVGATimeoutException(timeout!, source: url);
    } catch (error) {
      throw SVGANetworkException(
        'The request failed',
        source: url,
        cause: error,
      );
    }

    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      throw SVGANetworkException(
        'The server answered with HTTP $status',
        statusCode: status,
        source: url,
      );
    }
    return response.bodyBytes;
  }
}
