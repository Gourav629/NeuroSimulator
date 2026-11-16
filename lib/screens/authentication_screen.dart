
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../models/patient_profile.dart';
import '../services/app_store.dart';
import '../services/pin_hasher.dart';
import '../widgets/brand_mark.dart';
import '../widgets/info_note.dart';
import 'profile_setup_screen.dart';

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({
    super.key,
    required this.store,
    required this.profile,
    required this.onLogin,
    required this.onProfileSaved,
  });

  final AppStore store;
  final PatientProfile? profile;
  final VoidCallback onLogin;
  final ValueChanged<PatientProfile> onProfileSaved;

  @override
  State<AuthenticationScreen> createState() =>
      _AuthenticationScreenState();
}

class _AuthenticationScreenState
    extends State<AuthenticationScreen> {
  final pin = TextEditingController();

  bool signup = false;
  bool busy = false;

  @override
  void dispose() {
    pin.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final profile = widget.profile;

    if (profile == null) {
      _show(
        'Create a patient profile using Sign up first.',
      );
      return;
    }

    if (!RegExp(r'^\d{6,8}$').hasMatch(pin.text)) {
      _show('Enter your 6–8 digit PIN.');
      return;
    }

    setState(() {
      busy = true;
    });

    final hash = await compute(
      derivePinHash,
      '${profile.pinSalt}:${pin.text}',
    );

    if (!mounted) return;

    setState(() {
      busy = false;
    });

    if (hash == profile.pinHash) {
      widget.onLogin();
    } else {
      pin.clear();
      _show('Incorrect PIN. Try again.');
    }
  }

  Future<void> _openSignup() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileSetupScreen(
          store: widget.store,
          initialProfile: widget.profile,
          onSaved: (profile) {
            widget.onProfileSaved(profile);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 460,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          const Center(
                            child: BrandMark(centered: true),
                          ),
                          const SizedBox(height: 48),

                          if (signup) ...[
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFF151D27),
                                borderRadius:
                                    BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFF293542),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.profile == null
                                        ? 'Create patient profile'
                                        : 'Update patient profile',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    widget.profile == null
                                        ? 'Add patient details and create a local PIN.'
                                        : 'Verify the current PIN to edit profile details or change the PIN.',
                                    style: const TextStyle(
                                      color: Color(0xFFA4B0BC),
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _openSignup,
                              icon: const Icon(Icons.edit_note),
                              label: Text(
                                widget.profile == null
                                    ? 'Continue to sign up'
                                    : 'Continue to profile update',
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize:
                                    const Size.fromHeight(54),
                              ),
                            ),
                          ] else ...[
                            if (widget.profile != null) ...[
                              Center(
                                child: CircleAvatar(
                                  radius: 38,
                                  foregroundImage:
                                      widget.profile!.photoBytes ==
                                              null
                                          ? null
                                          : MemoryImage(
                                              widget.profile!
                                                  .photoBytes!,
                                            ),
                                  child:
                                      widget.profile!.photoBytes ==
                                              null
                                          ? const Icon(
                                              Icons.person_outline,
                                              size: 30,
                                            )
                                          : null,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Welcome back, ${widget.profile!.name.split(' ').first}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 22),
                            ] else ...[
                              const InfoNote(
                                text:
                                    'No patient profile is set up on this device yet. Choose Sign up to create one.',
                              ),
                              const SizedBox(height: 18),
                            ],

                            TextField(
                              controller: pin,
                              obscureText: true,
                              keyboardType: TextInputType.number,
                              maxLength: 8,
                              textAlign: TextAlign.start,
                              decoration: const InputDecoration(
                                labelText: '6–8 digit PIN',
                                counterText: '',
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                ),
                              ),
                              onSubmitted: (_) => _login(),
                            ),
                            const SizedBox(height: 14),

                            FilledButton(
                              onPressed: busy ? null : _login,
                              style: FilledButton.styleFrom(
                                minimumSize:
                                    const Size.fromHeight(54),
                              ),
                              child: busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Login'),
                            ),
                          ],

                          const SizedBox(height: 22),

                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Login'),
                                icon: Icon(Icons.lock_open),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Sign up'),
                                icon: Icon(
                                  Icons.person_add_alt_1,
                                ),
                              ),
                            ],
                            selected: {signup},
                            onSelectionChanged: (value) {
                              setState(() {
                                signup = value.first;
                              });
                            },
                          ),

                          const SizedBox(height: 20),

                          const Center(
                            child: Text(
                              'Your profile stays on this device.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF83909D),
                              ),
                            ),
                          ),
                        ],
                      ),
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
}
