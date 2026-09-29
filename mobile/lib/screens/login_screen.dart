import 'package:flutter/material.dart';
import '../main.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _error = 'Escribe la contraseña.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await apiClient.login(password);
      if (result['ok'] == true && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        setState(() => _error = result['error']?.toString() ?? 'Error desconocido.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.7, -0.8),
            radius: 1.2,
            colors: [Color(0xFFE6F0E9), Color(0x00E6F0E9)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo mark
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF172A3A),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '↗',
                          style: TextStyle(
                            color: Color(0xFFFFB887),
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'TU ESPACIO PRIVADO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: const Color(0xFFD46E3D),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Mi mesa de ventas',
                        style: TextStyle(
                          fontSize: 31,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.4,
                          color: Color(0xFF172A3A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Entra para revisar consultas, entregas, productos y respuestas.',
                        style: TextStyle(color: Color(0xFF63747A)),
                      ),
                      const SizedBox(height: 25),

                      // Username field (readonly)
                      const Text(
                        'Usuario',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF42555A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        initialValue: 'propietario',
                        readOnly: true,
                        decoration: InputDecoration(
                          fillColor: const Color(0xFFF5F6F3),
                        ),
                      ),
                      const SizedBox(height: 13),

                      // Password field
                      const Text(
                        'Contraseña',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF42555A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        autofocus: true,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _login(),
                        autofillHints: const [AutofillHints.password],
                      ),
                      const SizedBox(height: 18),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Entrar'),
                        ),
                      ),

                      // Error message
                      if (_error != null) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0DF),
                            border: Border.all(color: const Color(0xFFF6D8B5)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFF74451E),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      Text(
                        'Guarda la contraseña en el gestor del celular. La sesión dura 7 días.',
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF7E8D8D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
