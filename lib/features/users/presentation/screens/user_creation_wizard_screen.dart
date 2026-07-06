import 'dart:io' show File;
import 'dart:math' show Random, min, max;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/enums/organization_type.dart';
import '../../../../core/enums/user_kind.dart';
import '../../../../core/enums/user_role.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../../auth/data/app_user.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../directory/data/directory_item.dart';
import '../../../directory/data/directory_repository.dart';
import '../../../../core/config/organization_config.dart';
import '../../../../core/enums/directory_type.dart';
import '../../data/face_capture_service.dart';
import '../../data/user_repository.dart';

class UserCreationWizardScreen extends StatefulWidget {
  const UserCreationWizardScreen({super.key, this.role = UserRole.member});

  final UserRole role;

  @override
  State<UserCreationWizardScreen> createState() => _UserCreationWizardScreenState();
}

class _UserCreationWizardScreenState extends State<UserCreationWizardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _userRepository = UserRepository();
  final _directoryRepository = DirectoryRepository();
  final _faceCaptureService = FaceCaptureService();
  AuthRepository? _authRepository;

  CameraController? _cameraController;
  bool _cameraInitializing = false;
  bool _cameraInitialized = false;

  int _step = 0;
  UserKind _kind = UserKind.student;
  String? _departmentId;
  String? _teamId;
  String? _shiftId;
  String? _profilePhotoPath;
  String? _faceImagePath;
  Map<String, dynamic>? _faceData;
  bool _saving = false;
  bool _useCameraForProfile = false;
  String _savingStatus = '';
  late final String _temporaryPassword = _generatePassword();

  UserKind _defaultUserKindFor(OrganizationType orgType) {
    return switch (orgType) {
      OrganizationType.school => UserKind.student,
      OrganizationType.corporate => UserKind.employee,
      OrganizationType.factory => UserKind.worker,
      OrganizationType.hospital => UserKind.member,
      OrganizationType.retail => UserKind.member,
      OrganizationType.warehouse => UserKind.worker,
    };
  }

  @override
  void initState() {
    super.initState();
    final currentUser = context.read<AuthBloc>().state.user;
    if (widget.role == UserRole.member && currentUser != null) {
      _kind = _defaultUserKindFor(currentUser.organizationType);
    } else {
      _kind = UserKind.member;
    }
  }

  static const _stepTitles = [
    'Basic Details',
    'Assignment',
    'Profile Photo',
    'Face Registration',
    'Review',
    'Save User',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _employeeIdController.dispose();
    _disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthBloc>().state.user;
    _authRepository ??= context.read<AuthRepository>();

    final orgType = currentUser?.organizationType;
    final config = orgType != null ? OrganizationConfigRegistry.of(orgType) : null;
    final roleLabel = currentUser != null && config != null
        ? config.roleLabel(widget.role)
        : widget.role.label;

    return Scaffold(
      appBar: AppBar(title: Text('Create $roleLabel')),
      body: SafeArea(
        child: currentUser == null
            ? const Center(child: Text('No active user profile found.'))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 780;
                  final content = Form(
                    key: _formKey,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: _buildStep(currentUser.organizationId, config, roleLabel),
                      ),
                    ),
                  );

                  if (wide) {
                    return Row(
                      children: [
                        SizedBox(width: 300.w, child: _StepRail(step: _step, titles: _stepTitles)),
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.all(24.w),
                            children: [content],
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView(
                    padding: EdgeInsets.all(20.w),
                    children: [
                      _StepStrip(step: _step, titles: _stepTitles),
                      SizedBox(height: 16.h),
                      content,
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildStep(String organizationId, OrganizationConfig? config, String roleLabel) {
    final idLabel = config?.idLabel ?? 'Employee ID';

    return switch (_step) {
      0 => _WizardPanel(
          title: 'Basic Details',
          subtitle: 'Create organization-owned users. No self-registration is exposed.',
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: _required,
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Email is required for account creation';
                  if (!email.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: _required,
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _employeeIdController,
                decoration: InputDecoration(labelText: idLabel),
                validator: _required,
              ),
              _WizardActions(onNext: _next),
            ],
          ),
        ),
      1 => _WizardPanel(
          title: 'Organization Assignment',
          subtitle: 'Attach the user to assignments for reporting (Optional).',
          child: Column(
            children: [
              if (config != null) ...[
                for (final type in config.getUserAssignmentTypes()) ...[
                  _DirectoryDropdown(
                    label: type.label,
                    value: type.userField == 'departmentId'
                        ? _departmentId
                        : (type.userField == 'shiftId' ? _shiftId : _teamId),
                    stream: _directoryRepository.watchItems(
                      organizationId: organizationId,
                      collection: type.collection,
                    ),
                    onChanged: (value) => setState(() {
                      if (type.userField == 'departmentId') {
                        _departmentId = value;
                      } else if (type.userField == 'shiftId') {
                        _shiftId = value;
                      } else {
                        _teamId = value;
                      }
                    }),
                    onAddPressed: () => _showQuickDirectoryCreator(
                      type,
                      organizationId,
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
              ],
              _WizardActions(onBack: _back, onNext: _next),
            ],
          ),
        ),
      2 => _WizardPanel(
          title: 'Profile Photo',
          subtitle: 'Choose an existing image or take a new photo.',
          child: Column(
            children: [
              if (_profilePhotoPath != null)
                _CameraCaptureWidget(
                  cameraInitialized: _cameraInitialized,
                  cameraInitializing: _cameraInitializing,
                  controller: _cameraController,
                  capturedPath: _profilePhotoPath,
                  onCapture: _pickProfilePhotoFromGallery, // Keep trigger callbacks aligned
                  onRetake: () => setState(() {
                    _profilePhotoPath = null;
                    _useCameraForProfile = false;
                  }),
                )
              else if (_useCameraForProfile) ...[
                _CameraCaptureWidget(
                  cameraInitialized: _cameraInitialized,
                  cameraInitializing: _cameraInitializing,
                  controller: _cameraController,
                  capturedPath: null,
                  onCapture: _captureProfilePhoto,
                  onRetake: () {},
                ),
                SizedBox(height: 12.h),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _useCameraForProfile = false;
                    _disposeCamera();
                  }),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Or Choose from Gallery'),
                ),
              ] else
                Container(
                  padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.r),
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 20.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _useCameraForProfile = true;
                            });
                            _initCamera();
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt_rounded, size: 32.w),
                              SizedBox(height: 8.h),
                              const Text('Take Photo'),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 20.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          onPressed: _pickProfilePhotoFromGallery,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_library_rounded, size: 32.w),
                              SizedBox(height: 8.h),
                              const Text('Choose Image'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _WizardActions(onBack: _back, onNext: _next),
            ],
          ),
        ),
      3 => _WizardPanel(
          title: 'Face Registration',
          subtitle: 'Position the user face in the frame to register the biometric profile.',
          child: Column(
            children: [
              _CameraCaptureWidget(
                cameraInitialized: _cameraInitialized,
                cameraInitializing: _cameraInitializing,
                controller: _cameraController,
                capturedPath: _faceImagePath,
                onCapture: _captureFace,
                onRetake: () => setState(() {
                  _faceImagePath = null;
                  _faceData = null;
                }),
              ),
              _WizardActions(onBack: _back, onNext: _faceData == null ? null : _next),
            ],
          ),
        ),
      4 => _WizardPanel(
          title: 'Review Details',
          subtitle: 'Confirm details before creating the user and face registration records.',
          child: Column(
            children: [
              _ReviewTile(label: 'Name', value: _nameController.text),
              _ReviewTile(label: 'Type', value: roleLabel),
              _ReviewTile(label: 'Email', value: _emailController.text.trim().isEmpty ? 'Not provided' : _emailController.text.trim()),
              _ReviewTile(label: 'Phone', value: _phoneController.text),
              _ReviewTile(label: idLabel, value: _employeeIdController.text),
              _ReviewTile(
                label: 'Face Quality',
                value: _faceData != null
                    ? '${((_faceData!['qualityScore'] as num? ?? 0) * 100).round()}%'
                    : 'Not registered',
              ),
              _WizardActions(onBack: _back, onNext: _next),
            ],
          ),
        ),
      _ => _WizardPanel(
          title: 'Save User',
          subtitle: 'This creates the user profile and face registration document in Firebase.',
          child: Column(
            children: [
              if (_saving)
                Column(
                  children: [
                    SizedBox(
                      height: 80.h,
                      width: 80.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 4.w,
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      _savingStatus.isEmpty ? 'Processing...' : _savingStatus,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              else ...[
                Icon(Icons.verified_user_rounded, size: 56.w, color: Theme.of(context).colorScheme.primary),
                SizedBox(height: 12.h),
                Text(
                  'Ready to create user',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ],
              SizedBox(height: 20.h),
              _WizardActions(
                onBack: _saving ? null : _back,
                onNext: _saving ? null : () => _save(organizationId),
                nextLabel: 'Create User',
                busy: _saving,
              ),
            ],
          ),
        ),
    };
  }

  Future<void> _initCamera() async {
    if (_cameraInitialized || _cameraInitializing) return;
    setState(() {
      _cameraInitializing = true;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraInitializing = false;
          _cameraInitialized = false;
        });
        return;
      }
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _cameraInitializing = false;
          _cameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
      if (mounted) {
        setState(() {
          _cameraInitializing = false;
          _cameraInitialized = false;
        });
      }
    }
  }

  Future<void> _disposeCamera() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }
    if (mounted) {
      setState(() {
        _cameraInitialized = false;
        _cameraInitializing = false;
      });
    }
  }

  void _onStepChanged(int nextStep) {
    setState(() => _step = nextStep);
    if (nextStep == 2) {
      if (_useCameraForProfile) {
        _initCamera();
      } else {
        _disposeCamera();
      }
    } else if (nextStep == 3) {
      _initCamera();
    } else {
      _disposeCamera();
    }
  }

  void _next() {
    if (_step == 0 || _step == 1) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }
    if (_step == 2) {
      if (_profilePhotoPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please capture a profile photo to continue.')),
        );
        return;
      }
    }
    if (_step == 3) {
      if (_faceData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete face registration to continue.')),
        );
        return;
      }
    }
    final nextStep = min(_step + 1, _stepTitles.length - 1);
    _onStepChanged(nextStep);
  }

  void _back() {
    final nextStep = max(_step - 1, 0);
    _onStepChanged(nextStep);
  }

  Future<void> _captureProfilePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      // Fallback
      setState(() {
        _profilePhotoPath = 'simulated_profile_photo.jpg';
      });
      return;
    }
    try {
      final XFile photo = await _cameraController!.takePicture();
      setState(() {
        _profilePhotoPath = photo.path;
      });
    } catch (e) {
      debugPrint('Error taking profile photo: $e');
    }
  }

  Future<void> _captureFace() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      // Fallback
      final result = _faceCaptureService.createDesktopFallback();
      setState(() {
        _faceData = result.toMap();
        _faceImagePath = 'simulated_face_photo.jpg';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Desktop mode: Photo stored as face proof. ML Kit unavailable.'),
        ),
      );
      return;
    }

    try {
      setState(() {
        _saving = true;
      });
      final XFile photo = await _cameraController!.takePicture();
      final result = await _faceCaptureService.detectAndValidateFace(photo.path);
      
      setState(() {
        _saving = false;
        if (result.success) {
          _faceData = result.toMap();
          _faceImagePath = photo.path;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Face captured and validated successfully!')),
          );
        } else {
          _faceData = null;
          _faceImagePath = null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.errorMessage ?? 'Face quality check failed.')),
          );
        }
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _faceData = null;
        _faceImagePath = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Face registration error: $e')),
        );
      }
    }
  }

  Future<void> _pickProfilePhotoFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image != null) {
        setState(() {
          _profilePhotoPath = image.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking profile photo from gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image from gallery: $e')),
        );
      }
    }
  }

  Future<void> _save(String organizationId) async {
    setState(() {
      _saving = true;
      _savingStatus = 'Initializing user creation...';
    });
    try {
      await _userRepository.createUserWithFace(
        organizationId: organizationId,
        authRepository: _authRepository!,
        onProgress: (status) {
          if (mounted) {
            setState(() {
              _savingStatus = status;
            });
          }
        },
        draft: UserCreationDraft(
          user: AppUser(
            id: '',
            organizationId: organizationId,
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            role: widget.role,
            kind: _kind,
            phone: _phoneController.text.trim(),
            employeeId: _employeeIdController.text.trim(),
            departmentId: _departmentId?.isEmpty == true ? null : _departmentId,
            teamId: _teamId?.isEmpty == true ? null : _teamId,
            shiftId: _shiftId?.isEmpty == true ? null : _shiftId,
          ),
          profilePhoto: _profilePhotoPath ?? '',
          faceMetadata: _faceData ?? const <String, dynamic>{},
          temporaryPassword: _temporaryPassword,
          faceImagePath: _faceImagePath,
        ),
      );
      if (mounted) {
        await _showCredentialsDialog();
        if (mounted) context.pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create user: $error')),
        );
      }
    }
  }

  Future<void> _showCredentialsDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('User Created Successfully'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share these login credentials with the user:'),
              SizedBox(height: 12.h),
              SelectableText('Email: ${_emailController.text.trim()}'),
              SizedBox(height: 4.h),
              SelectableText('Temporary Password: $_temporaryPassword'),
              SizedBox(height: 12.h),
              Text(
                'The user should change their password after first login.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _authRepository?.sendPasswordReset(_emailController.text.trim());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password reset email sent.')),
                );
              },
              child: const Text('Send Reset Email'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showQuickDirectoryCreator(
    DirectoryType type,
    String organizationId,
  ) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 8.h,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 20.h,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Create ${type.label}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: '${type.label} Name',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 12.h),
                    TextFormField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    SizedBox(height: 18.h),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) {
                                  return;
                                }
                                setSheetState(() => isSaving = true);
                                try {
                                  final newId = FirebaseFirestore.instance
                                      .collection('organizations')
                                      .doc(organizationId)
                                      .collection(type.collection)
                                      .doc()
                                      .id;
                                  final newItem = DirectoryItem(
                                    id: newId,
                                    name: nameController.text.trim(),
                                    description: descriptionController.text.trim(),
                                  );
                                  await _directoryRepository.saveItem(
                                    organizationId: organizationId,
                                    collection: type.collection,
                                    id: newId,
                                    item: newItem,
                                  );
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    setState(() {
                                      if (type.userField == 'departmentId') {
                                        _departmentId = newId;
                                      } else if (type.userField == 'shiftId') {
                                        _shiftId = newId;
                                      } else {
                                        _teamId = newId;
                                      }
                                    });
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    setSheetState(() => isSaving = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to save: $e'),
                                        backgroundColor: Theme.of(context).colorScheme.error,
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: isSaving
                            ? SizedBox.square(
                                dimension: 18.w,
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(isSaving ? 'Creating...' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
  }

  static String _generatePassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#';
    final random = Random.secure();
    return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;
}

class _WizardPanel extends StatelessWidget {
  const _WizardPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 6.h),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
                ),
          ),
          SizedBox(height: 18.h),
          child,
        ],
      ),
    );
  }
}

