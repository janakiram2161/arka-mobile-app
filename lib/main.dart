import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/more_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/wishlist_screen.dart';
import 'state/stores.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  await Future.wait<void>([
    CartStore.instance.load(),
    WishlistStore.instance.load(),
  ]);
  runApp(const ArkaApp());
}

class ArkaApp extends StatelessWidget {
  const ArkaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARKA Schmuck',
      debugShowCheckedModeBanner: false,
      theme: buildArkaTheme(),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatelessWidget {
  const RootShell({super.key});

  static const List<Widget> _tabs = [
    HomeScreen(),
    ShopScreen(),
    WishlistScreen(),
    CartScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: rootTab,
      builder: (context, index, _) {
        return Scaffold(
          body: IndexedStack(index: index, children: _tabs),
          bottomNavigationBar: ListenableBuilder(
            listenable: Listenable.merge([CartStore.instance, WishlistStore.instance]),
            builder: (context, _) {
              final cartCount = CartStore.instance.count;
              final wishCount = WishlistStore.instance.count;
              return NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => rootTab.value = i,
                backgroundColor: Colors.white,
                indicatorColor: ArkaColors.goldSoft,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Start',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.diamond_outlined),
                    selectedIcon: Icon(Icons.diamond),
                    label: 'Shop',
                  ),
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: wishCount > 0,
                      label: Text('$wishCount'),
                      backgroundColor: ArkaColors.gold,
                      child: const Icon(Icons.favorite_border),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: wishCount > 0,
                      label: Text('$wishCount'),
                      backgroundColor: ArkaColors.gold,
                      child: const Icon(Icons.favorite),
                    ),
                    label: 'Merkliste',
                  ),
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: cartCount > 0,
                      label: Text('$cartCount'),
                      backgroundColor: ArkaColors.gold,
                      child: const Icon(Icons.shopping_bag_outlined),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: cartCount > 0,
                      label: Text('$cartCount'),
                      backgroundColor: ArkaColors.gold,
                      child: const Icon(Icons.shopping_bag),
                    ),
                    label: 'Warenkorb',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.menu),
                    label: 'Mehr',
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
