import 'package:flutter/material.dart';
import 'package:alraya_app/alrayah.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PasswordResetScreen extends StatefulWidget {
  @override
  _PasswordResetScreenState createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isEmailSent = false;
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

  void _onEmailChanged() {
    setState(() {
      _isButtonEnabled = _emailController.text.trim().isNotEmpty &&
          _emailController.text.contains('@');
    });
  }

 

void _sendResetLink() async {
  if (_isButtonEnabled) {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      setState(() {
        _isEmailSent = true; // show the "Check your email" screen
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent!')),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else {
        message = 'Error: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

  void _resendEmail() {
    // Handle resend email logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reset link sent again!')),
    );
  }

  void _backToLogin() {
    Navigator.pop(context);
  }

  void _tryDifferentEmail() {
    setState(() {
      _isEmailSent = false;
      _emailController.clear();
      _isButtonEnabled = false;
    });
  }

  void _emailReceived() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesertColors.lightBackground,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: DesertColors.lightSurface,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(maxWidth: 400),
              padding: EdgeInsets.all(32),
              child: _isEmailSent ? _buildEmailSentView() : _buildEmailInputView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailInputView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Email Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: DesertColors.primaryGoldDark,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.email_outlined,
            size: 40,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 24),
        
        // Title
        Text(
          'Forgot Password?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: DesertColors.lightText,
          ),
        ),
        SizedBox(height: 16),
        
        // Description
        Text(
          'Enter your email address and we\'ll send you a link to reset your password.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: DesertColors.lightText.withOpacity(0.7),
            height: 1.4,
          ),
        ),
        SizedBox(height: 32),
        
        // Email Input
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email Address',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DesertColors.lightText,
              ),
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(
                fontSize: 16,
                color: DesertColors.lightText,
              ),
              decoration: InputDecoration(
                hintText: 'Enter your email',
                hintStyle: TextStyle(
                  color: DesertColors.lightText.withOpacity(0.5),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: DesertColors.primaryGoldDark,
                    width: 2,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 32),
        
        // Send Reset Link Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isButtonEnabled ? _sendResetLink : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isButtonEnabled 
                  ? DesertColors.camelSand 
                  : DesertColors.camelSand.withOpacity(0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Send Reset Link',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DesertColors.lightText,
              ),
            ),
          ),
        ),
        SizedBox(height: 24),
        
        // Back to Login
        TextButton(
          onPressed: _backToLogin,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back,
                size: 20,
                color: DesertColors.lightText.withOpacity(0.7),
              ),
              SizedBox(width: 8),
              Text(
                'Back to Login',
                style: TextStyle(
                  fontSize: 16,
                  color: DesertColors.lightText.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailSentView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Check Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: DesertColors.primaryGoldDark,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check,
            size: 40,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 24),
        
        // Title
        Text(
          'Check Your Email',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: DesertColors.lightText,
          ),
        ),
        SizedBox(height: 16),
        
        // Email sent message
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: 16,
              color: DesertColors.lightText.withOpacity(0.7),
              height: 1.4,
            ),
            children: [
              TextSpan(text: 'We\'ve sent a password reset link to '),
              TextSpan(
                text: _emailController.text,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: DesertColors.lightText,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
        
        // Info message
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DesertColors.camelSand.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Didn\'t receive the email? Check your spam folder or click below to resend.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: DesertColors.lightText.withOpacity(0.7),
              height: 1.4,
            ),
          ),
        ),
        SizedBox(height: 32),
        
        // Resend Email Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _resendEmail,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: DesertColors.camelSand,
                width: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Resend Email',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DesertColors.primaryGoldDark,
              ),
            ),
          ),
        ),
        SizedBox(height: 16),
        
        // I've Received Email Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _emailReceived,
            style: ElevatedButton.styleFrom(
              backgroundColor: DesertColors.camelSand,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'I\'ve Received the Email',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DesertColors.lightText,
              ),
            ),
          ),
        ),
        SizedBox(height: 24),
        
        // Try Different Email
        TextButton(
          onPressed: _tryDifferentEmail,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back,
                size: 20,
                color: DesertColors.lightText.withOpacity(0.7),
              ),
              SizedBox(width: 8),
              Text(
                'Try Different Email',
                style: TextStyle(
                  fontSize: 16,
                  color: DesertColors.lightText.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
