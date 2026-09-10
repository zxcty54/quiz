import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BatchManagerModal extends StatefulWidget {
  final List<dynamic> batches;
  final dynamic coachingId;
  final bool isDarkMode;
  final VoidCallback onRefresh;

  const BatchManagerModal({
    super.key,
    required this.batches,
    required this.coachingId,
    required this.isDarkMode,
    required this.onRefresh,
  });

  @override
  State<BatchManagerModal> createState() => _BatchManagerModalState();
}

class _BatchManagerModalState extends State<BatchManagerModal> {
  final batchNameCtrl = TextEditingController();
  final batchCodeCtrl = TextEditingController();
  String newBatchStatus = 'LIVE';
  bool isCreating = false;

  @override
  void dispose() {
    batchNameCtrl.dispose();
    batchCodeCtrl.dispose();
    super.dispose();
  }

  // 🗑️ CENTRAL SAFE DELETION (Har jagah se batch wipe-out karega)
  Future<void> _confirmAndDeleteBatch(String batchId, String batchName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              'Delete Batch Permanently?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Kya aap "$batchName" ko delete karna chahte hain?\n\n• Is batch ke tests har screen se hat jayenge.\n• Students ke attempts aur submission data clear ho jayenge.\n• Ye action undo nahi kiya ja sakta.',
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Delete Batch', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final client = Supabase.instance.client;

      // 1️⃣ Linked student submissions clean karein (Cascade safe)
      await client.from('batch_submissions').delete().eq('batch_id', batchId);

      // 2️⃣ Batch tests clean karein
      await client.from('batch_tests').delete().eq('batch_id', batchId);

      // 3️⃣ Main batch record delete karein
      await client.from('batches').delete().eq('id', batchId);

      // 4️⃣ Dashboard refresh trigger karein
      widget.onRefresh();

      if (mounted) {
        Navigator.pop(context); // Modal band karein
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ Batch "$batchName" har jagah se delete ho gaya!'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Batch delete error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Delete failed: $e'),
            backgroundColor: Colors.black87,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🏫 Manage Classroom Batches',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (widget.batches.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text(
                    'Koi active batch nahi mila.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ),
              ),

            ...List.generate(widget.batches.length, (idx) {
              final b = widget.batches[idx];
              final String bId = b['id'].toString();
              final String bName = b['batch_name'] ?? 'Batch';
              final String bStatus = b['status'] ?? 'LIVE';
              final bool isHidden = bStatus == 'HIDDEN';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isHidden
                      ? Colors.grey.withOpacity(0.1)
                      : (widget.isDarkMode
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.18)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'CODE: ${b['batch_code']} • Status: $bStatus',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF16A34A)),
                      tooltip: 'Copy Batch Code',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: b['batch_code'] ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied Code: ${b['batch_code']}')),
                        );
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) async {
                        if (val == 'DELETE') {
                          await _confirmAndDeleteBatch(bId, bName);
                        } else {
                          await Supabase.instance.client
                              .from('batches')
                              .update({'status': val}).eq('id', b['id']);
                          widget.onRefresh();
                          if (mounted) Navigator.pop(context);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'LIVE', child: Text('🟢 Set LIVE')),
                        const PopupMenuItem(value: 'UPCOMING', child: Text('⏳ Set UPCOMING')),
                        const PopupMenuItem(value: 'HIDDEN', child: Text('⚪ HIDE Batch')),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'DELETE',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text(
                                '🗑️ Delete Batch',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            const Divider(height: 20),
            const Text(
              '+ Add New Batch',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: batchNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Batch Name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: batchCodeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Join Code (Password)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
                onPressed: isCreating
                    ? null
                    : () async {
                        final bName = batchNameCtrl.text.trim();
                        final bCode = batchCodeCtrl.text.trim().toUpperCase();
                        if (bName.isEmpty || bCode.isEmpty) return;

                        setState(() => isCreating = true);
                        try {
                          await Supabase.instance.client.from('batches').insert({
                            'coaching_id': widget.coachingId,
                            'batch_name': bName,
                            'batch_code': bCode,
                            'status': newBatchStatus,
                          });
                          if (mounted) Navigator.pop(context);
                          widget.onRefresh();
                        } catch (_) {
                          if (mounted) setState(() => isCreating = false);
                        }
                      },
                child: const Text(
                  'Create Batch Code 🚀',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
