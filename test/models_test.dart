import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:neurosim/models/patient_profile.dart';
import 'package:neurosim/models/simulation_config.dart';

void main() {
  group('PatientProfile tests', () {
    test('Patient profile should serialize correctly', () {
      final photo = Uint8List.fromList([1, 2, 3, 4]);

      const profile = PatientProfile(
        name: 'Test Patient',
        photoBytes: null,
        age: 25,
        gender: 'Male',
        clinician: 'Dr Test',
        hospital: 'Test Hospital',
        pinSalt: 'test_salt',
        pinHash: 'test_hash',
      );

      final map = profile.toMap();

      expect(map['name'], 'Test Patient');
      expect(map['age'], 25);
      expect(map['gender'], 'Male');
      expect(map['clinician'], 'Dr Test');
      expect(map['hospital'], 'Test Hospital');
      expect(map['pin_salt'], 'test_salt');
      expect(map['pin_hash'], 'test_hash');

      expect(map['photo_blob'], isNull);

      final profileWithPhoto = PatientProfile(
        name: 'Test Patient',
        photoBytes: photo,
        age: 25,
        gender: 'Male',
        clinician: 'Dr Test',
        hospital: 'Test Hospital',
      );

      expect(profileWithPhoto.toMap()['photo_blob'], photo);
    });

    test('Patient profile should deserialize correctly', () {
      final photo = Uint8List.fromList([10, 20, 30]);

      final profile = PatientProfile.fromMap({
        'name': 'Test Patient',
        'photo_blob': photo,
        'age': 30,
        'gender': 'Female',
        'clinician': 'Dr Example',
        'hospital': 'Example Hospital',
        'pin_salt': 'salt123',
        'pin_hash': 'hash123',
      });

      expect(profile.name, 'Test Patient');
      expect(profile.age, 30);
      expect(profile.gender, 'Female');
      expect(profile.clinician, 'Dr Example');
      expect(profile.hospital, 'Example Hospital');
      expect(profile.pinSalt, 'salt123');
      expect(profile.pinHash, 'hash123');
      expect(profile.photoBytes, photo);
    });

    test('Profile without photo should deserialize', () {
      final profile = PatientProfile.fromMap({
        'name': 'Patient',
        'photo_blob': null,
        'age': 20,
        'gender': 'Male',
        'clinician': 'Doctor',
        'hospital': 'Clinic',
        'pin_salt': 'salt',
        'pin_hash': 'hash',
      });

      expect(profile.photoBytes, isNull);
    });
  });

  group('SimulationConfig tests', () {
    test('Default configuration should be correct', () {
      const config = SimulationConfig();

      expect(config.channel, 1);
      expect(config.periodMs, 1000);
      expect(config.frequencyHz, 20);
      expect(config.pulseWidthUs, 200);
      expect(config.gapUs, 100);
    });

    test('Configuration should serialize correctly', () {
      const config = SimulationConfig(
        channel: 2,
        periodMs: 1500,
        frequencyHz: 30,
        pulseWidthUs: 250,
        gapUs: 120,
      );

      final map = config.toMap();

      expect(map['channel'], 2);
      expect(map['period_ms'], 1500);
      expect(map['frequency_hz'], 30);
      expect(map['pulse_width_us'], 250);
      expect(map['gap_us'], 120);
    });
  });
}
