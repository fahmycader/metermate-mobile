import 'package:flutter/material.dart';
import 'package:metermate_frontend/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showForgotPassword = false;
  final _forgotPasswordEmailController = TextEditingController();
  final _forgotPasswordCodeController = TextEditingController();
  final _forgotPasswordNewPasswordController = TextEditingController();
  String _forgotPasswordStep = 'email'; // 'email', 'code', 'reset'
  bool _sendingCode = false;

  void _handleLogin() async {
    setState(() => _isLoading = true);
    final result = await _authService.login(
      _usernameController.text,
      _passwordController.text,
    );
    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success']) {
        Navigator.of(context).pushReplacementNamed('/vehicle-check');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleForgotPassword() async {
    if (_forgotPasswordEmailController.text.isEmpty ||
        !_forgotPasswordEmailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _sendingCode = true);
    final result = await _authService.forgotPassword(_forgotPasswordEmailController.text);
    setState(() => _sendingCode = false);

    if (mounted) {
      if (result['success']) {
        setState(() => _forgotPasswordStep = 'code');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent to your email'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleVerifyPasswordResetCode() async {
    if (_forgotPasswordCodeController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the 6-digit verification code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.verifyCode(
      _forgotPasswordEmailController.text,
      _forgotPasswordCodeController.text,
      type: 'password_reset',
    );
    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success']) {
        setState(() => _forgotPasswordStep = 'reset');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleResetPassword() async {
    if (_forgotPasswordNewPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.resetPassword(
      _forgotPasswordEmailController.text,
      _forgotPasswordCodeController.text,
      _forgotPasswordNewPasswordController.text,
    );
    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success']) {
        setState(() {
          _showForgotPassword = false;
          _forgotPasswordStep = 'email';
          _forgotPasswordEmailController.clear();
          _forgotPasswordCodeController.clear();
          _forgotPasswordNewPasswordController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully! Please login with your new password.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10133D),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Card(
              elevation: 18.0,
              shadowColor: Colors.black.withOpacity(0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF8DCC6F), Color(0xFF75D4ED), Color(0xFF9A8AC7)],
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: const Center(
                            child: Text('M', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Color(0xFF10133D))),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    const Text(
                      'METERMATE',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26.0, letterSpacing: 2.2, fontWeight: FontWeight.w800, color: Color(0xFF10133D)),
                    ),
                    const SizedBox(height: 7.0),
                    Text(
                      'Powering every reading, beautifully.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.0,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 40.0),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _showForgotPassword = true;
                            _forgotPasswordStep = 'email';
                          });
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(color: Colors.indigo[900], fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              backgroundColor: const Color(0xFF10133D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.0),
                              ),
                            ),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(fontSize: 18.0, color: Colors.white),
                            ),
                          ),
                    const SizedBox(height: 16.0),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/signup');
                      },
                      child: Text(
                        'Don\'t have an account? Sign Up',
                        style: TextStyle(color: Colors.indigo[900], fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      // Forgot Password Dialog
      bottomSheet: _showForgotPassword
          ? Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10.0,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Reset Password',
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _showForgotPassword = false;
                            _forgotPasswordStep = 'email';
                            _forgotPasswordEmailController.clear();
                            _forgotPasswordCodeController.clear();
                            _forgotPasswordNewPasswordController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),
                  if (_forgotPasswordStep == 'email') ...[
                    const Text(
                      'Enter your email address and we\'ll send you a verification code.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _forgotPasswordEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton(
                      onPressed: _sendingCode ? null : _handleForgotPassword,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        backgroundColor: Colors.blue[700],
                      ),
                      child: _sendingCode
                          ? const SizedBox(
                              height: 20.0,
                              width: 20.0,
                              child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                            )
                          : const Text('Send Verification Code'),
                    ),
                  ] else if (_forgotPasswordStep == 'code') ...[
                    Text(
                      'Enter the verification code sent to ${_forgotPasswordEmailController.text}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _forgotPasswordCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Verification Code',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                        hintText: 'Enter 6-digit code',
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleVerifyPasswordResetCode,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              backgroundColor: Colors.green,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20.0,
                                    width: 20.0,
                                    child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                                  )
                                : const Text('Verify Code'),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        ElevatedButton(
                          onPressed: _sendingCode ? null : _handleForgotPassword,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                            backgroundColor: Colors.grey[300],
                          ),
                          child: const Text('Resend'),
                        ),
                      ],
                    ),
                  ] else if (_forgotPasswordStep == 'reset') ...[
                    const Text(
                      'Enter your new password',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _forgotPasswordNewPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleResetPassword,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        backgroundColor: Colors.blue[700],
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20.0,
                              width: 20.0,
                              child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                            )
                          : const Text('Reset Password'),
                    ),
                  ],
                ],
              ),
            )
          : null,
    );
  }
}
