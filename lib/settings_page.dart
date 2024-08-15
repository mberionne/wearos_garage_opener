import 'package:flutter/material.dart';
import 'settings.dart';

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
  final Settings _settings = Settings();

  @override
  void initState() {
    super.initState();
    _deviceId = _settings.getDeviceId();
    _accessToken = _settings.getAccessToken();
    _currentSliderValue = _settings.getDuration().toDouble();
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
                      prefix: Icon(
                        Icons.perm_device_info,
                        color: Colors.white24,
                      ),
                    ),
                    onSaved: (String? value) =>
                        _settings.setDeviceId(value ?? ''),
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
                      prefix: Icon(
                        Icons.token,
                        color: Colors.white24,
                      ),
                    ),
                    onSaved: (String? value) =>
                        _settings.setAccessToken(value ?? ''),
                    validator: (String? value) {
                      final regex = RegExp(r'^[0-9A-Fa-f]{40}$');
                      return (value == null || !regex.hasMatch(value))
                          ? 'Invalid access token.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Duration: ${_currentSliderValue.toInt()} seconds',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Slider(
                      value: _currentSliderValue,
                      min: 1,
                      max: 15,
                      divisions: 14,
                      label: _currentSliderValue.toInt().toString(),
                      onChanged: (double value) {
                        setState(() {
                          _currentSliderValue = value;
                        });
                      }),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        _settings.setDuration(_currentSliderValue.toInt());
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
