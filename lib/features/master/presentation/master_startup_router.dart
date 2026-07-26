import 'package:flutter/material.dart';

import 'package:fixleo/features/master/data/master_document_model.dart';
import 'package:fixleo/features/master/data/master_model.dart';
import 'package:fixleo/features/master/data/master_service.dart';
import 'package:fixleo/features/master/presentation/master_categories_screen.dart';
import 'package:fixleo/features/master/presentation/master_documents_screen.dart';
import 'package:fixleo/features/master/presentation/master_home_screen.dart';
import 'package:fixleo/features/master/presentation/master_profile_screen.dart';
import 'package:fixleo/features/master/presentation/master_register_screen.dart';
import 'package:fixleo/features/master/presentation/master_selfie_screen.dart';
import 'package:fixleo/features/master/presentation/master_verification_screen.dart';
import 'package:fixleo/features/master/presentation/master_work_zone_screen.dart';

/// Resolves where a master should resume after login / app restart.
///
/// The backend can return a partially completed master profile. Instead of
/// dumping the user back into the first onboarding page, this walks the saved
/// data and returns the first missing step.
Future<Widget> resolveMasterStartupScreen(
  MasterService service,
  Master master,
) async {
  if (master.verificationStatus == VerificationStatus.approved) {
    return MasterHomeScreen(initialMaster: master, masterService: service);
  }

  if (master.verificationStatus == VerificationStatus.pending) {
    return const MasterVerificationScreen(submitOnOpen: false);
  }

  if (!_hasBasicProfile(master)) {
    return MasterRegisterScreen(
      initialName: master.name,
      initialCity: master.city,
      initialExperienceYears: master.experienceYears,
    );
  }

  if (!_hasBio(master)) {
    return const MasterProfileScreen();
  }

  if (!_hasCategories(master)) {
    return const MasterCategoriesScreen();
  }

  if (!_hasWorkZone(master)) {
    return const MasterWorkZoneScreen();
  }

  final documents = await _safeDocuments(service);
  if (!_hasRequiredDocuments(documents)) {
    return const MasterDocumentsScreen();
  }

  if (!_hasSelfie(documents)) {
    return const MasterSelfieScreen();
  }

  return const MasterVerificationScreen();
}

bool _hasBasicProfile(Master master) =>
    (master.name ?? '').trim().isNotEmpty &&
    (master.city ?? '').trim().isNotEmpty &&
    master.experienceYears != null;

bool _hasBio(Master master) => (master.bio ?? '').trim().isNotEmpty;

bool _hasCategories(Master master) => master.categories.isNotEmpty;

bool _hasWorkZone(Master master) =>
    master.latitude != null &&
    master.longitude != null &&
    master.workRadiusKm != null;

Future<List<MasterDocument>> _safeDocuments(MasterService service) async {
  try {
    return await service.documents();
  } catch (_) {
    return const [];
  }
}

bool _hasRequiredDocuments(List<MasterDocument> documents) {
  final types = documents.map((d) => d.type).toSet();
  return types.contains(MasterDocumentType.passportFront) &&
      types.contains(MasterDocumentType.passportBack);
}

bool _hasSelfie(List<MasterDocument> documents) {
  return documents.any((d) => d.type == MasterDocumentType.selfieWithPassport);
}
