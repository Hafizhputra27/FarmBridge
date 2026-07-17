import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farmbridge/features/auth/providers/auth_provider.dart';
import 'package:farmbridge/features/auth/screens/login_screen.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(AuthState initial) {
    state = initial;
  }
}

void main() {
  testWidgets('LoginScreen menampilkan field email, password, dan hint role',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuthNotifier(const AuthState())),
        ],
        child: const MaterialApp(home: LoginScreen(role: 'farmer')),
      ),
    );

    expect(find.text('Login sebagai Petani'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
  });

  testWidgets('LoginScreen menampilkan pesan error dari authProvider',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuthNotifier(
                const AuthState(error: 'Email atau password salah'),
              )),
        ],
        child: const MaterialApp(home: LoginScreen(role: 'buyer')),
      ),
    );

    expect(find.text('Email atau password salah'), findsOneWidget);
  });

  testWidgets('LoginScreen nonaktifkan tombol & tampil loading saat isLoading true',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuthNotifier(
                const AuthState(isLoading: true),
              )),
        ],
        child: const MaterialApp(home: LoginScreen(role: 'farmer')),
      ),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
