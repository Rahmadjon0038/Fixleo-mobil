import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/locale/app_locale.dart';

/// Picks a photo (gallery or camera) and lets the user crop/adjust it in a
/// square preview before it's uploaded as an avatar. Returns the cropped
/// file path, or `null` if the user cancelled at either step.
Future<String?> pickAndCropAvatar({
  required ImagePicker picker,
  required ImageSource source,
}) async {
  final picked = await picker.pickImage(
    source: source,
    imageQuality: 90,
    maxWidth: 2000,
  );
  if (picked == null) return null;

  final lang = LocaleController.language.value;
  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    maxWidth: 1200,
    maxHeight: 1200,
    compressQuality: 90,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: tr(
          lang,
          'Rasmni moslashtirish',
          'Настройка фото',
          'Adjust photo',
        ),
        toolbarColor: AppColors.navy,
        toolbarWidgetColor: AppColors.background,
        backgroundColor: AppColors.navy,
        activeControlsWidgetColor: AppColors.blue,
        lockAspectRatio: true,
      ),
      IOSUiSettings(
        title: tr(
          lang,
          'Rasmni moslashtirish',
          'Настройка фото',
          'Adjust photo',
        ),
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
      ),
    ],
  );
  return cropped?.path;
}
