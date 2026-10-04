import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'model.dart';

enum _TrackState { idle, starting, playing, paused }

/// Plays one sound embedded in an animation.
///
/// The controller tells the track what it wants ([play], [pause], [stop]);
/// the track turns that into audio-plugin calls and absorbs every failure,
/// so a broken sound or a missing audio plugin never interrupts the
/// animation itself.
class SVGAAudioTrack {
  SVGAAudioTrack(this.entity, this._data);

  final AudioEntity entity;
  final Uint8List _data;

  // One playable source per distinct sound, shared by every track and
  // controller that plays it.
  static final Expando<Future<Source>> _sources = Expando('svga-audio-source');

  AudioPlayer? _player;
  _TrackState _state = _TrackState.idle;
  double _volume = 1.0;
  bool _disposed = false;
  bool _failed = false;

  // Bumped whenever a pending start is no longer wanted.
  int _generation = 0;

  /// Whether the sound should be audible on [frame].
  bool covers(int frame) {
    if (frame < entity.startFrame) return false;
    return entity.endFrame <= entity.startFrame || frame < entity.endFrame;
  }

  /// Writes the sound where the audio plugin can read it, ahead of the
  /// first [play], so playback does not hitch mid-animation.
  void prepare() {
    if (_disposed || _failed) return;
    _source().then<void>((_) {}, onError: (_) {});
  }

  void play() {
    if (_disposed || _failed) return;
    switch (_state) {
      case _TrackState.idle:
        _start();
      case _TrackState.paused:
        _state = _TrackState.playing;
        _run(_player?.resume());
      case _TrackState.starting || _TrackState.playing:
        break;
    }
  }

  void pause() {
    switch (_state) {
      case _TrackState.playing:
        _state = _TrackState.paused;
        _run(_player?.pause());
      case _TrackState.starting:
        _generation++;
        _state = _TrackState.idle;
      case _TrackState.idle || _TrackState.paused:
        break;
    }
  }

  void stop() {
    switch (_state) {
      case _TrackState.playing || _TrackState.paused:
        _state = _TrackState.idle;
        _run(_player?.stop());
      case _TrackState.starting:
        _generation++;
        _state = _TrackState.idle;
      case _TrackState.idle:
        break;
    }
  }

  void setVolume(double volume) {
    _volume = volume;
    if (!_disposed) _run(_player?.setVolume(volume));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _state = _TrackState.idle;
    _run(_player?.dispose());
    _player = null;
  }

  Future<void> _start() async {
    _state = _TrackState.starting;
    final generation = ++_generation;
    try {
      final source = await _source();
      if (generation != _generation) return;
      final player = _player ??= AudioPlayer();
      await player.setVolume(_volume);
      if (generation != _generation) return;
      await player.play(
        source,
        position: entity.startTime > 0
            ? Duration(milliseconds: entity.startTime)
            : null,
      );
      if (generation != _generation) {
        // Stopped, paused or disposed while the plugin was starting up.
        if (!_disposed) _run(player.stop());
        return;
      }
      _state = _TrackState.playing;
    } catch (error) {
      // No audio plugin, unsupported codec, unwritable storage: play the
      // animation silently rather than retrying on every frame.
      _failed = true;
      _state = _TrackState.idle;
      assert(() {
        debugPrint('SVGA: audio "${entity.audioKey}" disabled: $error');
        return true;
      }());
    }
  }

  Future<Source> _source() => _sources[_data] ??= _createSource(_data);

  static Future<Source> _createSource(Uint8List data) async {
    if (kIsWeb) {
      return UrlSource(
        Uri.dataFromBytes(data, mimeType: 'audio/mpeg').toString(),
      );
    }
    // Named by content, so two animations that reuse an audio key for
    // different sounds can never be handed each other's file.
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}/svga_audio',
    );
    await directory.create(recursive: true);
    final file = File('${directory.path}/${md5.convert(data)}.mp3');
    if (!await file.exists() || await file.length() != data.length) {
      final temp = File('${file.path}.${identityHashCode(data)}.tmp');
      await temp.writeAsBytes(data, flush: true);
      await temp.rename(file.path);
    }
    return DeviceFileSource(file.path);
  }

  static void _run(Future<void>? call) {
    call?.then<void>((_) {}, onError: (_) {});
  }
}
