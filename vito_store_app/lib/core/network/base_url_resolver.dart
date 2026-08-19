import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Resuelve la base URL del backend en modo híbrido.
///
/// Prueba `<candidato>/api/health` en **paralelo** sobre cada candidato
/// (p. ej. USB `http://localhost:3001`, IP LAN `http://192.168.x.x:3001`,
/// túnel `https://xxx.trycloudflare.com`) y devuelve el primero que responda
/// HTTP 200. Si ninguno responde, devuelve el primer candidato (la app
/// mostrará errores de red normales).
class BaseUrlResolver {
  BaseUrlResolver._();

  static const _timeout = Duration(seconds: 5);

  static Future<String> resolve(List<String> candidates) async {
    if (candidates.length <= 1) {
      return candidates.isEmpty ? '' : candidates.first;
    }

    final winner = Completer<String>();

    await Future.wait(candidates.map((url) async {
      final reachable = await _probe(url);
      if (reachable && !winner.isCompleted) {
        winner.complete(url);
      }
    }));

    final selected = winner.isCompleted ? await winner.future : candidates.first;
    debugPrint('[BaseUrlResolver] backend seleccionado: $selected');
    return selected;
  }

  static Future<bool> _probe(String baseUrl) async {
    final trimmed = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final healthUrl =
        trimmed.endsWith('/api') ? '$trimmed/health' : '$trimmed/api/health';
    final dio = Dio(BaseOptions(
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      sendTimeout: _timeout,
    ));
    try {
      final resp = await dio.get(healthUrl);
      final ok = resp.statusCode == 200;
      debugPrint('[BaseUrlResolver] $healthUrl -> ${resp.statusCode}');
      return ok;
    } catch (_) {
      debugPrint('[BaseUrlResolver] $healthUrl -> sin respuesta');
      return false;
    } finally {
      dio.close();
    }
  }
}
