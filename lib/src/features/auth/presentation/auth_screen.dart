import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_fire_detection_app/src/app/app_colors.dart';
import 'package:smart_fire_detection_app/src/data/services/auth_service.dart';

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

  bool _isSignUp = false;
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 860;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 32 : 20,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 920 : 520,
                    minHeight: isWide ? 560 : 0,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 32,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: isWide
                          ? SizedBox(
                              height: _isSignUp ? 700 : 560,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: 330,
                                    child: _buildBrandPanel(context),
                                  ),
                                  Expanded(
                                    child: _buildFormPanel(context, auth),
                                  ),
                                ],
                              ),
                            )
                          : _buildFormPanel(context, auth, compactLayout: true),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrandPanel(BuildContext context) {
    return Container(
      color: AppColors.surfaceHigh,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Fire Detection',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Secure access for live room monitoring, alerts, and device status.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.55,
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(),
          _buildBrandStat(
            icon: Icons.sensors,
            label: 'Live Sensors',
            value: 'Real time',
            color: AppColors.info,
          ),
          const SizedBox(height: 14),
          _buildBrandStat(
            icon: Icons.notifications_active_outlined,
            label: 'Alerts',
            value: 'Critical events',
            color: AppColors.warning,
          ),
          const SizedBox(height: 14),
          _buildBrandStat(
            icon: Icons.verified_user_outlined,
            label: 'Status',
            value: 'Protected access',
            color: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildBrandStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormPanel(
    BuildContext context,
    AuthController auth, {
    bool compactLayout = false,
  }) {
    return Padding(
      padding: EdgeInsets.all(compactLayout ? 24 : 40),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isSignUp ? 'Create Account' : 'Welcome Back',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isSignUp
                  ? 'Register your monitoring profile.'
                  : 'Sign in to continue monitoring.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            _buildModeSwitcher(),
            const SizedBox(height: 22),
            if (auth.errorMessage != null) ...[
              _buildError(auth.errorMessage!),
              const SizedBox(height: 16),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _isSignUp
                  ? Column(
                      key: const ValueKey('signup-fields'),
                      children: [
                        _buildTextField(
                          controller: _fullNameController,
                          label: 'Full name',
                          icon: Icons.person_outline,
                          validator: _requiredValidator,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email address',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          validator: _emailValidator,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Phone number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: _requiredValidator,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _addressController,
                          label: 'Address',
                          icon: Icons.location_on_outlined,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        _buildPasswordField(),
                      ],
                    )
                  : Column(
                      key: const ValueKey('signin-fields'),
                      children: [
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email address',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          validator: _emailValidator,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        _buildPasswordField(),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: auth.isLoading ? null : _submit,
                icon: auth.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_isSignUp ? Icons.person_add_alt : Icons.login),
                label: Text(_isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN'),
              ),
            ),
          ],
        ),
      ),
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
          value: false,
          label: Text('Sign in'),
          icon: Icon(Icons.login),
        ),
        ButtonSegment(
          value: true,
          label: Text('Register'),
          icon: Icon(Icons.person_add_alt),
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

  Widget _buildPasswordField() {
    return _buildTextField(
      controller: _passwordController,
      label: 'Password',
      icon: Icons.lock_outline,
      obscureText: _obscurePassword,
      validator: _passwordValidator,
      textInputAction: TextInputAction.done,
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
    TextInputAction? textInputAction,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      textInputAction: textInputAction,
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
