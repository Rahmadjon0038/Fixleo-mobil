import 'package:fixleo/app/widgets/app_feedback.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/master/data/master_service.dart';
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
  final _service = MasterService();
  XFile? _photo;
  bool _loading = false;

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

  /// Uploads the mandatory profile photo, saves the optional bio, then moves on.
  Future<void> _next() async {
    if (_loading) return;
    if (_photo == null) {
      final lang = LocaleController.language.value;
      AppFeedback.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              tr(
                lang,
                'Profil rasmini tanlang',
                'Выберите фото профиля',
                'Choose a profile photo',
              ),
            ),
          ),
        );
      return;
    }
    setState(() => _loading = true);
    try {
      await _service.uploadAvatar(_photo!.path);
      final bio = _about.text.trim();
      if (bio.isNotEmpty) {
        await _service.updateAbout(bio);
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MasterCategoriesScreen()));
    } on ApiException catch (e) {
      if (!mounted) return;
      AppFeedback.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      final lang = LocaleController.language.value;
      AppFeedback.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(lang, 'Tarmoq xatosi', 'Ошибка сети', 'Network error'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(lang, 'Profil', 'Профиль', 'Profile'),
      showBack: true,
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 28),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PhotoCard(file: _photo, onTap: _pickPhoto),
                  const SizedBox(height: 12),
                  _AboutCard(controller: _about),
                  const Spacer(),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: _loading
                        ? tr(
                            lang,
                            'Saqlanmoqda...',
                            'Сохранение...',
                            'Saving...',
                          )
                        : tr(
                            lang,
                            'Saqlash va davom etish',
                            'Сохранить и продолжить',
                            'Save and continue',
                          ),
                    onPressed: _loading ? null : _next,
                  ),
                ],
              ),
            ),
          ),
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
    final lang = LocaleController.language.value;
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        width: double.infinity,
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Placeholder tile grows into a bigger preview once a photo is
            // picked (matches the two states in the design).
            LiquidSurface(
              width: file != null ? 100 : 66,
              height: file != null ? 100 : 66,
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
            const SizedBox(height: 8),
            Text(
              file != null
                  ? tr(
                      lang,
                      'Rasmni oʻzgartirish uchun rasmga bosing',
                      'Нажмите на фото, чтобы изменить его',
                      'Tap the photo to change it',
                    )
                  : tr(lang, 'Rasm qoʻshish', 'Добавить фото', 'Add photo'),
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
    final lang = LocaleController.language.value;
    return GlassContainer(
      width: double.infinity,
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(lang, 'Oʻzim haqimda', 'О себе', 'About me'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 10),
          GlassContainer.lite(
            height: 140,
            borderRadius: 20,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller,
              scrollPadding: const EdgeInsets.only(bottom: 120),
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
                hintText: tr(
                  lang,
                  'Tajribali santexnik. Ozoda ishlayman, oʻz asboblarim bor.',
                  'Опытный сантехник. Работаю аккуратно, есть свой инструмент.',
                  'Experienced plumber. I work neatly and have my own tools.',
                ),
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
