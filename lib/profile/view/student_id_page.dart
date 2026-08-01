import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:conecta_itt/profile/widgets/widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Digital student identification inspired by the physical campus credential.
///
/// This first version is visual only. The photograph and secure validation QR
/// will be implemented in later profile blocks.
class StudentIdPage extends StatefulWidget {
  const StudentIdPage({super.key});

  @override
  State<StudentIdPage> createState() => _StudentIdPageState();
}

class _StudentIdPageState extends State<StudentIdPage> {
  final PageController _pageController = PageController();

  int _selectedSide = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identificación digital')),
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<AppBloc, AppState>(
          buildWhen:
              (previous, current) =>
                  previous.institutionalProfile != current.institutionalProfile,
          builder: (context, state) {
            final profile = state.institutionalProfile;

            if (profile == null) {
              return const _UnavailableIdentification(
                message: 'No fue posible consultar tu perfil institucional.',
              );
            }

            if (!_hasAcademicIdentity(profile)) {
              return const _UnavailableIdentification(
                message:
                    'Completa tu información académica antes de consultar '
                    'la identificación digital.',
              );
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                132 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Text(
                  'Identificación digital del estudiante',
                  textAlign: TextAlign.center,
                  style: AppTextStyle.h4.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Desliza para consultar el frente y reverso.',
                  textAlign: TextAlign.center,
                  style: AppTextStyle.body.copyWith(
                    color: Theme.of(context).extension<AppColors>()!.deactive,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 590,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged:
                        (index) => setState(() => _selectedSide = index),
                    children: [
                      _StudentIdFront(profile: profile),
                      _StudentIdBack(profile: profile),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _PageIndicator(selectedIndex: _selectedSide),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _selectedSide == 0
                                ? null
                                : () => _pageController.animateToPage(
                                  0,
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOutCubic,
                                ),
                        icon: const Icon(Icons.badge_outlined),
                        label: const Text('Ver frente'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            _selectedSide == 1
                                ? null
                                : () => _pageController.animateToPage(
                                  1,
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOutCubic,
                                ),
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: const Text('Ver reverso'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF003B5C),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_selectedSide == 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  _ProfilePhotoAction(profile: profile),
                ],
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Identificación digital de Conecta ITT para '
                          'validaciones internas. Su aceptación depende del '
                          'área o servicio institucional correspondiente.',
                          style: TextStyle(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _ProfilePhotoAction extends StatefulWidget {
  const _ProfilePhotoAction({required this.profile});

  final AppUserProfile profile;

  @override
  State<_ProfilePhotoAction> createState() => _ProfilePhotoActionState();
}

class _ProfilePhotoActionState extends State<_ProfilePhotoAction> {
  bool _isSubmitting = false;

  Future<void> _selectAndSubmitPhoto() async {
    if (_isSubmitting) {
      return;
    }

    final source = await _selectPhotoSource(context);

    if (source == null || !mounted) {
      return;
    }

    final repository = context.read<StudentProfilePhotoRepository>();

    try {
      final selectedFile = await repository.pickAndPreparePhoto(source: source);

      if (selectedFile == null || !mounted) {
        return;
      }

      final confirmed = await _previewAndConfirmPhoto(
        context,
        file: selectedFile,
        replacing: widget.profile.hasProfilePhoto,
      );

      if (!confirmed || !mounted) {
        return;
      }

      setState(() => _isSubmitting = true);

      final updatedProfile = await repository.submitPhoto(
        uid: widget.profile.uid,
        file: selectedFile,
        previousPhotoPath: widget.profile.photoPath,
      );

      if (!mounted) {
        return;
      }

      context.read<AppBloc>().add(
        AppInstitutionalProfileChanged(updatedProfile),
      );

      await _showMessage(
        'Fotografía enviada correctamente. '
        'Quedó pendiente de validación.',
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }

      await _showError(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      await _showError(
        'No fue posible subir la fotografía. '
        'Verifica tu conexión e inténtalo nuevamente.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showMessage(String message, {bool isError = false}) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (messenger != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor:
                isError ? Theme.of(context).colorScheme.error : null,
          ),
        );
      return;
    }

    await showCupertinoDialog<void>(
      context: context,
      builder:
          (dialogContext) => CupertinoAlertDialog(
            title: Text(
              isError
                  ? 'No fue posible completar la acción'
                  : 'Fotografía actualizada',
            ),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(message),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Aceptar'),
              ),
            ],
          ),
    );
  }

  Future<void> _showError(String message) {
    return _showMessage(message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final status = _photoStatusPresentation(profile);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(status.icon, color: status.color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status.description,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profile.isProfilePhotoRejected &&
              profile.photoRejectionReason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                profile.photoRejectionReason!.trim(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _selectAndSubmitPhoto,
              icon:
                  _isSubmitting
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Icon(
                        profile.hasProfilePhoto
                            ? Icons.change_circle_outlined
                            : Icons.add_a_photo_outlined,
                      ),
              label: Text(
                _isSubmitting
                    ? 'Subiendo fotografía...'
                    : profile.hasProfilePhoto
                    ? 'Cambiar fotografía'
                    : 'Agregar fotografía',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF003B5C),
                side: const BorderSide(color: Color(0xFF003B5C)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoStatusPresentation {
  const _PhotoStatusPresentation({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
}

_PhotoStatusPresentation _photoStatusPresentation(AppUserProfile profile) {
  return switch (profile.photoStatus) {
    'pending' => const _PhotoStatusPresentation(
      icon: Icons.schedule_rounded,
      color: Colors.orange,
      title: 'Fotografía pendiente de validación',
      description:
          'La imagen ya aparece en tu credencial mientras '
          'se realiza la revisión institucional.',
    ),
    'approved' => const _PhotoStatusPresentation(
      icon: Icons.verified_rounded,
      color: Colors.green,
      title: 'Fotografía validada',
      description:
          'La fotografía fue aprobada para tu '
          'identificación digital.',
    ),
    'rejected' => const _PhotoStatusPresentation(
      icon: Icons.cancel_outlined,
      color: Colors.red,
      title: 'Fotografía rechazada',
      description:
          'Selecciona una nueva fotografía que cumpla '
          'con los requisitos institucionales.',
    ),
    _ => const _PhotoStatusPresentation(
      icon: Icons.account_box_outlined,
      color: Color(0xFF003B5C),
      title: 'Fotografía no registrada',
      description:
          'Agrega una fotografía frontal y clara para '
          'personalizar tu identificación digital.',
    ),
  };
}

Future<StudentProfilePhotoSource?> _selectPhotoSource(BuildContext context) {
  return showModalBottomSheet<StudentProfilePhotoSource>(
    context: context,
    showDragHandle: true,
    builder:
        (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Seleccionar fotografía',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'La imagen se recortará en formato vertical antes '
                  'de enviarse.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Tomar fotografía'),
                  subtitle: const Text('Usar la cámara del dispositivo'),
                  onTap:
                      () => Navigator.of(
                        sheetContext,
                      ).pop(StudentProfilePhotoSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Elegir de galería'),
                  subtitle: const Text('Seleccionar una imagen existente'),
                  onTap:
                      () => Navigator.of(
                        sheetContext,
                      ).pop(StudentProfilePhotoSource.gallery),
                ),
              ],
            ),
          ),
        ),
  );
}

Future<bool> _previewAndConfirmPhoto(
  BuildContext context, {
  required PlatformFile file,
  required bool replacing,
}) async {
  final bytes = file.bytes;

  if (bytes == null || bytes.isEmpty) {
    return false;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: Text(
            replacing ? 'Confirmar nueva fotografía' : 'Confirmar fotografía',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: Image.memory(bytes, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                replacing
                    ? 'La fotografía actual será sustituida y la nueva '
                        'quedará pendiente de validación.'
                    : 'Esta fotografía se utilizará en tu identificación '
                        'digital y quedará pendiente de validación.',
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF003B5C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Usar fotografía'),
            ),
          ],
        ),
  );

  return confirmed ?? false;
}

class _StudentIdFront extends StatelessWidget {
  const _StudentIdFront({required this.profile});

  final AppUserProfile profile;

  @override
  Widget build(BuildContext context) {
    final displayName = _displayValue(profile.displayName, 'Usuario');
    final career = _careerLabel(profile.careerId);
    final controlNumber = _displayValue(profile.controlNumber, 'No registrado');
    final semester =
        profile.semester == null
            ? 'Semestre no registrado'
            : '${profile.semester}.º semestre';
    final group = _displayValue(profile.groupId, 'Sin grupo').toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: const Color(0xFF003B5C).withValues(alpha: 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF002A43),
                    Color(0xFF003B5C),
                    Color(0xFF075578),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/branding/'
                        'conecta_itt_splash_android12.png',
                        width: 52,
                        height: 52,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'IDENTIFICACIÓN DIGITAL',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'TecNM Campus Tlalpan',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  StudentProfilePhoto(
                    profile: profile,
                    initials: _initials(displayName),
                    width: 142,
                    height: 172,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    displayName.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _CredentialStatus(active: profile.active),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned(
                    right: -42,
                    bottom: -45,
                    child: Icon(
                      Icons.school_outlined,
                      size: 190,
                      color: const Color(0xFF003B5C).withValues(alpha: 0.045),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CredentialData(
                          label: 'Número de control',
                          value: controlNumber,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _CredentialData(
                          label: 'Carrera',
                          value: career,
                          maxLines: 3,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: _CredentialCompactData(
                                label: 'Semestre',
                                value: semester,
                              ),
                            ),
                            Container(
                              height: 42,
                              width: 1,
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.55),
                            ),
                            Expanded(
                              child: _CredentialCompactData(
                                label: 'Grupo',
                                value: group,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const _InstitutionalFooter(),
          ],
        ),
      ),
    );
  }
}

class _StudentIdBack extends StatelessWidget {
  const _StudentIdBack({required this.profile});

  final AppUserProfile profile;

  @override
  Widget build(BuildContext context) {
    final controlNumber = _displayValue(profile.controlNumber, 'No registrado');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFB), Color(0xFFEAF1F4)],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: const Color(0xFF003B5C).withValues(alpha: 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xlg),
              color: const Color(0xFF003B5C),
              child: Column(
                children: [
                  Image.asset(
                    'assets/branding/'
                    'conecta_itt_splash_android12.png',
                    width: 64,
                    height: 64,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'VALIDACIÓN INSTITUCIONAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Conecta ITT · TecNM Campus Tlalpan',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 184,
                      height: 184,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(
                            0xFF003B5C,
                          ).withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_2_rounded,
                            size: 90,
                            color: Color(0xFF003B5C),
                          ),
                          SizedBox(height: AppSpacing.md),
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              'QR seguro\npróximamente',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: TextStyle(
                                color: Color(0xFF003B5C),
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _BackDataRow(
                      label: 'Número de control',
                      value: controlNumber,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _BackDataRow(
                      label: 'Estado',
                      value:
                          profile.active
                              ? 'Identificación activa'
                              : 'Identificación inactiva',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _BackDataRow(
                      label: 'Vigencia',
                      value: 'Pendiente de configuración institucional',
                    ),
                    const Spacer(),
                    Text(
                      'El código de validación será dinámico y tendrá una '
                      'vigencia limitada para evitar reutilización o '
                      'suplantación mediante capturas de pantalla.',
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const _InstitutionalFooter(),
          ],
        ),
      ),
    );
  }
}

class _CredentialStatus extends StatelessWidget {
  const _CredentialStatus({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:
            active
                ? Colors.green.withValues(alpha: 0.18)
                : Colors.red.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              active
                  ? Colors.greenAccent.withValues(alpha: 0.65)
                  : Colors.redAccent.withValues(alpha: 0.65),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.verified_rounded : Icons.block_rounded,
            size: 17,
            color: Colors.white,
          ),
          const SizedBox(width: 7),
          Text(
            active ? 'ESTUDIANTE ACTIVO' : 'IDENTIFICACIÓN INACTIVA',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CredentialData extends StatelessWidget {
  const _CredentialData({
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CredentialCompactData extends StatelessWidget {
  const _CredentialCompactData({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _BackDataRow extends StatelessWidget {
  const _BackDataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFF002A43),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _InstitutionalFooter extends StatelessWidget {
  const _InstitutionalFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 16,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF002A43), Color(0xFF075578)],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        2,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: selectedIndex == index ? 28 : 9,
          height: 9,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color:
                selectedIndex == index
                    ? const Color(0xFF003B5C)
                    : const Color(0xFF003B5C).withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _UnavailableIdentification extends StatelessWidget {
  const _UnavailableIdentification({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.badge_outlined,
              size: 72,
              color: Color(0xFF003B5C),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyle.body.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

bool _hasAcademicIdentity(AppUserProfile profile) {
  return profile.isStudent ||
      (profile.controlNumber?.trim().isNotEmpty ?? false) ||
      (profile.careerId?.trim().isNotEmpty ?? false) ||
      profile.semester != null ||
      (profile.groupId?.trim().isNotEmpty ?? false);
}

String _careerLabel(String? careerId) {
  final normalized = careerId?.trim();

  if (normalized == null || normalized.isEmpty) {
    return 'Carrera no registrada';
  }

  return InstitutionalCareers.labelFor(normalized);
}

String _displayValue(String? value, String fallback) {
  final normalized = value?.trim();

  if (normalized == null || normalized.isEmpty) {
    return fallback;
  }

  return normalized;
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) {
    return 'U';
  }

  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }

  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
