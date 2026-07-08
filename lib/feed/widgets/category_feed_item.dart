import 'package:flutter/material.dart' hide Spacer;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:news_blocks/news_blocks.dart';
import 'package:news_blocks_ui/news_blocks_ui.dart';
import 'package:rtu_mirea_app/categories/categories.dart';
import 'package:rtu_mirea_app/l10n/l10n.dart';

class CategoryFeedItem extends StatelessWidget {
  const CategoryFeedItem({required this.block, super.key});

  /// The associated [NewsBlock] instance.
  final NewsBlock block;

  @override
  Widget build(BuildContext context) {
    final newsBlock = block;

    late Widget widget;

    if (newsBlock is DividerHorizontalBlock) {
      widget = Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: DividerHorizontal(block: newsBlock),
      );
    } else if (newsBlock is SpacerBlock) {
      widget = Spacer(block: newsBlock);
    } else if (newsBlock is SectionHeaderBlock) {
      widget = Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SectionHeader(
          block: newsBlock,
          onPressed: (action) => _onFeedItemAction(context, action),
        ),
      );
    } else if (newsBlock is PostLargeBlock) {
      final categoryName = context.read<CategoriesBloc>().state.getCategoryName(
        newsBlock.categoryId,
      );
      widget = PostLarge(
        block: newsBlock,
        categoryName: categoryName,
        isLocked: false,
        onPressed: (action) => _onFeedItemAction(context, action),
      );
    } else if (newsBlock is PostMediumBlock) {
      widget = PostMedium(
        block: newsBlock,
        onPressed: (action) => _onFeedItemAction(context, action),
      );
    } else if (newsBlock is PostSmallBlock) {
      widget = PostSmall(
        block: newsBlock,
        onPressed: (action) => _onFeedItemAction(context, action),
      );
    } else if (newsBlock is VideoBlock) {
      widget = Video(block: newsBlock);
    } else if (newsBlock is PostGridGroupBlock) {
      final categoryName = context.read<CategoriesBloc>().state.getCategoryName(
        newsBlock.categoryId,
      );
      widget = PostGrid(
        gridGroupBlock: newsBlock,
        categoryName: categoryName,
        onPressed: (action) => _onFeedItemAction(context, action),
      );
    } else if (newsBlock is BannerAdBlock) {
  widget = const SizedBox.shrink();
} else {
      // Render an empty widget for the unsupported block type.
      widget = const SizedBox();
    }

    // Agrega espaciado entre bloques para mejorar la legibilidad.
    // Algunos bloques ya manejan su propio espaciado.
    final needsExtraPadding =
        !(newsBlock is DividerHorizontalBlock ||
            newsBlock is SectionHeaderBlock ||
            newsBlock is BannerAdBlock);

    final wrappedWidget =
        needsExtraPadding
            ? Padding(padding: const EdgeInsets.only(bottom: 16), child: widget)
            : widget;

    return (newsBlock is! PostGridGroupBlock)
        ? SliverToBoxAdapter(child: wrappedWidget)
        : widget;
  }

  /// Handles actions triggered by tapping on feed items.
  Future<void> _onFeedItemAction(
    BuildContext context,
    BlockAction action,
  ) async {
    if (action is NavigateToArticleAction) {
      context.push('/feed/article/${action.articleId}');
    } else if (action is NavigateToVideoArticleAction) {
      context.push('/feed/article/${action.articleId}');
    } else if (action is NavigateToFeedCategoryAction) {
      context.read<CategoriesBloc>().add(
        CategorySelected(category: action.category),
      );
    }
  }
}
