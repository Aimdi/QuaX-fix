import 'package:flutter_test/flutter_test.dart';
import 'package:xta/utils/urls.dart';

void main() {
  test('cleanUrl strips tracking parameters', () {
    expect(cleanUrl('https://x.com/a/status/1?s=20&t=xyz'), 'https://x.com/a/status/1');
    expect(cleanUrl('https://example.com/p?utm_source=tw&utm_medium=social&id=7'), 'https://example.com/p?id=7');
    expect(cleanUrl('https://example.com/p?s=size-m'), 'https://example.com/p?s=size-m');
    expect(cleanUrl('https://example.com/plain'), 'https://example.com/plain');
    expect(cleanUrl('https://x.com/search?q=hello&s=1'), 'https://x.com/search?q=hello');
    expect(cleanUrl('https://shop.com/x?fbclid=abc#frag'), 'https://shop.com/x#frag');
    expect(cleanUrl('not a url at all'), 'not a url at all');
  });
}
