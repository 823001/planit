import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // 타임존 초기화
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
  }

  /// 마감 기한 알림 예약
  static Future<void> scheduleDeadlineNotification({
    required String notificationId, // task docId 사용
    required String courseTitle,
    required String taskTitle,
    required DateTime deadline,
  }) async {
    final now = DateTime.now();
    if (!deadline.isAfter(now)) return; // 이미 지난 시간이면 안 보냄

    final id = notificationId.hashCode & 0x7fffffff;

    final androidDetails = const AndroidNotificationDetails(
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

    final tzDateTime = tz.TZDateTime.from(deadline, tz.local);

    await _plugin.zonedSchedule(
      id,
      '[$courseTitle] 마감 알림',
      '$taskTitle 마감 시간이 되었습니다.',
      tzDateTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: notificationId,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  /// 해당 task 에 대한 알림 취소
  static Future<void> cancelDeadlineNotification(String notificationId) async {
    final id = notificationId.hashCode & 0x7fffffff;
    await _plugin.cancel(id);
  }
}
