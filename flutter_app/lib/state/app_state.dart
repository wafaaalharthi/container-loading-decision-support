import 'package:flutter/widgets.dart';

import '../core/strings.dart';
import '../data/models.dart';
import '../data/repositories.dart';

/// App-wide state: language and the signed-in user.
class AppState extends ChangeNotifier {
  final _users = UserRepository();
  final _settings = SettingsRepository();

  String lang = 'ar';
  AppUser? user;

  Future<void> load() async {
    lang = await _settings.get('lang') ?? 'ar';
    final id = int.tryParse(await _settings.get('session_user') ?? '');
    if (id != null) user = await _users.byId(id);
  }

  String t(String key, [Map<String, Object>? args]) => translate(lang, key, args);

  Future<void> setLang(String value) async {
    if (value == lang) return;
    lang = value;
    notifyListeners();
    await _settings.set('lang', value);
  }

  Future<void> signUp(String name, String email, String password) async {
    _setUser(await _users.signUp(name, email, password));
    await _settings.set('session_user', '${user!.id}');
  }

  Future<void> signIn(String email, String password) async {
    _setUser(await _users.signIn(email, password));
    await _settings.set('session_user', '${user!.id}');
  }

  Future<void> updateProfile(String name, String email) async {
    _setUser(await _users.updateProfile(user!.id, name, email));
  }

  Future<void> changePassword(String current, String next) => _users.changePassword(user!.id, current, next);

  Future<void> signOut() async {
    _setUser(null);
    await _settings.set('session_user', null);
  }

  void _setUser(AppUser? u) {
    user = u;
    notifyListeners();
  }
}

/// Makes [AppState] reachable from any widget.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState super.notifier, required super.child});

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Same as [of] without listening (safe in initState and callbacks).
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

extension AppContext on BuildContext {
  AppState get app => AppScope.of(this);
  String tr(String key, [Map<String, Object>? args]) => AppScope.of(this).t(key, args);
}
