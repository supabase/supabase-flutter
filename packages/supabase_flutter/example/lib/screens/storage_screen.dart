import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  final _bucketNameController = TextEditingController();
  List<FileObject> _files = [];
  List<Bucket> _buckets = [];
  String? _selectedBucket;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadBuckets();
  }

  @override
  void dispose() {
    _bucketNameController.dispose();
    super.dispose();
  }

  Future<void> _loadBuckets() async {
    setState(() => _loading = true);
    
    try {
      final buckets = await Supabase.instance.client.storage.listBuckets();
      setState(() {
        _buckets = buckets;
        if (_buckets.isNotEmpty && _selectedBucket == null) {
          _selectedBucket = _buckets.first.name;
          _loadFiles();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading buckets: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadFiles() async {
    if (_selectedBucket == null) return;
    
    setState(() => _loading = true);
    
    try {
      final files = await Supabase.instance.client.storage
          .from(_selectedBucket!)
          .list();
      setState(() => _files = files);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading files: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createBucket() async {
    if (_bucketNameController.text.isEmpty) return;
    
    setState(() => _loading = true);
    
    try {
      await Supabase.instance.client.storage
          .createBucket(_bucketNameController.text);
      
      _bucketNameController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bucket created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      await _loadBuckets();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating bucket: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _uploadDummyFile() async {
    if (_selectedBucket == null) return;
    
    setState(() => _loading = true);
    
    try {
      final fileName = 'dummy_${DateTime.now().millisecondsSinceEpoch}.txt';
      final fileContent = 'This is a dummy file created at ${DateTime.now()}';
      
      await Supabase.instance.client.storage
          .from(_selectedBucket!)
          .uploadBinary(
            fileName,
            Uint8List.fromList(fileContent.codeUnits),
          );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      await _loadFiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteFile(String fileName) async {
    if (_selectedBucket == null) return;
    
    try {
      await Supabase.instance.client.storage
          .from(_selectedBucket!)
          .remove([fileName]);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      await _loadFiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadFile(String fileName) async {
    if (_selectedBucket == null) return;
    
    try {
      final response = await Supabase.instance.client.storage
          .from(_selectedBucket!)
          .download(fileName);
      
      final content = String.fromCharCodes(response);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('File: $fileName'),
            content: SingleChildScrollView(
              child: Text(content),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Examples'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Storage Management',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Bucket',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _bucketNameController,
                            decoration: const InputDecoration(
                              labelText: 'Bucket Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.folder),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _loading ? null : _createBucket,
                          child: _loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Create'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Select Bucket',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _loading ? null : _loadBuckets,
                          icon: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    if (_buckets.isEmpty) ...[
                      const Text('No buckets found. Create one above.'),
                    ] else ...[
                      DropdownButtonFormField<String>(
                        initialValue: _selectedBucket,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: _buckets.map((bucket) {
                          return DropdownMenuItem(
                            value: bucket.name,
                            child: Text(bucket.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedBucket = value);
                          _loadFiles();
                        },
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _selectedBucket == null || _loading ? null : _uploadDummyFile,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Dummy File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedBucket != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Files in $_selectedBucket (${_files.length})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: _loading ? null : _loadFiles,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading && _files.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _files.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_off,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No files in this bucket',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Upload a dummy file to get started',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _files.length,
                            itemBuilder: (context, index) {
                              final file = _files[index];
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.insert_drive_file),
                                  title: Text(file.name),
                                  subtitle: Text(
                                    'Size: ${_formatFileSize(file.metadata?['size'])} • '
                                    'Modified: ${file.updatedAt ?? 'Unknown'}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.download, color: Colors.blue),
                                        onPressed: () => _downloadFile(file.name),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _showDeleteFileConfirmation(file.name),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatFileSize(dynamic size) {
    if (size == null) return 'Unknown';
    
    final bytes = size is int ? size : int.tryParse(size.toString()) ?? 0;
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  void _showDeleteFileConfirmation(String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFile(fileName);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}