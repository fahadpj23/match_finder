import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Model Class
class ScreenGuard {
  final String id;
  final String modelName;
  final DateTime createdAt;
  final DateTime updatedAt;

  ScreenGuard({
    required this.id,
    required this.modelName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ScreenGuard.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ScreenGuard(
      id: doc.id,
      modelName: data['modelName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}

// Main Screen Guard Tab
class ScreenGuardTab extends StatefulWidget {
  const ScreenGuardTab({super.key});

  @override
  State<ScreenGuardTab> createState() => _ScreenGuardTabState();
}

class _ScreenGuardTabState extends State<ScreenGuardTab> {
  final TextEditingController _searchController = TextEditingController();
  final CollectionReference _guardsCollection = FirebaseFirestore.instance
      .collection('screenGuards');

  String _searchQuery = '';
  List<ScreenGuard> _allGuards = [];

  // Helper method to normalize text (remove spaces, special characters and convert to lowercase)
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('_', '')
        .replaceAll('/', '');
  }

  // Enhanced duplicate checking with better edge case handling
  Future<bool> _isModelNameExists(String modelName, {String? excludeId}) async {
    // Get all model parts from the new input
    final newModelParts = modelName
        .split('/')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    final normalizedNewParts = newModelParts
        .map((part) => _normalizeText(part))
        .toList();

    print('=== Checking for duplicates ===');
    print('New model: "$modelName"');
    print('Parts: $newModelParts');
    print('Normalized parts: $normalizedNewParts');

    final snapshot = await _guardsCollection.get();

    for (var doc in snapshot.docs) {
      final existingGuard = ScreenGuard.fromFirestore(doc);

      // Skip current document when editing
      if (excludeId != null && existingGuard.id == excludeId) {
        continue;
      }

      // Get existing model parts
      final existingModelParts = existingGuard.modelName
          .split('/')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();

      final normalizedExistingParts = existingModelParts
          .map((part) => _normalizeText(part))
          .toList();

      print('Checking against: "${existingGuard.modelName}"');
      print('Existing parts: $existingModelParts');

      // Check for exact matches in parts
      for (int i = 0; i < normalizedNewParts.length; i++) {
        final newPart = normalizedNewParts[i];
        final originalNewPart = newModelParts[i];

        for (int j = 0; j < normalizedExistingParts.length; j++) {
          final existingPart = normalizedExistingParts[j];
          final originalExistingPart = existingModelParts[j];

          // Check if parts match exactly after normalization
          if (newPart == existingPart) {
            print(
              '✓ DUPLICATE FOUND: "$originalNewPart" matches "$originalExistingPart"',
            );
            return true;
          }
        }
      }

      // Check if any new part exists in existing parts (for single part addition)
      if (newModelParts.length == 1) {
        if (normalizedExistingParts.contains(normalizedNewParts[0])) {
          print(
            '✓ SINGLE PART MATCH: "${newModelParts[0]}" exists in "${existingGuard.modelName}"',
          );
          return true;
        }
      }

      // Check if all new parts exist in existing parts (for multiple parts addition)
      bool allPartsExist = true;
      for (var newPart in normalizedNewParts) {
        if (!normalizedExistingParts.contains(newPart)) {
          allPartsExist = false;
          break;
        }
      }
      if (allPartsExist && normalizedNewParts.isNotEmpty) {
        print('✓ ALL PARTS EXIST IN: "${existingGuard.modelName}"');
        return true;
      }
    }

    print('✓ No duplicate found - can add');
    return false;
  }

  // Get duplicate details for better error message
  Future<String> _getDuplicateDetails(String modelName) async {
    final newModelParts = modelName
        .split('/')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    final normalizedNewParts = newModelParts
        .map((part) => _normalizeText(part))
        .toList();

    final snapshot = await _guardsCollection.get();

    for (var doc in snapshot.docs) {
      final existingGuard = ScreenGuard.fromFirestore(doc);

      final existingModelParts = existingGuard.modelName
          .split('/')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();

      final normalizedExistingParts = existingModelParts
          .map((part) => _normalizeText(part))
          .toList();

      // Check for matches
      for (int i = 0; i < normalizedNewParts.length; i++) {
        final newPart = normalizedNewParts[i];
        final originalNewPart = newModelParts[i];

        for (int j = 0; j < normalizedExistingParts.length; j++) {
          final existingPart = normalizedExistingParts[j];
          final originalExistingPart = existingModelParts[j];

          if (newPart == existingPart) {
            return '"$originalNewPart" is already in: "${existingGuard.modelName}"';
          }
        }
      }

      // Check for single part match
      if (newModelParts.length == 1) {
        if (normalizedExistingParts.contains(normalizedNewParts[0])) {
          return '"${newModelParts[0]}" is already in: "${existingGuard.modelName}"';
        }
      }
    }

    return 'Model already exists';
  }

  // Check if a specific model part matches search query
  bool _isPartMatch(String part, String query) {
    if (query.isEmpty) return false;
    return _normalizeText(part).contains(_normalizeText(query));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search models...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.grey,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        // Add button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Add New Model',
                style: TextStyle(fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Content
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _guardsCollection
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 40,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading data',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 3),
                );
              }

              // Convert documents to ScreenGuard objects
              _allGuards = snapshot.data!.docs
                  .map((doc) => ScreenGuard.fromFirestore(doc))
                  .toList();

              // Filter guards based on search query
              var guards = _allGuards.where((guard) {
                if (_searchQuery.isEmpty) return true;

                String normalizedQuery = _normalizeText(_searchQuery);

                // Check if any part of the model name matches
                var parts = guard.modelName.split('/');
                for (var part in parts) {
                  if (_normalizeText(part).contains(normalizedQuery)) {
                    return true;
                  }
                }

                return _normalizeText(
                  guard.modelName,
                ).contains(normalizedQuery);
              }).toList();

              if (guards.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isEmpty ? Icons.inbox : Icons.search_off,
                        size: 56,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No screen guards added yet'
                            : 'No matching models found',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      if (_searchQuery.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your first model',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: guards.length,
                itemBuilder: (context, index) {
                  return GuardListItem(
                    guard: guards[index],
                    searchQuery: _searchQuery,
                    onTap: () => _showGuardDetails(context, guards[index]),
                    onEdit: () => _showEditDialog(context, guards[index]),
                    onDelete: () => _showDeleteDialog(context, guards[index]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isChecking = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text(
              'Add Screen Guard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 400,
                    child: TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Model Name',
                        labelStyle: const TextStyle(fontSize: 12),
                        hintText:
                            'Enter model name (use / to separate multiple models)',
                        hintStyle: const TextStyle(fontSize: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a model name';
                        }
                        return null;
                      },
                      autofocus: true,
                      maxLines: 2,
                      minLines: 1,
                    ),
                  ),
                  if (isChecking)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
              ElevatedButton(
                onPressed: isChecking
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setDialogState(() => isChecking = true);

                          final modelName = controller.text.trim();
                          final exists = await _isModelNameExists(modelName);

                          if (exists) {
                            final duplicateDetails = await _getDuplicateDetails(
                              modelName,
                            );

                            setDialogState(() => isChecking = false);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    duplicateDetails,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.orange,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                            return;
                          }

                          try {
                            final now = DateTime.now();
                            await _guardsCollection.add({
                              'modelName': modelName,
                              'createdAt': now,
                              'updatedAt': now,
                            });

                            setDialogState(() => isChecking = false);

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Added successfully',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isChecking = false);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error: $e',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, ScreenGuard guard) {
    final TextEditingController controller = TextEditingController(
      text: guard.modelName,
    );
    final formKey = GlobalKey<FormState>();
    bool isChecking = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text(
              'Edit Screen Guard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 400,
                    child: TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Model Name',
                        labelStyle: const TextStyle(fontSize: 12),
                        hintText:
                            'Enter model name (use / to separate multiple models)',
                        hintStyle: const TextStyle(fontSize: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a model name';
                        }
                        return null;
                      },
                      autofocus: true,
                      maxLines: 2,
                      minLines: 1,
                    ),
                  ),
                  if (isChecking)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
              ElevatedButton(
                onPressed: isChecking
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setDialogState(() => isChecking = true);

                          final modelName = controller.text.trim();
                          final exists = await _isModelNameExists(
                            modelName,
                            excludeId: guard.id,
                          );

                          if (exists) {
                            final duplicateDetails = await _getDuplicateDetails(
                              modelName,
                            );

                            setDialogState(() => isChecking = false);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    duplicateDetails,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.orange,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                            return;
                          }

                          try {
                            await _guardsCollection.doc(guard.id).update({
                              'modelName': modelName,
                              'updatedAt': DateTime.now(),
                            });

                            setDialogState(() => isChecking = false);

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Updated successfully',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isChecking = false);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error: $e',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Updated Delete Dialog with Confirmation
  void _showDeleteDialog(BuildContext context, ScreenGuard guard) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange[700],
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'Confirm Delete',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this screen guard?',
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"${guard.modelName}"',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _guardsCollection.doc(guard.id).delete();

                if (context.mounted) {
                  Navigator.pop(context); // Close delete dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Screen guard deleted successfully',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close delete dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.error, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Error: ${e.toString()}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showGuardDetails(BuildContext context, ScreenGuard guard) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => GuardDetailsSheet(guard: guard),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// UPDATED Guard List Item Widget - with buttons at bottom
class GuardListItem extends StatelessWidget {
  final ScreenGuard guard;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const GuardListItem({
    super.key,
    required this.guard,
    required this.searchQuery,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Split the model name by "/"
    final modelParts = guard.modelName.split('/');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shadowColor: Colors.grey.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row with icon and model chips
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon/Initial

                  // Model parts chips - Expanded to take remaining space
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 8,
                      children: modelParts.map((part) {
                        final isMatch = _isPartMatch(part, searchQuery);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isMatch
                                ? Colors.blue.withOpacity(0.15)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isMatch
                                  ? Colors.blue.shade300
                                  : Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            part.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isMatch
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isMatch
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Bottom row with date and action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Created date

                  // Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onEdit,
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Delete button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onDelete,
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isPartMatch(String part, String query) {
    if (query.isEmpty) return false;

    String normalize(String text) {
      return text.toLowerCase().replaceAll(' ', '');
    }

    return normalize(part).contains(normalize(query));
  }
}

// Guard Details Bottom Sheet
class GuardDetailsSheet extends StatelessWidget {
  final ScreenGuard guard;

  const GuardDetailsSheet({super.key, required this.guard});

  @override
  Widget build(BuildContext context) {
    final modelParts = guard.modelName.split('/');

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Icon
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                guard.modelName.isNotEmpty
                    ? guard.modelName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Title with parts
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: modelParts.map((part) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  part.trim(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Details
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  'Created',
                  DateFormat('MMM dd, yyyy').format(guard.createdAt),
                ),
                const Divider(height: 12),
                _buildInfoRow(
                  'Last Updated',
                  DateFormat('MMM dd, yyyy').format(guard.updatedAt),
                ),
                const Divider(height: 12),
                _buildInfoRow('ID', '${guard.id.substring(0, 8)}...'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
