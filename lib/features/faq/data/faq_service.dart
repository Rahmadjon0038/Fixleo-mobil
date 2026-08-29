import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/features/faq/data/faq_model.dart';

class FaqService {
  FaqService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<List<FaqItem>> list({required String audience}) async {
    final data = await _client.get('/faqs?audience=$audience');
    return (data as List<dynamic>)
        .map((item) => FaqItem.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
