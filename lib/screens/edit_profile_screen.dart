import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart'
    show MultipartFile; // <--- Pastikan ini diimport!
import 'package:http_parser/http_parser.dart'; // <--- Tambahkan ini untuk MediaType

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isUploading = false;
  File? _pickedImage;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  void _loadCurrentUserData() {
    if (pb.authStore.isValid && pb.authStore.model is RecordModel) {
      final user = pb.authStore.model as RecordModel;

      // --- DEBUGGING: Cetak objek user untuk melihat strukturnya ---
      print('EditProfile: User RecordModel raw: ${user.toJson()}');
      print('EditProfile: User ID: ${user.id}');
      print('EditProfile: User Username: ${user.data['username']}');
      print('EditProfile: User Email: ${user.data['email']}');
      print('EditProfile: User name from data: ${user.data['name']}');
      print('EditProfile: User bio from data: ${user.data['bio']}');
      print('EditProfile: User image from data: ${user.data['image']}');
      // --- END DEBUGGING ---

      setState(() {
        _nameController.text = user.data['name'] ?? user.data['username'] ?? '';
        _emailController.text = user.data['email'] ?? '';
        _bioController.text = user.data['bio'] ?? '';

        if (user.data['image'] != null && user.data['image'].isNotEmpty) {
          try {
            _currentImageUrl =
                pb.getFileUrl(user, user.data['image']).toString();
          } catch (e) {
            print('Error getting existing image URL in EditProfile: $e');
            _currentImageUrl = null;
          }
        } else {
          _currentImageUrl = null;
        }
      });
    } else {
      _nameController.text = '';
      _emailController.text = '';
      _bioController.text = '';
      _currentImageUrl = null;
      print('No authenticated user found for EditProfileScreen.');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Pilih Sumber Gambar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.photo_camera, color: AppTheme.primaryColor),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
        _currentImageUrl = null;
      });
    }
  }

  void _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text('Menyimpan perubahan...'),
          ],
        ),
      ),
    );

    try {
      final currentUser = pb.authStore.model as RecordModel?;

      if (currentUser == null) {
        throw Exception('User not logged in!');
      }

      final body = <String, dynamic>{
        'name': _nameController.text,
        'bio': _bioController.text,
      };

      // Siapkan list MultipartFile
      List<MultipartFile> filesToUpload = [];
      if (_pickedImage != null) {
        filesToUpload.add(
          await MultipartFile.fromPath(
            'image', // Pastikan ini sesuai dengan nama field di PocketBase
            _pickedImage!.path,
            filename: _pickedImage!.path.split('/').last,
            contentType: MediaType('image',
                'jpeg'), // import 'package:http_parser/http_parser.dart';
          ),
        );
      } else {
        // Jika tidak ada gambar baru yang dipilih dan pengguna ingin menghapus gambar lama,
        // Anda perlu secara eksplisit mengirim list kosong untuk field 'image'.
        // Contoh:
        // if (_currentImageUrl != null && _pickedImage == null && userPressedDeleteImage) {
        //   filesToUpload.add(MultipartFile.fromString('image', '')); // Mengirim string kosong untuk menghapus file
        // }
        // Atau:
        // filesToUpload.add(MultipartFile.fromBytes('image', [])); // Mengirim byte kosong
      }

      await pb.collection('users').update(
            currentUser.id,
            body: body,
            files: filesToUpload, // <--- Pass as List<MultipartFile>
          );

      // await pb.authStore.refresh(); // Removed because AuthStore has no 'refresh' method

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil diperbarui'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } on ClientException catch (e) {
      if (mounted) Navigator.pop(context);

      String errorMessage = 'Gagal menyimpan perubahan. Silakan coba lagi.';
      if (e.response['message'] != null) {
        errorMessage = e.response['message'].toString();
        if (e.response['data'] != null) {
          e.response['data'].forEach((key, value) {
            errorMessage += '\n${key}: ${value['message']}';
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('PocketBase Client Error: ${e.response}');
    } catch (e) {
      if (mounted) Navigator.pop(context);

      print('Unexpected Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan tak terduga: $e'),
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
        title: const Text('Edit Profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveChanges,
            child: const Text(
              'Simpan',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    _isUploading
                        ? Container(
                            width: 120,
                            height: 120,
                            decoration: const BoxDecoration(
                              color: AppTheme.surfaceColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          )
                        : CircleAvatar(
                            radius: 60,
                            backgroundColor: AppTheme.primaryColor,
                            backgroundImage: _pickedImage != null
                                ? FileImage(_pickedImage!)
                                : (_currentImageUrl != null
                                    ? NetworkImage(_currentImageUrl!)
                                    : null) as ImageProvider<Object>?,
                            child: (_pickedImage == null &&
                                    _currentImageUrl == null)
                                ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                    GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.backgroundColor,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildInputField(
                  label: 'Nama',
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nama tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email tidak boleh kosong';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Masukkan email yang valid';
                    }
                    return null;
                  },
                  readOnly: true,
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  label: 'Bio',
                  controller: _bioController,
                  maxLines: 3,
                  validator: (value) => null,
                ),
                const SizedBox(height: 24),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Preferensi Musik',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildGenreChip('Pop', true),
                    _buildGenreChip('Rock', false),
                    _buildGenreChip('Hip Hop', true),
                    _buildGenreChip('Jazz', false),
                    _buildGenreChip('Klasik', false),
                    _buildGenreChip('R&B', true),
                    _buildGenreChip('EDM', false),
                    _buildGenreChip('K-Pop', true),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Simpan Perubahan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          readOnly: readOnly,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.surfaceColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.errorColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenreChip(String label, bool isSelected) {
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        setState(() {
          // Logic for changing genre selection status
        });
      },
      backgroundColor: AppTheme.surfaceColor,
      selectedColor: AppTheme.primaryColor.withOpacity(0.3),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.white24,
        ),
      ),
    );
  }
}
