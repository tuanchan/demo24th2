// save_flash_popup.dart
// =====================================================================
// SAVE FLASH POPUP – hiển thị khi app khởi động/resume và có file mới
// trong thư mục SaveFlash.
// KHÔNG đụng logic/UI cũ.
//
// Cách dùng:
//   await SaveFlashPopup.show(context,
//     flashLogic: saveFlashLogic,   // SaveFlashLogic instance
//     appLogic: appLogic,            // AppLogic instance từ logic.dart
//   );
// =====================================================================

import 'package:flutter/material.dart';

import 'logic.dart';            // AppLogic, TrackRow, PlaylistRow
import 'save_flash_logic.dart'; // SaveFlashLogic, SaveFlashFile

class SaveFlashPopup {
  /// Gọi sau khi SaveFlashLogic.scan() trả về true.
  static Future<void> show(
    BuildContext context, {
    required SaveFlashLogic flashLogic,
    required AppLogic appLogic,
  }) async {
    if (flashLogic.pendingFiles.isEmpty) return;
    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      shape: Theme.of(context).bottomSheetTheme.shape,
      builder: (_) => _SaveFlashSheet(
        flashLogic: flashLogic,
        appLogic: appLogic,
      ),
    );
  }
}

// ---------------------------------------------------------------
// Sheet widget
// ---------------------------------------------------------------
class _SaveFlashSheet extends StatefulWidget {
  final SaveFlashLogic flashLogic;
  final AppLogic appLogic;

  const _SaveFlashSheet({
    required this.flashLogic,
    required this.appLogic,
  });

  @override
  State<_SaveFlashSheet> createState() => _SaveFlashSheetState();
}

class _SaveFlashSheetState extends State<_SaveFlashSheet> {
  // file path -> playlist id được chọn (null = chỉ lưu library)
  final Map<String, String?> _chosenPlaylist = {};

  // file path -> đang xử lý
  final Set<String> _processing = {};

  // file path -> thông báo kết quả
  final Map<String, String> _resultMsg = {};

  @override
  void initState() {
    super.initState();
    // Mặc định chưa chọn playlist nào
    for (final f in widget.flashLogic.pendingFiles) {
      _chosenPlaylist[f.path] = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = widget.flashLogic.pendingFiles;
    final playlists =
        widget.appLogic.playlists.where((p) => !p.isSpecial).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle bar ──
              const SizedBox(height: 10),
              _handleBar(context),
              const SizedBox(height: 10),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.flash_on_rounded),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SaveFlash – ${files.length} file mới',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Chọn playlist rồi nhấn "Thêm" cho từng file, hoặc "Bỏ qua tất cả"',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => _dismissAll(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ── File list ──
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: files.length,
                  itemBuilder: (_, i) =>
                      _FileItem(
                    file: files[i],
                    playlists: playlists,
                    chosen: _chosenPlaylist[files[i].path],
                    isProcessing: _processing.contains(files[i].path),
                    resultMsg: _resultMsg[files[i].path],
                    onPlaylistChanged: (pid) => setState(
                        () => _chosenPlaylist[files[i].path] = pid),
                    onAdd: () => _addFile(context, files[i]),
                    onSkip: () => _skipFile(context, files[i]),
                  ),
                ),
              ),

