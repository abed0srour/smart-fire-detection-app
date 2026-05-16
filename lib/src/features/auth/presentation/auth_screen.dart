import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_fire_detection_app/src/app/app_colors.dart';
import 'package:smart_fire_detection_app/src/data/services/auth_service.dart';
import 'package:smart_fire_detection_app/src/data/services/backend_bootstrap.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 24),
                      if (auth.errorMessage != null) ...[
                        _buildError(auth.errorMessage!),
                        const SizedBox(height: 16),
                      ],
                      _buildModeSwitcher(),
                      const SizedBox(height: 20),
                      if (_isSignUp) ...[
                        _buildTextField(
                          controller: _fullNameController,
                          label: 'Full name',
                          icon: Icons.person_outline,
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: 14),
                      ],
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        validator: _emailValidator,
                      ),
                      const SizedBox(height: 14),
                      if (_isSignUp) ...[
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Phone',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: _requiredValidator,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _addressController,
                          label: 'Address',
                          icon: Icons.location_on_outlined,
                        ),
                        const SizedBox(height: 14),
                      ],
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        validator: _passwordValidator,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: auth.isLoading ? null : _submit,
                        icon: Icon(
                          _isSignUp ? Icons.person_add_alt : Icons.login,
                        ),
                        label: Text(_isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN'),
                      ),
                      const SizedBox(height: 14),
                      _buildBackendHint(context),
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

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: const Icon(
            Icons.local_fire_department,
            color: AppColors.primary,
            size: 42,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Smart Fire Detection',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          _isSignUp ? 'Create your monitoring account' : 'Sign in to continue',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildModeSwitcher() {
    return SegmentedButton<bool>(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surfaceHigh,
        selectedBackgroundColor: AppColors.primary.withValues(alpha: 0.16),
        selectedForegroundColor: AppColors.primary,
        foregroundColor: AppColors.textMuted,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      segments: const [
        ButtonSegment(
          value: true,
          label: Text('Sign up'),
          icon: Icon(Icons.person_add_alt),
        ),
        ButtonSegment(
          value: false,
          label: Text('Sign in'),
          icon: Icon(Icons.login),
        ),
      ],
      selected: {_isSignUp},
      onSelectionChanged: (selection) {
        setState(() {
          _isSignUp = selection.first;
        });
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: AppColors.textPrimary),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textMuted),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendHint(BuildContext context) {
    return Text(
      'Backend: ${BackendBootstrap.backendBaseUrl}',
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
    );
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final auth = context.read<AuthController>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isSignUp) {
      await auth.signUpAndCreateProfile(
        fullName: _fullNameController.text.trim(),
        email: email,
        phone: _phoneController.text.trim(),
        password: password,
        address: _addressController.text.trim(),
      );
      return;
    }

    await auth.signIn(email: email, password: password);
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Required';
    }
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.length < 6) {
      return 'Use at least 6 characters';
    }
    return null;
  }
}
