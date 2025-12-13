import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      'task_deadline_channel',
      '할 일 마감 알림',
      description: '강의별 투두리스트 마감 기한 알림',
      importance: Importance.max,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// 마감 하루 전 알림 예약
  static Future<void> scheduleDeadlineNotification({
    required String notificationId,
    required String courseTitle,
    required String taskTitle,
    required DateTime deadline,
  }) async {
    final now = DateTime.now();

    // 마감 자체가 과거면 예약 불가
    if (!deadline.isAfter(now)) return;

    // "하루 전" 알림 시각
    final notifyAt = deadline.subtract(const Duration(days: 1));

    // 하루 전 시간이 이미 지났으면 예약 안 함
    if (!notifyAt.isAfter(now)) return;

    final id = notificationId.hashCode & 0x7fffffff;

    const androidDetails = AndroidNotificationDetails(
      'task_deadline_channel',
      '할 일 마감 알림',
      channelDescription: '강의별 투두리스트 마감 기한 알림',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tzDateTime = tz.TZDateTime.from(notifyAt, tz.local);

    await _plugin.zonedSchedule(
      id,
      '[$courseTitle] 마감 하루 전 알림',
      '내일 마감: $taskTitle',
      tzDateTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: notificationId,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  static Future<void> cancelDeadlineNotification(String notificationId) async {
    final id = notificationId.hashCode & 0x7fffffff;
    await _plugin.cancel(id);
  }
}
