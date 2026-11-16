
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/patient_profile.dart';
import '../screens/authentication_screen.dart';
import '../screens/home_screen.dart';
import '../screens/splash_screen.dart';
import '../services/app_store.dart';

class AppGate extends StatefulWidget {
  const AppGate({
    super.key,
    required this.store,
  });

  final AppStore store;

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  PatientProfile? profile;

  bool checking = true;
  bool unlocked = false;
  bool splashComplete = false;

  @override
  void initState() {
    super.initState();

    _load();

    Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() {
          splashComplete = true;
        });
      }
    });
  }

  Future<void> _load() async {
    final result = await widget.store.getProfile();

    if (!mounted) return;

    setState(() {
      profile = result;
      checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!splashComplete || checking) {
      return const SplashScreen();
    }

    if (!unlocked) {
      return AuthenticationScreen(
        store: widget.store,
        profile: profile,
        onLogin: () {
          setState(() {
            unlocked = true;
          });
        },
        onProfileSaved: (updatedProfile) {
          setState(() {
            profile = updatedProfile;
            unlocked = true;
          });
        },
      );
    }

    return HomeScreen(
      store: widget.store,
      profile: profile!,
      onProfileChanged: (updatedProfile) {
        setState(() {
          profile = updatedProfile;
        });
      },
      onLogout: () {
        setState(() {
          unlocked = false;
        });
      },
    );
  }
}
