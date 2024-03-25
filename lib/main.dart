import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum AppState {
  // The first 5 states corresponds to the values provided by the server.
  unknown,
  open,
  opening,
  closed,
  closing,
  // Additional states used by the application, but not returned by server.
  refreshing,
  error,
  timeout
}

enum AppAction { open, close }

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Garage Opener',
      theme: ThemeData(
        visualDensity: VisualDensity.compact,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlueAccent),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  final String title = "";

  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  AppState _appState = AppState.error;
  bool _needsRefresh = false;
  bool _isAndroidDevice = true;
  bool _isWatch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (defaultTargetPlatform == TargetPlatform.android) {
      _isAndroidDevice = true;
    }
    _refreshState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _needsRefresh = true;
        break;
      case AppLifecycleState.resumed:
        if (_needsRefresh) {
          _needsRefresh = false;
          _refreshState();
        }
        break;
    }
  }

  Uri _composeUri(SharedPreferences prefs, String action) {
    String deviceId = prefs.getString('device_id') ?? '';
    String accessToken = prefs.getString('access_token') ?? '';
    return Uri.parse(
        'https://api.particle.io/v1/devices/$deviceId/$action?access_token=$accessToken');
  }

  void _refreshState() async {
    // Set State to refreshing to update the UI
    setState(() {
      _appState = AppState.refreshing;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final uri = _composeUri(prefs, 'doorstatus');
    AppState newState = AppState.error;
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        Map<String, dynamic> map = jsonDecode(response.body);
        int result = map['result'];
        newState = AppState.values[result];
      }
    } on TimeoutException catch (_) {
      newState = AppState.timeout;
    } catch (e) {
      newState = AppState.error;
    }
    // Update new state on the UI
    setState(() {
      _appState = newState;
    });
    // For opening and closing, these are intermediate states.
    if (newState == AppState.opening || newState == AppState.closing) {
      int delay = double.parse(prefs.getString('duration') ?? '3.0').round();
      Future<void>.delayed(
        Duration(seconds: delay),
        () => _refreshState(),
      );
    }
  }

  void _onButtonPressed(AppAction appAction) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Uri? uri;
    // Compose the URI and set the new state based on action and state.
    AppState newState = AppState.error;
    if (appAction == AppAction.open && _appState == AppState.closed) {
      uri = _composeUri(prefs, 'open');
      newState = AppState.opening;
    } else if (appAction == AppAction.close && _appState == AppState.open) {
      uri = _composeUri(prefs, 'close');
      newState = AppState.closing;
    } else {
      // Nothing to do in invalid state
      return;
    }
    setState(() {
      _appState = newState;
    });

    // Perform HTTP request
    bool success = false;
    try {
      final response = await http.post(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        success = true;
        // In case of success to issue the request, there is no point in checking
        // the state immediately because the proper value was already set above,
        // but rather schedule it based on the refresh period.
        int delay = double.parse(prefs.getString('duration') ?? '3.0').round();
        Future<void>.delayed(
          Duration(seconds: delay),
          () => _refreshState(),
        );
      } else {
        newState = AppState.error;
      }
    } on TimeoutException catch (_) {
      newState = AppState.timeout;
    } catch (e) {
      newState = AppState.error;
    }
    if (!success) {
      // In case of success, the state is refreshed automatically.
      setState(() {
        _appState = newState;
      });
    }
  }

  void calculateDeviceType(BuildContext context) {
    if (_isAndroidDevice) {
      int width = MediaQuery.of(context).size.width.round();
      int height = MediaQuery.of(context).size.height.round();
      // This is an approximation
      _isWatch = (width == height);
    }
  }

  @override
  Widget build(BuildContext context) {
    calculateDeviceType(context);
    return Scaffold(
      backgroundColor: const Color.fromRGBO(20, 20, 20, 0.9),
      appBar: _isWatch
          ? null
          : AppBar(
              title: const Center(child: Text('GarageOpen 2.1')),
            ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            showButton(AppAction.open),
            GestureDetector(
              onDoubleTap: () {
                if (_appState != AppState.refreshing &&
                    _appState != AppState.opening &&
                    _appState != AppState.closing) {
                  _refreshState();
                }
              },
              onLongPress: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                ).then((value) {
                  // If the settings are modified, perform a refresh
                  if (value) {
                    _refreshState();
                  }
                });
              },
              child: showState(),
            ),
            showButton(AppAction.close),
          ],
        ),
      ),
    );
  }

  bool _isButtonEnabled(AppAction appAction) {
    switch (appAction) {
      case AppAction.open:
        return _appState == AppState.closed;
      case AppAction.close:
        return _appState == AppState.open;
    }
  }

  Widget showButton(AppAction appAction) {
    bool isEnabled = _isButtonEnabled(appAction);
    return OutlinedButton.icon(
      style: ButtonStyle(
          foregroundColor: MaterialStatePropertyAll<Color>(
              isEnabled ? Colors.white : Colors.white54),
          backgroundColor: MaterialStatePropertyAll<Color>(isEnabled
              ? (appAction == AppAction.open ? Colors.green : Colors.red)
              : Colors.grey)),
      onPressed: isEnabled
          ? () {
              log('Button pressed: $appAction.name');
              _onButtonPressed(appAction);
            }
          : null,
      icon: Icon(appAction == AppAction.open
          ? Icons.file_upload
          : Icons.file_download),
      label: Text(appAction == AppAction.open ? 'Open' : 'Close'),
    );
  }

  Widget showState() {
    double fontSize = _isWatch ? 20 : 40;
    double animationSize = _isWatch ? 30 : 60;
    switch (_appState) {
      case AppState.refreshing:
      case AppState.opening:
      case AppState.closing:
        return Column(
          children: <Widget>[
            SizedBox(
              width: animationSize,
              height: animationSize,
              child: const CircularProgressIndicator(),
            ),
            Text(
              _appState.name,
              style: TextStyle(fontSize: fontSize, color: Colors.white),
            )
          ],
        );
      case AppState.open:
      case AppState.closed:
      case AppState.unknown:
      case AppState.error:
      case AppState.timeout:
        return Text(
          _appState.name,
          style: TextStyle(fontSize: fontSize, color: Colors.white),
        );
    }
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  double _currentSliderValue = 3.0;
  String _deviceId = '';
  String _accessToken = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceId = prefs.getString('device_id') ?? '';
      _accessToken = prefs.getString('access_token') ?? '';
      _currentSliderValue = double.parse(prefs.getString('duration') ?? '3.0');
    });
  }

  void _saveSettings(String key, String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(20, 20, 20, 0.9),
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: FractionallySizedBox(
            widthFactor: 0.8,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TextFormField(
                    style: const TextStyle(color: Colors.white),
                    controller: TextEditingController(text: _deviceId),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Device ID',
                      labelText: 'Device ID',
                      prefix: Icon(Icons.perm_device_info, color: Colors.white24,),
                    ),
                    onSaved: (String? value) =>
                        _saveSettings('device_id', value ?? ''),
                    validator: (String? value) {
                      final regex = RegExp(r'^[0-9A-Fa-f]{24}$');
                      return (value == null || !regex.hasMatch(value))
                          ? 'Invalid Device ID.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    style: const TextStyle(color: Colors.white),
                    controller: TextEditingController(text: _accessToken),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Access token',
                      labelText: 'Access token',
                      prefix: Icon(Icons.token, color: Colors.white24,),
                    ),
                    onSaved: (String? value) =>
                        _saveSettings('access_token', value ?? ''),
                    validator: (String? value) {
                      final regex = RegExp(r'^[0-9A-Fa-f]{40}$');
                      return (value == null || !regex.hasMatch(value))
                          ? 'Invalid access token.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Duration: ${_currentSliderValue.round()} seconds',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Slider(
                      value: _currentSliderValue,
                      min: 1,
                      max: 15,
                      divisions: 15,
                      label: _currentSliderValue.round().toString(),
                      onChanged: (double value) {
                        setState(() {
                          _currentSliderValue = value;
                        });
                      }),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        _saveSettings(
                            'duration', _currentSliderValue.toString());
                        Navigator.pop(context, true);
                      }
                    },
                    child: const Text('Save!'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
