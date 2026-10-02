import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Saves [content] as a file download in the browser.
void saveTextFile(
  String fileName,
  String content, {
  String mimeType = 'text/csv',
}) {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: '$mimeType;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
