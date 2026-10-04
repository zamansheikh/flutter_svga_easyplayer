/// Base type for every failure this package reports.
///
/// Catch [SVGAException] to handle any load failure, or one of the subtypes
/// to react to a specific cause:
///
/// ```dart
/// try {
///   final movie = await SVGAParser.shared.decodeFromURL(url);
/// } on SVGANetworkException catch (e) {
///   // e.statusCode is the HTTP status, or null if the request never landed.
/// } on SVGAFormatException {
///   // The server answered, but not with an SVGA file.
/// }
/// ```
sealed class SVGAException implements Exception {
  const SVGAException(this.message, {this.source, this.cause});

  /// What went wrong, in plain words.
  final String message;

  /// The URL or asset path being loaded, when known.
  final String? source;

  /// The lower-level error that triggered this one, when there is one.
  final Object? cause;

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (source != null) buffer.write(' (source: $source)');
    if (cause != null) buffer.write(' — caused by: $cause');
    return buffer.toString();
  }
}

/// The request could not be completed, or the server answered with a
/// non-success status.
final class SVGANetworkException extends SVGAException {
  const SVGANetworkException(
    super.message, {
    this.statusCode,
    super.source,
    super.cause,
  });

  /// HTTP status code, or `null` when no response was received.
  final int? statusCode;
}

/// The request did not finish within the allowed time.
final class SVGATimeoutException extends SVGAException {
  const SVGATimeoutException(this.timeout, {super.source})
    : super('Request timed out');

  final Duration timeout;
}

/// The bytes are not a valid SVGA 2.x file: wrong container, truncated, or
/// corrupt.
final class SVGAFormatException extends SVGAException {
  const SVGAFormatException(super.message, {super.source, super.cause});

  /// The same failure, tagged with where the bytes came from.
  SVGAFormatException withSource(String source) =>
      SVGAFormatException(message, source: source, cause: cause);
}

/// A bundled asset could not be read.
final class SVGAAssetException extends SVGAException {
  const SVGAAssetException(super.message, {super.source, super.cause});
}
