import 'dart:async';
import 'dart:js_interop';

@JS('Blob')
extension type _HtmlBlob._(JSObject _) implements JSObject {
  external factory _HtmlBlob(JSArray<JSString> parts, _BlobOptions options);
}

extension type _BlobOptions._(JSObject _) implements JSObject {
  external factory _BlobOptions({String type});
}

extension type _DownloadAnchor._(JSObject _) implements JSObject {
  external set href(String value);
  external set download(String value);
  external void click();
}

@JS('URL.createObjectURL')
external String _createObjectURL(_HtmlBlob blob);
@JS('URL.revokeObjectURL')
external void _revokeObjectURL(String url);
@JS('document.createElement')
external _DownloadAnchor _createElement(String name);

/// The self-contained document can be opened and printed without a connection.
/// Downloading avoids popup blockers after asynchronous exposure persistence.
bool downloadKompassHtml(String html, String filename) {
  final blob = _HtmlBlob(
      [html.toJS].toJS, _BlobOptions(type: 'text/html;charset=utf-8'));
  final url = _createObjectURL(blob);
  _createElement('a')
    ..href = url
    ..download = filename
    ..click();
  Timer(const Duration(seconds: 30), () => _revokeObjectURL(url));
  return true;
}
