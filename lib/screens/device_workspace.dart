
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/simulation_config.dart';
import '../protocol/ble_packet_codec.dart';
import '../services/app_store.dart';
import '../widgets/info_note.dart';

class DeviceWorkspace extends StatefulWidget {
  const DeviceWorkspace({
    super.key,
    required this.store,
    required this.device,
  });

  final AppStore store;
  final BluetoothDevice device;

  @override
  State<DeviceWorkspace> createState() =>
      _DeviceWorkspaceState();
}

class _DeviceWorkspaceState extends State<DeviceWorkspace> {
  int page = 0;
  int channel = 1;

  final period = TextEditingController(text: '1000');
  final frequency = TextEditingController(text: '20');
  final pulse = TextEditingController(text: '200');
  final gap = TextEditingController(text: '100');

  bool running = false;
  bool busy = false;

  List<Map<String, Object?>> logs = [];
  List<Map<String, Object?>> configs = [];

  // BLE UUID CONFIGURATION

  static final Guid _serviceUuid =
      Guid('12345678-1234-1234-1234-123456789000');

  static final Guid _notifyUuid =
      Guid('12345678-1234-1234-1234-123456789001');

  static final Guid _writeUuid =
      Guid('12345678-1234-1234-1234-123456789002');

  BluetoothCharacteristic? _writeCharacteristic;

  StreamSubscription<List<int>>? _notificationSubscription;

  Completer<int>? _pendingAck;

  Future<void>? _bleSetupFuture;

  bool _ackChannelReady = false;

  String? _bleSetupError;

  // --------------------------------------------------
  // PAGE HEADER
  // --------------------------------------------------

