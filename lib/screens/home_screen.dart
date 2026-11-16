
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/patient_profile.dart';
import '../services/app_store.dart';
import '../widgets/brand_mark.dart';
import 'device_workspace.dart';
import 'profile_edit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.profile,
    required this.onProfileChanged,
    required this.onLogout,
  });

  final AppStore store;
  final PatientProfile profile;
  final ValueChanged<PatientProfile> onProfileChanged;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ScanResult> results = [];

  bool scanning = false;

  String? connectingDeviceId;

  StreamSubscription<List<ScanResult>>? scanSubscription;
  StreamSubscription<BluetoothAdapterState>? adapterSubscription;

  String? scanError;

  @override
  void initState() {
    super.initState();

    scanSubscription = FlutterBluePlus.onScanResults.listen(
      (items) {
        if (mounted) {
          setState(() {
            results = items;
          });
        }
      },
      onError: (Object error) {
        _setScanError(error);
      },
    );

    adapterSubscription =
        FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() {});
      }
    });

    _scan();
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    adapterSubscription?.cancel();

    if (scanning) {
      unawaited(FlutterBluePlus.stopScan());
    }

    super.dispose();
  }

  Future<void> _scan() async {
    if (scanning) return;

    setState(() {
      scanning = true;
      scanError = null;
      results = [];
    });

    try {
      if (!await FlutterBluePlus.isSupported) {
        throw StateError(
          'This phone does not support Bluetooth Low Energy.',
        );
      }

      var adapter = await FlutterBluePlus.adapterState
          .where(
            (state) => state != BluetoothAdapterState.unknown,
          )
          .first
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => BluetoothAdapterState.unknown,
          );

      if (adapter != BluetoothAdapterState.on &&
          Platform.isAndroid &&
          adapter == BluetoothAdapterState.off) {
        await FlutterBluePlus.turnOn();

        adapter = await FlutterBluePlus.adapterState
            .where(
              (state) => state == BluetoothAdapterState.on,
            )
            .first
            .timeout(
              const Duration(seconds: 12),
              onTimeout: () => BluetoothAdapterState.off,
            );
      }

      if (adapter != BluetoothAdapterState.on) {
        throw StateError(
          adapter == BluetoothAdapterState.unauthorized
              ? 'Bluetooth permission is denied. Allow Nearby devices / Bluetooth access in Settings.'
              : 'Turn on Bluetooth, then scan again.',
        );
      }

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidCheckLocationServices: true,
      );

      await FlutterBluePlus.isScanning
          .where((isScanning) => !isScanning)
          .first
          .timeout(
            const Duration(seconds: 12),
          );
    } catch (e) {
      await _setScanError(e);
    }

    if (mounted) {
      setState(() {
        scanning = false;
      });
    }
  }

  Future<void> _setScanError(Object error) async {
    if (!mounted) return;

    final message = error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');

    setState(() {
      scanError = message;
      scanning = false;
    });

    await widget.store.log(
      'error',
      'BLE scan failed: $message',
    );
  }

  String _deviceName(ScanResult result) {
    final advertised =
        result.advertisementData.advName.trim();

    if (advertised.isNotEmpty) {
      return advertised;
    }

    final platform = result.device.platformName.trim();

    return platform.isNotEmpty ? platform : 'BLE device';
  }

  Future<void> _connect(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;

    if (connectingDeviceId != null) return;

    setState(() {
      connectingDeviceId = deviceId;
    });

    try {
      await device.connect();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeviceWorkspace(
            store: widget.store,
            device: device,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Connection error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          connectingDeviceId = null;
        });
      }
    }
  }

  Future<void> _editProfile() async {
    final updated = await Navigator.push<PatientProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(
          store: widget.store,
          profile: widget.profile,
        ),
      ),
    );

    if (updated != null) {
      widget.onProfileChanged(updated);
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log out?'),
          content: const Text(
            'Your saved profile and session history will remain on this device.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(compact: true),
        actions: [
          IconButton(
            onPressed: _editProfile,
            tooltip: 'Update patient profile',
            icon: CircleAvatar(
              radius: 16,
              foregroundImage: widget.profile.photoBytes == null
                  ? null
                  : MemoryImage(widget.profile.photoBytes!),
              child: widget.profile.photoBytes == null
                  ? const Icon(
                      Icons.person_outline,
                      size: 19,
                    )
                  : null,
            ),
          ),
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(
              Icons.logout,
              size: 18,
            ),
            label: const Text('Logout'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            8,
            20,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connect your simulator',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Choose a nearby BLE device to continue.',
                style: TextStyle(
                  color: Color(0xFFA4B0BC),
                ),
              ),

              const SizedBox(height: 22),

              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: const Color(0xFF151D27),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  border: Border.all(
                    color: const Color(0xFF283441),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bluetooth_searching,
                      color: Color(0xFF58D6B0),
                    ),

                    const SizedBox(width: 10),

                    Text(
                      scanning
                          ? 'Scanning nearby'
                          : scanError == null
                              ? 'Available devices'
                              : 'Scan needs attention',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const Spacer(),

                    if (scanning)
                      const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    else
                      IconButton(
                        onPressed:
                            connectingDeviceId != null ? null : _scan,
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Scan again',
                      ),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF151D27),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                    border: const Border(
                      left: BorderSide(
                        color: Color(0xFF283441),
                      ),
                      right: BorderSide(
                        color: Color(0xFF283441),
                      ),
                      bottom: BorderSide(
                        color: Color(0xFF283441),
                      ),
                    ),
                  ),
                  child: results.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  scanError != null
                                      ? Icons.bluetooth_disabled
                                      : Icons.bluetooth_searching,
                                  size: 38,
                                  color: const Color(0xFF83909D),
                                ),

                                const SizedBox(height: 14),

                                Text(
                                  scanError != null
                                      ? scanError!
                                      : scanning
                                          ? 'Looking for nearby BLE devices...'
                                          : 'No BLE devices found.\nMake sure your simulator is advertising and nearby.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFA4B0BC),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Scrollbar(
                          child: ListView.separated(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            itemCount: results.length,
                            separatorBuilder: (_, __) {
                              return const Divider(
                                color: Color(0xFF293542),
                                height: 1,
                              );
                            },
                            itemBuilder: (context, index) {
                              final result = results[index];

                              final deviceId =
                                  result.device.remoteId.str;

                              final isThisDeviceConnecting =
                                  connectingDeviceId == deviceId;

                              return ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 5,
                                ),
                                leading: const CircleAvatar(
                                  backgroundColor:
                                      Color(0xFF20362F),
                                  child: Icon(
                                    Icons.sensors,
                                    color: Color(0xFF58D6B0),
                                  ),
                                ),
                                title: Text(
                                  _deviceName(result),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${result.device.remoteId.str} · ${result.rssi} dBm',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: isThisDeviceConnecting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.chevron_right,
                                      ),
                                onTap: connectingDeviceId != null
                                    ? null
                                    : () => _connect(result.device),
                              );
                            },
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
