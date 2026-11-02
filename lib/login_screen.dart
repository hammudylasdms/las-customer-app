import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({
    super.key,
    required this.onSubmit,
    required this.faceIdAvailable,
    this.faceIdEnrolled = false,
  });
  final Future<void> Function(String username, String password, bool faceId)
  onSubmit;
  final bool faceIdAvailable;
  final bool faceIdEnrolled;
  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool faceId = false;
  bool visible = false;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    faceId = widget.faceIdAvailable && widget.faceIdEnrolled;
  }

  @override
  void didUpdateWidget(covariant CustomerLoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.faceIdEnrolled && widget.faceIdEnrolled) {
      faceId = widget.faceIdAvailable;
    }
  }

  Future<void> submit() async {
    if (busy) return;
    if (!faceId && (username.text.trim().isEmpty || password.text.isEmpty)) {
      setState(() => error = 'Enter your LAS ID and password.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSubmit(username.text.trim(), password.text, faceId);
      if (mounted) password.clear();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = faceId
              ? 'Sign-in was not completed. To set up Face ID, enter your LAS ID and password, then try again.'
              : 'Could not sign in. Check your details and connection, or try again later.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Widget field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool secret = false,
  }) => ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: TextField(
        controller: controller,
        enabled: !busy,
        obscureText: secret && !visible,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: [
          secret ? AutofillHints.password : AutofillHints.username,
        ],
        textInputAction: secret ? TextInputAction.done : TextInputAction.next,
        onSubmitted: secret ? (_) => submit() : null,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white, fontSize: 16),
          prefixIcon: Icon(icon, color: Colors.white),
          suffixIcon: secret
              ? IconButton(
                  tooltip: visible ? 'Hide password' : 'Show password',
                  onPressed: () => setState(() => visible = !visible),
                  icon: Icon(
                    visible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white,
                  ),
                )
              : null,
          filled: true,
          fillColor: const Color(0x88434a50),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 19,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Colors.white38),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Colors.white38),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Colors.white, width: 1.5),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/branding/login_background.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0.15, 0),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x44000000),
                  Color(0x00000000),
                  Color(0x99000000),
                ],
                stops: [0, 0.4, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 48).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        const Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: 'We Handle. '),
                              TextSpan(
                                text: 'You Drive.',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontFamily: 'BMWTypeNext',
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Transform.translate(
                                offset: const Offset(0, 28),
                                child: const Text(
                                  'My ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 56,
                                    height: 1.2,
                                    fontFamily: 'Snell Roundhand',
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              const Text(
                                'LAS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 56,
                                  height: 1.2,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 100),
                        if (!(faceId && widget.faceIdEnrolled))
                          AutofillGroup(
                            child: Column(
                              children: [
                                field(
                                  controller: username,
                                  hint: 'Your LAS ID (Username)',
                                  icon: Icons.person_outline,
                                ),
                                const SizedBox(height: 12),
                                field(
                                  controller: password,
                                  hint: 'Password',
                                  icon: Icons.lock_outline,
                                  secret: true,
                                ),
                              ],
                            ),
                          ),
                        if (widget.faceIdAvailable)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.face_outlined,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Sign in with Face ID',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Switch.adaptive(
                                  value: faceId,
                                  activeTrackColor: const Color(0xff007aff),
                                  onChanged: busy
                                      ? null
                                      : (value) =>
                                            setState(() => faceId = value),
                                ),
                              ],
                            ),
                          ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              error!,
                              style: const TextStyle(color: Colors.white),
                              semanticsLabel: error,
                            ),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 62,
                          child: FilledButton.icon(
                            onPressed: busy ? null : submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xff007aff),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xff316a9c),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            icon: busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    faceId ? Icons.face_outlined : Icons.login,
                                  ),
                            label: Text(
                              faceId ? 'Sign In with Face ID' : 'Sign In',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
