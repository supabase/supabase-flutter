import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:storage_transforms_example/main.dart';
import 'package:storage_transforms_example/sample_image.dart';
import 'package:storage_transforms_example/storage_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

/// End-to-end tests that drive the Storage example against the local stack.
///
/// The first test exercises the whole flow through the repository (upload, list,
/// transformed download and delete), asserting on the returned bytes. The second
/// drives the app widgets to confirm the gallery, detail view and delete button
/// are wired to those calls.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late StorageRepository repository;

  setUpAll(() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
    repository = StorageRepository(Supabase.instance.client);
    // Start from an empty bucket so the gallery is deterministic.
    await _clearBucket(repository);
  });

  tearDownAll(() async {
    await Supabase.instance.dispose();
  });

  tearDown(() async {
    // Remove anything a test uploaded so it can run repeatedly.
    await _clearBucket(repository);
  });

  testWidgets('uploads, transforms, downloads and deletes through the '
      'repository', (tester) async {
    final name = 'e2e-${DateTime.now().microsecondsSinceEpoch}.png';
    final bytes = await generateSampleImagePng(color: Colors.teal, size: 640);

    // Upload returns the stored path, and the object then shows up in the list.
    final path = await repository.uploadImage(name: name, bytes: bytes);
    expect(path, contains(name));
    final images = await repository.listImages();
    expect(images.map((image) => image.path), contains(name));

    // A public URL with a transform points at the render endpoint and carries
    // the transform query parameters.
    final url = repository.imageUrl(
      name,
      transform: const TransformOptions(width: 100, height: 100),
    );
    expect(url, contains('/render/image/'));
    expect(url, contains('width=100'));

    // The original downloads at its full size.
    final original = await repository.downloadImage(name);
    expect(await _decodeSize(original), const Size(640, 640));

    // Downloading with a transform resizes the image server-side.
    final resized = await repository.downloadImage(
      name,
      transform: const TransformOptions(
        width: 100,
        height: 100,
        resize: ResizeMode.cover,
      ),
    );
    expect(await _decodeSize(resized), const Size(100, 100));

    // Delete removes it from the bucket.
    await repository.deleteImage(name);
    final remaining = await repository.listImages();
    expect(remaining.map((image) => image.path), isNot(contains(name)));
  });

  testWidgets('uploads and deletes an image through the UI', (tester) async {
    await tester.pumpWidget(const StorageExampleApp());

    // A freshly cleared bucket shows the empty state.
    await _pumpUntil(tester, find.text('No images yet. Upload one to start.'));

    // Uploading through the FAB adds a tile to the gallery.
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Upload'));
    await _pumpUntilGone(
      tester,
      find.text('No images yet. Upload one to start.'),
    );
    expect(find.byType(Card), findsWidgets);

    // Opening the tile shows the transformation variants by name.
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('120×120 cover'), findsOneWidget);

    // Deleting from the detail view returns to an empty gallery.
    await tester.tap(find.byIcon(Icons.delete));
    await _pumpUntil(tester, find.text('No images yet. Upload one to start.'));
  });
}

/// Removes every object currently in the bucket.
Future<void> _clearBucket(StorageRepository repository) async {
  final images = await repository.listImages();
  for (final image in images) {
    await repository.deleteImage(image.path);
  }
}

/// Decodes [bytes] far enough to read the image's pixel dimensions.
Future<Size> _decodeSize(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final size = Size(image.width.toDouble(), image.height.toDouble());
  image.dispose();
  codec.dispose();
  return size;
}

/// Pumps frames until [finder] matches at least one widget or [timeout] elapses.
///
/// Storage calls go over the network, so the UI can't be settled with
/// `pumpAndSettle`; this polls the widget tree instead.
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for: $finder');
}

/// The inverse of [_pumpUntil]: pumps until [finder] matches nothing.
Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Timed out waiting for it to disappear: $finder');
}
