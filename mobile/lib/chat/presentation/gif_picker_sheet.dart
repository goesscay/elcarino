import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../data/chat_repository.dart';
import '../domain/gif_result.dart';

/// docs/07-ui-ux-design.md §3.3's composer "attachment button reveals ...
/// GIF" — Phase 3 item 2 (open decision #17). A modal bottom sheet: search
/// field, grid of results, tap one to pick it. Returns the picked
/// [GifResult] (its `id` is what actually gets sent — see
/// `ChatRepository.sendGif`'s doc comment), or `null` if dismissed without
/// picking.
Future<GifResult?> showGifPickerSheet(BuildContext context) {
  return showModalBottomSheet<GifResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _GifPickerSheet(),
  );
}

class _GifPickerSheet extends ConsumerStatefulWidget {
  const _GifPickerSheet();

  @override
  ConsumerState<_GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends ConsumerState<_GifPickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;

  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String _query = '';
  int _nextPage = 1;
  bool _hasMore = false;
  List<GifResult> _results = [];

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    setState(() {
      _query = trimmed;
      _results = [];
      _hasMore = false;
      _error = null;
    });
    if (trimmed.isEmpty) return;

    setState(() => _loading = true);
    try {
      final page = await ref.read(chatRepositoryProvider).searchGifs(trimmed);
      // A later keystroke may have already started a newer search by the
      // time this one resolves — drop a stale response rather than
      // flashing outdated results before the newer search's own arrives.
      if (!mounted || trimmed != _query) return;
      setState(() {
        _results = page.gifs;
        _hasMore = page.hasMore;
        _nextPage = 2;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || trimmed != _query) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(chatRepositoryProvider)
          .searchGifs(_query, page: _nextPage);
      if (!mounted) return;
      setState(() {
        _results = [..._results, ...page.gifs];
        _hasMore = page.hasMore;
        _nextPage++;
        _loadingMore = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The search field is `autofocus: true`, so the keyboard is open for
    // essentially the entire time this sheet is visible — without shifting
    // the whole sheet up by the keyboard's own height, a fixed-height
    // SizedBox keeps sizing itself against the *full* screen height (not
    // the shrunk visible viewport), and a centered empty/loading/results
    // state renders partly or fully behind the keyboard. Caught live: "No
    // GIFs found." was actually rendering correctly, just invisible until
    // the keyboard was dismissed.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onChanged,
                  decoration: const InputDecoration(
                    hintText: 'Search GIFs…',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_query.isEmpty) {
      return const Center(child: Text('Search for a GIF to send.'));
    }
    if (_results.isEmpty) {
      return const Center(child: Text('No GIFs found.'));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >
            notification.metrics.maxScrollExtent - 200) {
          _loadMore();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
        ),
        itemCount: _results.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _results.length) {
            return const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final gif = _results[index];
          return GestureDetector(
            onTap: () => Navigator.pop(context, gif),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Ink(
                color: AppColors.surfaceLight,
                child: AspectRatio(
                  aspectRatio: gif.height > 0 ? gif.width / gif.height : 1,
                  child: Image.network(gif.previewUrl, fit: BoxFit.cover),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
