import 'package:flutter/foundation.dart';
import '../data/api_repository.dart';
import '../data/mock_repository.dart';
import '../data/repository.dart';
import '../data/holiday_calendar_service.dart';
import 'models.dart';

const bool pandoraDemo=bool.fromEnvironment('PANDORA_DEMO',defaultValue:true);
const String apiBaseUrl=String.fromEnvironment('API_BASE_URL',defaultValue:'http://10.0.2.2:8080/api');
// Demo-only switch. Example: --dart-define=PANDORA_DEMO_DISABLED_IDS=12
// Never used in real API mode; real account states come from the backend.
const String demoDisabledUserIds = String.fromEnvironment(
  'PANDORA_DEMO_DISABLED_IDS', defaultValue: '');

class AppState extends ChangeNotifier {
  late final PandoraRepository repo;
  late final HolidayCalendarService holidays;
  UserProfile? user;
  bool initialized=false;
  AppState(){
    repo=pandoraDemo ? MockRepository(disabledUserIds: demoDisabledUserIds
      .split(',').map((value) => int.tryParse(value.trim()))
      .whereType<int>().toSet()) : ApiRepository(baseUrl:apiBaseUrl);
    holidays=HolidayCalendarService(fetchYear: repo.holidayYear);
  }
  Future<void> initialize() async {
    try {user=await repo.restore();}catch (_) {user=null;}
    initialized=true;notifyListeners();
  }
  Future<void> login(String username,String password) async {
    user=await repo.login(username,password);
    notifyListeners();
  }
  Future<void> logout() async {
    try {await repo.logout();} finally {user=null;notifyListeners();}
  }
}
