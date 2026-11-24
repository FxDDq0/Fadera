import 'package:flutter/material.dart';

import '../../controller/app_controller.dart';
import '../../l10n/l10n.dart';
import '../../theme.dart';

/// Menu della lingua: "Automatica" (lingua di Windows) e le lingue disponibili, ognuna col suo nome.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, required this.ctl, this.dense = false});
  final AppController ctl;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final sys = kLanguages.firstWhere((l) => l.$1 == L10n.systemLanguage()).$2;
    return DropdownButton<String>(
      key: const ValueKey('language-picker'),
      value: ctl.prefs.language,
      isDense: dense,
      underline: const SizedBox(),
      dropdownColor: AppColors.surface2,
      icon: const Icon(Icons.translate, size: 16, color: AppColors.textDim),
      items: [
        DropdownMenuItem(value: 'system', child: Text(tr('Automatica ({p0})', {'p0': sys}))),
        for (final (code, name) in kLanguages) DropdownMenuItem(value: code, child: Text(name)),
      ],
      onChanged: (v) {
        if (v != null) ctl.setLanguage(v);
      },
    );
  }
}
