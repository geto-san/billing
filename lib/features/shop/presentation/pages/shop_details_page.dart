import 'dart:io';

import 'package:billing_app/core/widgets/input_label.dart';
import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/shop.dart';
import '../bloc/shop_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';

class ShopDetailsPage extends StatefulWidget {
  const ShopDetailsPage({super.key});

  @override
  State<ShopDetailsPage> createState() => _ShopDetailsPageState();
}

class _ShopDetailsPageState extends State<ShopDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  String _avatarPath = '';
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    context.read<ShopBloc>().add(LoadShopEvent());
  }

  void _updateControllers(Shop shop) {
    if (_loadedOnce) return;
    _loadedOnce = true;
    _nameController.text = shop.name;
    _phoneController.text = shop.phoneNumber;
    _avatarPath = shop.avatarPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    final docs = await getApplicationDocumentsDirectory();
    final dest = File(
        '${docs.path}/shop_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(picked.path).copy(dest.path);
    if (!mounted) return;
    setState(() => _avatarPath = dest.path);
  }

  void _saveShop() {
    if (_formKey.currentState!.validate()) {
      final shop = Shop(
        name: _nameController.text,
        phoneNumber: _phoneController.text,
        avatarPath: _avatarPath,
      );
      context.read<ShopBloc>().add(UpdateShopEvent(shop));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Shop Details'),
        ),
        body: BlocConsumer<ShopBloc, ShopState>(
          listener: (context, state) {
            if (state is ShopLoaded) {
              _updateControllers(state.shop);
              setState(() {});
            } else if (state is ShopOperationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Shop details saved!'),
                  backgroundColor: Colors.green));
              context.pop();
            } else if (state is ShopError) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(state.message), backgroundColor: Colors.red));
            }
          },
          buildWhen: (previous, current) =>
              current is ShopLoading || current is ShopLoaded,
          builder: (context, state) {
            if (state is ShopLoading && !_loadedOnce) {
              return const Center(child: CircularProgressIndicator());
            }

            final avatarFile =
                _avatarPath.isNotEmpty ? File(_avatarPath) : null;
            final hasFile = avatarFile != null && avatarFile.existsSync();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickAvatar,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: AppTheme.primaryColor,
                              backgroundImage:
                                  hasFile ? FileImage(avatarFile) : null,
                              child: hasFile
                                  ? null
                                  : const Icon(Icons.storefront,
                                      color: Colors.white, size: 36),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the photo to choose any avatar you like',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 24),
                    Text('Shop information',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: AppTheme.primaryColor.withOpacity(0.8),
                        )),
                    const SizedBox(height: 16),
                    const InputLabel(text: 'Shop Name'),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'e.g. Kampala Kiosk',
                      validator: AppValidators.required('Required'),
                    ),
                    const SizedBox(height: 15),
                    const InputLabel(text: 'Phone Number'),
                    _buildTextField(
                      controller: _phoneController,
                      hint: '+256 700 000000',
                      keyboardType: TextInputType.phone,
                      validator: AppValidators.required('Required'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: PrimaryButton(
          onPressed: _saveShop,
          icon: Icons.save,
          label: 'Save Details',
        ));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.words,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
      ),
    );
  }
}
