import 'package:flutter/foundation.dart';
import '../data/api_repository.dart';
import '../data/mock_repository.dart';
import '../data/repository.dart';
import 'models.dart';

const bool pandoraDemo=bool.fromEnvironment('PANDORA_DEMO',defaultValue:true);
const String apiBaseUrl=String.fromEnvironment('API_BASE_URL',defaultValue:'http://10.0.2.2:8080/api');

class AppState extends ChangeNotifier {
  late final PandoraRepository repo;
  UserProfile? user;
  bool initialized=false;
  AppState(){repo=pandoraDemo?MockRepository():ApiRepository(baseUrl:apiBaseUrl);}
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
