import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'config/routes/app_routes.dart';
import 'core/data/hive_database.dart';
import 'core/service_locator.dart' as di;

import 'core/theme/app_theme.dart';
import 'features/billing/presentation/bloc/billing_bloc.dart';
import 'features/product/presentation/bloc/product_bloc.dart';
import 'features/shop/presentation/bloc/shop_bloc.dart';
import 'features/settings/presentation/bloc/printer_bloc.dart';
import 'features/settings/presentation/bloc/printer_event.dart';
import 'features/inventory/presentation/bloc/inventory_bloc.dart';
import 'features/inventory/presentation/bloc/inventory_event.dart';
import 'features/sales/presentation/bloc/sales_bloc.dart';
import 'features/sales/presentation/bloc/sales_event.dart';
import 'features/credit/presentation/bloc/credit_bloc.dart';
import 'features/credit/presentation/bloc/credit_event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Avoid blocking first paint on a network font download.
  GoogleFonts.config.allowRuntimeFetching = false;
  await HiveDatabase.init();
  await di.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<InventoryBloc>(
            create: (context) => di.sl<InventoryBloc>()..add(LoadInventoryEvent())),
        BlocProvider<SalesBloc>(
            create: (context) => di.sl<SalesBloc>()..add(const LoadSalesEvent())),
        BlocProvider<CreditBloc>(
            create: (context) =>
                di.sl<CreditBloc>()..add(LoadCreditAccountsEvent())),
        BlocProvider<ProductBloc>(
            create: (context) => di.sl<ProductBloc>()..add(LoadProducts())),
        BlocProvider<ShopBloc>(
            create: (context) => di.sl<ShopBloc>()..add(LoadShopEvent())),
        BlocProvider<BillingBloc>(
            create: (context) => BillingBloc(getProductByBarcodeUseCase: di.sl())),
        BlocProvider<PrinterBloc>(
            create: (context) => di.sl<PrinterBloc>()..add(InitPrinterEvent())),
      ],
      child: MaterialApp.router(
        title: 'Inventory & Sales Tracking',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        builder: (context, child) => AuthGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _unlocked = false;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) {
        if (mounted) {
          setState(() {
            _unlocked = true;
            _busy = false;
          });
        }
        return;
      }

      final success = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access the app',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!mounted) return;
      setState(() {
        _unlocked = success;
        _busy = false;
        _error = success ? null : 'Authentication was cancelled or failed.';
      });
    } catch (e) {
      if (!mounted) return;
      // Unlock rather than leaving the user on a dead splash screen.
      setState(() {
        _unlocked = true;
        _busy = false;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: 16),
              Text(
                _busy ? 'Unlocking…' : 'Unlock required',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              if (_busy)
                const CircularProgressIndicator()
              else
                FilledButton(
                  onPressed: _authenticate,
                  child: const Text('Try again'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
