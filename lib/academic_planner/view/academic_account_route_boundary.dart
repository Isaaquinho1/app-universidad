import 'dart:async';

import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
import 'package:conecta_itt/app/bloc/app_bloc.dart';
import 'package:conecta_itt/academic_planner/view/academic_planner_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Mantiene un contexto académico asociado a un UID y una revisión
/// de autenticación. Invalida el contexto cuando cambia la sesión.
class AcademicAccountRouteBoundary extends StatefulWidget {
  const AcademicAccountRouteBoundary({
    required this.userId,
    required this.authRevision,
    super.key,
  });

  final String userId;
  final int authRevision;

  @override
  State<AcademicAccountRouteBoundary> createState() =>
      _AcademicAccountRouteBoundaryState();
}

class _AcademicAccountRouteBoundaryState
    extends State<AcademicAccountRouteBoundary> {
  late final AcademicAccountScope _account;
  late final AppBloc _appBloc;
  late final StreamSubscription<dynamic> _authSubscription;

  void _invalidateIfSessionChanged() {
    final state = _appBloc.state;

    if (_appBloc.authRevision != widget.authRevision ||
        !state.status.isLoggedIn ||
        state.user.id.trim() != widget.userId) {
      _account.invalidate();
    }
  }

  @override
  void initState() {
    super.initState();

    _account = AcademicAccountScope.forUser(widget.userId);
    _appBloc = context.read<AppBloc>();

    _authSubscription = _appBloc.authRevisionChanges.listen((_) {
      _invalidateIfSessionChanged();
    });

    _invalidateIfSessionChanged();
  }

  @override
  void dispose() {
    _account.invalidate();
    unawaited(_authSubscription.cancel());
    unawaited(_account.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<AcademicAccountScope>.value(
      value: _account,
      child: AcademicPlannerPage(account: _account),
    );
  }
}
