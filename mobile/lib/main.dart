import 'package:flutter/material.dart';
import 'core/app_state.dart';
import 'core/theme.dart';
import 'screens/login_page.dart';
import 'screens/shell_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PandoraApp());
}

class PandoraApp extends StatefulWidget {
  const PandoraApp({super.key});
  @override State<PandoraApp> createState()=>_PandoraAppState();
}
class _PandoraAppState extends State<PandoraApp> {
  final AppState app=AppState();
  @override void initState() {super.initState();app.initialize();}
  @override void dispose(){app.dispose();super.dispose();}
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation:app,
    builder:(context,child)=>MaterialApp(
      title:'潘多拉 · 智能掌上日志',
      debugShowCheckedModeBanner:false,
      theme:pandoraTheme(),
      home:!app.initialized?
        const Scaffold(body:Center(child:CircularProgressIndicator())):
        app.user==null?LoginPage(app:app):ShellPage(key:ValueKey(app.user!.id),app:app),
    ),
  );
}
