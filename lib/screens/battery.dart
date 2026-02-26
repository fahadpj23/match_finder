import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Model Class
class Battery {
  final String id;
  final String modelName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Battery({
    required this.id,
    required this.modelName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Battery.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Battery(
      id: doc.id,
      modelName: data['modelName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}

// Main Battery Tab
class BatteryTab extends StatefulWidget {
  const BatteryTab({super.key});

  @override
  State<BatteryTab> createState() => _BatteryTabState();
}

class _BatteryTabState extends State<BatteryTab> {
  final TextEditingController _searchController = TextEditingController();
  final CollectionReference _batteryCollection = FirebaseFirestore.instance
      .collection('battery');

  String _searchQuery = '';
  List<Battery> _allBatteries = [];

  // Helper method to split text by multiple delimiters
  List<String> _splitByDelimiters(String text) {
    // Split by '/', '=', ',' and trim each part
    return text
        .split(RegExp(r'[/=,]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  // Helper method to normalize text (remove spaces, special characters and convert to lowercase)
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('_', '')
        .replaceAll('/', '')
        .replaceAll('=', '')
        .replaceAll(',', '');
  }

  // Enhanced duplicate checking with better edge case handling
  Future<bool> _isModelNameExists(String modelName, {String? excludeId}) async {
    // Get all model parts from the new input using multiple delimiters
    final newModelParts = _splitByDelimiters(modelName);

    final normalizedNewParts = newModelParts
        .map((part) => _normalizeText(part))
        .toList();

    print('=== Checking for duplicates ===');
    print('New model: "$modelName"');
    print('Parts: $newModelParts');
    print('Normalized parts: $normalizedNewParts');

    final snapshot = await _batteryCollection.get();

    for (var doc in snapshot.docs) {
      final existingBattery = Battery.fromFirestore(doc);

      // Skip if we're editing and it's the same document
      if (excludeId != null && existingBattery.id == excludeId) {
        continue;
      }

      // Get existing model parts using multiple delimiters
      final existingModelParts = _splitByDelimiters(existingBattery.modelName);

      final normalizedExistingParts = existingModelParts
          .map((part) => _normalizeText(part))
          .toList();

      print('Checking against: "${existingBattery.modelName}"');
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
            '✓ SINGLE PART MATCH: "${newModelParts[0]}" exists in "${existingBattery.modelName}"',
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
        print('✓ ALL PARTS EXIST IN: "${existingBattery.modelName}"');
        return true;
      }

      // Check for partial matches (to catch variations)
      for (int i = 0; i < normalizedNewParts.length; i++) {
        final newPart = normalizedNewParts[i];
        final originalNewPart = newModelParts[i];

        for (int j = 0; j < normalizedExistingParts.length; j++) {
          final existingPart = normalizedExistingParts[j];
          final originalExistingPart = existingModelParts[j];

          // Skip very short parts (like "v" or "5g" might cause false positives)
          if (newPart.length < 3 || existingPart.length < 3) continue;

          // Check if one contains the other
          if (existingPart.contains(newPart) ||
              newPart.contains(existingPart)) {
            // Calculate similarity ratio
            double similarity;
            if (newPart.length <= existingPart.length) {
              similarity = newPart.length / existingPart.length;
            } else {
              similarity = existingPart.length / newPart.length;
            }

            // Only consider it a duplicate if similarity is high (over 70%)
            if (similarity > 0.7) {
              print(
                '✓ SIMILAR FOUND: "$originalNewPart" is ${(similarity * 100).toStringAsFixed(0)}% similar to "$originalExistingPart"',
              );
              return true;
            }
          }
        }
      }
    }

    print('✓ No duplicate found - can add');
    return false;
  }

  // Get duplicate details for better error message
  Future<String> _getDuplicateDetails(String modelName) async {
    final newModelParts = _splitByDelimiters(modelName);

    final normalizedNewParts = newModelParts
        .map((part) => _normalizeText(part))
        .toList();

    final snapshot = await _batteryCollection.get();

    for (var doc in snapshot.docs) {
      final existingBattery = Battery.fromFirestore(doc);

      final existingModelParts = _splitByDelimiters(existingBattery.modelName);

      final normalizedExistingParts = existingModelParts
          .map((part) => _normalizeText(part))
          .toList();

      // Check for exact matches
      for (int i = 0; i < normalizedNewParts.length; i++) {
        final newPart = normalizedNewParts[i];
        final originalNewPart = newModelParts[i];

        for (int j = 0; j < normalizedExistingParts.length; j++) {
          final existingPart = normalizedExistingParts[j];
          final originalExistingPart = existingModelParts[j];

          if (newPart == existingPart) {
            return '"$originalNewPart" is already in: "${existingBattery.modelName}"';
          }
        }
      }

      // Check for single part match
      if (newModelParts.length == 1) {
        if (normalizedExistingParts.contains(normalizedNewParts[0])) {
          return '"${newModelParts[0]}" is already in: "${existingBattery.modelName}"';
        }
      }

      // Check for partial matches
      for (int i = 0; i < normalizedNewParts.length; i++) {
        final newPart = normalizedNewParts[i];
        final originalNewPart = newModelParts[i];

        for (int j = 0; j < normalizedExistingParts.length; j++) {
          final existingPart = normalizedExistingParts[j];
          final originalExistingPart = existingModelParts[j];

          if (newPart.length < 3 || existingPart.length < 3) continue;

          if (existingPart.contains(newPart) ||
              newPart.contains(existingPart)) {
            double similarity;
            if (newPart.length <= existingPart.length) {
              similarity = newPart.length / existingPart.length;
            } else {
              similarity = existingPart.length / newPart.length;
            }

            if (similarity > 0.7) {
              return '"$originalNewPart" is very similar to "$originalExistingPart" in "${existingBattery.modelName}"';
            }
          }
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
              hintText: 'Search battery models...',
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
                'Add New Battery Model',
                style: TextStyle(fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
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
            stream: _batteryCollection
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
                          backgroundColor: Colors.green,
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

              // Convert documents to Battery objects
              _allBatteries = snapshot.data!.docs
                  .map((doc) => Battery.fromFirestore(doc))
                  .toList();

              // Filter batteries based on search query
              var batteries = _allBatteries.where((battery) {
                if (_searchQuery.isEmpty) return true;

                String normalizedQuery = _normalizeText(_searchQuery);

                // Check if any part of the model name matches
                var parts = _splitByDelimiters(battery.modelName);
                for (var part in parts) {
                  if (_normalizeText(part).contains(normalizedQuery)) {
                    return true;
                  }
                }

                return _normalizeText(
                  battery.modelName,
                ).contains(normalizedQuery);
              }).toList();

              if (batteries.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isEmpty
                            ? Icons.battery_unknown
                            : Icons.search_off,
                        size: 56,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No battery models added yet'
                            : 'No matching models found',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      if (_searchQuery.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your first battery model',
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
                itemCount: batteries.length,
                itemBuilder: (context, index) {
                  return BatteryListItem(
                    battery: batteries[index],
                    searchQuery: _searchQuery,
                    onTap: () => _showBatteryDetails(context, batteries[index]),
                    onEdit: () =>
                        _showEditBottomSheet(context, batteries[index]),
                    onDelete: () =>
                        _showDeleteBottomSheet(context, batteries[index]),
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
              'Add Battery Model',
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
                            'Enter model name (use / = or , to separate multiple models)',
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
                        prefixIcon: const Icon(Icons.battery_full, size: 18),
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
                            await _batteryCollection.add({
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
                  backgroundColor: Colors.green,
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

  // Edit Bottom Sheet
  // Fixed Edit Bottom Sheet with proper keyboard handling
  void _showEditBottomSheet(BuildContext context, Battery battery) {
    final TextEditingController controller = TextEditingController(
      text: battery.modelName,
    );
    final formKey = GlobalKey<FormState>();
    bool isChecking = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Edit Battery Model',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Form with properly sized text field
                  Form(
                    key: formKey,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: SingleChildScrollView(
                        child: TextFormField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: 'Model Name',
                            labelStyle: const TextStyle(fontSize: 12),
                            hintText:
                                'Enter model name (use / = or , to separate multiple models)',
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
                            prefixIcon: const Icon(
                              Icons.battery_full,
                              size: 18,
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
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.done,
                        ),
                      ),
                    ),
                  ),

                  if (isChecking) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],

                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isChecking
                              ? null
                              : () async {
                                  if (formKey.currentState!.validate()) {
                                    setSheetState(() => isChecking = true);

                                    final modelName = controller.text.trim();
                                    final exists = await _isModelNameExists(
                                      modelName,
                                      excludeId: battery.id,
                                    );

                                    if (exists) {
                                      final duplicateDetails =
                                          await _getDuplicateDetails(modelName);

                                      setSheetState(() => isChecking = false);

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              duplicateDetails,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            backgroundColor: Colors.orange,
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(
                                              seconds: 4,
                                            ),
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    try {
                                      await _batteryCollection
                                          .doc(battery.id)
                                          .update({
                                            'modelName': modelName,
                                            'updatedAt': DateTime.now(),
                                          });

                                      setSheetState(() => isChecking = false);

                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
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
                                      setSheetState(() => isChecking = false);

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
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
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                          child: const Text('Update'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Delete Bottom Sheet
  void _showDeleteBottomSheet(BuildContext context, Battery battery) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Warning Icon
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline,
                size: 36,
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Delete Battery Model',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Message
            Text(
              'Are you sure you want to delete this battery model?',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Model name
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.battery_full, size: 24, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(
                    battery.modelName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Warning text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Colors.orange[800],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'This action cannot be undone',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[800],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await _batteryCollection.doc(battery.id).delete();

                        if (context.mounted) {
                          Navigator.pop(context); // Close delete bottom sheet
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
                                      'Battery model deleted successfully',
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
                          Navigator.pop(context); // Close delete bottom sheet
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    Icons.error,
                                    size: 18,
                                    color: Colors.white,
                                  ),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showBatteryDetails(BuildContext context, Battery battery) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => BatteryDetailsSheet(battery: battery),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Battery List Item Widget
class BatteryListItem extends StatelessWidget {
  final Battery battery;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const BatteryListItem({
    super.key,
    required this.battery,
    required this.searchQuery,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  // Helper method to split by multiple delimiters
  List<String> _splitByDelimiters(String text) {
    return text
        .split(RegExp(r'[/=,]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('_', '')
        .replaceAll('/', '')
        .replaceAll('=', '')
        .replaceAll(',', '');
  }

  @override
  Widget build(BuildContext context) {
    // Split the model name by multiple delimiters
    final modelParts = _splitByDelimiters(battery.modelName);

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
              // Model parts chips
              Wrap(
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
                          ? Colors.green.withOpacity(0.15)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isMatch
                            ? Colors.green.shade300
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
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Bottom row with action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
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
                                color: Colors.green,
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
    return _normalizeText(part).contains(_normalizeText(query));
  }
}

// Battery Details Bottom Sheet
class BatteryDetailsSheet extends StatelessWidget {
  final Battery battery;

  const BatteryDetailsSheet({super.key, required this.battery});

  // Helper method to split by multiple delimiters
  List<String> _splitByDelimiters(String text) {
    return text
        .split(RegExp(r'[/=,]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final modelParts = _splitByDelimiters(battery.modelName);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header handle
          Container(
            width: 40,
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
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.battery_full, size: 36, color: Colors.green),
            ),
          ),
          const SizedBox(height: 16),

          // Title with parts
          Text(
            'Model Name',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: modelParts.map((part) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  'Created',
                  DateFormat(
                    'MMM dd, yyyy · hh:mm a',
                  ).format(battery.createdAt),
                ),
                const Divider(height: 16),
                _buildInfoRow(
                  'Last Updated',
                  DateFormat(
                    'MMM dd, yyyy · hh:mm a',
                  ).format(battery.updatedAt),
                ),
                const Divider(height: 16),
                _buildInfoRow(
                  'Document ID',
                  '${battery.id.substring(0, 8)}...',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: const Text('Close'),
            ),
          ),
          const SizedBox(height: 20),
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
