import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/routes.dart';
import '../../state/app_state.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/input_validators.dart';
import 'auth_scaffold.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _agree = false;
  bool _loading = false;
  int _strength = 0;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_recalcStrength);
  }

  void _recalcStrength() {
    setState(() {
      _strength = AppValidators.passwordStrength(_passwordController.text);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      showAppSnackBar(
        context,
        'Please accept the Terms & Privacy to continue.',
        isError: true,
      );
      return;
    }
    setState(() => _loading = true);
    final error = await context.read<AppState>().register(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Start understanding how your screen time shapes your day.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: AppValidators.name,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: AppValidators.email,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: AppValidators.password,
            ),
            const SizedBox(height: 8),
            _StrengthMeter(strength: _strength),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
              validator: (value) => AppValidators.confirmPassword(
                value,
                _passwordController.text,
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _agree = !_agree),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agree,
                      onChanged: (v) => setState(() => _agree = v ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          'I agree to the Terms of Service and acknowledge '
                          'the Privacy Policy.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text('Create account'),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account?',
                  style: theme.textTheme.bodyMedium,
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).pushReplacementNamed(
                            Routes.login,
                          ),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.strength});

  final int strength;

  static const List<String> _labels = [
    '', 'Too short', 'Okay', 'Good', 'Strong',
  ];
  static const List<Color> _colors = [
    Colors.transparent,
    AppTheme.severe,
    AppTheme.moderate,
    AppTheme.info,
    AppTheme.good,
  ];

  @override
  Widget build(BuildContext context) {
    final clamped = strength.clamp(0, 4);
    final color = _colors[clamped];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            final active = i < clamped;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                height: 4,
                decoration: BoxDecoration(
                  color: active
                      ? color
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        if (clamped > 0) ...[
          const SizedBox(height: 4),
          Text(
            _labels[clamped],
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color),
          ),
        ],
      ],
    );
  }
}
