import 'dart:io' show File;
import 'dart:math' show min;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, EmailAuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../../auth/data/app_user.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../users/data/cloudinary_service.dart';
import '../../../users/data/face_capture_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  // Change password fields
  final _changePasswordFormKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isUpdatingPassword = false;

  final _faceCaptureService = FaceCaptureService();
  final _cloudinaryService = CloudinaryService();

  bool _isSavingDetails = false;
  bool _isSavingPhoto = false;
  bool _isSavingFace = false;

  // Camera fields for Face ID registration
  bool _isCameraActive = false;
  CameraController? _cameraController;
  bool _cameraInitializing = false;
  bool _cameraInitialized = false;
  String? _tempFacePath;
  Map<String, dynamic>? _capturedFaceData;

  // Department & Team names
  String _departmentName = 'Loading...';
  String _teamName = 'Loading...';
  String? _lastResolvedDeptId;
  String? _lastResolvedTeamId;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthBloc>().state.user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthBloc>().state.user;
    if (user != null) {
      _resolveDirectoryNames(user.organizationId, user.departmentId, user.teamId);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _disposeCamera();
    super.dispose();
  }

  Future<void> _resolveDirectoryNames(String orgId, String? deptId, String? teamId) async {
    if (deptId == null || deptId.isEmpty) {
      if (mounted) setState(() => _departmentName = 'Not Assigned');
    } else if (deptId != _lastResolvedDeptId) {
      _lastResolvedDeptId = deptId;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgId)
            .collection('departments')
            .doc(deptId)
            .get();
        if (mounted) {
          setState(() {
            _departmentName = doc.data()?['name'] as String? ?? 'Unknown Department';
          });
        }
      } catch (_) {
        if (mounted) setState(() => _departmentName = 'Error loading');
      }
    }

    if (teamId == null || teamId.isEmpty) {
      if (mounted) setState(() => _teamName = 'Not Assigned');
    } else if (teamId != _lastResolvedTeamId) {
      _lastResolvedTeamId = teamId;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgId)
            .collection('teams')
            .doc(teamId)
            .get();
        if (mounted) {
          setState(() {
            _teamName = doc.data()?['name'] as String? ?? 'Unknown Team';
          });
        }
      } catch (_) {
        if (mounted) setState(() => _teamName = 'Error loading');
      }
    }
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

  Future<void> _pickProfilePhoto(ImageSource source, AppUser user) async {
    Navigator.of(context).pop(); // Dismiss bottom sheet
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (image != null) {
        setState(() => _isSavingPhoto = true);
        final secureUrl = await _cloudinaryService.uploadProfilePhoto(image.path, user.organizationId);

        final batch = FirebaseFirestore.instance.batch();
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.id);
        final faceRef = FirebaseFirestore.instance.collection('faceRegistrations').doc(user.id);

        batch.update(userRef, {
          'profileImageUrl': secureUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        batch.set(faceRef, {
          'profileImageUrl': secureUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await batch.commit();

        // Refresh authentication session to sync UI
        await FirebaseAuth.instance.currentUser?.reload();
        if (mounted) {
          context.read<AuthBloc>().add(AuthSessionRequested());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated successfully!')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading profile photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingPhoto = false);
      }
    }
  }

  void _showPhotoOptions(AppUser user) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () => _pickProfilePhoto(ImageSource.gallery, user),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () => _pickProfilePhoto(ImageSource.camera, user),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDetails(AppUser user) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSavingDetails = true);
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.id);
      await userRef.update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Sync local user session
      await FirebaseAuth.instance.currentUser?.reload();
      if (mounted) {
        context.read<AuthBloc>().add(AuthSessionRequested());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Details saved successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error saving details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save details: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingDetails = false);
      }
    }
  }

  Future<void> _changePassword(AppUser appUser) async {
    if (!_changePasswordFormKey.currentState!.validate()) return;
    
    // Unfocus all current inputs and close keyboard
    FocusManager.instance.primaryFocus?.unfocus();
    
    // Open a simple dialog that pop/returns the password string synchronously.
    final currentPassword = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return const _ConfirmPasswordDialog();
      },
    );

    if (currentPassword == null || currentPassword.isEmpty) return;
    if (!mounted) return;

    // Run the Firebase operations sequentially on the main screen context.
    final outerScaffoldMessenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    
    setState(() => _isUpdatingPassword = true);
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null && firebaseUser.email != null) {
        // Step 1: Re-authenticate
        final credential = EmailAuthProvider.credential(
          email: firebaseUser.email!,
          password: currentPassword,
        );
        await firebaseUser.reauthenticateWithCredential(credential);
        
        // Step 2: Update Password
        await firebaseUser.updatePassword(_newPasswordController.text.trim());
        
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        outerScaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Password updated successfully!')),
        );
      } else {
        throw Exception('No authenticated firebase user session found.');
      }
    } catch (e) {
      outerScaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update password: $e'),
          backgroundColor: errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPassword = false);
      }
    }
  }

  Future<void> _captureFace() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      // Simulator/Desktop fallback
      final result = _faceCaptureService.createDesktopFallback();
      setState(() {
        _capturedFaceData = result.toMap();
        _tempFacePath = 'simulated_face_photo.jpg';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Desktop/Simulator mode: Simulated face captured.'),
        ),
      );
      return;
    }

    try {
      final XFile photo = await _cameraController!.takePicture();
      final result = await _faceCaptureService.detectAndValidateFace(photo.path);

      if (mounted) {
        if (result.success) {
          setState(() {
            _capturedFaceData = result.toMap();
            _tempFacePath = photo.path;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Face captured and validated successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.errorMessage ?? 'Face verification failed.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error taking face picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Face capture error: $e')),
        );
      }
    }
  }

  Future<void> _saveFaceData(AppUser user) async {
    if (_tempFacePath == null || _capturedFaceData == null) return;
    setState(() => _isSavingFace = true);
    try {
      String? faceImageUrl;
      final isSimulated = _tempFacePath!.startsWith('simulated_');

      if (!isSimulated) {
        // Upload face reference image to Cloudinary
        faceImageUrl = await _cloudinaryService.uploadFaceImage(_tempFacePath!, user.organizationId);
      } else {
        faceImageUrl = user.faceImageUrl ?? 'https://res.cloudinary.com/dvc7rmdyt/image/upload/v1/placeholder_face.jpg';
      }

      final updatedFaceMetadata = {
        ..._capturedFaceData!,
        'faceImageUrl': faceImageUrl,
      };

      final batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.id);
      final faceRef = FirebaseFirestore.instance.collection('faceRegistrations').doc(user.id);

      batch.update(userRef, {
        'faceImageUrl': faceImageUrl,
        'faceMetadata': updatedFaceMetadata,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(faceRef, {
        'userId': user.id,
        'organizationId': user.organizationId,
        'faceImageUrl': faceImageUrl,
        'faceMetadata': updatedFaceMetadata,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      // Sync session
      await FirebaseAuth.instance.currentUser?.reload();
      if (mounted) {
        context.read<AuthBloc>().add(AuthSessionRequested());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face ID registered successfully!')),
        );
        setState(() {
          _isCameraActive = false;
          _tempFacePath = null;
          _capturedFaceData = null;
        });
        _disposeCamera();
      }
    } catch (e) {
      debugPrint('Error saving Face ID: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save Face ID biometrics: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingFace = false);
      }
    }
  }

  Color get _mutedTextColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
  }

  Color get _fieldBackgroundColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.darkSurfaceMuted : AppColors.lightSurfaceMuted;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: const Center(child: Text('No active user profile found.')),
      );
    }

    final hasChanges = _nameController.text.trim() != user.name ||
        _phoneController.text.trim() != (user.phone ?? '');

    if (_isCameraActive) {
      return _buildCameraView(user);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          children: [
            // Profile Photo card
            _buildProfilePhotoCard(user),
            SizedBox(height: 16.h),

            // Details Edit card
            _buildDetailsCard(user, hasChanges),
            SizedBox(height: 16.h),

            // Change Password card
            _buildPasswordCard(user),
            SizedBox(height: 16.h),

            // Face ID Registration card
            _buildFaceIdCard(user),
            SizedBox(height: 16.h),

            // Administrative card
            _buildAdminCard(user),
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }

  Widget _buildProfilePhotoCard(AppUser user) {
    final theme = Theme.of(context);
    final size = 100.w;

    return PremiumCard(
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: size + 8.w,
                height: size + 8.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: EdgeInsets.all(4.w),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surface,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isSavingPhoto
                      ? const Center(child: CircularProgressIndicator())
                      : user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: user.profileImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            )
                          : Container(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              child: Center(
                                child: Text(
                                  user.name.trim().isEmpty ? 'U' : user.name.trim()[0].toUpperCase(),
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isSavingPhoto ? null : () => _showPhotoOptions(user),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary,
                      border: Border.all(color: theme.colorScheme.surface, width: 2.w),
                    ),
                    padding: EdgeInsets.all(6.w),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100.r),
                  ),
                  child: Text(
                    user.role.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(AppUser user, bool hasChanges) {
    final theme = Theme.of(context);
    return PremiumCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Personal Details',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              onChanged: (_) => setState(() {}),
              validator: (val) => val == null || val.trim().isEmpty ? 'Name cannot be empty' : null,
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_android_rounded),
              ),
              onChanged: (_) => setState(() {}),
              validator: (val) => val == null || val.trim().isEmpty ? 'Phone number is required' : null,
            ),
            SizedBox(height: 16.h),
            FilledButton.icon(
              onPressed: (hasChanges && !_isSavingDetails) ? () => _saveDetails(user) : null,
              icon: _isSavingDetails
                  ? SizedBox.square(dimension: 16.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceIdCard(AppUser user) {
    final theme = Theme.of(context);
    final isRegistered = user.faceImageUrl != null && user.faceImageUrl!.isNotEmpty;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isRegistered ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
                color: isRegistered ? AppColors.success : theme.colorScheme.error,
                size: 28.w,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  isRegistered ? 'Face ID Registered' : 'Face ID Not Registered',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            isRegistered
                ? 'Your biometric face profile is verified. You can use it to scan attendance at scanners.'
                : 'Register your face profile to sign-in securely and scan your attendance.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _mutedTextColor,
            ),
          ),
          if (isRegistered && user.faceMetadata != null) ...[
            SizedBox(height: 12.h),
            Divider(color: theme.colorScheme.outlineVariant),
            SizedBox(height: 8.h),
            if (user.faceMetadata!['qualityScore'] != null)
              _buildMetaRow('Capture Quality', '${((user.faceMetadata!['qualityScore'] as num) * 100).round()}%'),
            if (user.faceMetadata!['capturedAt'] != null)
              _buildMetaRow('Registered On', user.faceMetadata!['capturedAt'].toString().split('T')[0]),
          ],
          SizedBox(height: 14.h),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _isCameraActive = true;
                _tempFacePath = null;
                _capturedFaceData = null;
              });
              _initCamera();
            },
            icon: Icon(isRegistered ? Icons.refresh_rounded : Icons.face_rounded),
            label: Text(isRegistered ? 'Re-register Face ID' : 'Setup Face ID'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(AppUser user) {
    final theme = Theme.of(context);
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, color: theme.colorScheme.primary, size: 22.w),
              SizedBox(width: 8.w),
              Text(
                'Administrative Details',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildInfoRow('Email', user.email),
          _buildInfoRow('Employee / Roll ID', user.employeeId ?? 'Not Assigned'),
          _buildInfoRow('Department', _departmentName),
          _buildInfoRow('Team / Class', _teamName),
          SizedBox(height: 6.h),
          Text(
            'Note: Administrative details can only be modified by your organization manager.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: _mutedTextColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: _mutedTextColor)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: _mutedTextColor)),
          SizedBox(height: 2.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: _fieldBackgroundColor,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView(AppUser user) {
    final theme = Theme.of(context);
    final hasCaptured = _tempFacePath != null && _capturedFaceData != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Face ID Registration', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _isSavingFace
              ? null
              : () {
                  setState(() {
                    _isCameraActive = false;
                    _tempFacePath = null;
                    _capturedFaceData = null;
                  });
                  _disposeCamera();
                },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (hasCaptured) ...[
                        if (_tempFacePath!.startsWith('simulated_'))
                          Container(
                            color: theme.colorScheme.surfaceContainerHigh,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.face_retouching_natural_rounded, size: 64.w, color: theme.colorScheme.primary),
                                  SizedBox(height: 16.h),
                                  Text('Simulated Face Captured Successfully', style: theme.textTheme.titleMedium),
                                ],
                              ),
                            ),
                          )
                        else
                          Image.file(
                            File(_tempFacePath!),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                      ] else ...[
                        if (_cameraInitialized && _cameraController != null)
                          CameraPreview(_cameraController!)
                        else if (_cameraInitializing)
                          const Center(child: CircularProgressIndicator())
                        else
                          Container(
                            color: Colors.grey[900],
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24.w),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.no_photography_rounded, size: 48.w, color: Colors.grey),
                                    SizedBox(height: 12.h),
                                    const Text('No Camera Available', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    SizedBox(height: 6.h),
                                    const Text(
                                      'Simulator fallback is active. You can tap "Simulate Capture" below.',
                                      style: TextStyle(color: Colors.grey, fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (_cameraInitialized && _cameraController != null)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _FaceGuidePainter(
                                borderColor: theme.colorScheme.primary.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                      ],
                      if (_isSavingFace)
                        Container(
                          color: Colors.black54,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(),
                                SizedBox(height: 16.h),
                                const Text('Uploading Face ID Profile...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
              decoration: const BoxDecoration(
                color: Colors.black,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!hasCaptured) ...[
                    Text(
                      'Position your face in the center guide',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                    SizedBox(height: 20.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (!_cameraInitialized && !_cameraInitializing)
                          FilledButton.icon(
                            onPressed: _captureFace,
                            icon: const Icon(Icons.settings_suggest_rounded),
                            label: const Text('Simulate Capture'),
                            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.secondary),
                          )
                        else
                          IconButton(
                            onPressed: _captureFace,
                            iconSize: 52.w,
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                          ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      'Confirm Face ID settings',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                    if (_capturedFaceData != null && _capturedFaceData!['qualityScore'] != null) ...[
                      SizedBox(height: 6.h),
                      Text(
                        'Quality Score: ${((_capturedFaceData!['qualityScore'] as num) * 100).round()}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                    SizedBox(height: 20.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSavingFace
                                ? null
                                : () => setState(() {
                                      _tempFacePath = null;
                                      _capturedFaceData = null;
                                    }),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retake'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isSavingFace ? null : () => _saveFaceData(user),
                            icon: const Icon(Icons.cloud_upload_rounded),
                            label: const Text('Confirm & Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordCard(AppUser user) {
    final theme = Theme.of(context);
    return PremiumCard(
      child: Form(
        key: _changePasswordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Change Password',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'New password is required';
                if (val.length < 6) return 'Password must be at least 6 characters';
                return null;
              },
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: Icon(Icons.check_circle_outline_rounded),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Please confirm your new password';
                if (val != _newPasswordController.text) return 'Passwords do not match';
                return null;
              },
            ),
            SizedBox(height: 16.h),
            FilledButton.icon(
              onPressed: _isUpdatingPassword ? null : () => _changePassword(user),
              icon: _isUpdatingPassword
                  ? SizedBox.square(dimension: 16.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock_reset_rounded),
              label: const Text('Update Password'),
            ),
          ],
        ),
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
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.65,
      height: min(size.height * 0.65, size.width * 0.85),
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

class _ConfirmPasswordDialog extends StatefulWidget {
  const _ConfirmPasswordDialog();

  @override
  State<_ConfirmPasswordDialog> createState() => _ConfirmPasswordDialogState();
}

class _ConfirmPasswordDialogState extends State<_ConfirmPasswordDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Password Change'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('For security reasons, please enter your current password to authorize this action.'),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Current password is required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop(null);
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
