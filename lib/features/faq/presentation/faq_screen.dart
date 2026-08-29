import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/core/network/api_exception.dart';
import 'package:fixleo/features/faq/data/faq_model.dart';
import 'package:fixleo/features/faq/data/faq_service.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key, required this.audience, this.service});

  final String audience;
  final FaqService? service;

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  late final FaqService _service = widget.service ?? FaqService();
  final _search = TextEditingController();
  List<FaqItem> _items = const [];
  bool _loading = true;
  String? _error;
  String? _topic;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.list(audience: widget.audience);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      final language = LocaleController.language.value;
      setState(() {
        _error = tr(
          language,
          'Savollarni yuklab bo‘lmadi',
          'Не удалось загрузить вопросы',
          'Could not load questions',
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleController.language,
      builder: (context, language, _) {
        final topics = _items
            .map((item) => item.localizedTopic(language))
            .toSet()
            .toList(growable: false);
        final filtered = _items
            .where((item) {
              if (_topic != null && item.localizedTopic(language) != _topic) {
                return false;
              }
              return item.matches(_search.text, language);
            })
            .toList(growable: false);

        return BrandedScaffold(
          title: tr(language, 'Yordam markazi', 'Центр помощи', 'Help center'),
          showBack: true,
          body: RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  sliver: SliverList.list(
                    children: [
                      _hero(language),
                      const SizedBox(height: 14),
                      _searchField(language),
                      if (topics.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 38,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              _topicChip(
                                label: tr(language, 'Hammasi', 'Все', 'All'),
                                selected: _topic == null,
                                onTap: () => setState(() => _topic = null),
                              ),
                              for (final topic in topics) ...[
                                const SizedBox(width: 8),
                                _topicChip(
                                  label: topic,
                                  selected: _topic == topic,
                                  onTap: () => setState(() => _topic = topic),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null)
                        _message(
                          _error!,
                          action: TextButton(
                            onPressed: _load,
                            child: Text(
                              tr(
                                language,
                                'Qayta urinish',
                                'Повторить',
                                'Retry',
                              ),
                            ),
                          ),
                        )
                      else if (filtered.isEmpty)
                        _message(
                          tr(
                            language,
                            'Mos savol topilmadi',
                            'Подходящий вопрос не найден',
                            'No matching question found',
                          ),
                        )
                      else
                        for (
                          var index = 0;
                          index < filtered.length;
                          index++
                        ) ...[
                          _faqCard(filtered[index], language, index),
                          if (index != filtered.length - 1)
                            const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _hero(AppLanguage language) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B84F3), Color(0xFF48ACFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330B84F3),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    language,
                    'Savolingizga tez javob toping',
                    'Быстро найдите ответ',
                    'Find an answer quickly',
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  tr(
                    language,
                    'Fixleo’dan foydalanish bo‘yicha kerakli ma’lumotlar',
                    'Всё важное о работе с Fixleo',
                    'Everything you need to use Fixleo',
                  ),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .82),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField(AppLanguage language) {
    return TextField(
      controller: _search,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: tr(
          language,
          'Savol yoki mavzu qidiring',
          'Найдите вопрос или тему',
          'Search questions or topics',
        ),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.blue),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _search.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: .9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE3EAF3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE3EAF3)),
        ),
      ),
    );
  }

  Widget _topicChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.navy,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: AppColors.blue,
      backgroundColor: Colors.white.withValues(alpha: .88),
      side: BorderSide(
        color: selected ? AppColors.blue : const Color(0xFFE3EAF3),
      ),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _faqCard(FaqItem item, AppLanguage language, int index) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3EAF3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D172A4A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: ValueKey('faq-${item.id}-$index'),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 5,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5FF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.question_mark_rounded,
                color: AppColors.blue,
                size: 20,
              ),
            ),
            title: Text(
              item.localizedQuestion(language),
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                item.localizedTopic(language),
                style: const TextStyle(color: AppColors.blue, fontSize: 11.5),
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: MarkdownBody(
                  data: item.localizedAnswer(language),
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                      color: Color(0xFF53627A),
                      fontSize: 13.5,
                      height: 1.55,
                    ),
                    strong: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _message(String text, {Widget? action}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .75),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.help_outline_rounded,
            size: 34,
            color: AppColors.muted,
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          if (action != null) ...[const SizedBox(height: 14), action],
        ],
      ),
    );
  }
}
