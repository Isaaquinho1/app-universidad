import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web_oauth_interceptor_client/web_oauth_interceptor_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }

  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final OAuthInterceptorClient oauthClient = OAuthInterceptorClient(
    oauthUrl: 'https://example.edu/login',
    expectedRedirectUrls: ['https://example.edu/callback'],
    specialCookieName: 'example_session',
    onLoginSuccess: (data) {
      debugPrint('Login success. Cookie: ${data.specialCookieValue}');
    },
    onLoginError: (String error) {
      debugPrint('Login failure. Error: $error');
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OAuth Interceptor Example'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await oauthClient.initiateOAuthFlow();
          },
          child: const Text('Start OAuth Flow'),
        ),
      ),
    );
  }
}
