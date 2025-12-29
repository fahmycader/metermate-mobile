import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  String _selectedDepartment = 'meter';
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _emailVerified = false;
  bool _verificationCodeSent = false;
  bool _sendingCode = false;

  void _handleSendVerificationCode() async {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _sendingCode = true);
    final result = await _authService.sendVerificationCode(_emailController.text);
    setState(() => _sendingCode = false);

    if (mounted) {
      if (result['success']) {
        setState(() => _verificationCodeSent = true);
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

  void _handleVerifyCode() async {
    if (_verificationCodeController.text.length != 6) {
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
      _emailController.text,
      _verificationCodeController.text,
      type: 'registration',
    );
    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success']) {
        setState(() => _emailVerified = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully!'),
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

  void _handleSignup() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username and password are required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your email address first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.register(
      _usernameController.text,
      _passwordController.text,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      employeeId: _employeeIdController.text,
      department: _selectedDepartment,
      verificationCode: _verificationCodeController.text,
    );
    setState(() => _isLoading = false);

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'Get started with MeterMate',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16.0,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 40.0),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username *',
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
                        labelText: 'Password *',
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
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (value) {
                        setState(() {
                          _emailVerified = false;
                          _verificationCodeSent = false;
                        });
                      },
                    ),
                    if (_emailController.text.isNotEmpty &&
                        _emailController.text.contains('@') &&
                        !_emailVerified) ...[
                      const SizedBox(height: 8.0),
                      if (!_verificationCodeSent)
                        ElevatedButton(
                          onPressed: _sendingCode ? null : _handleSendVerificationCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                          ),
                          child: _sendingCode
                              ? const SizedBox(
                                  height: 20.0,
                                  width: 20.0,
                                  child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                                )
                              : const Text('Send Verification Code'),
                        )
                      else ...[
                        TextFormField(
                          controller: _verificationCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Verification Code',
                            prefixIcon: Icon(Icons.lock_outline),
                            border: OutlineInputBorder(),
                            hintText: 'Enter 6-digit code',
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                        ),
                        const SizedBox(height: 8.0),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading || _verificationCodeController.text.length != 6
                                    ? null
                                    : _handleVerifyCode,
                                style: ElevatedButton.styleFrom(
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
                              onPressed: _sendingCode ? null : _handleSendVerificationCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                              ),
                              child: const Text('Resend'),
                            ),
                          ],
                        ),
                      ],
                      if (_emailVerified)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 20.0),
                              const SizedBox(width: 8.0),
                              Text(
                                'Email verified',
                                style: TextStyle(color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _employeeIdController,
                      decoration: const InputDecoration(
                        labelText: 'Employee ID',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      value: _selectedDepartment,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        prefixIcon: Icon(Icons.business_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'meter',
                          child: Text('Meter Department'),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Admin Department'),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedDepartment = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 32.0),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _emailVerified ? _handleSignup : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              backgroundColor: Colors.blue[700],
                              disabledBackgroundColor: Colors.grey,
                            ),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(fontSize: 18.0, color: Colors.white),
                            ),
                          ),
                    const SizedBox(height: 16.0),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Already have an account? Sign In',
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
