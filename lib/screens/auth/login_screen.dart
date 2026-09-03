import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/logo.dart';

/// Redesigned login screen. Changes from the previous version:
///  - Logo added (was missing entirely before).
///  - Inline error banner instead of relying only on a SnackBar (matches
///    the error-display convention used by every other screen in this
///    app, and doesn't disappear before the person reads it).
///  - Field leading icons, proper TextInputAction flow (username ->
///    password -> submit), and AutofillGroup/autofillHints so OS/browser
///    password managers can actually offer to save & fill credentials -
///    standard behavior for any real production login form.
///  - "Forgot Password?" was previously a dead button (onPressed: null).
///    There's no confirmed self-service reset endpoint anywhere in this
///    app, so rather than fabricate one, it now honestly tells the
///    person to contact their administrator instead of doing nothing.
///  - Responsive: a two-panel branding+form layout on wide widths
///    (tablet/desktop Chrome), matching AppNavShell's existing 900px
///    breakpoint, collapsing to a single centered card on phone widths.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    await auth.login(_identifierCtrl.text.trim(), _passwordCtrl.text);
  }

  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please contact your fleet administrator to reset your password.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.sidebar, Color(0xFF16243D)],
          ),
        ),
        child: SafeArea(
          child: isWide ? _wideLayout(auth) : _narrowLayout(auth),
        ),
      ),
    );
  }

  Widget _narrowLayout(AuthProvider auth) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Logo(size: 26),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: _formContent(auth),
              ),
              const SizedBox(height: 20),
              Text('Eyeoty Fleet Platform', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wideLayout(AuthProvider auth) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Logo(size: 30),
                const SizedBox(height: 28),
                const Text(
                  'Real-time visibility\nfor your entire fleet.',
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1.25),
                ),
                const SizedBox(height: 14),
                Text(
                  'Track vehicles, monitor alerts, and review reports \u2014 all in one place.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: _formContent(auth),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _formContent(AuthProvider auth) {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Welcome back', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              'Sign in to continue to your dashboard.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 24),
            if (auth.errorMessage != null && !auth.isLoading) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFE11D48)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(auth.errorMessage!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 12.5))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _identifierCtrl,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(
                labelText: 'Username or Email',
                prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordCtrl,
              focusNode: _passwordFocus,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              onFieldSubmitted: (_) {
                TextInput.finishAutofillContext();
                _submit();
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v ?? true)),
                ),
                const SizedBox(width: 8),
                const Text('Remember me', style: TextStyle(fontSize: 13)),
                const Spacer(),
                TextButton(
                  onPressed: _forgotPassword,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Forgot password?', style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: auth.isLoading
                    ? null
                    : () {
                        TextInput.finishAutofillContext();
                        _submit();
                      },
                child: auth.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}