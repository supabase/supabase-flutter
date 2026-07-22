import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'sample_image.dart';
import 'storage_repository.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

final messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const StorageExampleApp());
}

SupabaseClient get supabase => Supabase.instance.client;

class StorageExampleApp extends StatelessWidget {
  const StorageExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Storage transformations',
      scaffoldMessengerKey: messengerKey,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const GalleryPage(),
    );
  }
}

/// Uploads generated images to a public bucket and shows them in a gallery.
/// Tapping an image opens the transformations view.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final _repository = StorageRepository(supabase);

  /// Seed colors cycled through for each uploaded image, so successive uploads
  /// look different.
  static const _palette = [
    Colors.indigo,
    Colors.teal,
    Colors.deepOrange,
    Colors.pink,
    Colors.green,
  ];

  List<StoredImage> _images = [];
  bool _loading = true;
  bool _mutating = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  /// Reloads the gallery. Leaves the previous list on screen while it runs so a
  /// refresh doesn't flash a spinner over the whole grid.
  Future<void> _load() async {
    try {
      final images = await _repository.listImages();
      if (mounted) setState(() => _images = images);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Generates a fresh PNG and uploads it, then reloads the gallery. Ignores the
  /// call while another upload is in flight so a double tap can't fire twice.
  Future<void> _upload() async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      final color = _palette[_images.length % _palette.length];
      final bytes = await generateSampleImagePng(color: color);
      final name = 'sample-${DateTime.now().microsecondsSinceEpoch}.png';
      await _repository.uploadImage(name: name, bytes: bytes);
      await _load();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _openDetail(StoredImage image) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ImageDetailPage(repository: _repository, image: image),
      ),
    );
    if (deleted ?? false) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Images')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mutating ? null : _upload,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Upload'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _images.isEmpty
          ? const Center(child: Text('No images yet. Upload one to start.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  final image = _images[index];
                  return _GalleryTile(
                    // A downscaled, cropped thumbnail keeps the grid light: the
                    // resize happens server-side, so the app never downloads the
                    // full-size image here.
                    url: _repository.imageUrl(
                      image.path,
                      transform: TransformPreset.thumbnail.options,
                    ),
                    onTap: () => _openDetail(image),
                  );
                },
              ),
            ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.url, required this.onTap});

  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    );
  }
}

/// Shows a single stored image rendered through every [TransformPreset], each
/// one a public URL built with different [TransformOptions].
class ImageDetailPage extends StatelessWidget {
  const ImageDetailPage({
    required this.repository,
    required this.image,
    super.key,
  });

  final StorageRepository repository;
  final StoredImage image;

  Future<void> _delete(BuildContext context) async {
    try {
      await repository.deleteImage(image.path);
      if (context.mounted) Navigator.of(context).pop(true);
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(image.path),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete',
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final preset in TransformPreset.values)
            _TransformCard(
              label: preset.label,
              url: repository.imageUrl(image.path, transform: preset.options),
            ),
        ],
      ),
    );
  }
}

class _TransformCard extends StatelessWidget {
  const _TransformCard({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Image.network(
              url,
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(24),
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showError(Object error) {
  final message = error is StorageException ? error.message : error.toString();
  messengerKey.currentState?.showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red),
  );
}
