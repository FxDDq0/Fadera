import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'controller/app_controller.dart';
import 'design/tokens.dart';
import 'l10n/l10n.dart';

/// Cattura globale degli errori: quelli del framework (disegno, layout) e quelli asincroni
/// (timer, socket, stream) finiscono nel registro di Fadera invece di andare persi.
/// In versione finale un widget che fallisce mostra un riquadro neutro, non la schermata rossa.
void installErrorHandlers(AppController ctl, {bool presentToConsole = true}) {
  FlutterError.onError = (details) {
    if (presentToConsole) FlutterError.presentError(details);
    ctl.log('E', 'errore dell\'interfaccia (${details.library ?? 'flutter'}): ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    final top = stack.toString().split('\n').take(3).join(' | ');
    ctl.log('E', 'errore non gestito: $error · $top');
    return true; // gestito: l'app resta aperta
  };
  if (kReleaseMode) ErrorWidget.builder = releaseErrorWidget;
}

/// Riquadro mostrato al posto di un widget che non riesce a disegnarsi (solo versione finale).
Widget releaseErrorWidget(FlutterErrorDetails details) => Container(
      key: const ValueKey('error-box'),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      color: AppColors.surface,
      child: Text(
        tr('Questa parte non può essere mostrata. Dettagli in ⚙ → Diagnostica.'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: AppColors.textDim),
      ),
    );