  Widget _pageHeader(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF173B3A),
            Color(0xFF142337),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF294B4B),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF244A43),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF55D8B8),
                  size: 27,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFA4B0BC),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(
                'BLE CONNECTED',
                Icons.bluetooth_connected,
                const Color(0xFF55D8B8),
                const Color(0xFF183B32),
              ),

              _statusChip(
                _ackChannelReady
                    ? 'ACK LISTENING'
                    : 'ACK NOT READY',
                Icons.verified_outlined,
                _ackChannelReady
                    ? const Color(0xFF55D8B8)
                    : const Color(0xFFFFB86B),
                _ackChannelReady
                    ? const Color(0xFF183B32)
                    : const Color(0xFF403321),
              ),
            ],
          ),

          if (_bleSetupError != null) ...[
            const SizedBox(height: 12),

            Text(
              _bleSetupError!,
              style: const TextStyle(
                color: Color(0xFFFF8585),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(
    String label,
    IconData icon,
    Color foreground,
    Color background,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: foreground,
          ),

          const SizedBox(width: 6),

          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // BLE INITIALIZATION
  // --------------------------------------------------

  Future<void> _prepareBle() async {
    try {
      final services = await widget.device.discoverServices();

      BluetoothCharacteristic? notifyCharacteristic;
      BluetoothCharacteristic? writeCharacteristic;

      for (final service in services) {
        if (service.serviceUuid != _serviceUuid) {
          continue;
        }

        for (final characteristic in service.characteristics) {
          if (characteristic.characteristicUuid == _notifyUuid) {
            if (characteristic.properties.notify ||
                characteristic.properties.indicate) {
              notifyCharacteristic = characteristic;
            }
          }

          if (characteristic.characteristicUuid == _writeUuid) {
            if (characteristic.properties.write ||
                characteristic.properties.writeWithoutResponse) {
              writeCharacteristic = characteristic;
            }
          }
        }
      }

      if (notifyCharacteristic == null) {
        throw StateError(
          'BLE notification characteristic not found.',
        );
      }

      if (writeCharacteristic == null) {
        throw StateError(
          'BLE write characteristic not found.',
        );
      }

      _writeCharacteristic = writeCharacteristic;

      _notificationSubscription =
          notifyCharacteristic.onValueReceived.listen(
        _handleDeviceNotification,
        onError: (Object error) {
          debugPrint('BLE notification error: $error');
        },
      );

      await notifyCharacteristic.setNotifyValue(true);

      if (!mounted) return;

      setState(() {
        _ackChannelReady = true;
        _bleSetupError = null;
      });

      await widget.store.log(
        'info',
        'BLE notification and write characteristics initialized.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _ackChannelReady = false;
        _bleSetupError = e.toString();
      });

      await widget.store.log(
        'error',
        'BLE setup failed: $e',
      );
    }
  }

  // --------------------------------------------------
  // BLE NOTIFICATION / ACK / NACK
  // --------------------------------------------------

  void _handleDeviceNotification(List<int> data) {
    if (data.isEmpty) return;

    debugPrint(
      'BLE RX: ${data.map(
        (b) => b.toRadixString(16).padLeft(2, '0'),
      ).join(' ')}',
    );

    // Assumed device protocol:
    // 0x06 = ACK
    // 0x15 = NACK

    final response = data.first;

    if (response == 0x06 || response == 0x15) {
      final completer = _pendingAck;

      if (completer != null && !completer.isCompleted) {
        completer.complete(response);
      }
    } else {
      debugPrint(
        'Unknown device response: $response',
      );
    }
  }

  // --------------------------------------------------
  // ACK / NACK DIALOG
  // --------------------------------------------------

  Future<void> _showAckDialog({
    required bool acknowledged,
    required String message,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            acknowledged
                ? Icons.check_circle_outline
                : Icons.error_outline,
            size: 48,
            color: acknowledged
                ? const Color(0xFF58D6B0)
                : Colors.redAccent,
          ),
          title: Text(
            acknowledged
                ? 'Device Acknowledged'
                : 'Device Response Failed',
          ),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------
  // INITIALIZATION
  // --------------------------------------------------

  @override
  void initState() {
    super.initState();

    unawaited(_refresh());

    _bleSetupFuture = _prepareBle();
  }

  @override
  void dispose() {
    period.dispose();
    frequency.dispose();
    pulse.dispose();
    gap.dispose();

    unawaited(
      _notificationSubscription?.cancel() ??
          Future<void>.value(),
    );

    super.dispose();
  }

  // --------------------------------------------------
  // DATABASE REFRESH
  // --------------------------------------------------

  Future<void> _refresh() async {
    final recentLogs = await widget.store.recentLogs();
    final recentConfigs = await widget.store.recentConfigs();

    if (!mounted) return;

    setState(() {
      logs = recentLogs;
      configs = recentConfigs;
    });
  }

  // --------------------------------------------------
  // CONFIGURATION VALIDATION
  // --------------------------------------------------

  SimulationConfig? _config() {
    final values = [
      int.tryParse(period.text),
      int.tryParse(frequency.text),
      int.tryParse(pulse.text),
      int.tryParse(gap.text),
    ];

    if (values.any(
      (value) => value == null || value <= 0,
    )) {
      _snack(
        'Enter positive whole numbers for all parameters.',
      );

      return null;
    }

    return SimulationConfig(
      channel: channel,
      periodMs: values[0]!,
      frequencyHz: values[1]!,
      pulseWidthUs: values[2]!,
      gapUs: values[3]!,
    );
  }

  // --------------------------------------------------
  // SEND / START / STOP COMMAND
  // --------------------------------------------------

  Future<void> _command(String action) async {
    if (busy) return;

    final config = _config();

    if (config == null) return;

    setState(() {
      busy = true;
    });

    Completer<int>? ackCompleter;

    try {
      // Wait until BLE notification setup is complete.
      await (_bleSetupFuture ??= _prepareBle());

      if (!_ackChannelReady ||
          _writeCharacteristic == null) {
        throw StateError(
          _bleSetupError ??
              'BLE acknowledgement channel is not ready.',
        );
      }

      final bool isStart = action != 'stop';

      final Uint8List payload =
          BlePacketCodec.buildTxPacket(
        days: 0,
        hours: 0,
        minutes: 0,
        seconds: 0,
        milliseconds: 0,
        start: isStart,
        channel: config.channel,
        current: 0,
        frequency: config.frequencyHz,
        pulseWidth: config.pulseWidthUs,
        gap: config.gapUs,
      );

      final characteristic = _writeCharacteristic!;

      // Create ACK listener before transmitting.
      ackCompleter = Completer<int>();

      _pendingAck = ackCompleter;

      await characteristic.write(
        payload,
        withoutResponse:
            !characteristic.properties.write,
      );

      final packetHex = payload.map((byte) {
        return byte
            .toRadixString(16)
            .padLeft(2, '0')
            .toUpperCase();
      }).join(' ');

      await widget.store.log(
        'tx',
        'Sent $action packet: $packetHex',
      );

      // Wait up to 6 seconds for device response.
      final response = await ackCompleter.future.timeout(
        const Duration(seconds: 6),
      );

      if (response == 0x06) {
        // Device acknowledged the command.
        await widget.store.saveConfig(config);

        running = isStart;

        // Update the UI immediately after ACK.
        if (mounted) {
          setState(() {});
        }

        await widget.store.log(
          'ack',
          '$action command acknowledged by device.',
        );

        await _showAckDialog(
          acknowledged: true,
          message:
              '$action command was successfully acknowledged by the device.',
        );
      } else {
        // Device returned NACK.
        await widget.store.log(
          'nack',
          '$action command rejected by device.',
        );

        await _showAckDialog(
          acknowledged: false,
          message:
              'The device rejected the $action command.',
        );
      }
    } on TimeoutException {
      await widget.store.log(
        'timeout',
        '$action command: No device acknowledgement received within 6 seconds.',
      );

      if (mounted) {
        await _showAckDialog(
          acknowledged: false,
          message:
              'No acknowledgement was received within 6 seconds. '
              'The command may have been transmitted, but its execution is unconfirmed.',
        );
      }
    } catch (e) {
      await widget.store.log(
        'error',
        '$action command failed: $e',
      );

      if (mounted) {
        _snack('Command failed: $e');
      }
    } finally {
      if (ackCompleter != null &&
          identical(_pendingAck, ackCompleter)) {
        _pendingAck = null;
      }

      try {
        await _refresh();
      } finally {
        if (mounted) {
          setState(() {
            busy = false;
          });
        }
      }
    }
  }

  // --------------------------------------------------
  // DISCONNECT
  // --------------------------------------------------

  Future<void> _disconnect() async {
    if (busy) return;

    // Send STOP first if simulation is running.
    if (running) {
      await _command('stop');

      if (!mounted) return;

      // Do not disconnect if STOP was not acknowledged.
      if (running) {
        _snack(
          'STOP was not acknowledged. Disconnect cancelled.',
        );
        return;
      }
    }

    setState(() {
      busy = true;
    });

    try {
      await widget.device.disconnect();

      await widget.store.log(
        'info',
        'Disconnected from ${widget.device.platformName}',
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      await widget.store.log(
        'error',
        'Disconnection failed: $e',
      );

      if (mounted) {
        _snack('Disconnection failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // MAIN BUILD
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          widget.device.platformName.isEmpty
              ? 'Device console'
              : widget.device.platformName,
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(
              vertical: 17,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF18352D),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: Color(0xFF58D6B0),
                ),
                SizedBox(width: 6),
                Text(
                  'CONNECTED',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: .7,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: page,
              children: [
                _configuration(),
                _console(),
              ],
            ),
          ),

          NavigationBar(
            selectedIndex: page,
            onDestinationSelected: (index) {
              setState(() {
                page = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.tune),
                label: 'Configure',
              ),
              NavigationDestination(
                icon: Icon(Icons.terminal),
                label: 'Console',
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            12,
          ),
          child: OutlinedButton.icon(
            onPressed: busy ? null : _disconnect,
            icon: const Icon(Icons.bluetooth_disabled),
            label: const Text('Disconnect device'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF9A91),
              side: const BorderSide(
                color: Color(0xFF70403D),
              ),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // CONFIGURATION PAGE
  // --------------------------------------------------

  Widget _configuration() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Simulation setup',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Set the parameters for this session.',
          style: TextStyle(
            color: Color(0xFFA4B0BC),
          ),
        ),

        _pageHeader(
          'Simulation setup',
          'Configure your device parameters.',
          Icons.tune_rounded,
        ),

        const SizedBox(height: 22),

        _section(
          'CHANNEL',
          child: Wrap(
            spacing: 9,
            children: List.generate(
              4,
              (index) {
                return ChoiceChip(
                  label: Text('CH${index + 1}'),
                  selected: channel == index + 1,
                  onSelected: (_) {
                    setState(() {
                      channel = index + 1;
                    });
                  },
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 14),

        _section(
          'TIMING & PULSE',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      period,
                      'Time period',
                      'ms',
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _numberField(
                      frequency,
                      'Frequency',
                      'Hz',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      pulse,
                      'Pulse width',
                      'µs',
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _numberField(
                      gap,
                      'Gap',
                      'µs',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        const InfoNote(
          text:
              'Confirm all settings against your device documentation and clinical protocol before sending.',
        ),

        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    busy ? null : () => _command('stop'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('STOP'),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: FilledButton(
                onPressed:
                    busy ? null : () => _command('send'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('SEND'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        FilledButton.icon(
          onPressed: busy
              ? null
              : () => _command(
                    running ? 'stop' : 'start',
                  ),
          icon: Icon(
            running
                ? Icons.stop_circle_outlined
                : Icons.play_arrow,
          ),
          label: Text(
            running
                ? 'Stop simulation'
                : 'Start simulation',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: running
                ? const Color(0xFF7E3434)
                : const Color(0xFF58D6B0),
            foregroundColor: const Color(0xFF102019),
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // CONSOLE PAGE
  // --------------------------------------------------

  Widget _console() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Session console',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Saved configuration and BLE communication events.',
            style: TextStyle(
              color: Color(0xFFA4B0BC),
            ),
          ),

          _pageHeader(
            'Session console',
            'Monitor device communication and configuration history.',
            Icons.terminal_rounded,
          ),

          const SizedBox(height: 22),

          _section(
            'CURRENT SETTINGS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Channel  CH$channel'),
                Text('Period  ${period.text} ms'),
                Text('Frequency  ${frequency.text} Hz'),
                Text('Pulse width  ${pulse.text} µs'),
                Text('Gap  ${gap.text} µs'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _section(
            'RECENT CONFIGURATIONS',
            child: configs.isEmpty
                ? const Text(
                    'No configurations sent yet.',
                    style: TextStyle(
                      color: Color(0xFFA4B0BC),
                    ),
                  )
                : Column(
                    children: configs
                        .take(8)
                        .map(
                          (config) {
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'CH${config['channel']} · '
                                '${config['frequency_hz']} Hz · '
                                '${config['pulse_width_us']} µs',
                              ),
                              subtitle: Text(
                                '${config['period_ms']} ms period · '
                                '${config['gap_us']} µs gap',
                              ),
                              trailing: Text(
                                _time(
                                  config['created_at'] as String,
                                ),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFA4B0BC),
                                ),
                              ),
                            );
                          },
                        )
                        .toList(),
                  ),
          ),

          const SizedBox(height: 16),

          _section(
            'COMMUNICATION',
            child: logs.isEmpty
                ? const Text(
                    'No communication recorded.',
                    style: TextStyle(
                      color: Color(0xFFA4B0BC),
                    ),
                  )
                : Column(
                    children: logs
                        .take(15)
                        .map(
                          (log) {
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                log['level'] == 'error'
                                    ? Icons.error_outline
                                    : Icons.circle,
                                size: 13,
                                color: log['level'] == 'error'
                                    ? Colors.redAccent
                                    : const Color(0xFF58D6B0),
                              ),
                              title: Text(
                                log['message'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                ),
                              ),
                              subtitle: Text(
                                _time(
                                  log['created_at'] as String,
                                ),
                                style: const TextStyle(
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        )
                        .toList(),
                  ),
          ),

          const SizedBox(height: 12),

          const InfoNote(
            text:
                'Console entries are stored in the local SQLite database on this device.',
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // REUSABLE SECTION
  // --------------------------------------------------

  Widget _section(
    String title, {
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: const Color(0xFF121D29),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF28394A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Color(0xFF55D8B8),
            ),
          ),

          const SizedBox(height: 17),

          child,
        ],
      ),
    );
  }

  // --------------------------------------------------
  // NUMBER INPUT FIELD
  // --------------------------------------------------

  Widget _numberField(
    TextEditingController controller,
    String label,
    String suffix,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }

  // --------------------------------------------------
  // TIME FORMATTER
  // --------------------------------------------------

  String _time(String value) {
    final dateTime = DateTime.tryParse(value)?.toLocal();

    if (dateTime == null) {
      return value;
    }

    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // --------------------------------------------------
  // SNACKBAR
  // --------------------------------------------------

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}
