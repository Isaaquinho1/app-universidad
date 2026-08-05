import 'dart:async';
import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:conecta_itt/profile/widgets/widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

  late Future<ProfilePhotoAllowance> _allowanceFuture;

  @override
  void initState() {
    super.initState();
    _allowanceFuture = _loadAllowance();
  }

  @override
  void didUpdateWidget(_ProfilePhotoAction oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.profile.photoStatus != widget.profile.photoStatus ||
        oldWidget.profile.photoUpdatedAt != widget.profile.photoUpdatedAt) {
      _allowanceFuture = _loadAllowance();
    }
  }

  Future<ProfilePhotoAllowance> _loadAllowance() {
    return context.read<StudentProfilePhotoRepository>().getPhotoAllowance();
  }

  void _reloadAllowance() {
    setState(() {
      _allowanceFuture = _loadAllowance();
    });
  }

  Future<void> _selectAndSubmitPhoto() async {
    if (_isSubmitting) {
      return;
    }

    ProfilePhotoAllowance allowance;

    try {
      allowance = await _allowanceFuture;
    } catch (_) {
      if (!mounted) {
        return;
      }

      await _showError(
        'No fue posible consultar tus cambios disponibles. '
        'Actualiza la información e inténtalo nuevamente.',
      );
      return;
    }

    if (!mounted) {
      return;
    }

    if (!allowance.canSubmit) {
      final message =
          allowance.hasPendingSubmission
              ? 'Ya tienes una fotografía pendiente de revisión. '
                  'Espera la resolución antes de enviar otra.'
              : 'Has utilizado todos los cambios disponibles para '
                  '${allowance.academicPeriodName}.';

      await _showError(message);
      return;
    }

    final acceptedRequirements = await _confirmPhotoRequirements(
      context,
      replacing: allowance.hasInitialSubmission,
      remainingChanges: allowance.remainingChanges,
    );

    if (!acceptedRequirements || !mounted) {
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
      );

      if (!mounted) {
        return;
      }

      context.read<AppBloc>().add(
        AppInstitutionalProfileChanged(updatedProfile),
      );

      _reloadAllowance();

      await _showMessage(
        'Fotografía enviada correctamente. '
        'Quedó pendiente de validación institucional.',
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

    return FutureBuilder<ProfilePhotoAllowance>(
      future: _allowanceFuture,
      builder: (context, snapshot) {
        final allowance = snapshot.data;
        final loading =
            snapshot.connectionState == ConnectionState.waiting &&
            allowance == null;
        final allowanceError = snapshot.hasError && allowance == null;

        final canSubmit =
            !_isSubmitting && allowance != null && allowance.canSubmit;

        final buttonLabel =
            _isSubmitting
                ? 'Subiendo fotografía...'
                : loading
                ? 'Consultando disponibilidad...'
                : allowanceError
                ? 'No disponible'
                : allowance!.hasPendingSubmission
                ? 'Pendiente de revisión'
                : !allowance.canSubmit
                ? 'Límite de cambios alcanzado'
                : profile.hasProfilePhoto
                ? 'Cambiar fotografía'
                : 'Agregar fotografía';

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
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
              if (allowance != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allowance.academicPeriodName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        allowance.hasInitialSubmission
                            ? 'Cambios disponibles: '
                                '${allowance.remainingChanges} de '
                                '${allowance.totalLimit}'
                            : 'Tu primera fotografía no consume '
                                'ningún cambio.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      if (allowance.hasPendingSubmission) ...[
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'Debes esperar la revisión de la solicitud actual.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else if (allowanceError)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'No fue posible consultar los cambios disponibles.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      TextButton(
                        onPressed: _reloadAllowance,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: canSubmit ? _selectAndSubmitPhoto : null,
                  icon:
                      _isSubmitting || loading
                          ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Icon(
                            profile.hasProfilePhoto
                                ? Icons.change_circle_outlined
                                : Icons.add_a_photo_outlined,
                          ),
                  label: Text(buttonLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF003B5C),
                    side: const BorderSide(color: Color(0xFF003B5C)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

Future<bool> _confirmPhotoRequirements(
  BuildContext context, {
  required bool replacing,
  required int remainingChanges,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Requisitos de la fotografía'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PhotoRequirement(
                icon: Icons.wallpaper_outlined,
                text: 'Utiliza preferentemente un fondo blanco o claro.',
              ),
              const _PhotoRequirement(
                icon: Icons.light_mode_outlined,
                text: 'Colócate con buena iluminación frontal y sin sombras.',
              ),
              const _PhotoRequirement(
                icon: Icons.face_retouching_natural_outlined,
                text: 'Mantén el rostro descubierto, centrado y de frente.',
              ),
              const _PhotoRequirement(
                icon: Icons.filter_alt_off_outlined,
                text:
                    'No uses filtros, capturas de pantalla ni imágenes ajenas.',
              ),
              if (replacing) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Este envío utilizará uno de tus '
                  '$remainingChanges cambios restantes.',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF003B5C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Entendido'),
            ),
          ],
        ),
  );

  return result ?? false;
}

class _PhotoRequirement extends StatelessWidget {
  const _PhotoRequirement({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: const Color(0xFF003B5C)),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
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
                  'Usa una fotografía frontal, con fondo blanco o claro '
                  'y buena iluminación. La imagen se recortará en formato '
                  'vertical antes de enviarse.',
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
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
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
                  const SizedBox(height: 20),
                  StudentProfilePhoto(
                    profile: profile,
                    initials: _initials(displayName),
                    width: 142,
                    height: 172,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final normalizedName = displayName.trim();
                      final nameLength = normalizedName.length;

                      final fontSize = switch (nameLength) {
                        > 38 => 17.0,
                        > 29 => 18.5,
                        _ => 21.0,
                      };

                      return ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 48,
                          maxHeight: 52,
                        ),
                        child: Center(
                          child: Text(
                            normalizedName.toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: fontSize,
                              height: 1.12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CredentialData(
                          label: 'Número de control',
                          value: controlNumber,
                        ),
                        const SizedBox(height: AppSpacing.xs),
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
                    _DynamicStudentIdQr(profile: profile),
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
                      value: 'Código temporal de 60 segundos',
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

class _DynamicStudentIdQr extends StatefulWidget {
  const _DynamicStudentIdQr({required this.profile});

  final AppUserProfile profile;

  @override
  State<_DynamicStudentIdQr> createState() => _DynamicStudentIdQrState();
}

class _DynamicStudentIdQrState extends State<_DynamicStudentIdQr> {
  static const Duration _renewalThreshold = Duration(seconds: 10);

  Timer? _timer;
  StudentIdQrToken? _token;

  DateTime _now = DateTime.now().toUtc();

  bool _isLoading = true;
  bool _isRenewing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    unawaited(_issueToken());

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void didUpdateWidget(covariant _DynamicStudentIdQr oldWidget) {
    super.didUpdateWidget(oldWidget);

    final eligibilityChanged =
        oldWidget.profile.active != widget.profile.active ||
        oldWidget.profile.photoStatus != widget.profile.photoStatus ||
        oldWidget.profile.profileCompleted != widget.profile.profileCompleted;

    if (eligibilityChanged) {
      _token = null;
      unawaited(_issueToken());
    }
  }

  void _onTick() {
    if (!mounted) {
      return;
    }

    final now = DateTime.now().toUtc();
    final token = _token;

    setState(() {
      _now = now;
    });

    if (token == null || _isRenewing) {
      return;
    }

    if (token.remainingAt(now) <= _renewalThreshold) {
      unawaited(_issueToken(automatic: true));
    }
  }

  Future<void> _issueToken({bool automatic = false}) async {
    if (_isRenewing) {
      return;
    }

    final eligibilityError = _eligibilityError();

    if (eligibilityError != null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _token = null;
        _isLoading = false;
        _isRenewing = false;
        _errorMessage = eligibilityError;
      });
      return;
    }

    setState(() {
      _isRenewing = true;

      if (_token == null) {
        _isLoading = true;
      }

      if (!automatic) {
        _errorMessage = null;
      }
    });

    try {
      final nextToken =
          await context.read<StudentIdQrRepository>().issueToken();

      if (!mounted) {
        return;
      }

      setState(() {
        _token = nextToken;
        _now = DateTime.now().toUtc();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Student ID QR token error: $error\n$stackTrace');

      if (!mounted) {
        return;
      }

      final activeToken = _token;
      final tokenStillValid =
          activeToken != null &&
          !activeToken.isExpiredAt(DateTime.now().toUtc());

      setState(() {
        _isLoading = false;
        _errorMessage =
            tokenStillValid
                ? 'La renovación falló. Se reintentará automáticamente.'
                : 'No fue posible generar el código temporal.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRenewing = false;
        });
      }
    }
  }

  String? _eligibilityError() {
    if (!widget.profile.active) {
      return 'La identificación institucional está inactiva.';
    }

    if (!widget.profile.profileCompleted) {
      return 'Completa tu perfil institucional.';
    }

    if (!widget.profile.isProfilePhotoApproved) {
      return 'La fotografía debe estar aprobada.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final token = _token;
    final remaining = token?.remainingAt(_now) ?? Duration.zero;

    final remainingSeconds = ((remaining.inMilliseconds + 999) ~/ 1000).clamp(
      0,
      60,
    );

    final tokenIsVisible = token != null && !token.isExpiredAt(_now);

    return Container(
      width: 184,
      height: 184,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF003B5C).withValues(alpha: 0.18),
        ),
      ),
      child:
          _isLoading && token == null
              ? const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF003B5C),
                ),
              )
              : tokenIsVisible
              ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  QrImageView(
                    data: token.value,
                    version: QrVersions.auto,
                    size: 136,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF003B5C),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF003B5C),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isRenewing)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: SizedBox.square(
                            dimension: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.7,
                              color: Color(0xFF003B5C),
                            ),
                          ),
                        ),
                      Text(
                        _formatCountdown(remainingSeconds),
                        style: const TextStyle(
                          color: Color(0xFF003B5C),
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              )
              : _QrUnavailableState(
                message: _errorMessage ?? 'El código temporal expiró.',
                onRetry: _isRenewing ? null : () => _issueToken(),
              ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _QrUnavailableState extends StatelessWidget {
  const _QrUnavailableState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.qr_code_2_rounded,
            size: 44,
            color: Color(0xFF003B5C),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.blueGrey.shade700,
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 2),
            TextButton(onPressed: onRetry, child: const Text('Renovar ahora')),
          ],
        ],
      ),
    );
  }
}

String _formatCountdown(int seconds) {
  return '00:${seconds.toString().padLeft(2, '0')}';
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
