part of 'main_page_screen.dart';

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

abstract class _MainPageController extends State<MainPage> with WidgetsBindingObserver {
  AppState _appState = AppState.error;
  bool _needsRefresh = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  void _setState(AppState newState) {
    setState(() {
      _appState = newState;
    });
  }

  void _refreshState() async {
    // Set State to refreshing to update the UI
    _setState(AppState.refreshing);

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
    _setState(newState);
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
    _setState(newState);

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
      _setState(newState);
    }
  }
}
