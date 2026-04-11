import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/collage_layout.dart';

class TemplateRepository {
  List<String> categories = [];
  List<TemplateModel> templates = [];

  Future<void> loadTemplates() async {
    final String jsonStr = await rootBundle.loadString('assets/templates.json');
    final Map<String, dynamic> data = jsonDecode(jsonStr);

    categories = (data['categories'] as List).cast<String>();
    
    final List<dynamic> tplList = data['templates'];
    templates = tplList.map((e) => TemplateModel.fromJson(e)).toList();
  }
}

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return TemplateRepository();
});

final templatesInitializationProvider = FutureProvider<void>((ref) async {
  final repo = ref.read(templateRepositoryProvider);
  await repo.loadTemplates();
});
