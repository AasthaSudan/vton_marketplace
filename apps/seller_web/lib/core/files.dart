import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';

/// A file the seller chose.
class PickedFile {
  final String name;
  final Uint8List bytes;

  const PickedFile(this.name, this.bytes);

  String get contentType {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'csv' => 'text/csv',
      _ => 'image/jpeg',
    };
  }
}

typedef PickFile = Future<PickedFile?> Function(List<String> extensions);
typedef SaveText =
    void Function(String fileName, String content, {String mimeType});

/// Opens the browser's file chooser (replaced in tests).
final pickFileProvider = Provider<PickFile>((ref) => _pick);

/// Saves text as a download, e.g. a CSV statement (replaced in tests).
final saveTextProvider = Provider<SaveText>((ref) => saveTextFile);

Future<PickedFile?> _pick(List<String> extensions) async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
  );
  final file = files.firstOrNull;
  if (file == null) return null;
  return PickedFile(file.name, await file.xFile.readAsBytes());
}