              // ── Footer ──
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.skip_next_rounded),
                        label: const Text('Bỏ qua tất cả'),
                        onPressed: () => _dismissAll(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Thêm tất cả'),
                        onPressed: _processing.isNotEmpty
                            ? null
                            : () => _addAll(context, files),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Actions ──

  Future<void> _addFile(BuildContext context, SaveFlashFile f) async {
    if (_processing.contains(f.path)) return;
    setState(() => _processing.add(f.path));

    try {
      final result = await widget.appLogic
          .importSharedFiles([f.path]);

      String msg;
      if (result.importedTrackIds.isEmpty) {
        msg = 'Đã có trong thư viện';
      } else {
        msg = 'Đã thêm vào thư viện';
        final pid = _chosenPlaylist[f.path];
        if (pid != null && result.importedTrackIds.isNotEmpty) {
          await widget.appLogic
              .addManyToPlaylist(pid, result.importedTrackIds);
          final plName = widget.appLogic.playlists
              .firstWhere((p) => p.id == pid)
              .name;
          msg = 'Đã thêm vào "$plName"';
        }
      }

      await widget.flashLogic.markSeen([f.path]);
      if (mounted) setState(() => _resultMsg[f.path] = msg);
    } catch (e) {
      if (mounted) setState(() => _resultMsg[f.path] = 'Lỗi: $e');
    } finally {
      if (mounted) setState(() => _processing.remove(f.path));
    }
  }

  Future<void> _skipFile(BuildContext ctx, SaveFlashFile f) async {
    await widget.flashLogic.markSeen([f.path]);
    if (mounted) setState(() {});
  }

  Future<void> _addAll(
      BuildContext context, List<SaveFlashFile> files) async {
    for (final f in files) {
      if (_resultMsg.containsKey(f.path)) continue; // đã xử lý
      await _addFile(context, f);
    }
    // Đợi 1 nhịp rồi tự đóng nếu xong hết
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (mounted && widget.flashLogic.pendingFiles.isEmpty) {
      Navigator.pop(context);
    }
  }

  void _dismissAll(BuildContext context) async {
    final paths =
        widget.flashLogic.pendingFiles.map((f) => f.path).toList();
    await widget.flashLogic.markSeen(paths);
    if (context.mounted) Navigator.pop(context);
  }

  Widget _handleBar(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

// ---------------------------------------------------------------
// File item widget
// ---------------------------------------------------------------
class _FileItem extends StatelessWidget {
  final SaveFlashFile file;
  final List<PlaylistRow> playlists;
  final String? chosen; // playlist id
  final bool isProcessing;
  final String? resultMsg;
  final ValueChanged<String?> onPlaylistChanged;
  final VoidCallback onAdd;
  final VoidCallback onSkip;

  const _FileItem({
    required this.file,
    required this.playlists,
    required this.chosen,
    required this.isProcessing,
    required this.resultMsg,
    required this.onPlaylistChanged,
    required this.onAdd,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = resultMsg != null;
    final ext = file.name.toLowerCase().endsWith('.m4a') ? 'm4a' : 'mp3';
    final sizeMb = (file.sizeBytes / (1024 * 1024)).toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── File info row ──
            Row(
              children: [
                // Icon ext
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ext.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        '$sizeMb MB • ${_fmtDate(file.modified)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Kết quả nếu đã xử lý ──
            if (isDone) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        resultMsg!,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Playlist chọn + nút ──
            if (!isDone) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  // Dropdown playlist
                  Expanded(
                    child: _PlaylistDropdown(
                      playlists: playlists,
                      chosen: chosen,
                      onChanged: onPlaylistChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Nút thêm / loading
                  if (isProcessing)
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else ...[
                    IconButton(
                      tooltip: 'Bỏ qua',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: onSkip,
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onAdd,
                      child: const Text('Thêm'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------
// Playlist dropdown (null = chỉ thư viện)
// ---------------------------------------------------------------
class _PlaylistDropdown extends StatelessWidget {
  final List<PlaylistRow> playlists;
  final String? chosen;
  final ValueChanged<String?> onChanged;

  const _PlaylistDropdown({
    required this.playlists,
    required this.chosen,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      value: chosen,
      isExpanded: true,
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      hint: const Text('Chỉ lưu thư viện', overflow: TextOverflow.ellipsis),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Chỉ lưu thư viện', overflow: TextOverflow.ellipsis),
        ),
        ...playlists.map(
          (pl) => DropdownMenuItem<String?>(
            value: pl.id,
            child: Text(pl.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}