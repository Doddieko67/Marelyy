// lib/navigation/tab_navigator.dart
import 'package:flutter/material.dart';

import 'package:classroom_mejorado/Screen/CommunitiesScreen.dart';
import 'package:classroom_mejorado/Screen/CommunityDetailScreen.dart'; // ¡Apunta a la CommunityDetailScreen modificada!
import 'package:classroom_mejorado/Screen/ProfileScreen.dart';

class TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final String? initialRouteName;
  final Widget? initialScreen;

  const TabNavigator({
    super.key,
    required this.navigatorKey,
    this.initialRouteName,
    this.initialScreen,
  }) : assert(
         initialRouteName != null || initialScreen != null,
         'TabNavigator must have either initialRouteName or initialScreen',
       );

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      initialRoute: initialRouteName ?? '/',
      onGenerateRoute: (RouteSettings settings) {
        Widget page;

        if (settings.name == '/' && initialScreen != null) {
          page = initialScreen!;
        } else {
          switch (settings.name) {
            case '/':
              // Aquí puedes definir pantallas raíz por defecto si no se usa initialScreen.
              page = const Center(
                // Agregado const
                child: Text(
                  'Please define initialScreen or routes for this tab',
                  style: TextStyle(color: Colors.white),
                ),
              );
              break;

            case '/communities_root':
              page = const CommunitiesScreen(); // Agregado const
              break;
            case '/profile_root':
              page = const ProfileScreen(); // Agregado const
              break;
            case '/tasks_root':
              page = const Center(
                // Agregado const
                child: Text(
                  'Tasks Screen Placeholder',
                  style: TextStyle(color: Colors.white),
                ),
              );
              break;
            case '/inbox_root':
              page = const Center(
                // Agregado const
                child: Text(
                  'Inbox Screen Placeholder',
                  style: TextStyle(color: Colors.white),
                ),
              );
              break;

            case '/communityDetail':
              final args = settings.arguments as Map<String, dynamic>?;
              page = CommunityDetailScreen(
                communityId:
                    args?['id'] ??
                    'default_community_id', // ¡Solo pasamos el ID!
              );
              break;

            default:
              page = Center(
                // Agregado const
                child: Text(
                  'Error: Ruta ${settings.name} desconocida en esta pestaña',
                  style: TextStyle(color: Colors.red),
                ),
              );
              break;
          }
        }

        return MaterialPageRoute(builder: (context) => page);
      },
    );
  }
}
