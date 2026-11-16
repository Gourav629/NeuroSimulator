
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/patient_profile.dart';
import '../services/app_store.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    super.key,
    required this.store,
    required this.profile,
  });

  final AppStore store;
  final PatientProfile profile;

  @override
  State<ProfileEditScreen> createState() =>
      _ProfileEditScreenState();
}

class _ProfileEditScreenState
    extends State<ProfileEditScreen> {
  late final name = TextEditingController(
    text: widget.profile.name,
  );

  late final age = TextEditingController(
    text: '${widget.profile.age}',
  );

  late final clinician = TextEditingController(
    text: widget.profile.clinician,
  );

  late final hospital = TextEditingController(
    text: widget.profile.hospital,
  );

  late String gender = widget.profile.gender;

  late Uint8List? photoBytes = widget.profile.photoBytes;

  final form = GlobalKey<FormState>();

  bool saving = false;

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

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    clinician.dispose();
    hospital.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;

    setState(() {
      saving = true;
    });

    final updated = PatientProfile(
      name: name.text.trim(),
      photoBytes: photoBytes,
      age: int.parse(age.text),
      gender: gender,
      clinician: clinician.text.trim(),
      hospital: hospital.text.trim(),
      pinSalt: widget.profile.pinSalt,
      pinHash: widget.profile.pinHash,
    );

    try {
      await widget.store.saveProfile(updated);

      if (!mounted) return;

      Navigator.pop(context, updated);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save profile: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit patient profile'),
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    foregroundImage: photoBytes == null
                        ? null
                        : MemoryImage(photoBytes!),
                    child: photoBytes == null
                        ? const Icon(
                            Icons.person_outline,
                            size: 38,
                          )
                        : null,
                  ),

                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(
                      Icons.photo_camera_back_outlined,
                    ),
                    label: const Text('Update profile photo'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            TextFormField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Patient name',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter patient name';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: age,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age',
              ),
              validator: (value) {
                final parsed = int.tryParse(value ?? '');

                if (parsed == null ||
                    parsed < 0 ||
                    parsed > 125) {
                  return 'Enter a valid age';
                }

                return null;
              },
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: gender,
              decoration: const InputDecoration(
                labelText: 'Gender',
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

            TextFormField(
              controller: clinician,
              decoration: const InputDecoration(
                labelText: 'Clinician',
              ),
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: hospital,
              decoration: const InputDecoration(
                labelText: 'Hospital / clinic',
              ),
            ),

            const SizedBox(height: 20),

            FilledButton(
              onPressed: saving ? null : _save,
              child: Text(
                saving ? 'Saving…' : 'Save changes',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
