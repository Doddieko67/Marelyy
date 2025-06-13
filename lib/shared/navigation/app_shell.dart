import 'package:classroom_mejorado/features/communities/screens/communities_screen.dart';
import 'package:classroom_mejorado/features/tasks/screens/my_tasks_screen.dart';
import 'package:classroom_mejorado/features/profile/screens/profile_screen.dart';
import 'package:classroom_mejorado/shared/navigation/tab_navigation.dart';
import 'package:classroom_mejorado/features/shared/widgets/theme_switcher_widget.dart';
import 'package:classroom_mejorado/features/shared/widgets/floating_search_button.dart';
import 'package:flutter/material.dart';
import 'package:classroom_mejorado/core/constants/app_colors.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0; // Índice de la pestaña actualmente seleccionada

  // Define una GlobalKey para cada TabNavigator. Esto permite manejar el estado de cada Navigator anidado.
  // ¡Estas claves deben ser estables y no reconstruirse!
  final GlobalKey<NavigatorState> _communitiesNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _tasksNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _profileNavigatorKey =
      GlobalKey<NavigatorState>();

  // Lista de las GlobalKeys, en el mismo orden que _widgetOptions.
  late final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    _communitiesNavigatorKey,
    _tasksNavigatorKey,
    _profileNavigatorKey,
  ];

  // Lista de widgets (los TabNavigator) que se mostrarán en cada pestaña
  // Ahora usando las claves estables y el parámetro `initialScreen`
  late final List<Widget> _widgetOptions = <Widget>[
    TabNavigator(
      navigatorKey: _communitiesNavigatorKey,
      initialScreen: const CommunitiesScreen(),
    ), // Comunidades (Home)
    TabNavigator(
      navigatorKey: _tasksNavigatorKey,
      initialScreen: MyTasksScreen(),
    ), // Tareas
    TabNavigator(
      navigatorKey: _profileNavigatorKey,
      initialScreen: const ProfileScreen(),
    ), // Perfil
  ];

  void _onItemTapped(int index) {
    setState(() {
      // Si la pestaña seleccionada es la misma, la "popamos" a su ruta raíz
      if (_selectedIndex == index) {
        _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      }
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false, // Por defecto, no permite salir de la app
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Si el navegador actual puede hacer pop, lo hace
        if (_navigatorKeys[_selectedIndex].currentState?.canPop() == true) {
          _navigatorKeys[_selectedIndex].currentState?.pop();
        } else {
          // Si no puede hacer pop (está en la ruta raíz de su pestaña),
          // intentamos salir de la aplicación si no estamos en la primera pestaña
          if (_selectedIndex != 0) {
            setState(() {
              _selectedIndex = 0; // Vuelve a la primera pestaña (Home)
            });
          } else {
            // Si estamos en la raíz de la primera pestaña y no hay rutas previas,
            // permitimos que el PopScope "pops" y el Navigator principal puede manejar la salida
            // (ej. salir de la app o ir al login si no se usa Firebase authStateChanges para redirigir)
            // Para una aplicación con autenticación, usualmente no quieres que PopScope
            // cierre la app aquí, sino que el flujo de autenticación maneje la salida.
            // Si quieres que el botón de atrás del sistema realmente cierre la app aquí,
            // puedes usar SystemNavigator.pop();
            // print("Attempting to exit app via SystemNavigator.pop()");
            // SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          // Se usa la lista _widgetOptions definida arriba
          children: _widgetOptions,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: bottomNavBarBgColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 0,
                blurRadius: 15,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20.0),
            ),
            child: BottomNavigationBar(
              items: <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  label: 'Inicio', // Traducido
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt_outlined),
                  label: 'Mis Tareas', // Traducido
                ),
                BottomNavigationBarItem(
                  // El índice para 'Profile' en _widgetOptions es 2,
                  // pero el BottomNavigationBarItem es el tercero,
                  // así que su índice en `items` es 2.
                  // Si _selectedIndex es 2, entonces es la pestaña de Perfil.
                  icon:
                      _selectedIndex ==
                          2 // Comparar con el índice del item de perfil
                      ? Icon(Icons.person)
                      : Icon(Icons.person_outline),
                  label: 'Perfil', // Traducido
                ),
              ],
              currentIndex: _selectedIndex,
              selectedItemColor: theme.colorScheme.primary,
              unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
              onTap: _onItemTapped,
              backgroundColor: Colors.transparent,
              type: BottomNavigationBarType.fixed,
              selectedLabelStyle: TextStyle(
                fontFamily: fontFamilyPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelStyle: TextStyle(
                fontFamily: fontFamilyPrimary,
                fontWeight: FontWeight.normal,
                fontSize: 12,
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}
