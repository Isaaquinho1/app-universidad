import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/announcements/models/models.dart';
import 'package:conecta_itt/announcements/repositories/repositories.dart';
import 'package:conecta_itt/announcements/view/announcement_feed_view.dart';
import 'package:conecta_itt/announcements/view/widgets/publication_asset_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

// Exercise the real cover widget without Storage, networking or a cache plugin.
// Empty signed URLs settle on its existing image placeholder.
class _AssetRepository implements PublicationAssetRepository {
  @override
  Future<String> createSignedUrl(
    PublicationAsset asset, {
    int expiresInSeconds = 3600,
  }) async => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _date = DateTime(2026, 11, 5, 12);

Announcement _publication({
  bool news = false,
  bool featured = false,
  AnnouncementPriority priority = AnnouncementPriority.normal,
  int version = 1,
}) => Announcement(
  id: 'publication',
  title: 'Actividad del campus',
  summary: 'Resumen institucional para estudiantes.',
  body: 'Contenido completo del comunicado.',
  authorUid: 'author',
  authorName: 'Coordinación académica',
  newsCategory: news ? 'Comunidad' : null,
  contentType:
      news ? PublicationContentType.news : PublicationContentType.announcement,
  featured: featured,
  priority: priority,
  target: const AnnouncementTarget.all(),
  status: AnnouncementStatus.published,
  createdAt: _date,
  updatedAt: _date,
  contentVersion: version,
);

PublicationAsset _asset(PublicationAssetType type) => PublicationAsset(
  id: type.name,
  publicationId: 'publication',
  type: type,
  storageBucket: PublicationAsset.defaultBucket,
  storagePath: type.isCover ? 'cover.png' : 'document.pdf',
  originalName: type.isCover ? 'cover.png' : 'document.pdf',
  mimeType: type.isCover ? 'image/png' : 'application/pdf',
  sizeBytes: 100,
  displayOrder: 0,
  uploadedBy: 'author',
  createdAt: _date,
  updatedAt: _date,
);

double _contrast(Color foreground, Color background) {
  final effective = Color.alphaBlend(foreground, background);
  final a = effective.computeLuminance() + 0.05;
  final b = background.computeLuminance() + 0.05;
  return a > b ? a / b : b / a;
}

// Follow painted solid surfaces from the actual element, including a badge
// background before its card. Do not assume all labels sit on the card itself.
Color _background(Element element) {
  final layers = <Color>[];
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    Color? color;
    if (widget is DecoratedBox && widget.decoration is BoxDecoration) {
      color = (widget.decoration as BoxDecoration).color;
    } else if (widget is ColoredBox) {
      color = widget.color;
    } else if (widget is Material && widget.type != MaterialType.transparency) {
      color = widget.color;
    }
    if (color != null) layers.add(color);
    return color == null || color.a < 1;
  });
  var result = Theme.of(element).scaffoldBackgroundColor;
  for (final layer in layers.reversed) {
    result = Color.alphaBlend(layer, result);
  }
  return result;
}

Color _foreground(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text).text.style!.color!;

void _expectContrast(WidgetTester tester) {
  final card = find.byType(AnnouncementCard);
  final texts = find.descendant(of: card, matching: find.byType(Text));
  for (final element in texts.evaluate()) {
    final finder = find.byElementPredicate((candidate) => candidate == element);
    final text = element.widget as Text;
    expect(
      _contrast(_foreground(tester, finder), _background(element)),
      greaterThanOrEqualTo(4.5),
      reason: 'Normal text: ${text.data}',
    );
  }
  final icons = find.descendant(of: card, matching: find.byType(Icon));
  for (final element in icons.evaluate()) {
    final icon = element.widget as Icon;
    final inherited = IconTheme.of(element);
    final color = icon.color ?? inherited.color!;
    final effective = color.withValues(
      alpha: color.a * (inherited.opacity ?? 1),
    );
    expect(
      _contrast(effective, _background(element)),
      greaterThanOrEqualTo(3),
      reason: 'Icon: ${icon.icon}',
    );
  }
}