class _StepStrip extends StatelessWidget {
  const _StepStrip({required this.step, required this.titles});

  final int step;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.all(12.w),
      child: Row(
        children: [
          for (var index = 0; index < titles.length; index++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 6.h,
                decoration: BoxDecoration(
                  color: index <= step
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
            if (index != titles.length - 1) SizedBox(width: 6.w),
          ],
        ],
      ),
    );
  }
}

class _StepRail extends StatelessWidget {
  const _StepRail({required this.step, required this.titles});

  final int step;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(20.w),
      children: [
        for (var index = 0; index < titles.length; index++)
          PremiumCard(
            margin: EdgeInsets.only(bottom: 10.h),
            padding: EdgeInsets.all(14.w),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16.r,
                  backgroundColor: index <= step
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: index <= step
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(child: Text(titles[index], style: Theme.of(context).textTheme.titleSmall)),
              ],
            ),
          ),
      ],
    );
  }
}

class _WizardActions extends StatelessWidget {
  const _WizardActions({
    this.onBack,
    this.onNext,
    this.nextLabel = 'Continue',
    this.busy = false,
  });

  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 20.h),
      child: Row(
        children: [
          if (onBack != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back'),
              ),
            ),
          if (onBack != null) SizedBox(width: 12.w),
          Expanded(
            child: FilledButton.icon(
              onPressed: onNext,
              icon: busy
                  ? SizedBox.square(
                      dimension: 16.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(nextLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectoryDropdown extends StatelessWidget {
  const _DirectoryDropdown({
    required this.label,
    required this.value,
    required this.stream,
    required this.onChanged,
    this.onAddPressed,
  });

  final String label;
  final String? value;
  final Stream<List<DirectoryItem>> stream;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onAddPressed;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DirectoryItem>>(
      stream: stream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <DirectoryItem>[];
        final currentValue = value != null && value!.isNotEmpty && items.any((item) => item.id == value)
            ? value
            : '';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: currentValue,
                decoration: InputDecoration(
                  labelText: label,
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Not Assigned (None)'),
                  ),
                  ...items.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))),
                ],
                onChanged: onChanged,
              ),
            ),
            if (onAddPressed != null) ...[
              SizedBox(width: 8.w),
              IconButton.filledTonal(
                tooltip: 'Create New $label',
                onPressed: onAddPressed,
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CameraCaptureWidget extends StatelessWidget {
  const _CameraCaptureWidget({
    required this.cameraInitialized,
    required this.cameraInitializing,
    required this.controller,
    required this.capturedPath,
    required this.onCapture,
    required this.onRetake,
  });

  final bool cameraInitialized;
  final bool cameraInitializing;
  final CameraController? controller;
  final String? capturedPath;
  final VoidCallback onCapture;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    if (capturedPath != null) {
      final isSimulated = capturedPath!.startsWith('simulated_');
      return Container(
        height: 300.h,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isSimulated)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.settings_suggest_rounded,
                        size: 48.w,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'Simulated Image Captured',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        capturedPath!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Image.file(
                File(capturedPath!),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            Positioned(
              bottom: 16.h,
              child: FilledButton.icon(
                onPressed: onRetake,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retake'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Camera not captured yet
    return Container(
      height: 300.h,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        color: Colors.black,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (cameraInitialized && controller != null)
            CameraPreview(controller!)
          else if (cameraInitializing)
            const Center(child: CircularProgressIndicator())
          else
            // Fallback for Desktop/Simulator where availableCameras() is empty or fails
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    Theme.of(context).colorScheme.surfaceContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.no_photography_rounded,
                        size: 48.w,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'No Camera Available',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Simulator / Desktop Fallback is active. You can still test this flow.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Face registration guide overlay
          if (cameraInitialized && controller != null)
            Positioned.fill(
              child: CustomPaint(
                painter: _FaceGuidePainter(
                  borderColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
            ),
          // Trigger button
          Positioned(
            bottom: 16.h,
            child: FloatingActionButton(
              heroTag: UniqueKey(),
              onPressed: onCapture,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              child: const Icon(Icons.camera_alt_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceGuidePainter extends CustomPainter {
  _FaceGuidePainter({required this.borderColor});
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Draw dark overlay with transparent oval cutout in the middle
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.65,
      height: size.height * 0.7,
    );

    final ovalPath = Path()..addOval(ovalRect);
    final combinedPath = Path.combine(PathOperation.difference, path, ovalPath);

    canvas.drawPath(combinedPath, paint);

    // Draw the oval border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawOval(ovalRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value.isEmpty ? 'Not provided' : value),
    );
  }
}
