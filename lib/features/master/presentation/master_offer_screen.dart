import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fixleo/app/theme/app_colors.dart';
import 'package:fixleo/app/widgets/branded_scaffold.dart';
import 'package:fixleo/app/widgets/primary_button.dart';
import 'package:fixleo/features/master/presentation/master_offer_sent_screen.dart';

/// Master's offer for a request — price type, amount and a note to the
/// client, submitted as a response.
class MasterOfferScreen extends StatefulWidget {
  const MasterOfferScreen({super.key});

  @override
  State<MasterOfferScreen> createState() => _MasterOfferScreenState();
}

class _MasterOfferScreenState extends State<MasterOfferScreen> {
  static const _types = ['Fiks', 'Diapazon', 'Koʻrgandan keyin'];

  final _price = TextEditingController(text: '50 000');
  final _comment = TextEditingController();
  int _type = 1;

  @override
  void dispose() {
    _price.dispose();
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BrandedScaffold(
      title: 'Sizning taklifingiz',
      showBack: true,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Price type.
            _Card(
              title: 'Narx turi',
              child: Row(
                children: [
                  Expanded(
                    child: _TypeChip(
                      label: _types[0],
                      selected: _type == 0,
                      onTap: () => setState(() => _type = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TypeChip(
                      label: _types[1],
                      selected: _type == 1,
                      onTap: () => setState(() => _type = 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TypeChip(
                    label: _types[2],
                    selected: _type == 2,
                    onTap: () => setState(() => _type = 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Price amount.
            _Card(
              title: 'Sizning narxingiz',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _price,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                        ],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.navy,
                        ),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    Text(
                      'soʻm',
                      style: TextStyle(fontSize: 14, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Comment.
            _Card(
              title: 'Mijozga izoh',
              child: Container(
                height: 110,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _comment,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    color: AppColors.navy,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Masalan: Bir soat ichida yetib bora olaman.',
                    hintStyle: TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                ),
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Javobni yuborish',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MasterOfferSentScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White section card with a semibold title and content below.
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF23232E),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Pill chip for the price-type row.
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: selected ? Colors.white : AppColors.navy,
          ),
        ),
      ),
    );
  }
}
