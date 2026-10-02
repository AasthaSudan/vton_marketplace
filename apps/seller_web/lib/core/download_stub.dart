/// Downloads only exist in the browser build of the panel.
void saveTextFile(
  String fileName,
  String content, {
  String mimeType = 'text/csv',
}) => throw UnsupportedError('Downloads need the web build');
