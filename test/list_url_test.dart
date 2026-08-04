import 'package:flutter_test/flutter_test.dart';
import 'package:xta/utils/urls.dart';

void main() {
  test('extractListId accepts list URLs and bare ids', () {
    expect(extractListId('https://x.com/i/lists/1234567890123456789'), '1234567890123456789');
    expect(extractListId('https://twitter.com/i/lists/42/'), '42');
    expect(extractListId('  987654321  '), '987654321');
    expect(extractListId('https://x.com/SomeUser/lists'), isNull);
    expect(extractListId('https://x.com/i/lists/not-a-number'), isNull);
    expect(extractListId('hello'), isNull);
  });

  test('parseUri routes list links, profiles and posts correctly', () async {
    expect(await parseUri(Uri.parse('https://x.com/i/lists/123')), isA<ListUriInfo>());
    expect(await parseUri(Uri.parse('https://x.com/DogsTrust')), isA<ProfileUriInfo>());
    expect(await parseUri(Uri.parse('https://x.com/DogsTrust/lists')), isA<ProfileUriInfo>());
    expect(await parseUri(Uri.parse('https://x.com/DogsTrust/status/1')), isA<PostUriInfo>());
    // /i/… reserved paths must never parse as a profile named "i".
    expect(await parseUri(Uri.parse('https://x.com/i/topics/tweet/9')), isA<PostUriInfo>());
    expect(await parseUri(Uri.parse('https://x.com/i/flow/login')), isA<UnknownResult>());
  });
}