Future<void> _show(
  WidgetTester tester,
  ThemeData theme,
  Announcement publication, {
  List<PublicationAsset> assets = const [],
  AnnouncementReceipt? receipt,
  double width = 430,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: RepositoryProvider<PublicationAssetRepository>.value(
          value: _AssetRepository(),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: AnnouncementCard(
                announcement: publication,
                assets: assets,
                receipt: receipt,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final dark in [false, true]) {
    final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
    for (final scenario in [
      'news-cover',
      'news-no-cover',
      'announcement-cover',
      'announcement',
      'pdf',
    ]) {
      testWidgets('$dark: $scenario text, metadata and icons meet contrast', (
        tester,
      ) async {
        final news = scenario.startsWith('news');
        final assets = switch (scenario) {
          'news-cover' ||
          'announcement-cover' => [_asset(PublicationAssetType.cover)],
          'pdf' => [_asset(PublicationAssetType.attachment)],
          _ => <PublicationAsset>[],
        };
        await _show(
          tester,
          theme,
          _publication(news: news, featured: news),
          assets: assets,
        );
        expect(find.text('Actividad del campus'), findsOneWidget);
        expect(
          find.text('Resumen institucional para estudiantes.'),
          findsOneWidget,
        );
        expect(find.text('Coordinación académica'), findsOneWidget);
        expect(find.text('5 nov. 2026'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
        if (news) {
          expect(find.text('Comunidad'), findsOneWidget);
          expect(
            _background(tester.element(find.text('Destacada'))),
            const Color(0xFF8D5000),
          );
        }
        if (scenario == 'pdf') {
          expect(find.byIcon(Icons.attach_file), findsOneWidget);
        }
        if (assets.any((asset) => asset.type.isCover)) {
          final cover = tester.widget<PublicationAssetImage>(
            find.byType(PublicationAssetImage),
          );
          expect(cover.asset, same(assets.single));
          expect(cover.fit, BoxFit.cover);
          expect(cover.width, 148);
          expect(cover.height, closeTo(143, 0.01));
        }
        final card = tester.widget<Card>(find.byType(Card));
        expect(
          card.color,
          dark
              ? (theme.extension<AppColors>()?.surfaceHigh ??
                  theme.colorScheme.surfaceContainerHigh)
              : theme.colorScheme.surface,
        );
        if (!dark) {
          expect(card.color, Colors.white);
          expect(
            _foreground(tester, find.text('Actividad del campus')),
            const Color(0xFF111827),
          );
          for (final label in [
            'Resumen institucional para estudiantes.',
            'Coordinación académica',
          ]) {
            expect(
              _foreground(tester, find.text(label)),
              const Color(0xFF39465B),
            );
          }
          expect(
            _foreground(tester, find.text('5 nov. 2026')),
            const Color(0xFF49566A),
          );
          final arrow = tester.widget<Icon>(
            find.byIcon(Icons.chevron_right_rounded),
          );
          expect(arrow.color, const Color(0xFF192B50));
          final shape = card.shape! as RoundedRectangleBorder;
          expect(shape.borderRadius, BorderRadius.circular(22));
          expect(shape.side.color, const Color(0xFFE9EDF3));
          expect(shape.side.width, 1);
        }
        _expectContrast(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$dark: all priority and receipt presentations are readable', (
      tester,
    ) async {
      final receipts = <AnnouncementReceipt?>[
        null,
        for (final status in AnnouncementReceiptStatus.values)
          AnnouncementReceipt(userUid: 'student', status: status),
        const AnnouncementReceipt(
          userUid: 'student',
          status: AnnouncementReceiptStatus.confirmed,
          receiptVersion: 0,
        ),
      ];
      const priorities = ['Baja', 'Normal', 'Importante', 'Urgente'];
      final fillByPriority = <AnnouncementPriority, Color>{};
      final fillByStatus = <String, Color>{};
      for (final priority in AnnouncementPriority.values) {
        for (final receipt in receipts) {
          await _show(
            tester,
            theme,
            _publication(priority: priority),
            receipt: receipt,
          );
          final label = priorities[priority.index];
          expect(find.text(label), findsOneWidget);
          final statusLabel =
              receipt == null
                  ? 'Nuevo'
                  : receipt.receiptVersion < 1
                  ? 'Editado'
                  : switch (receipt.status) {
                    AnnouncementReceiptStatus.delivered => 'Nuevo',
                    AnnouncementReceiptStatus.seen => 'Visto',
                    AnnouncementReceiptStatus.read => 'Leído',
                    AnnouncementReceiptStatus.confirmed => 'Confirmado',
                  };
          expect(find.text(statusLabel), findsOneWidget);
          fillByPriority[priority] = _background(
            tester.element(find.text(label)),
          );
          fillByStatus[statusLabel] = _background(
            tester.element(find.text(statusLabel)),
          );
          _expectContrast(tester);
        }
      }
      expect(fillByStatus['Nuevo'], theme.colorScheme.primaryContainer);
      expect(fillByStatus['Visto'], theme.colorScheme.secondaryContainer);
      expect(fillByStatus['Leído'], theme.colorScheme.surface);
      expect(fillByStatus['Editado'], const Color(0xFF9A4100));
      expect(fillByStatus['Confirmado'], Colors.green.shade800);
      expect(fillByStatus['Confirmado'], isNot(fillByStatus['Editado']));
      expect(
        fillByPriority[AnnouncementPriority.high],
        const Color(0xFF8D5000),
      );
      expect(fillByPriority[AnnouncementPriority.urgent], Colors.red.shade700);
      expect(
        fillByPriority[AnnouncementPriority.high],
        isNot(fillByPriority[AnnouncementPriority.urgent]),
      );
    });
  }

  testWidgets('theme changes preserve card, content and thumbnail geometry', (
    tester,
  ) async {
    for (final scenario in [
      'news-cover',
      'announcement-cover',
      'announcement',
    ]) {
      final news = scenario == 'news-cover';
      final hasCover = scenario.endsWith('-cover');
      for (final width in [320.0, 430.0]) {
        final assets =
            hasCover
                ? [_asset(PublicationAssetType.cover)]
                : <PublicationAsset>[];
        final publication = _publication(news: news);
        final geometry = <List<Rect>>[];
        for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
          await _show(tester, theme, publication, assets: assets, width: width);
          geometry.add([
            tester.getRect(find.byType(Card)),
            tester.getRect(find.text('Actividad del campus')),
            tester.getRect(find.text('Coordinación académica')),
            tester.getRect(find.byIcon(Icons.chevron_right_rounded)),
            if (hasCover) tester.getRect(find.byType(PublicationAssetImage)),
          ]);
          _expectContrast(tester);
        }
        expect(geometry.last, orderedEquals(geometry.first));
      }
    }
  });
}
