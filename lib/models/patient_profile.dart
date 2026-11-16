
import 'dart:typed_data';

class PatientProfile {
  const PatientProfile({
    required this.name,
    required this.photoBytes,
    required this.age,
    required this.gender,
    required this.clinician,
    required this.hospital,
    this.pinSalt = '',
    this.pinHash = '',
  });

  final String name;
  final String gender;
  final String clinician;
  final String hospital;

  final Uint8List? photoBytes;

  final String pinSalt;
  final String pinHash;

  final int age;

  Map<String, Object?> toMap() {
    return {
      'name': name,
      'photo_blob': photoBytes,
      'age': age,
      'gender': gender,
      'clinician': clinician,
      'hospital': hospital,
      'pin_salt': pinSalt,
      'pin_hash': pinHash,
    };
  }

  factory PatientProfile.fromMap(Map<String, Object?> map) {
    final rawPhoto = map['photo_blob'];

    Uint8List? photo;

    if (rawPhoto is Uint8List) {
      photo = rawPhoto;
    } else if (rawPhoto is List<int>) {
      photo = Uint8List.fromList(rawPhoto);
    }

    return PatientProfile(
      name: map['name'] as String,
      photoBytes: photo,
      age: map['age'] as int,
      gender: map['gender'] as String,
      clinician: map['clinician'] as String,
      hospital: map['hospital'] as String,
      pinSalt: map['pin_salt'] as String? ?? '',
      pinHash: map['pin_hash'] as String? ?? '',
    );
  }
}
