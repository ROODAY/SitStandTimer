import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';

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
    tz.initializeTimeZones();
    _initNotifications();
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

  Future<bool> _canScheduleExactAlarms() async {
    if (!mounted) return false;
    final platform = Theme.of(context).platform;
    if (platform != TargetPlatform.android) return true;
    // Android 12+
    final intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      package: 'com.example.sit_stand_timer',
    );
    // Check permission
    var status = await Permission.scheduleExactAlarm.status;
    if (!status.isGranted) {
      await intent.launch();
      return false;
    }
    return true;
  }

  Future<void> _requestNotificationPermission() async {
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.android) {
      await Permission.notification.request();
    }
  }

  Future<void> _scheduleWarningNotification() async {
    if (flutterLocalNotificationsPlugin == null) return;
    final int warnSeconds = warningTime * (useSeconds ? 1 : 60);
    if (_remainingSeconds > warnSeconds) {
      bool canSchedule = await _canScheduleExactAlarms();
      if (!canSchedule) {
        // Fallback: show immediate notification
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
      await flutterLocalNotificationsPlugin!.zonedSchedule(
        0,
        'Phase ending soon',
        'Current phase ($currentPhase) will end soon. Delay?',
        tz.TZDateTime.from(
          DateTime.now().add(Duration(seconds: _remainingSeconds - warnSeconds)),
          tz.local,
        ),
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
        payload: '',
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null,
      );
    }
  }

  Future<void> _schedulePhaseSwitchNotification(String nextPhase) async {
    if (flutterLocalNotificationsPlugin == null) return;
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
  }

  void _cancelAllNotifications() {
    flutterLocalNotificationsPlugin?.cancelAll();
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
    _cancelAllNotifications();
    _scheduleWarningNotification();
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
    String nextPhase = '';
    if (currentPhase == 'Sit') {
      nextPhase = 'Stand';
    } else if (currentPhase == 'Stand' && walkEnabled && _walkCycleCounter + 1 >= walkFrequency) {
      nextPhase = 'Walk';
    } else {
      nextPhase = 'Sit';
    }
    _schedulePhaseSwitchNotification(nextPhase);
    _proceedToNextPhase();
    if (isRunning) {
      _runTimer();
      _cancelAllNotifications();
      _scheduleWarningNotification();
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
    setState(() {
      isRunning = false;
      isPaused = false;
      currentPhase = startPhase;
      _remainingSeconds = 0;
    });
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
        child: ListView(
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
                    onChanged: isRunning ? null : (v) => setState(() => sitMinutes = v.round()),
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
                    onChanged: isRunning ? null : (v) => setState(() => standMinutes = v.round()),
                  ),
                ),
                Text('$standMinutes ${useSeconds ? 'sec' : 'min'}'),
              ],
            ),
            SwitchListTile(
              title: const Text('Enable Walk Phase'),
              value: walkEnabled,
              onChanged: isRunning ? null : (v) => setState(() => walkEnabled = v),
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
                      onChanged: isRunning ? null : (v) => setState(() => walkMinutes = v.round()),
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
                    onChanged: isRunning ? null : (v) => setState(() => walkFrequency = v ?? 1),
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
                  onChanged: isRunning ? null : (v) => setState(() => startPhase = v ?? 'Sit'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Text(
                    'Current Phase: $currentPhase',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (isRunning)
                    Text(
                      _formatTime(_remainingSeconds),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  if (isRunning) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (var min in [5, 10, 15])
                          ElevatedButton(
                            onPressed: () => _addTimeToCurrentPhase(min * (useSeconds ? 1 : 60)),
                            child: Text('Add $min ${useSeconds ? 'sec' : 'min'}'),
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
                        ),
                        ElevatedButton(
                          onPressed: _skipCurrentPhase,
                          child: const Text('Skip Phase'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: isRunning
                      ? null
                      : _startTimer,
                  child: const Text('Start'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: isRunning && !isPaused
                      ? _pauseTimer
                      : isRunning && isPaused
                          ? _resumeTimer
                          : null,
                  child: Text(isPaused ? 'Resume' : 'Pause'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: isRunning ? _stopTimer : null,
                  child: const Text('Stop'),
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
                    onChanged: isRunning ? null : (v) => setState(() => warningTime = v.round()),
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

