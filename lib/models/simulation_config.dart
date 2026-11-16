
class SimulationConfig {
  const SimulationConfig({
    this.channel = 1,
    this.periodMs = 1000,
    this.frequencyHz = 20,
    this.pulseWidthUs = 200,
    this.gapUs = 100,
  });

  final int channel;
  final int periodMs;
  final int frequencyHz;
  final int pulseWidthUs;
  final int gapUs;

  Map<String, Object?> toMap() {
    return {
      'channel': channel,
      'period_ms': periodMs,
      'frequency_hz': frequencyHz,
      'pulse_width_us': pulseWidthUs,
      'gap_us': gapUs,
    };
  }
}
