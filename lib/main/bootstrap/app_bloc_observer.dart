import 'package:analytics_repository/analytics_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

class AppBlocObserver extends BlocObserver {
  const AppBlocObserver({required AnalyticsRepository analyticsRepository})
    : _analyticsRepository = analyticsRepository;

  final AnalyticsRepository _analyticsRepository;

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);

    if (!kDebugMode) return;

    if (_containsSensitiveAuthenticationData(bloc)) {
      debugPrint(
        '${bloc.runtimeType} Change '
        '{ currentState: ${change.currentState.runtimeType}, '
        'nextState: ${change.nextState.runtimeType}, redacted: true }',
      );
      return;
    }

    debugPrint('${bloc.runtimeType} $change');
  }

  bool _containsSensitiveAuthenticationData(BlocBase<dynamic> bloc) {
    return const {
      'LoginBloc',
      'RegisterBloc',
      'LoginWithEmailLinkBloc',
      'AppBloc',
      'AnnouncementBloc',
    }.contains(bloc.runtimeType.toString());
  }

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);

    if (event is AnalyticsEventMixin) {
      _analyticsRepository.track(event.event);
    }
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    debugPrint('${bloc.runtimeType} $error');
  }
}
