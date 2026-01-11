import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  
  bool _isRegistering = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    UserCredential? user;
    String? errorMessage;

    try {
      if (_isRegistering) {
        user = await _authService.signUpWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _nameController.text.trim(),
        );
        if (user != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Verification email sent. Please verify before logging in.')),
            );
          }
          setState(() {
            _isRegistering = false;
            _formKey.currentState?.reset();
            _passwordController.clear();
            // _emailController.clear(); // Keeping email for user convenience, or uncomment to clear
          });
          // Do not log them in automatically after signup, as they need to verify
          user = null; 
        } else {
          errorMessage = 'Registration failed. Email might be in use.';
        }
      } else {
        try {
          user = await _authService.signInWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
          if (user == null) errorMessage = 'Login failed. Check your credentials.';
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-not-verified') {
            errorMessage = e.message;
          } else {
            errorMessage = 'Login failed: ${e.message}';
          }
        }
      }
    } catch (e) {
        errorMessage = 'An error occurred. Please try again.';
    }

    setState(() => _isLoading = false);

    if (user != null) {
      debugPrint("Email Auth Successful: ${user.user?.email}");
    } else if (mounted && errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 4),
          action: errorMessage.contains('verify') ? SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ) : null,
        ),
      );
    }
  }

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final user = await _authService.signInWithGoogle();
    setState(() => _isLoading = false);
    
    if (user != null) {
      debugPrint("Google Sign-In Successful: ${user.user?.displayName}");
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Sign-In failed or cancelled')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 48, // approx safe area
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  const Icon(
                    Icons.confirmation_number_outlined,
                    size: 80,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Tambola Tickets',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isRegistering ? 'Create an account to get started' : 'Welcome back!',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (_isRegistering) ...[
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) => val != null && val.isNotEmpty ? null : 'Name is required',
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) => val != null && val.contains('@') ? null : 'Enter a valid email',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (val) => val != null && val.length >= 6 ? null : 'Min 6 characters',
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    ElevatedButton(
                      onPressed: _handleEmailAuth,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _isRegistering ? 'SIGN UP' : 'LOGIN',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _handleGoogleSignIn,
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                         _isRegistering = !_isRegistering;
                         _formKey.currentState?.reset();
                      });
                    },
                    child: Text(_isRegistering 
                      ? 'Already have an account? Login' 
                      : 'New here? Create Account'
                    ),
                  ),
                  
                  const Spacer(),
                  const Text(
                    'By continuing, you agree to our Terms & Privacy Policy.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
