import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/src/auth_async_resumable_upload_storage.dart';

import 'widget_test_stubs.dart';

void main() {
  test('reads, writes and removes through the auth storage', () async {
    final authStorage = MockAsyncStorage();
    final storage = AuthAsyncResumableUploadStorage(authStorage);

    await storage.setItem('upload', 'record');
    expect(await authStorage.getItem('upload'), 'record');
    expect(await storage.getItem('upload'), 'record');

    await storage.removeItem('upload');
    expect(await authStorage.getItem('upload'), isNull);
  });
}
