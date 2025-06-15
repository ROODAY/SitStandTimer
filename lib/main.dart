import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SitStandTimerScreen(),
    );
  }
}

class SitStandTimerScreen extends StatefulWidget {
  const SitStandTimerScreen({super.key});

  @override
  State<SitStandTimerScreen> createState() => _SitStandTimerScreenState();
}

class _SitStandTimerScreenState extends State<SitStandTimerScreen> {
  int sitMinutes = 30;
  int standMinutes = 30;
  bool walkEnabled = false;
  int walkMinutes = 5;
  int walkFrequency = 2; // every N cycles
  String startPhase = 'Sit';
  String currentPhase = 'Sit';
  bool isRunning = false;
  bool isPaused = false;
  Timer? _timer;
  int _remainingSeconds = 0;
  int _walkCycleCounter = 0;
  bool developerMode = false;
  bool useSeconds = false; // true: seconds, false: minutes
  int warningTime = 5; // minutes (or seconds in dev mode)
  FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
  bool _didRequestPermissions = false;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    // _requestNotificationPermission(); // Moved to didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didRequestPermissions) {
      _didRequestPermissions = true;
      _requestNotificationPermission();
    }
  }

  Future<void> _initNotifications() async {
    tz.initializeTimeZones();
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin!.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    if (response.payload == 'delay5') {
      _addTimeToCurrentPhase(5 * (useSeconds ? 1 : 60));
    } else if (response.payload == 'delay10') {
      _addTimeToCurrentPhase(10 * (useSeconds ? 1 : 60));
    }
  }

  Future<void> _requestNotificationPermission() async {
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Notification Permission Required'),
              content: const Text('Please enable notification permissions in settings to receive reminders.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }
      // Request exact alarm permission if needed
      final alarmStatus = await Permission.scheduleExactAlarm.request();
      if (!alarmStatus.isGranted) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Alarm Permission Required'),
              content: const Text('Please enable exact alarm permissions in settings to receive scheduled reminders.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> _scheduleWarningNotification() async {
    if (flutterLocalNotificationsPlugin == null) return;
    final int warnSeconds = warningTime * (useSeconds ? 1 : 60);
    final int scheduleDelay = _remainingSeconds - warnSeconds;
    // Check permissions before scheduling
    final notificationStatus = await Permission.notification.status;
    final alarmStatus = await Permission.scheduleExactAlarm.status;
    if (!notificationStatus.isGranted || !alarmStatus.isGranted) {
      return;
    }
    if (scheduleDelay <= 0) {
      // If the warning time has already passed, show immediately
      await flutterLocalNotificationsPlugin!.show(
        0,
        'Phase ending soon',
        'Current phase ($currentPhase) will end soon. Delay?',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'phase_warning',
            'Phase Warning',
            channelDescription: 'Warn before phase ends',
            importance: Importance.max,
            priority: Priority.high,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction('delay5', 'Delay 5'),
              AndroidNotificationAction('delay10', 'Delay 10'),
            ],
          ),
        ),
      );
      return;
    }
    final scheduledTime = tz.TZDateTime.now(tz.local).add(Duration(seconds: scheduleDelay));
    // ignore: avoid_print
    // print('[DEBUG] Scheduling warning notification for: $scheduledTime, curTime: ${DateTime.now()}');
    await flutterLocalNotificationsPlugin!.zonedSchedule(
      0,
      'Phase ending soon',
      'Current phase ($currentPhase) will end soon. Delay?',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'phase_warning',
          'Phase Warning',
          channelDescription: 'Warn before phase ends',
          importance: Importance.max,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction('delay5', 'Delay 5'),
            AndroidNotificationAction('delay10', 'Delay 10'),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _schedulePhaseSwitchNotification(String nextPhase, int secondsUntilSwitch) async {
    if (flutterLocalNotificationsPlugin == null) return;
    // Check permissions before scheduling
    final notificationStatus = await Permission.notification.status;
    final alarmStatus = await Permission.scheduleExactAlarm.status;
    if (!notificationStatus.isGranted || !alarmStatus.isGranted) {
      return;
    }
    if (secondsUntilSwitch <= 0) {
      await flutterLocalNotificationsPlugin!.show(
        1,
        'Phase switched',
        'It\'s time to $nextPhase!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'phase_switch',
            'Phase Switch',
            channelDescription: 'Notify when phase switches',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
      return;
    }
    final curTime = tz.TZDateTime.now(tz.local);
    final scheduledTime = curTime.add(Duration(seconds: secondsUntilSwitch));
    print('[DEBUG] Scheduling phase switch notification for: $scheduledTime, curTime: $curTime');
    await flutterLocalNotificationsPlugin!.zonedSchedule(
      1,
      'Phase switched',
      'It\'s time to $nextPhase!',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'phase_switch',
          'Phase Switch',
          channelDescription: 'Notify when phase switches',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  void _startTimer() {
    setState(() {
      isRunning = true;
      isPaused = false;
      currentPhase = startPhase;
      _walkCycleCounter = 0;
      _setPhaseDuration();
    });
    _runTimer();
    // _cancelAllNotifications();
    _scheduleWarningNotification();
    _schedulePhaseSwitchNotification(_getNextPhase(), _remainingSeconds);
  }

  String _getNextPhase() {
    if (currentPhase == 'Sit') {
      return 'Stand';
    } else if (currentPhase == 'Stand' && walkEnabled && _walkCycleCounter + 1 >= walkFrequency) {
      return 'Walk';
    } else {
      return 'Sit';
    }
  }

  void _runTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isPaused && isRunning) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _onPhaseComplete();
          }
        });
      }
    });
  }

  void _setPhaseDuration() {
    int multiplier = useSeconds ? 1 : 60;
    switch (currentPhase) {
      case 'Sit':
        _remainingSeconds = sitMinutes * multiplier;
        break;
      case 'Stand':
        _remainingSeconds = standMinutes * multiplier;
        break;
      case 'Walk':
        _remainingSeconds = walkMinutes * multiplier;
        break;
    }
  }

  void _onPhaseComplete() {
    _timer?.cancel();
    _proceedToNextPhase();
    if (isRunning) {
      _runTimer();
      // _cancelAllNotifications();
      _scheduleWarningNotification();
      _schedulePhaseSwitchNotification(_getNextPhase(), _remainingSeconds);
    }
  }

  void _addTimeToCurrentPhase(int seconds) {
    setState(() {
      _remainingSeconds += seconds;
    });
  }

  void _skipCurrentPhase() {
    _timer?.cancel();
    _proceedToNextPhase();
    if (isRunning) {
      _runTimer();
    }
  }

  void _proceedToNextPhase() {
    if (currentPhase == 'Sit') {
      currentPhase = 'Stand';
      _setPhaseDuration();
    } else if (currentPhase == 'Stand') {
      if (walkEnabled) {
        _walkCycleCounter++;
        if (_walkCycleCounter >= walkFrequency) {
          currentPhase = 'Walk';
          _walkCycleCounter = 0;
          _setPhaseDuration();
          setState(() {});
          return;
        }
      }
      currentPhase = 'Sit';
      _setPhaseDuration();
    } else if (currentPhase == 'Walk') {
      currentPhase = 'Sit';
      _setPhaseDuration();
    }
    setState(() {});
  }

  void _pauseTimer() {
    setState(() {
      isPaused = true;
    });
  }

  void _resumeTimer() {
    setState(() {
      isPaused = false;
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _cancelAllNotifications();
    setState(() {
      isRunning = false;
      isPaused = false;
      currentPhase = startPhase;
      _remainingSeconds = 0;
    });
  }

  void _cancelAllNotifications() {
    flutterLocalNotificationsPlugin?.cancelAll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sit/Stand Timer')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isRunning
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Current Phase: '
                      '$currentPhase',
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        for (var min in [5, 10, 15])
                          ElevatedButton(
                            onPressed: () => _addTimeToCurrentPhase(min * (useSeconds ? 1 : 60)),
                            child: Text('Add $min ${useSeconds ? 'sec' : 'min'}'),
                            style: ElevatedButton.styleFrom(
                              textStyle: const TextStyle(fontSize: 20),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                          ),
                        ElevatedButton(
                          onPressed: () async {
                            final controller = TextEditingController();
                            final result = await showDialog<int>(
                              context: context,
                              builder: (dialogContext) {
                                return AlertDialog(
                                  title: const Text('Custom Add Time'),
                                  content: TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(hintText: useSeconds ? 'Seconds' : 'Minutes'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(dialogContext).pop(),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        final val = int.tryParse(controller.text);
                                        if (val != null && val > 0) {
                                          Navigator.of(dialogContext).pop(val * (useSeconds ? 1 : 60));
                                        }
                                      },
                                      child: const Text('OK'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (result != null) {
                              _addTimeToCurrentPhase(result);
                            }
                          },
                          child: const Text('Custom'),
                          style: ElevatedButton.styleFrom(
                            textStyle: const TextStyle(fontSize: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _skipCurrentPhase,
                          child: const Text('Skip Phase'),
                          style: ElevatedButton.styleFrom(
                            textStyle: const TextStyle(fontSize: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: isPaused ? _resumeTimer : _pauseTimer,
                          child: Text(isPaused ? 'Resume' : 'Pause'),
                          style: ElevatedButton.styleFrom(
                            textStyle: const TextStyle(fontSize: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                          ),
                        ),
                        const SizedBox(width: 24),
                        ElevatedButton(
                          onPressed: _stopTimer,
                          child: const Text('Stop'),
                          style: ElevatedButton.styleFrom(
                            textStyle: const TextStyle(fontSize: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : ListView(
                children: [
                  if (kDebugMode)
                    Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Developer Mode'),
                          value: developerMode,
                          onChanged: (v) => setState(() => developerMode = v),
                        ),
                        if (developerMode)
                          SwitchListTile(
                            title: const Text('Use Seconds (instead of Minutes)'),
                            value: useSeconds,
                            onChanged: (v) => setState(() => useSeconds = v),
                          ),
                      ],
                    ),
                  Row(
                    children: [
                      const Text('Sit'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: sitMinutes.toDouble(),
                          min: 5,
                          max: 120,
                          divisions: 23,
                          label: sitMinutes.toString(),
                          onChanged: (v) => setState(() => sitMinutes = v.round()),
                        ),
                      ),
                      Text('$sitMinutes ${useSeconds ? 'sec' : 'min'}'),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Stand'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: standMinutes.toDouble(),
                          min: 5,
                          max: 120,
                          divisions: 23,
                          label: standMinutes.toString(),
                          onChanged: (v) => setState(() => standMinutes = v.round()),
                        ),
                      ),
                      Text('$standMinutes ${useSeconds ? 'sec' : 'min'}'),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('Enable Walk Phase'),
                    value: walkEnabled,
                    onChanged: (v) => setState(() => walkEnabled = v),
                  ),
                  if (walkEnabled) ...[
                    Row(
                      children: [
                        const Text('Walk'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: walkMinutes.toDouble(),
                            min: 1,
                            max: 30,
                            divisions: 29,
                            label: walkMinutes.toString(),
                            onChanged: (v) => setState(() => walkMinutes = v.round()),
                          ),
                        ),
                        Text('$walkMinutes ${useSeconds ? 'sec' : 'min'}'),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Walk every'),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: walkFrequency,
                          items: List.generate(10, (i) => i + 1)
                              .map((e) => DropdownMenuItem(value: e, child: Text('$e cycle${e > 1 ? 's' : ''}')))
                              .toList(),
                          onChanged: (v) => setState(() => walkFrequency = v ?? 1),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Start with:'),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: startPhase,
                        items: const [
                          DropdownMenuItem(value: 'Sit', child: Text('Sit')),
                          DropdownMenuItem(value: 'Stand', child: Text('Stand')),
                        ],
                        onChanged: (v) => setState(() => startPhase = v ?? 'Sit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _startTimer,
                        child: const Text('Start'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Warn before phase ends:'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: warningTime.toDouble(),
                          min: 1,
                          max: useSeconds ? 30 : 30,
                          divisions: 29,
                          label: warningTime.toString(),
                          onChanged: (v) => setState(() => warningTime = v.round()),
                        ),
                      ),
                      Text('$warningTime ${useSeconds ? 'sec' : 'min'}'),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
