import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

Future<void> main() async {
  // TODO: get `url` and `anonKey` on https://supabase.com/
  await Supabase.initialize(
    url: 'SUPABASE_URL',
    anonKey: 'SUPABASE_ANON_KEY',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Flutter Demo',
      home: const MyWidget(),
      theme: ThemeData.light(
        useMaterial3: true,
      ),
    );
  }
}

class MyWidget extends StatefulWidget {
  const MyWidget({Key? key}) : super(key: key);

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  User? _user;
  @override
  void initState() {
    _getAuth();
    super.initState();
  }

  Future<void> _getAuth() async {
    setState(() {
      _user = Supabase.instance.client.auth.currentUser;
    });
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.signedIn:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Welcome! ${data.session!.user.email ?? data.session!.user.id}.'),
              backgroundColor: Colors.green,
            ),
          );
          break;
        case AuthChangeEvent.passwordRecovery:
          break;
        case AuthChangeEvent.signedOut:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bye! ${_user?.email ?? _user?.id}.'),
              backgroundColor: Colors.green,
            ),
          );
          break;
        case AuthChangeEvent.tokenRefreshed:
          break;
        case AuthChangeEvent.userUpdated:
          break;
        case AuthChangeEvent.userDeleted:
          break;
        case AuthChangeEvent.mfaChallengeVerified:
          break;
      }

      setState(() {
        _user = data.session?.user;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Example'),
      ),
      body: _user == null ? const _LoginForm() : const _ProfileForm(),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({Key? key}) : super(key: key);

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  bool _loading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            TextFormField(
              keyboardType: TextInputType.emailAddress,
              controller: _emailController,
              decoration: const InputDecoration(
                label: Text('Email'),
              ),
            ),
            TextFormField(
              obscureText: true,
              controller: _passwordController,
              decoration: const InputDecoration(
                label: Text('Password'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                setState(() {
                  _loading = true;
                });
                try {
                  final email = _emailController.text;
                  final password = _passwordController.text;

                  debugPrint('signInWithPassword...');
                  final response =
                      await Supabase.instance.client.auth.signInWithPassword(
                    email: email,
                    password: password,
                  );
                  debugPrint(
                      'signInWithPassword success! ${response.user!.id}');
                } catch (error, stackTrace) {
                  debugPrint(error.toString());
                  debugPrintStack(stackTrace: stackTrace);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Signin failed! ${error.toString()}'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }

                setState(() {
                  _loading = false;
                });
              },
              child: const Text('Sign In'),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _loading = true;
                });
                try {
                  final email = _emailController.text;
                  final password = _passwordController.text;

                  debugPrint('signUp...');
                  final response = await Supabase.instance.client.auth.signUp(
                    email: email,
                    password: password,
                  );
                  debugPrint('signUp success! ${response.user!.id}');
                } catch (error, stackTrace) {
                  debugPrint(error.toString());
                  debugPrintStack(stackTrace: stackTrace);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('signUp failed! ${error.toString()}'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }

                setState(() {
                  _loading = false;
                });
              },
              child: const Text('Create an account'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _loading = true;
                });

                try {
                  var credential = await SignInWithApple.getAppleIDCredential(
                    scopes: [
                      AppleIDAuthorizationScopes.email,
                      AppleIDAuthorizationScopes.fullName,
                    ],
                    webAuthenticationOptions: WebAuthenticationOptions(
                      // TODO: Set the `clientId` and `redirectUri` arguments to the values you entered in the Apple Developer portal during the setup
                      clientId: 'com.example.example',
                      redirectUri: // For web your redirect URI needs to be the host of the "current page",
                          // while for Android you will be using the API server that redirects back into your app via a deep link
                          kIsWeb
                              ? Uri.parse('http://localhost/')
                              : Uri.parse(
                                  'https://localhost/callbacks/sign_in_with_apple',
                                ),
                    ),
                  );

                  if (credential.identityToken == null) {
                    throw const AuthException(
                        'Could not find ID Token from generated credential.');
                  }

                  // you are logged
                  var appleAuthCredential = AppleAuthProvider.credential(
                    credential.identityToken!,
                    credential.authorizationCode,
                  );

                  // signin to supabase
                  await Supabase.instance.client.auth
                      .signInWithCredential(appleAuthCredential);
                } catch (error, stackTrace) {
                  debugPrint(error.toString());
                  debugPrintStack(stackTrace: stackTrace);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'signInWithCredential failed! ${error.toString()}'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }

                setState(() {
                  _loading = false;
                });
              },
              child: const Text('Signin with Apple'),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _loading = true;
                });

                try {
                  // TODO: put file client in "/android/app/client_secret_*.json"
                  // follow instructions: https://pub.dev/packages/google_sign_in
                  // resources: https://console.cloud.google.com/ https://developers.google.com/identity
                  var client = GoogleSignIn(
                    // optional
                    clientId: '*-*.apps.googleusercontent.com',
                    // `serverClientId` required to get idToken, `serverClientId` same `client_id` on Auth Providers page
                    serverClientId: '*-*.apps.googleusercontent.com',
                  );

                  // throw if error
                  var result = await client.signIn();
                  var authentication = await result!.authentication;

                  // you are logged
                  var googleAuthCredential = GoogleAuthProvider.credential(
                    idToken: authentication.idToken,
                    accessToken: authentication.accessToken,
                  );

                  // signin to supabase
                  await Supabase.instance.client.auth
                      .signInWithCredential(googleAuthCredential);
                } catch (error, stackTrace) {
                  debugPrint(error.toString());
                  debugPrintStack(stackTrace: stackTrace);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'signInWithCredential failed! ${error.toString()}'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }

                setState(() {
                  _loading = false;
                });
              },
              child: const Text('Sign in with Google'),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _loading = true;
                });

                try {
                  // TODO: edit `app_id` and `client_token` in "android/app/src/main/res/values/strings.xml"
                  // follow instructions: https://pub.dev/packages/flutter_facebook_auth
                  // https://developers.facebook.com/apps
                  final LoginResult result =
                      await FacebookAuth.instance.login();

                  // throw if error
                  if (result.status != LoginStatus.success) {
                    throw Exception('${result.status} ${result.message}');
                  }

                  // you are logged
                  var facebookAuthCredential = FacebookAuthProvider.credential(
                      result.accessToken!.token);

                  // signin to supabase
                  await Supabase.instance.client.auth
                      .signInWithCredential(facebookAuthCredential);
                } catch (error, stackTrace) {
                  debugPrint(error.toString());
                  debugPrintStack(stackTrace: stackTrace);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'signInWithCredential failed! ${error.toString()}'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }

                setState(() {
                  _loading = false;
                });
              },
              child: const Text('Sign in with Facebook'),
            ),
          ],
        ),
        _loading
            ? Container(
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.background.withOpacity(.5),
                ),
              )
            : Container(),
      ],
    );
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({Key? key}) : super(key: key);

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  var _loading = true;
  final _usernameController = TextEditingController();
  final _websiteController = TextEditingController();

  @override
  void initState() {
    _loadProfile();
    super.initState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = (await Supabase.instance.client
          .from('profiles')
          .select()
          .match({'id': userId}).maybeSingle()) as Map?;
      if (data != null) {
        setState(() {
          _usernameController.text = data['username'];
          _websiteController.text = data['website'];
        });
      }
    } catch (error, stackTrace) {
      debugPrint(error.toString());
      debugPrintStack(stackTrace: stackTrace);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error occurred while getting profile! ${error}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                label: Text('Username'),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _websiteController,
              decoration: const InputDecoration(
                label: Text('Website'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                try {
                  setState(() {
                    _loading = true;
                  });
                  final userId = Supabase.instance.client.auth.currentUser!.id;
                  final username = _usernameController.text;
                  final website = _websiteController.text;

                  await Supabase.instance.client.from('profiles').upsert({
                    'id': userId,
                    'username': username,
                    'website': website,
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Saved profile!'),
                      ),
                    );
                  }
                } catch (error, stackTrace) {
                  debugPrint(error.toString());
                  debugPrintStack(stackTrace: stackTrace);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error saving profile! ${error}'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
                setState(() {
                  _loading = false;
                });
              },
              child: const Text('Save changes'),
            ),
            ElevatedButton(
              onPressed: () => Supabase.instance.client.auth.signOut(),
              child: const Text('Sign Out'),
            ),
          ],
        ),
        _loading
            ? Container(
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.background.withOpacity(.5),
                ),
              )
            : Container(),
      ],
    );
  }
}
