import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'errors.dart';
import 'io/fetcher.dart';

/// Draws extra content on top of a sprite. Called once per painted frame
/// with the canvas already transformed into the sprite's coordinate space.
typedef SVGACustomDrawer = void Function(Canvas canvas, int frameIndex);

/// Runtime replacements for the layers of one decoded animation.
///
/// Layers are addressed by their image key, the name the designer gave the
/// layer when exporting the SVGA file.
class SVGADynamicEntity {
  final Map<String, bool> dynamicHidden = {};
  final Map<String, ui.Image> dynamicImages = {};
  final Map<String, TextPainter> dynamicText = {};
  final Map<String, SVGACustomDrawer> dynamicDrawer = {};

  /// Whether nothing has been replaced, so the painter can skip the lookups.
  bool get isEmpty =>
      dynamicHidden.isEmpty &&
      dynamicImages.isEmpty &&
      dynamicText.isEmpty &&
      dynamicDrawer.isEmpty;

  /// Hides or shows the layer named [forKey].
  void setHidden(bool value, String forKey) {
    dynamicHidden[forKey] = value;
  }

  /// Replaces the bitmap of the layer named [forKey]. The caller keeps
  /// ownership of [image] and is responsible for disposing it.
  void setImage(ui.Image image, String forKey) {
    dynamicImages[forKey] = image;
  }

  /// Downloads an image and uses it for the layer named [forKey].
  ///
  /// Throws an [SVGAException] if the download fails or the response is not
  /// an image Flutter can decode.
  Future<void> setImageWithUrl(
    String url,
    String forKey, {
    Duration? timeout,
  }) async {
    final bytes = await SVGAFetcher.fetch(url, timeout: timeout);
    try {
      dynamicImages[forKey] = await decodeImageFromList(bytes);
    } catch (error) {
      throw SVGAFormatException(
        'The response is not a decodable image',
        source: url,
        cause: error,
      );
    }
  }

  /// Draws [textPainter] centred on the layer named [forKey].
  void setText(TextPainter textPainter, String forKey) {
    textPainter.textDirection ??= TextDirection.ltr;
    textPainter.layout();
    dynamicText[forKey] = textPainter;
  }

  /// Runs [drawer] on top of the layer named [forKey] on every frame.
  void setDynamicDrawer(SVGACustomDrawer drawer, String forKey) {
    dynamicDrawer[forKey] = drawer;
  }

  /// Removes every replacement.
  void reset() {
    dynamicHidden.clear();
    dynamicImages.clear();
    dynamicText.clear();
    dynamicDrawer.clear();
  }
}
