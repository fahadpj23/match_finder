import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Add this AppColors class at the top of the file
class AppColors {
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryDarkBlue = Color(0xFF1E40AF);
  static const Color successGreen = Color(0xFF059669);
  static const Color warningOrange = Color(0xFFD97706);
  static const Color errorRed = Color(0xFFDC2626);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE5E7EB);
}

// Model Class
class Display {
  final String id;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Display({
    required this.id,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Display.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Display(
      id: doc.id,
      displayName: data['displayName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}

// Main Display Tab - with duplicate checking and confirmation
class DisplayTab extends StatefulWidget {
  const DisplayTab({super.key});

  @override
  State<DisplayTab> createState() => _DisplayTabState();
}

class _DisplayTabState extends State<DisplayTab> {
  final TextEditingController _searchController = TextEditingController();
  final CollectionReference _displaysCollection = FirebaseFirestore.instance
      .collection('displays');
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';
  List<Display> _allDisplays = [];

  // Helper method to split text by multiple delimiters
  List<String> _splitByDelimiters(String text) {
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
  Future<bool> _isDisplayNameExists(
    String displayName, {
    String? excludeId,
  }) async {
    final newDisplayParts = _splitByDelimiters(displayName);
    final normalizedNewParts = newDisplayParts
        .map((part) => _normalizeText(part))
        .toList();

    final snapshot = await _displaysCollection.get();

    for (var doc in snapshot.docs) {
      final existingDisplay = Display.fromFirestore(doc);

      if (excludeId != null && existingDisplay.id == excludeId) {
        continue;
      }

      final existingDisplayParts = _splitByDelimiters(
        existingDisplay.displayName,
      );
      final normalizedExistingParts = existingDisplayParts
          .map((part) => _normalizeText(part))
          .toList();

      // Check each part individually
      for (int i = 0; i < normalizedNewParts.length; i++) {
        final newPart = normalizedNewParts[i];
        final originalNewPart = newDisplayParts[i];

        for (int j = 0; j < normalizedExistingParts.length; j++) {
          final existingPart = normalizedExistingParts[j];
          final originalExistingPart = existingDisplayParts[j];

          if (newPart == existingPart) {
            return true;
          }
        }
      }

      // If single part, check if it exists in any existing display
      if (newDisplayParts.length == 1) {
        if (normalizedExistingParts.contains(normalizedNewParts[0])) {
          return true;
        }
      }

      // Check if all new parts exist in any existing display
      bool allPartsExist = true;
      for (var newPart in normalizedNewParts) {
        if (!normalizedExistingParts.contains(newPart)) {
          allPartsExist = false;
          break;
        }
      }
      if (allPartsExist && normalizedNewParts.isNotEmpty) {
        return true;
      }
    }

    return false;
  }

  // Get duplicate details for better error message
  Future<Map<String, dynamic>> _getDuplicateDetails(String displayName) async {
    final newDisplayParts = _splitByDelimiters(displayName);
    final normalizedNewParts = newDisplayParts
        .map((part) => _normalizeText(part))
        .toList();

    final snapshot = await _displaysCollection.get();

    for (var doc in snapshot.docs) {
      final existingDisplay = Display.fromFirestore(doc);

      final existingDisplayParts = _splitByDelimiters(
        existingDisplay.displayName,
      );
      final normalizedExistingParts = existingDisplayParts
          .map((part) => _normalizeText(part))
          .toList();

      // Check each part individually
      for (int i = 0; i < normalizedNewParts.length; i++) {
        final newPart = normalizedNewParts[i];
        final originalNewPart = newDisplayParts[i];

        for (int j = 0; j < normalizedExistingParts.length; j++) {
          final existingPart = normalizedExistingParts[j];
          final originalExistingPart = existingDisplayParts[j];

          if (newPart == existingPart) {
            return {
              'message':
                  '"$originalNewPart" is already in: "${existingDisplay.displayName}"',
              'existingDisplay': existingDisplay,
            };
          }
        }
      }

      // If single part, check if it exists in any existing display
      if (newDisplayParts.length == 1) {
        if (normalizedExistingParts.contains(normalizedNewParts[0])) {
          return {
            'message':
                '"${newDisplayParts[0]}" is already in: "${existingDisplay.displayName}"',
            'existingDisplay': existingDisplay,
          };
        }
      }
    }

    return {'message': 'Display already exists', 'existingDisplay': null};
  }

  // Check if a specific display part matches search query
  bool _isPartMatch(String part, String query) {
    if (query.isEmpty) return false;
    return _normalizeText(part).contains(_normalizeText(query));
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  // New method to merge duplicate values
  Future<void> _mergeWithExisting(
    String newDisplayName,
    Display existingDisplay,
  ) async {
    try {
      // Split both display names into parts
      final newParts = _splitByDelimiters(newDisplayName);
      final existingParts = _splitByDelimiters(existingDisplay.displayName);

      // Normalize parts for comparison
      final normalizedNewParts = newParts
          .map((p) => _normalizeText(p))
          .toList();
      final normalizedExistingParts = existingParts
          .map((p) => _normalizeText(p))
          .toList();

      // Combine unique parts (avoid duplicates)
      final Set<String> uniqueNormalizedParts = {};
      final List<String> uniqueOriginalParts = [];

      // Add existing parts first
      for (int i = 0; i < existingParts.length; i++) {
        final normalized = normalizedExistingParts[i];
        if (!uniqueNormalizedParts.contains(normalized)) {
          uniqueNormalizedParts.add(normalized);
          uniqueOriginalParts.add(existingParts[i]);
        }
      }

      // Add new parts that don't already exist
      for (int i = 0; i < newParts.length; i++) {
        final normalized = normalizedNewParts[i];
        if (!uniqueNormalizedParts.contains(normalized)) {
          uniqueNormalizedParts.add(normalized);
          uniqueOriginalParts.add(newParts[i]);
        }
      }

      // Combine with original delimiter (using '/')
      final mergedDisplayName = uniqueOriginalParts.join(' / ');

      // Update the existing display with merged display name
      await _displaysCollection.doc(existingDisplay.id).update({
        'displayName': mergedDisplayName,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      print('Error merging: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        title: Text(
          'Displays',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        actions: [
          // Add button in app bar
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showAddDialog(context),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.successGreen,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.add, size: 18, color: AppColors.successGreen),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar with improved visibility
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search displays...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceWhite,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w400,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),

          // Content
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _displaysCollection
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.error_outline,
                            size: 40,
                            color: AppColors.errorRed,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading data',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryBlue,
                      ),
                    ),
                  );
                }

                _allDisplays = snapshot.data!.docs
                    .map((doc) => Display.fromFirestore(doc))
                    .toList();

                var displays = _allDisplays.where((display) {
                  if (_searchQuery.isEmpty) return true;

                  String normalizedQuery = _normalizeText(_searchQuery);

                  var parts = _splitByDelimiters(display.displayName);
                  for (var part in parts) {
                    if (_normalizeText(part).contains(normalizedQuery)) {
                      return true;
                    }
                  }

                  return _normalizeText(
                    display.displayName,
                  ).contains(normalizedQuery);
                }).toList();

                if (displays.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _searchQuery.isEmpty
                                ? Icons.inbox
                                : Icons.search_off,
                            size: 56,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No displays yet'
                              : 'No matching displays',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Tap + in the app bar to add your first display'
                              : 'Try a different search term',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => _showAddDialog(context),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add New Display'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: displays.length,
                  itemBuilder: (context, index) {
                    return DisplayListItem(
                      display: displays[index],
                      searchQuery: _searchQuery,
                      onTap: () =>
                          _showDisplayDetails(context, displays[index]),
                      onEdit: () => _showEditDialog(context, displays[index]),
                      onDelete: () =>
                          _showDeleteDialog(context, displays[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool isChecking = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceWhite,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.add,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Add Display',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            content: Container(
              width: 400,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Display Name',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'e.g., iPhone 13/13 Pro/13 Pro Max',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.borderLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.borderLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.primaryBlue,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: AppColors.backgroundLight,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.connected_tv,
                          size: 18,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a display name';
                        }
                        return null;
                      },
                      autofocus: true,
                      maxLines: 2,
                      minLines: 1,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use / = or , to separate multiple displays',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (isChecking)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: LinearProgressIndicator(
                          backgroundColor: AppColors.primaryBlue,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
              ElevatedButton(
                onPressed: isChecking
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setDialogState(() => isChecking = true);

                          final displayName = controller.text.trim();
                          final exists = await _isDisplayNameExists(
                            displayName,
                          );

                          if (exists) {
                            final duplicateDetails = await _getDuplicateDetails(
                              displayName,
                            );

                            setDialogState(() => isChecking = false);

                            if (context.mounted) {
                              // Close the add dialog
                              Navigator.pop(context);

                              // Show confirmation dialog with merge option
                              _showDuplicateConfirmationDialog(
                                context,
                                displayName,
                                duplicateDetails['message'],
                                duplicateDetails['existingDisplay'],
                              );
                            }
                            return;
                          }

                          try {
                            final now = DateTime.now();
                            await _displaysCollection.add({
                              'displayName': displayName,
                              'createdAt': now,
                              'updatedAt': now,
                            });

                            setDialogState(() => isChecking = false);

                            if (context.mounted) {
                              Navigator.pop(context);
                              _scrollToTop();

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
                                      const Expanded(
                                        child: Text(
                                          'Added successfully',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: AppColors.successGreen,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isChecking = false);

                            if (context.mounted) {
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
                                          'Error: $e',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: AppColors.errorRed,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  // Updated Duplicate Confirmation Dialog with Merge Option
  void _showDuplicateConfirmationDialog(
    BuildContext context,
    String displayName,
    String message,
    Display? existingDisplay,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warningOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warningOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Duplicate Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningOrange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warningOrange.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.warningOrange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'How would you like to proceed?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Add Separately: Keep as a new duplicate entry\n'
                    '• Add to Existing: Merge unique values with the existing record',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirmation dialog

              // Add Separately - Keep as duplicate
              try {
                final now = DateTime.now();
                await _displaysCollection.add({
                  'displayName': displayName,
                  'createdAt': now,
                  'updatedAt': now,
                });

                if (context.mounted) {
                  _scrollToTop();
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
                          const Expanded(
                            child: Text(
                              'Added as separate entry',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.warningOrange,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.error, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Error: $e',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.errorRed,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warningOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Add Separately'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirmation dialog

              if (existingDisplay != null) {
                // Merge with existing - remove duplicates and combine unique values
                await _mergeWithExisting(displayName, existingDisplay);

                if (context.mounted) {
                  _scrollToTop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.merge_type, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Merged with existing record',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.successGreen,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Add to Existing'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _showEditDialog(BuildContext context, Display display) {
    final TextEditingController controller = TextEditingController(
      text: display.displayName,
    );
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool isChecking = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceWhite,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.edit,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Edit Display',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Display Name',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: TextFormField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: 'e.g., iPhone 13/13 Pro/13 Pro Max',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.borderLight,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.borderLight,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.primaryBlue,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: AppColors.backgroundLight,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.connected_tv,
                              size: 18,
                              color: AppColors.primaryBlue,
                            ),
                            alignLabelWithHint: true,
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a display name';
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
                    const SizedBox(height: 8),
                    Text(
                      'Use / = or , to separate multiple displays',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (isChecking)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: LinearProgressIndicator(
                          backgroundColor: AppColors.primaryBlue,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
              ElevatedButton(
                onPressed: isChecking
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setDialogState(() => isChecking = true);

                          final displayName = controller.text.trim();
                          final exists = await _isDisplayNameExists(
                            displayName,
                            excludeId: display.id,
                          );

                          if (exists) {
                            final duplicateDetails = await _getDuplicateDetails(
                              displayName,
                            );

                            setDialogState(() => isChecking = false);

                            if (context.mounted) {
                              Navigator.pop(context); // Close edit dialog

                              _showDuplicateEditConfirmationDialog(
                                context,
                                display,
                                displayName,
                                duplicateDetails['message'],
                                duplicateDetails['existingDisplay'],
                              );
                            }
                            return;
                          }

                          try {
                            await _displaysCollection.doc(display.id).update({
                              'displayName': displayName,
                              'updatedAt': DateTime.now(),
                            });

                            setDialogState(() => isChecking = false);

                            if (context.mounted) {
                              Navigator.pop(context);
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
                                      const Expanded(
                                        child: Text(
                                          'Updated successfully',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: AppColors.successGreen,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isChecking = false);

                            if (context.mounted) {
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
                                          'Error: $e',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: AppColors.errorRed,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('Update'),
              ),
            ],
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  // Updated Edit Duplicate Confirmation Dialog with Merge Option
  void _showDuplicateEditConfirmationDialog(
    BuildContext context,
    Display display,
    String displayName,
    String message,
    Display? existingDisplay,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warningOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warningOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Duplicate Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningOrange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warningOrange.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.warningOrange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'How would you like to proceed?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Update Separately: Keep this as a separate duplicate\n'
                    '• Merge with Existing: Combine unique values with the existing record',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirmation dialog

              // Update Separately - Keep as duplicate
              try {
                await _displaysCollection.doc(display.id).update({
                  'displayName': displayName,
                  'updatedAt': DateTime.now(),
                });

                if (context.mounted) {
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
                          const Expanded(
                            child: Text(
                              'Updated as separate entry',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.warningOrange,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.error, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Error: $e',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.errorRed,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warningOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Update Separately'),
          ),
          const SizedBox(height: 5),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirmation dialog

              if (existingDisplay != null) {
                // Merge with existing - remove duplicates and combine unique values
                await _mergeWithExisting(displayName, existingDisplay);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.merge_type, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Merged with existing record',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.successGreen,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Merge with Existing'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // Updated Delete Dialog with Confirmation
  void _showDeleteDialog(BuildContext context, Display display) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: AppColors.errorRed,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Confirm Delete',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this display?',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.errorRed.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.errorRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"${display.displayName}"',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
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
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _displaysCollection.doc(display.id).delete();

                if (context.mounted) {
                  Navigator.pop(context);
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
                          const Expanded(
                            child: Text(
                              'Display deleted successfully',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.successGreen,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.error, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Error: ${e.toString()}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.errorRed,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _showDisplayDetails(BuildContext context, Display display) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DisplayDetailsSheet(display: display),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// Display List Item Widget - with improved visibility
class DisplayListItem extends StatelessWidget {
  final Display display;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DisplayListItem({
    super.key,
    required this.display,
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
    // Split the display name by multiple delimiters
    final displayParts = _splitByDelimiters(display.displayName);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderLight, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display parts chips - improved visibility
              Wrap(
                spacing: 6,
                runSpacing: 8,
                children: displayParts.map((part) {
                  final isMatch = _isPartMatch(part, searchQuery);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isMatch
                          ? AppColors.primaryBlue.withOpacity(0.15)
                          : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isMatch
                            ? AppColors.primaryBlue.withOpacity(0.3)
                            : AppColors.borderLight,
                        width: isMatch ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      part.trim(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isMatch ? FontWeight.w600 : FontWeight.w500,
                        color: isMatch
                            ? AppColors.primaryBlue
                            : AppColors.textPrimary,
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
                  // Edit button - improved visibility
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onEdit,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.edit,
                            size: 18,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Delete button - improved visibility
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onDelete,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.errorRed,
                          ),
                        ),
                      ),
                    ),
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

// Display Details Bottom Sheet - improved visibility
class DisplayDetailsSheet extends StatelessWidget {
  final Display display;

  const DisplayDetailsSheet({super.key, required this.display});

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
    final displayParts = _splitByDelimiters(display.displayName);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header handle - improved visibility
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon with better contrast
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                display.displayName.isNotEmpty
                    ? display.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title with parts - improved contrast
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: displayParts.map((part) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  part.trim(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Details section - improved readability
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  'Created',
                  DateFormat(
                    'MMM dd, yyyy · hh:mm a',
                  ).format(display.createdAt),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _buildInfoRow(
                  'Last Updated',
                  DateFormat(
                    'MMM dd, yyyy · hh:mm a',
                  ).format(display.updatedAt),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _buildInfoRow('ID', '${display.id.substring(0, 8)}...'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Close button - improved visibility
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
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
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
