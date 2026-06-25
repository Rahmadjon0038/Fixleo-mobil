import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/master/presentation/master_categories_screen.dart';

/// Second master onboarding step — profile photo and an "about me" blurb.
class MasterProfileScreen extends StatefulWidget {
  const MasterProfileScreen({super.key});

  @override
  State<MasterProfileScreen> createState() => _MasterProfileScreenState();
}

class _MasterProfileScreenState extends State<MasterProfileScreen> {
  final _picker = ImagePicker();
  final _about = TextEditingController();
  XFile? _photo;

  @override
  void dispose() {
    _about.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() => _photo = file);
  }

  void _next() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MasterCategoriesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Profil',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PhotoCard(file: _photo, onTap: _pickPhoto),
            const SizedBox(height: 12),
            _AboutCard(controller: _about),
            const Spacer(),
            PrimaryButton(label: 'Saqlash va davom etish', onPressed: _next),
          ],
        ),
      ),
    );
  }
}

/// White card with a tappable avatar placeholder (or the chosen photo) and
/// an "add photo" caption.
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.file, required this.onTap});

  final XFile? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 148,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: file != null
                  ? Image.file(File(file!.path), fit: BoxFit.cover)
                  : const Icon(
                      Icons.photo_camera_outlined,
                      size: 30,
                      color: AppColors.navy,
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              file != null ? 'Rasmni oʻzgartirish' : 'Rasm qoʻshish',
              style: const TextStyle(fontSize: 14, color: AppColors.navy),
            ),
          ],
        ),
      ),
    );
  }
}

/// White card holding the multiline "about me" text area.
class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Oʻzim haqimda',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 140,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.navy,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText:
                    'Tajribali santexnik. Ozoda ishlayman, oʻz asboblarim bor.',
                hintStyle: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
