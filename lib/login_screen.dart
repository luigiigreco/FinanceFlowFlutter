import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _login() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore di login: ${e.toString()}')),
      );
    }
  }

  Future<void> _register() async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrazione avvenuta con successo!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore di registrazione: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Finance Flow")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Spacer(flex: 2), // Spazio iniziale

            // Campi di input per email e password
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10), // Spazio tra i campi di input
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20), // Spazio tra i form e i pulsanti
            ElevatedButton(
              onPressed: _login,
              child: const Text("Login"),
            ),
            const SizedBox(height: 10), // Spazio tra i pulsanti
            ElevatedButton(
              onPressed: _register,
              child: const Text("Registrati"),
            ),
            const Spacer(flex: 1), // Spazio ridotto tra i pulsanti e il logo

            // Logo
            Image.asset(
              'assets/app_icon.png',
              height: 200, // Altezza leggermente ridotta per adattare
            ),
            const Spacer(flex: 1), // Spazio finale
          ],
        ),
      ),
    );
  }
}
