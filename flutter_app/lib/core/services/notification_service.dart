import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    await requestPermissions();
  }

  static Future<void> requestPermissions() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  static const _medicationChannel = AndroidNotificationDetails(
    'medication_channel',
    'Medication Reminders',
    channelDescription: 'Daily medication reminders',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
  );

  static const _appointmentChannel = AndroidNotificationDetails(
    'appointment_channel',
    'Appointment Reminders',
    channelDescription: 'Doctor appointment reminders',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
  );

  static const _orderChannel = AndroidNotificationDetails(
    'order_channel',
    'Order Updates',
    channelDescription: 'Pharmacy order status notifications',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  );

  static const _messageChannel = AndroidNotificationDetails(
    'message_channel',
    'Doctor Messages',
    channelDescription: 'Messages from your doctor',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> scheduleMedication({
    required int id,
    required String name,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      '💊 Medication Reminder',
      'Time to take $name',
      scheduled,
      NotificationDetails(
        android: _medicationChannel,
        iOS: const DarwinNotificationDetails(
          sound: 'default',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> showOrderNotification({
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      NotificationDetails(
        android: _orderChannel,
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
    );
  }

  static Future<void> showMessageNotification({
    required String senderName,
    required String message,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      '💬 Message from $senderName',
      message,
      NotificationDetails(
        android: _messageChannel,
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
    );
  }

  static Future<void> showAppointmentNotification({
    required String doctorName,
    required String time,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      '🗓 Appointment Reminder',
      'Your appointment with $doctorName is at $time',
      NotificationDetails(
        android: _appointmentChannel,
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
    );
  }

  static Future<void> cancelMedication(int id) async {
    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
