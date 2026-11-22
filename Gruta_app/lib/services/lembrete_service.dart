import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/progresso.dart';
import 'repositorio_supabase.dart';

/// Lembrete diário ("sua vela ainda não foi acesa hoje").
///
/// É notificação LOCAL, agendada no próprio aparelho: não precisa de servidor,
/// Firebase nem conta na Apple Push. Funciona no Android e no iOS.
/// No navegador não há agendamento (o site não roda fechado).
///
/// Estratégia: agenda os próximos 7 dias. Se a pessoa já estudou hoje, o
/// lembrete de hoje não é agendado. Toda vez que o app abre ou uma aula é
/// concluída, reagenda (assim nunca avisa quem já fez a aula do dia).
class LembreteService {
  LembreteService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _pronto = false;

  static bool get suportado =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static const _mensagens = [
    ('Sua vela ainda está apagada', 'Cinco minutos na Gruta e ela acende de novo.'),
    ('A aula de hoje te espera', 'Um vídeo curto, com calma, quando puder.'),
    ('Não deixe a chama apagar', 'Sua ofensiva continua com a aula de hoje.'),
    ('Hora de voltar à Gruta', 'Tem conhecimento novo na estante.'),
  ];

  static Future<void> iniciar() async {
    if (!suportado || _pronto) return;
    try {
      tzdata.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
      RepositorioSupabase.fuso = local.identifier;
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      RepositorioSupabase.fuso = 'America/Sao_Paulo';
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // No iOS NÃO pedimos permissão ao abrir o app: pedimos só quando a
    // pessoa liga o lembrete (a Apple recomenda pedir no momento em que faz
    // sentido; quem nega na primeira vez só reativa pelos Ajustes do iPhone).
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
    );
    _pronto = true;
  }

  /// Pede a permissão de notificação (Android 13+ e iOS). Retorna se foi dada.
  static Future<bool> pedirPermissao() async {
    if (!suportado) return false;
    await iniciar();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final a = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await a?.requestNotificationsPermission() ?? false;
    }
    final i = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await i?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  static Future<void> reagendar(Perfil perfil, {required bool feitoHoje}) async {
    if (!suportado) return;
    await iniciar();
    await _plugin.cancelAll();
    if (!perfil.lembreteAtivo) return;

    const detalhes = NotificationDetails(
      android: AndroidNotificationDetails(
        'gruta_lembrete',
        'Lembrete diário',
        channelDescription: 'Aviso para não perder a ofensiva',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    final agora = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < 7; i++) {
      final quando = tz.TZDateTime(tz.local, agora.year, agora.month,
          agora.day + i, perfil.lembreteHora, perfil.lembreteMinuto);
      if (quando.isBefore(agora)) continue;
      if (i == 0 && feitoHoje) continue;
      final m = _mensagens[(agora.day + i) % _mensagens.length];
      try {
        await _plugin.zonedSchedule(
          id: 100 + i,
          title: m.$1,
          body: m.$2,
          scheduledDate: quando,
          notificationDetails: detalhes,
          // Inexato: não precisa da permissão de "alarme exato" do Android
          // (que a Play Store fiscaliza). Pode chegar alguns minutos depois.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('Lembrete não agendado: $e');
      }
    }
  }

  /// Mostra na hora um aviso enviado pela equipe (painel /adm).
  static Future<void> mostrarAgora(String titulo, String texto) async {
    if (!suportado) return;
    try {
      await iniciar();
      await _plugin.show(
        id: 1,
        title: titulo,
        body: texto,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'gruta_avisos',
            'Avisos da Gruta',
            channelDescription: 'Novidades enviadas pela equipe',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Aviso não mostrado: $e');
    }
  }
}
