import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'settings_page.dart';
import 'settings.dart';

part 'main_page_controller.dart';

class MainPage extends StatefulWidget {
  final String title = "";

  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageScreen();
}

class _MainPageScreen extends _MainPageController {
  @override
  Widget build(BuildContext context) {
    bool isWatch = _checkIfWatch(context);
    return Scaffold(
      backgroundColor: const Color.fromRGBO(20, 20, 20, 0.9),
      appBar: isWatch
          ? null
          : AppBar(
              title: const Center(child: Text('GarageOpen 2.1')),
            ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _showButton(AppAction.open, isWatch),
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
              child: _showState(isWatch),
            ),
            _showButton(AppAction.close, isWatch),
          ],
        ),
      ),
    );
  }

  bool _checkIfWatch(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      int width = MediaQuery.of(context).size.width.round();
      int height = MediaQuery.of(context).size.height.round();
      // This is an approximation
      return (width == height);
    }
    return false;
  }

  bool _isButtonEnabled(AppAction appAction) {
    switch (appAction) {
      case AppAction.open:
        return _appState == AppState.closed;
      case AppAction.close:
        return _appState == AppState.open;
      case AppAction.doorstatus:
        return false; // This is impossible
    }
  }

  Widget _showButton(AppAction appAction, bool isWatch) {
    bool isEnabled = _isButtonEnabled(appAction);
    double fontSize = isWatch ? 20 : 40;
    return OutlinedButton.icon(
      style: ButtonStyle(
          foregroundColor: MaterialStatePropertyAll<Color>(
              isEnabled ? Colors.white : Colors.white54),
          backgroundColor: MaterialStatePropertyAll<Color>(isEnabled
              ? (appAction == AppAction.open ? Colors.green : Colors.red)
              : Colors.grey),
          // Make it as large as the screen
          padding: MaterialStatePropertyAll<EdgeInsetsGeometry>(
              EdgeInsets.all(fontSize)),
          minimumSize: MaterialStatePropertyAll<Size>(
              Size(MediaQuery.of(context).size.width, 0)),
          iconSize: MaterialStatePropertyAll<double>(fontSize),
          textStyle: MaterialStatePropertyAll<TextStyle>(
              TextStyle(fontSize: fontSize))),
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

  Widget _showState(bool isWatch) {
    double fontSize = isWatch ? 20 : 40;
    double animationSize = isWatch ? 30 : 60;
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
