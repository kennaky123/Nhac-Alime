import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../now_playing/audio_player_manager.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  late AndroidEqualizer _equalizer;
  bool _isEnabled = false;
  List<AndroidEqualizerBand>? _bands;

  @override
  void initState() {
    super.initState();
    _equalizer = AudioPlayerManager().equalizer;
    _initEqualizer();
  }

  Future<void> _initEqualizer() async {
    try {
      // Kích hoạt pipeline trước khi truy cập thông số
      await AudioPlayerManager().enableEqualizerSupport();

      final enabled = _equalizer.enabled;
      final parameters = await _equalizer.parameters;
      final bands = parameters.bands;
      
      if (!mounted) return;
      setState(() {
        _isEnabled = enabled;
        _bands = bands;
      });
    } catch (e) {
      debugPrint("❌ Lỗi khởi tạo Equalizer: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thiết bị này không hỗ trợ bộ lọc âm thanh hệ thống.'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Switch(
            value: _isEnabled,
            onChanged: (value) async {
              await _equalizer.setEnabled(value);
              if (mounted) {
                setState(() {
                  _isEnabled = value;
                });
              }
            },
            activeColor: colorScheme.primary,
          ),
        ],
      ),
      body: _bands == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                // +1 cho phần ghi chú ở cuối danh sách
                itemCount: _bands!.length + 1,
                itemBuilder: (context, index) {
                  // Nếu là item cuối cùng thì hiển thị box ghi chú
                  if (index == _bands!.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 32, bottom: 120), // Padding dưới cực lớn để vượt qua BottomBar
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Lưu ý: Hiệu ứng Equalizer sử dụng công nghệ xử lý âm thanh Android gốc, đảm bảo tính ổn định và tương thích cao.',
                                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final band = _bands![index];
                  final freq = band.centerFrequency;
                  final freqText = freq >= 1000 ? '${(freq / 1000).toStringAsFixed(1)} kHz' : '$freq Hz';
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(freqText, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${band.gain.toStringAsFixed(1)} dB', style: TextStyle(color: colorScheme.primary)),
                          ],
                        ),
                        Slider(
                          min: -15, 
                          max: 15,
                          value: band.gain.clamp(-15.0, 15.0),
                          activeColor: colorScheme.primary,
                          inactiveColor: colorScheme.primary.withOpacity(0.2),
                          onChanged: _isEnabled ? (value) async {
                            await band.setGain(value);
                            if (mounted) {
                              setState(() {
                                // Trigger rebuild to update text
                              });
                            }
                          } : null,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
