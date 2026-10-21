import 'package:flutter/material.dart';

class Palette {
  static const Color primary=Color(0xFF258F82);
  static const Color deep=Color(0xFF153C41);
  static const Color sage=Color(0xFFE0F5ED);
  static const Color paper=Color(0xFFF6F9F7);
  static const Color pastel=Color(0xFFFDF2E2);
  static const Color coral=Color(0xFFE9977E);
  static const Color muted=Color(0xFF839597);
  static const Color divider=Color(0xFFEDF1EE);
}
ThemeData pandoraTheme() {
  final scheme=ColorScheme.fromSeed(seedColor:Palette.primary,brightness:Brightness.light,surface:Colors.white);
  return ThemeData(
    useMaterial3:true,
    colorScheme:scheme,
    scaffoldBackgroundColor:Palette.paper,
    fontFamilyFallback:const ['Microsoft YaHei','Noto Sans CJK SC'],
    appBarTheme:const AppBarTheme(backgroundColor:Palette.paper,foregroundColor:Palette.deep,scrolledUnderElevation:0,centerTitle:false,elevation:0),
    textTheme:const TextTheme(headlineMedium:TextStyle(fontSize:28,fontWeight:FontWeight.w800,color:Palette.deep),titleLarge:TextStyle(fontSize:21,fontWeight:FontWeight.w800,color:Palette.deep),titleMedium:TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:Palette.deep),bodyMedium:TextStyle(color:Palette.deep,fontSize:14),bodySmall:TextStyle(color:Palette.muted)),
    inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.white,contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:15),border:OutlineInputBorder(borderRadius:BorderRadius.circular(17),borderSide:BorderSide.none),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(17),borderSide:const BorderSide(color:Palette.primary,width:1.5))),
    cardTheme:CardThemeData(color:Colors.white,elevation:0,margin:EdgeInsets.zero,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22))),
    elevatedButtonTheme:ElevatedButtonThemeData(style:ElevatedButton.styleFrom(backgroundColor:Palette.primary,foregroundColor:Colors.white,minimumSize:const Size.fromHeight(52),elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)))),
    filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(backgroundColor:Palette.primary,minimumSize:const Size.fromHeight(50),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)))),
    snackBarTheme:SnackBarThemeData(behavior:SnackBarBehavior.floating,backgroundColor:Palette.deep,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
    dividerColor:Palette.divider,
  );
}
