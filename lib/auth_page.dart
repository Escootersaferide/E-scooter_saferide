import 'package:material_ui/material_ui.dart';

import 'auth_service.dart';
import 'saferide_ui.dart';

enum AuthMode { login, register }

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.authService,
    this.initialMode = AuthMode.register,
  });

  final AuthService authService;
  final AuthMode initialMode;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AuthMode _mode = widget.initialMode;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode nextMode) {
    if (_mode == nextMode || _submitting) return;
    setState(() {
      _mode = nextMode;
      _errorMessage = null;
    });
    _formKey.currentState?.reset();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final AuthSession session;
      if (_mode == AuthMode.register) {
        session = await widget.authService.register(
          email: _emailController.text,
          phone: _phoneController.text,
          password: _passwordController.text,
        );
      } else {
        session = await widget.authService.login(
          identifier: _identifierController.text,
          password: _passwordController.text,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, session);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isRegister = _mode == AuthMode.register;

    return SaferideScaffold(
      child: SaferideCard(
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isRegister ? 'Создать аккаунт' : 'Вход в аккаунт',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isRegister
                      ? 'Укажите email, номер телефона и пароль для регистрации.'
                      : 'Войдите по email или номеру телефона.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<AuthMode>(
                  segments: const [
                    ButtonSegment(
                      value: AuthMode.login,
                      label: Text('Вход'),
                      icon: Icon(Icons.login_rounded),
                    ),
                    ButtonSegment(
                      value: AuthMode.register,
                      label: Text('Регистрация'),
                      icon: Icon(Icons.person_add_alt_1_rounded),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) =>
                      _switchMode(selection.first),
                ),
                const SizedBox(height: 20),
                if (isRegister) ...[
                  TextFormField(
                    key: const ValueKey('auth_email_field'),
                    controller: _emailController,
                    enabled: !_submitting,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: validateEmail,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'rider@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const ValueKey('auth_phone_field'),
                    controller: _phoneController,
                    enabled: !_submitting,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    validator: validatePhone,
                    decoration: const InputDecoration(
                      labelText: 'Номер телефона',
                      hintText: '+7 (999) 123-45-67',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else
                  TextFormField(
                    key: const ValueKey('auth_identifier_field'),
                    controller: _identifierController,
                    enabled: !_submitting,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    validator: validateIdentifier,
                    decoration: const InputDecoration(
                      labelText: 'Email или номер телефона',
                      hintText: 'rider@example.com или +7 999 123-45-67',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('auth_password_field'),
                  controller: _passwordController,
                  enabled: !_submitting,
                  obscureText: _obscurePassword,
                  textInputAction: isRegister
                      ? TextInputAction.next
                      : TextInputAction.done,
                  autofillHints: [
                    isRegister
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  validator: isRegister
                      ? validatePassword
                      : (value) => (value == null || value.isEmpty)
                            ? 'Введите пароль.'
                            : null,
                  onFieldSubmitted: isRegister ? null : (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    hintText: isRegister ? 'Минимум 8 символов' : null,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      tooltip: _obscurePassword
                          ? 'Показать пароль'
                          : 'Скрыть пароль',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                if (isRegister) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const ValueKey('auth_confirm_password_field'),
                    controller: _confirmPasswordController,
                    enabled: !_submitting,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Пароли не совпадают.';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Повторите пароль',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                        tooltip: _obscureConfirmPassword
                            ? 'Показать пароль'
                            : 'Скрыть пароль',
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: colors.onErrorContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  key: const ValueKey('auth_submit_button'),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: colors.onPrimary,
                          ),
                        )
                      : Text(isRegister ? 'Зарегистрироваться' : 'Войти'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
