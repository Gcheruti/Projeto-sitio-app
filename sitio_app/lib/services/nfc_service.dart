import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:ndef_record/ndef_record.dart';

import 'dispositivo_service.dart';

class NfcService {
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> disponivel() async {
    if (!isAndroid) return false;
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  // ---- Escuta global: qualquer tag de comanda encostada abre a comanda ----
  static void Function(String texto)? _onGlobal;
  static bool _globalAtivo = false;
  static bool _ocupado = false; // leitura/gravação pontual em andamento
  static Timer? _timeout;
  static String? _ultimo;
  static DateTime? _ultimoEm;

  /// Mantém uma sessão NFC aberta durante o uso do app. Leituras e gravações
  /// pontuais (tela NFC, gravar tag) pausam a escuta e a devolvem ao terminar.
  static Future<void> iniciarEscutaGlobal(
      void Function(String texto) onTexto) async {
    if (!isAndroid) return;
    _onGlobal = onTexto;
    if (!_globalAtivo) {
      _globalAtivo = true;
      WidgetsBinding.instance.addObserver(_ObservadorNfc());
    }
    await _abrirGlobal();
  }

  static Future<void> _abrirGlobal() async {
    if (!_globalAtivo || _ocupado) return;
    try {
      if (!await NfcManager.instance.isAvailable()) return;
      try {
        await NfcManager.instance.stopSession();
      } catch (_) {}
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        onDiscovered: (tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) return;
            final message = await ndef.read();
            final texto = message == null ? null : _textoDeMessage(message);
            if (texto == null || texto.trim().isEmpty) return;
            final agora = DateTime.now();
            if (texto == _ultimo &&
                _ultimoEm != null &&
                agora.difference(_ultimoEm!).inSeconds < 3) {
              return; // a mesma tag ainda encostada
            }
            _ultimo = texto;
            _ultimoEm = agora;
            _onGlobal?.call(texto.trim());
          } catch (_) {}
        },
      );
    } catch (_) {}
  }

  /// Chamado antes de uma sessão pontual: pausa a escuta global.
  static Future<void> _preparaSessao() async {
    _ocupado = true;
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 25), () => _stop());
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  static Future<void> _stop() async {
    _timeout?.cancel();
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
    _ocupado = false;
    unawaited(_abrirGlobal());
  }

  static String? _textoDeMessage(NdefMessage message) {
    final textos = <String>[];
    for (final r in message.records) {
      final p = r.payload;
      if (p.isEmpty) continue;
      try {
        // Text Record (NFC Well Known Type Text)
        final status = p[0];
        final langLen = status & 0x3F;
        if (1 + langLen < p.length) {
          final text =
              utf8.decode(p.skip(1 + langLen).toList(), allowMalformed: true).trim();
          if (text.isNotEmpty) textos.add(text);
        }
      } catch (_) {
        final raw = String.fromCharCodes(p).trim();
        if (raw.isNotEmpty) textos.add(raw);
      }
    }
    return textos.isNotEmpty ? textos.first : null;
  }

  static Future<void> lerUmaVez({
    required void Function(String texto) onTexto,
    required void Function(String erro) onErro,
  }) async {
    if (!isAndroid) {
      onErro('NFC só no app Android');
      return;
    }
    try {
      final ok = await NfcManager.instance.isAvailable();
      if (!ok) {
        onErro(DispositivoService.mensagemNfc(await DispositivoService.estadoNfc()));
        return;
      }
      await _preparaSessao();
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        onDiscovered: (tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              await _stop();
              onErro('Tag sem NDEF');
              return;
            }
            final message = await ndef.read();
            await _stop();
            final texto = message == null ? null : _textoDeMessage(message);
            if (texto == null || texto.isEmpty) {
              onErro('Tag vazia ou sem texto');
              return;
            }
            onTexto(texto);
          } catch (e) {
            await _stop();
            onErro('Erro ao ler: $e');
          }
        },
      );
    } catch (e) {
      await _stop();
      onErro('Erro NFC: $e');
    }
  }

  static Future<void> gravarTexto({
    required String texto,
    required void Function() onOk,
    required void Function(String erro) onErro,
    bool permitirVazio = false,
  }) async {
    if (!isAndroid) {
      onErro('NFC só no app Android');
      return;
    }
    final payload = texto.trim();
    if (payload.isEmpty && !permitirVazio) {
      onErro('Texto vazio');
      return;
    }
    try {
      final ok = await NfcManager.instance.isAvailable();
      if (!ok) {
        onErro(DispositivoService.mensagemNfc(await DispositivoService.estadoNfc()));
        return;
      }
      await _preparaSessao();
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
        },
        onDiscovered: (tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null || !ndef.isWritable) {
              await _stop();
              onErro('Tag não é NDEF gravável');
              return;
            }
            // Registro de texto NDEF
            final languageCode = 'pt';
            final langBytes = languageCode.codeUnits;
            final textBytes = utf8.encode(payload);
            final recordPayload = <int>[
              langBytes.length & 0x3F,
              ...langBytes,
              ...textBytes,
            ];
            final message = NdefMessage(
              records: [
                NdefRecord(
                  typeNameFormat: TypeNameFormat.wellKnown,
                  type: Uint8List.fromList([0x54]), // 'T'
                  identifier: Uint8List(0),
                  payload: Uint8List.fromList(recordPayload),
                ),
              ],
            );
            await ndef.write(message: message);
            await _stop();
            onOk();
          } catch (e) {
            await _stop();
            onErro('Erro ao gravar: $e');
          }
        },
      );
    } catch (e) {
      await _stop();
      onErro('Erro NFC: $e');
    }
  }

  static Future<void> limparTag({
    required void Function() onOk,
    required void Function(String erro) onErro,
  }) async {
    await gravarTexto(
      texto: '',
      permitirVazio: true,
      onOk: onOk,
      onErro: onErro,
    );
  }
}

class _ObservadorNfc with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NfcService._abrirGlobal();
    }
  }
}
