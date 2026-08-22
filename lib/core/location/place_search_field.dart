import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/glass/glass.dart';
import 'package:fixleo/core/location/place_search_service.dart';

/// Shared search overlay for all map-based location pickers.
class PlaceSearchField extends StatefulWidget {
  const PlaceSearchField({
    super.key,
    required this.language,
    required this.onSelected,
    this.service,
    this.bias,
  });

  final AppLanguage language;
  final ValueChanged<PlaceSearchResult> onSelected;
  final PlaceSearchService? service;
  final LatLng? bias;

  @override
  State<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<PlaceSearchField> {
  late final PlaceSearchService _service =
      widget.service ?? PlaceSearchService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<PlaceSearchResult> _results = const [];
  bool _searching = false;
  bool _searched = false;
  String? _error;
  Timer? _searchDebounce;
  int _searchToken = 0;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    final token = ++_searchToken;
    if (query.length < 2) {
      setState(() {
        _searching = false;
        _searched = false;
        _error = null;
        _results = const [];
      });
      return;
    }
    setState(() {
      _searching = true;
      _searched = false;
      _error = null;
      _results = const [];
    });
    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _performSearch(query, token),
    );
  }

  Future<void> _searchNow() async {
    _searchDebounce?.cancel();
    final query = _controller.text.trim();
    if (query.length < 2) return;
    final token = ++_searchToken;
    setState(() {
      _searching = true;
      _searched = false;
      _error = null;
      _results = const [];
    });
    await _performSearch(query, token);
  }

  Future<void> _performSearch(String query, int token) async {
    try {
      final results = await _service.search(
        query,
        language: widget.language,
        bias: widget.bias,
      );
      if (!mounted || token != _searchToken) return;
      setState(() {
        _results = results;
        _searching = false;
        _searched = true;
      });
    } catch (_) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _searching = false;
        _searched = true;
        _error = tr(
          widget.language,
          'Qidiruvda xatolik yuz berdi',
          'Не удалось выполнить поиск',
          'Could not search for this place',
        );
      });
    }
  }

  void _select(PlaceSearchResult result) {
    _searchDebounce?.cancel();
    _searchToken++;
    _controller.text = [result.label, result.subtitle].join(', ');
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    setState(() {
      _results = const [];
      _searched = false;
      _error = null;
    });
    _focusNode.unfocus();
    widget.onSelected(result);
  }

  void _clear() {
    _searchDebounce?.cancel();
    _searchToken++;
    _controller.clear();
    setState(() {
      _results = const [];
      _searched = false;
      _error = null;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final showPanel = _searching || _searched || _error != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassContainer(
          height: 54,
          borderRadius: 18,
          padding: const EdgeInsets.only(left: 15, right: 6),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: AppColors.blue, size: 23),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const ValueKey('location-search-field'),
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchNow(),
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: tr(
                      widget.language,
                      'Manzil yoki joyni qidiring',
                      'Найдите адрес или место',
                      'Search address or place',
                    ),
                    hintStyle: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty && !_searching)
                IconButton(
                  tooltip: tr(widget.language, 'Tozalash', 'Очистить', 'Clear'),
                  onPressed: _clear,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.muted,
                    size: 20,
                  ),
                ),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.all(11),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                )
              else
                IconButton(
                  tooltip: tr(widget.language, 'Qidirish', 'Найти', 'Search'),
                  onPressed: _searchNow,
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.blue,
                    size: 21,
                  ),
                ),
            ],
          ),
        ),
        if (showPanel) ...[
          const SizedBox(height: 8),
          GlassContainer(
            borderRadius: 18,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _results.isNotEmpty
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < _results.length; index++) ...[
                        if (index != 0)
                          const Divider(height: 1, indent: 52, endIndent: 12),
                        _PlaceResultTile(
                          key: ValueKey('location-search-result-$index'),
                          result: _results[index],
                          onTap: () => _select(_results[index]),
                        ),
                      ],
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      _searching
                          ? tr(
                              widget.language,
                              'Qidirilmoqda...',
                              'Поиск...',
                              'Searching...',
                            )
                          : _error ??
                                tr(
                                  widget.language,
                                  'Hech narsa topilmadi',
                                  'Ничего не найдено',
                                  'No places found',
                                ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

class _PlaceResultTile extends StatelessWidget {
  const _PlaceResultTile({
    super.key,
    required this.result,
    required this.onTap,
  });

  final PlaceSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFEAF4FE),
                  ),
                  child: Icon(
                    Icons.location_on_outlined,
                    color: AppColors.blue,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
