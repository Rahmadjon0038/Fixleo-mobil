import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/core/media/avatar_picker.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/core/network/current_user.dart';
import 'package:fixleo/features/master/data/master_model.dart';
import 'package:fixleo/features/master/data/master_service.dart';

/// Edit screen for the master's persistent profile. A master may replace their
/// required photo, but there is intentionally no delete action.
class MasterEditProfileScreen extends StatefulWidget {
  const MasterEditProfileScreen({super.key, required this.master});

  final Master master;

  @override
  State<MasterEditProfileScreen> createState() =>
      _MasterEditProfileScreenState();
}

class _MasterEditProfileScreenState extends State<MasterEditProfileScreen> {
  final _service = MasterService();
  final _picker = ImagePicker();
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _experience;
  late final TextEditingController _bio;
  String? _newPhotoPath;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.master.name ?? '');
    _city = TextEditingController(text: widget.master.city ?? '');
    _experience = TextEditingController(
      text: widget.master.experienceYears?.toString() ?? '',
    );
    _bio = TextEditingController(text: widget.master.bio ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _experience.dispose();
    _bio.dispose();
    super.dispose();
  }

  bool get _valid {
    final experience = int.tryParse(_experience.text.trim());
    return _name.text.trim().length >= 3 &&
        _city.text.trim().length >= 2 &&
        experience != null &&
        experience >= 0 &&
        experience <= 80;
  }

  Future<void> _pickPhoto() async {
    if (_saving) return;
    final lang = LocaleController.language.value;
    final source = await showGlassModalBottomSheet<ImageSource>(
      context: context,
      topRadius: 24,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                tr(
                  lang,
                  'Galereyadan tanlash',
                  'Выбрать из галереи',
                  'Choose from gallery',
                ),
              ),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(
                tr(lang, 'Kamera bilan olish', 'Сделать фото', 'Take a photo'),
              ),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final path = await pickAndCropAvatar(picker: _picker, source: source);
    if (path != null && mounted) setState(() => _newPhotoPath = path);
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_newPhotoPath != null) {
        await _service.uploadAvatar(_newPhotoPath!);
      }
      var updated = await _service.updateProfile(
        name: _name.text.trim(),
        city: _city.text.trim(),
        experienceYears: int.parse(_experience.text.trim()),
      );
      updated = await _service.updateAbout(_bio.text.trim());
      await CurrentUser.instance.refresh();
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            LocaleController.language.value,
            'Tarmoq xatosi',
            'Ошибка сети',
            'Network error',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocaleController.language.value;
    return BrandedScaffold(
      title: tr(
        lang,
        'Profilni tahrirlash',
        'Редактировать профиль',
        'Edit profile',
      ),
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: _avatar()),
                    const SizedBox(height: 20),
                    _label(
                      tr(lang, 'Ism va familiya', 'Имя и фамилия', 'Full name'),
                    ),
                    _field(_name, TextInputType.name),
                    const SizedBox(height: 12),
                    _label(tr(lang, 'Shahar', 'Город', 'City')),
                    _field(_city, TextInputType.streetAddress),
                    const SizedBox(height: 12),
                    _label(
                      tr(
                        lang,
                        'Ish tajribasi, yil',
                        'Опыт работы, лет',
                        'Work experience, years',
                      ),
                    ),
                    _field(
                      _experience,
                      TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 12),
                    _label(tr(lang, 'Oʻzim haqimda', 'О себе', 'About me')),
                    _field(_bio, TextInputType.multiline, maxLines: 5),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            PrimaryButton(
              label: _saving
                  ? tr(lang, 'Saqlanmoqda...', 'Сохранение...', 'Saving...')
                  : tr(
                      lang,
                      'Oʻzgarishlarni saqlash',
                      'Сохранить изменения',
                      'Save changes',
                    ),
              onPressed: _valid && !_saving ? _save : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          LiquidSurface(
            width: 104,
            height: 104,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(28),
            ),
            child: _newPhotoPath != null
                ? Image.file(File(_newPhotoPath!), fit: BoxFit.cover)
                : widget.master.avatarUrl != null
                ? Image.network(
                    widget.master.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.person,
                      size: 54,
                      color: AppColors.muted,
                    ),
                  )
                : const Icon(Icons.person, size: 54, color: AppColors.muted),
          ),
          Positioned(
            right: -5,
            bottom: -5,
            child: LiquidSurface(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.navy,
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    TextInputType keyboardType, {
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return GlassTextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      height: maxLines > 1 ? null : 56,
      onChanged: (_) => setState(() => _error = null),
    );
  }
}
