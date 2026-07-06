import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/enums/directory_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/directory_item.dart';
import '../../data/directory_repository.dart';
import '../../../../core/config/organization_config.dart';

class DirectoryManagementScreen extends StatefulWidget {
  const DirectoryManagementScreen({super.key, this.type});

  final DirectoryType? type;

  @override
  State<DirectoryManagementScreen> createState() =>
      _DirectoryManagementScreenState();
}

class _DirectoryManagementScreenState extends State<DirectoryManagementScreen> {
  final _repository = DirectoryRepository();
  DirectoryType? _selectedType;
  String _searchQuery = '';
  String _sortBy = 'name_asc';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.type;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No active user profile found.')),
      );
    }

    final config = OrganizationConfigRegistry.of(user.organizationType);
    final supportedTypes = config.getSupportedMasterDataTypes();
    if (_selectedType == null || !supportedTypes.contains(_selectedType)) {
      _selectedType = supportedTypes.isNotEmpty ? supportedTypes.first : DirectoryType.department;
    }

    final typeLabel = _selectedType!.label;
    final typePlural = '${_selectedType!.label}s';

    return Scaffold(
      appBar: AppBar(title: const Text('Master Data Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading
            ? null
            : () => _openEditor(context, user.organizationId),
        icon: const Icon(Icons.add_rounded),
        label: Text('Add $typeLabel'),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 12.h),
              Text(
                'Select Master Data Type',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: supportedTypes.map((type) {
                    final isSelected = type == _selectedType;
                    return Padding(
                      padding: EdgeInsets.only(right: 8.w),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(type.label),
                        avatar: Icon(type.icon, size: 16.w,
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                        selectedColor: config.primaryColor,
                        labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface),
                        onSelected: (_) => setState(() => _selectedType = type),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Search Master Data',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  DropdownButton<String>(
                    value: _sortBy,
                    items: const [
                      DropdownMenuItem(value: 'name_asc', child: Text('Name (A-Z)')),
                      DropdownMenuItem(value: 'name_desc', child: Text('Name (Z-A)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _sortBy = val);
                      }
                    },
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              if (_loading) const Center(child: LinearProgressIndicator()),
              Expanded(
                child: StreamBuilder<List<DirectoryItem>>(
                  stream: _repository.watchItems(
                    organizationId: user.organizationId,
                    collection: _selectedType!.collection,
                    includeInactive: true,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading items: ${snapshot.error}',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var items = snapshot.data ?? const <DirectoryItem>[];

                    // Filter
                    if (_searchQuery.isNotEmpty) {
                      items = items.where((item) {
                        return item.name.toLowerCase().contains(_searchQuery) ||
                            item.description.toLowerCase().contains(_searchQuery);
                      }).toList();
                    }

                    // Sort
                    items = List.from(items);
                    if (_sortBy == 'name_asc') {
                      items.sort((a, b) => a.name.compareTo(b.name));
                    } else {
                      items.sort((a, b) => b.name.compareTo(a.name));
                    }

                    if (items.isEmpty) {
                      return Center(
                        child: Text('No $typePlural found. Click Add to create one.'),
                      );
                    }

                    return ListView.separated(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => SizedBox(height: 12.h),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return PremiumCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Row(
                              children: [
                                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(width: 8.w),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: item.isActive
                                        ? AppColors.success.withValues(alpha: 0.15)
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text(
                                    item.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                      color: item.isActive ? AppColors.success : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: item.description.isEmpty
                                ? null
                                : Text(item.description),
                            leading: Icon(_selectedType!.icon),
                            trailing: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Switch(
                                  value: item.isActive,
                                  activeThumbColor: config.primaryColor,
                                  onChanged: (val) => _toggleActive(user.organizationId, item, val),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () => _openEditor(
                                    context,
                                    user.organizationId,
                                    item,
                                  ),
                                  icon: const Icon(Icons.edit_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  onPressed: () => _delete(user.organizationId, item),
                                  icon: const Icon(Icons.delete_outline_rounded),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleActive(String organizationId, DirectoryItem item, bool active) async {
    try {
      await _repository.toggleItemStatus(
        organizationId: organizationId,
        collection: _selectedType!.collection,
        id: item.id,
        isActive: active,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _delete(String organizationId, DirectoryItem item) async {
    final fieldName = _selectedType!.userField;
    if (fieldName != null) {
      setState(() => _loading = true);
      final inUse = await _repository.isItemInUse(
        organizationId: organizationId,
        itemId: item.id,
        fieldName: fieldName,
      );
      if (mounted) {
        setState(() => _loading = false);
      }
      if (inUse) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Item In Use'),
              content: Text(
                'This ${_selectedType!.label.toLowerCase()} is currently assigned to active members. '
                'Please reassign the members before deleting, or deactivate this item to prevent new assignments.'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${item.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.deleteItem(
          organizationId: organizationId,
          collection: _selectedType!.collection,
          id: item.id,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  Future<void> _openEditor(
    BuildContext context,
    String organizationId, [
    DirectoryItem? item,
  ]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _DirectoryEditor(
          type: _selectedType!,
          organizationId: organizationId,
          item: item,
          repository: _repository,
        );
      },
    );
  }
}

class _DirectoryEditor extends StatefulWidget {
  const _DirectoryEditor({
    required this.type,
    required this.organizationId,
    this.item,
    required this.repository,
  });

  final DirectoryType type;
  final String organizationId;
  final DirectoryItem? item;
  final DirectoryRepository repository;

  @override
  State<_DirectoryEditor> createState() => _DirectoryEditorState();
}

class _DirectoryEditorState extends State<_DirectoryEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name);
    _descriptionController =
        TextEditingController(text: widget.item?.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = widget.type.label;

    return Padding(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 8.h,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20.h,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.item == null
                  ? 'Add $typeLabel'
                  : 'Edit $typeLabel',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16.h),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '$typeLabel Name',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            SizedBox(height: 18.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : () => _save(typeLabel),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Saving...' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(String typeLabel) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
    });

    final name = _nameController.text.trim();

    try {
      final duplicate = await widget.repository.isNameDuplicate(
        organizationId: widget.organizationId,
        collection: widget.type.collection,
        name: name,
        excludeId: widget.item?.id,
      );

      if (duplicate) {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('An active $typeLabel with this name already exists.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      await widget.repository.saveItem(
        organizationId: widget.organizationId,
        collection: widget.type.collection,
        id: widget.item?.id,
        item: DirectoryItem(
          id: widget.item?.id ?? '',
          name: name,
          description: _descriptionController.text.trim(),
          isActive: widget.item?.isActive ?? true,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to save ${typeLabel.toLowerCase()}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
