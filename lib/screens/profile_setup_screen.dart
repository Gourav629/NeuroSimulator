
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/patient_profile.dart';
import '../services/app_store.dart';
import '../services/pin_hasher.dart';
import '../widgets/brand_mark.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.store,
    required this.onSaved,
    this.initialProfile,
  });

  final AppStore store;
  final ValueChanged<PatientProfile> onSaved;
  final PatientProfile? initialProfile;

  @override
  State<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState
    extends State<ProfileSetupScreen> {
  final form = GlobalKey<FormState>();

  late final name = TextEditingController(
    text: widget.initialProfile?.name ?? '',
  );

  late final age = TextEditingController(
    text: widget.initialProfile?.age.toString() ?? '',
  );

  late final clinician = TextEditingController(
    text: widget.initialProfile?.clinician ?? '',
  );

  late final hospital = TextEditingController(
    text: widget.initialProfile?.hospital ?? '',
  );

  final currentPin = TextEditingController();
  final pin = TextEditingController();
  final confirmPin = TextEditingController();

  late String gender =
      widget.initialProfile?.gender ?? 'Female';

  late Uint8List? photoBytes =
      widget.initialProfile?.photoBytes;

  bool saving = false;

  bool get isUpdate => widget.initialProfile != null;

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    clinician.dispose();
    hospital.dispose();
    currentPin.dispose();
    pin.dispose();
    confirmPin.dispose();

    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final selected = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (selected == null) return;

    final bytes = await selected.readAsBytes();

    if (!mounted) return;

    setState(() {
      photoBytes = bytes;
    });
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;

    setState(() {
      saving = true;
    });

    var salt = '';
    var hash = '';

    if (isUpdate) {
      if (!RegExp(r'^\d{6,8}$').hasMatch(currentPin.text)) {
        setState(() {
          saving = false;
        });

        _show(
          'Enter the current 6–8 digit PIN to update this profile.',
        );
        return;
      }

      final existing = widget.initialProfile!;

      final currentHash = await compute(
        derivePinHash,
        '${existing.pinSalt}:${currentPin.text}',
      );

      if (!mounted) return;

      if (currentHash != existing.pinHash) {
        setState(() {
          saving = false;
        });

        _show('The current PIN is incorrect.');
        return;
      }

      salt = existing.pinSalt;
      hash = existing.pinHash;
    }

    if (!isUpdate ||
        pin.text.isNotEmpty ||
        confirmPin.text.isNotEmpty) {
      if (!RegExp(r'^\d{6,8}$').hasMatch(pin.text)) {
        setState(() {
          saving = false;
        });

        _show('Choose a new PIN with 6 to 8 digits.');
        return;
      }

      if (pin.text != confirmPin.text) {
        setState(() {
          saving = false;
        });

        _show('PIN entries do not match.');
        return;
      }

      salt = List<int>.generate(
        16,
        (_) => Random.secure().nextInt(256),
      ).map(
        (b) => b.toRadixString(16).padLeft(2, '0'),
      ).join();

      hash = await compute(
        derivePinHash,
        '$salt:${pin.text}',
      );

      if (!mounted) return;
    }

    final profile = PatientProfile(
      name: name.text.trim(),
      photoBytes: photoBytes,
      age: int.parse(age.text),
      gender: gender,
      clinician: clinician.text.trim(),
      hospital: hospital.text.trim(),
      pinSalt: salt,
      pinHash: hash,
    );

    await widget.store.saveProfile(profile);

    if (!mounted) return;

    widget.onSaved(profile);
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool numeric = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: numeric
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Required';
        }

        if (numeric) {
          final parsed = int.tryParse(value);

          if (parsed == null || parsed < 0 || parsed > 125) {
            return 'Enter a valid age';
          }
        }

        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 520,
            ),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 24),

                const BrandMark(),

                const SizedBox(height: 32),

                Text(
                  isUpdate
                      ? 'Update patient profile'
                      : 'Sign up',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  isUpdate
                      ? 'Verify your current PIN to edit the patient profile.'
                      : 'Create a patient profile and PIN for offline access on this device.',
                  style: const TextStyle(
                    color: Color(0xFFA4B0BC),
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 24),

                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor: const Color(0xFF1D2A35),
                      foregroundImage: photoBytes == null
                          ? null
                          : MemoryImage(photoBytes!),
                      child: photoBytes == null
                          ? const Icon(
                              Icons.add_a_photo_outlined,
                              size: 27,
                            )
                          : null,
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                Form(
                  key: form,
                  child: Column(
                    children: [
                      _field(
                        name,
                        'Patient name',
                        Icons.person_outline,
                      ),

                      const SizedBox(height: 12),

                      _field(
                        age,
                        'Age',
                        Icons.cake_outlined,
                        numeric: true,
                      ),

                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: gender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(Icons.wc_outlined),
                        ),
                        items: const [
                          'Female',
                          'Male',
                          'Non-binary',
                          'Prefer not to say',
                        ].map((value) {
                          return DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            gender = value;
                          });
                        },
                      ),

                      const SizedBox(height: 12),

                      _field(
                        clinician,
                        'Clinician',
                        Icons.medical_services_outlined,
                      ),

                      const SizedBox(height: 12),

                      _field(
                        hospital,
                        'Hospital / clinic',
                        Icons.local_hospital_outlined,
                      ),

                      const SizedBox(height: 12),

                      if (isUpdate) ...[
                        TextFormField(
                          controller: currentPin,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Current PIN',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),

                        const SizedBox(height: 12),
                      ],

                      TextFormField(
                        controller: pin,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 8,
                        decoration: InputDecoration(
                          labelText: isUpdate
                              ? 'New PIN (optional)'
                              : 'Create 6–8 digit PIN',
                          counterText: '',
                          prefixIcon: const Icon(
                            Icons.pin_outlined,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: confirmPin,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 8,
                        decoration: const InputDecoration(
                          labelText: 'Confirm new PIN',
                          counterText: '',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: saving ? null : _save,
                  icon: const Icon(Icons.lock_open),
                  label: Text(
                    saving
                        ? 'Saving…'
                        : isUpdate
                            ? 'Update profile'
                            : 'Create profile & continue',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),

                const SizedBox(height: 12),

                const Center(
                  child: Text(
                    'PIN and profile stay on this device. No internet required.',
                    style: TextStyle(
                      color: Color(0xFF83909D),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
