import 'package:equatable/equatable.dart';
import 'package:news_blocks/news_blocks.dart';
import 'package:university_app_server_api/client.dart';

/// {@template news_failure}
/// Base failure class for the news repository failures.
/// {@endtemplate}
abstract class NewsFailure with EquatableMixin implements Exception {
  /// {@macro news_failure}
  const NewsFailure(this.error);

  /// The error which was caught.
  final Object error;

  @override
  List<Object?> get props => [error];
}

/// {@template get_feed_failure}
/// Thrown when fetching feed fails.
/// {@endtemplate}
class GetFeedFailure extends NewsFailure {
  /// {@macro get_feed_failure}
  const GetFeedFailure(super.error);
}

/// {@template get_categories_failure}
/// Thrown when fetching categories fails.
/// {@endtemplate}
class GetCategoriesFailure extends NewsFailure {
  /// {@macro get_categories_failure}
  const GetCategoriesFailure(super.error);
}

/// {@template popular_search_failure}
/// Thrown when fetching popular searches fails.
/// {@endtemplate}
class PopularSearchFailure extends NewsFailure {
  /// {@macro popular_search_failure}
  const PopularSearchFailure(super.error);
}

/// {@template relevant_search_failure}
/// Thrown when fetching relevant searches fails.
/// {@endtemplate}
class RelevantSearchFailure extends NewsFailure {
  /// {@macro relevant_search_failure}
  const RelevantSearchFailure(super.error);
}

/// Temporary development categories for TecNM Campus Tlalpan.
///
/// These values allow the app to remain navigable while the real backend
/// integration is implemented.
const _mockCategories = <Category>[
  Category(
    id: 'comunicados',
    name: 'Comunicados',
  ),
  Category(
    id: 'calendario_academico',
    name: 'Calendario académico',
  ),
  Category(
    id: 'eventos',
    name: 'Eventos',
  ),
  Category(
    id: 'servicios_escolares',
    name: 'Servicios escolares',
  ),
  Category(
    id: 'actividades_estudiantiles',
    name: 'Actividades estudiantiles',
  ),
];

/// {@template news_repository}
/// A repository that manages news data.
/// {@endtemplate}
class NewsRepository {
  /// {@macro news_repository}
  const NewsRepository({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Requests news feed metadata.
  ///
  /// Supported parameters:
  /// * [categoryId] - the desired news category.
  /// * [limit] - The number of results to return.
  /// * [offset] - The (zero-based) offset of the first item
  /// in the collection to return.
  Future<FeedResponse> getFeed({
    String? categoryId,
    int? limit,
    int? offset,
  }) async {
    try {
      return await _apiClient.getFeed(
        categoryId: categoryId,
        limit: limit,
        offset: offset,
      );
    } catch (_) {
      final mockFeed = _buildMockFeed(categoryId: categoryId);

      final start = offset ?? 0;
      final end = limit == null ? mockFeed.length : start + limit;

      final paginatedFeed = mockFeed.sublist(
        start.clamp(0, mockFeed.length),
        end.clamp(0, mockFeed.length),
      );

      return FeedResponse(
        feed: paginatedFeed,
        totalCount: mockFeed.length,
      );
    }
  }

  /// Requests the available news categories.
  Future<CategoriesResponse> getCategories() async {
    try {
      return await _apiClient.getCategories();
    } catch (_) {
      return const CategoriesResponse(categories: _mockCategories);
    }
  }

  /// Requests the popular searches.
  Future<PopularSearchResponse> popularSearch() async {
    try {
      return await _apiClient.popularSearch();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(PopularSearchFailure(error), stackTrace);
    }
  }

  /// Requests the searches relevant to [term].
  Future<RelevantSearchResponse> relevantSearch({required String term}) async {
    try {
      return await _apiClient.relevantSearch(term: term);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(RelevantSearchFailure(error), stackTrace);
    }
  }
}

List<NewsBlock> _buildMockFeed({String? categoryId}) {
  final feed = <PostSmallBlock>[
    PostSmallBlock(
      id: 'tecnm-tlalpan-comunicado-001',
      categoryId: 'comunicados',
      author: 'TecNM Campus Tlalpan',
      publishedAt: DateTime(2026, 7, 5),
      imageUrl: null,
      title: 'Bienvenida a la plataforma del Campus Tlalpan',
      description:
          'Este espacio concentrará comunicados importantes, avisos académicos '
          'y noticias relevantes para la comunidad estudiantil.',
    ),
    PostSmallBlock(
      id: 'tecnm-tlalpan-calendario-001',
      categoryId: 'calendario_academico',
      author: 'División Académica',
      publishedAt: DateTime(2026, 7, 5),
      imageUrl: null,
      title: 'Consulta del calendario académico',
      description:
          'La aplicación integrará fechas relevantes como reinscripciones, '
          'periodos de evaluación, bajas, altas y eventos institucionales.',
    ),
    PostSmallBlock(
      id: 'tecnm-tlalpan-eventos-001',
      categoryId: 'eventos',
      author: 'Coordinación de Actividades',
      publishedAt: DateTime(2026, 7, 5),
      imageUrl: null,
      title: 'Eventos institucionales del campus',
      description:
          'Aquí se publicarán conferencias, talleres, actividades culturales, '
          'eventos deportivos y sesiones informativas del campus.',
    ),
    PostSmallBlock(
      id: 'tecnm-tlalpan-servicios-001',
      categoryId: 'servicios_escolares',
      author: 'Servicios Escolares',
      publishedAt: DateTime(2026, 7, 5),
      imageUrl: null,
      title: 'Información de servicios escolares',
      description:
          'La sección permitirá consultar avisos relacionados con trámites, '
          'constancias, reinscripciones y atención administrativa.',
    ),
    PostSmallBlock(
      id: 'tecnm-tlalpan-actividades-001',
      categoryId: 'actividades_estudiantiles',
      author: 'Comunidad Estudiantil',
      publishedAt: DateTime(2026, 7, 5),
      imageUrl: null,
      title: 'Actividades para estudiantes',
      description:
          'Se mostrarán actividades académicas, extracurriculares y de apoyo '
          'para estudiantes del TecNM Campus Tlalpan.',
    ),
  ];

  if (categoryId == null || categoryId.isEmpty) {
    return feed;
  }

  return feed.where((item) => item.categoryId == categoryId).toList();
}
