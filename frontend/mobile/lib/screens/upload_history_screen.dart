import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_queue_service.dart';

class UploadHistoryScreen extends ConsumerStatefulWidget {
  const UploadHistoryScreen({super.key});

  @override
  ConsumerState<UploadHistoryScreen> createState() =>
      _UploadHistoryScreenState();
}

class _UploadHistoryScreenState extends ConsumerState<UploadHistoryScreen> {
  Future<void> _refresh() async {
    await ref.read(offlineQueueProvider.notifier).processQueue();
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(offlineQueueProvider);
    final connectivity = ref.watch(connectivityProvider);

    final failedCount = queue.where((u) => u.status == UploadStatus.failed).length;
    final uploadingCount = queue.where((u) => u.status == UploadStatus.uploading).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload History'),
        actions: [
          connectivity.when(
            data: (isOnline) {
              if (!isOnline || queue.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: queue.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_done,
                    size: 64,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending uploads',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white60,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your uploads will appear here when queued',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white38,
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final item = queue[queue.length - 1 - index];
                final fileName = item.filePath.split('/').last;
                final isUploading = item.status == UploadStatus.uploading;
                final isFailed = item.status == UploadStatus.failed;

                return Card(
                  color: const Color(0xFF252536),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: File(item.filePath).existsSync()
                                ? Image.file(
                                    File(item.filePath),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xFF3A3A50),
                                      child: const Icon(Icons.broken_image,
                                          color: Colors.white38),
                                    ),
                                  )
                                : Container(
                                    color: const Color(0xFF3A3A50),
                                    child: const Icon(Icons.image_not_supported,
                                        color: Colors.white38),
                                  ),
                          ),
                        ),
                        title: Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isFailed
                                            ? const Color(0xFFCF6679)
                                            : isUploading
                                                ? const Color(0xFF5F75EE)
                                                : const Color(0xFFE5A53C))
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isFailed
                                        ? 'Failed'
                                        : isUploading
                                            ? 'Uploading...'
                                            : 'Queued',
                                    style: TextStyle(
                                      color: isFailed
                                          ? const Color(0xFFCF6679)
                                          : isUploading
                                              ? const Color(0xFF5F75EE)
                                              : const Color(0xFFE5A53C),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatTime(item.queuedAt),
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            if (isFailed && item.errorMessage != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.errorMessage!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFCF6679),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isFailed)
                              IconButton(
                                icon: const Icon(Icons.refresh,
                                    color: Color(0xFF5F75EE), size: 22),
                                tooltip: 'Retry',
                                onPressed: () {
                                  ref
                                      .read(offlineQueueProvider.notifier)
                                      .retryUpload(queue.length - 1 - index);
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.white38, size: 20),
                              tooltip: 'Remove',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Remove from Queue?'),
                                    content: Text(
                                        'Remove "$fileName" from the upload queue?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          ref
                                              .read(offlineQueueProvider.notifier)
                                              .removeFromQueue(
                                                  queue.length - 1 - index);
                                        },
                                        child: const Text('Remove',
                                            style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        isThreeLine: isFailed && item.errorMessage != null,
                      ),
                      if (isUploading)
                        const LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: Color(0xFF3A3A50),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF5F75EE)),
                        ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: queue.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1C1C28),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${queue.length} item${queue.length == 1 ? '' : 's'} in queue',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          if (failedCount > 0 || uploadingCount > 0)
                            Text(
                              '${failedCount > 0 ? '$failedCount failed' : ''}${failedCount > 0 && uploadingCount > 0 ? ', ' : ''}${uploadingCount > 0 ? '$uploadingCount uploading' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: failedCount > 0
                                    ? const Color(0xFFCF6679)
                                    : const Color(0xFF5F75EE),
                              ),
                            ),
                        ],
                      ),
                    ),
                    connectivity.when(
                      data: (isOnline) {
                        if (!isOnline) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5A53C).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.wifi_off,
                                    size: 14, color: Color(0xFFE5A53C)),
                                SizedBox(width: 6),
                                Text(
                                  'Offline',
                                  style: TextStyle(
                                      color: Color(0xFFE5A53C), fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }
                        if (failedCount > 0 || queue.isNotEmpty) {
                          return ElevatedButton(
                            onPressed: _refresh,
                            child: const Text('Retry All'),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}