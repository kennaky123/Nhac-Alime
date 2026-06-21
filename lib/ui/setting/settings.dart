import 'package:flutter/material.dart';
import '../now_playing/audio_player_manager.dart';
import '../../main.dart';
import '../user/login.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _isDarkMode = themeNotifier.value == ThemeMode.dark;

  String _formatDuration(Duration? duration) {
    if (duration == null) return "Tắt";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  void _showSleepTimerDialog() {
    final TextEditingController hourController = TextEditingController();
    final TextEditingController minuteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text('Hẹn giờ tắt nhạc', 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ListTile(
                  title: const Text('Tắt'), 
                  onTap: () => _setTimer(null, "Tắt"),
                  trailing: AudioPlayerManager().sleepTimerRemainingNotifier.value == null 
                    ? const Icon(Icons.check, color: Colors.blue) : null,
                ),
                ListTile(
                  title: const Text('Sau 1 phút'), 
                  onTap: () => _setTimer(const Duration(minutes: 1), "1 phút"),
                ),
                ListTile(
                  title: const Text('Sau 30 phút'), 
                  onTap: () => _setTimer(const Duration(minutes: 30), "30 phút"),
                ),
                ListTile(
                  title: const Text('Sau 60 phút'), 
                  onTap: () => _setTimer(const Duration(minutes: 60), "60 phút"),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Tùy chỉnh thời gian', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hourController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: 'Giờ',
                          hintText: '0',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: minuteController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: 'Phút',
                          hintText: '0',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        final hours = int.tryParse(hourController.text) ?? 0;
                        final minutes = int.tryParse(minuteController.text) ?? 0;
                        if (hours > 0 || minutes > 0) {
                          final duration = Duration(hours: hours, minutes: minutes);
                          String label = "";
                          if (hours > 0) label += "$hours giờ ";
                          if (minutes > 0) label += "$minutes phút";
                          _setTimer(duration, label.trim());
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text('OK'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setTimer(Duration? duration, String label) {
    AudioPlayerManager().setSleepTimer(duration);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(duration == null ? 'Đã tắt hẹn giờ' : 'Đã hẹn giờ tắt: $label'))
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn thoát không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Thoát', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt', style: TextStyle(fontWeight: FontWeight.bold)), 
        centerTitle: true
      ),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: Icon(
              _isDarkMode ? Icons.dark_mode : Icons.light_mode, 
              color: _isDarkMode ? Colors.orange : Colors.blue
            ),
            title: const Text('Chế độ tối'),
            value: _isDarkMode,
            onChanged: (bool value) {
              setState(() => _isDarkMode = value);
              themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          const Divider(),
          ValueListenableBuilder<Duration?>(
            valueListenable: AudioPlayerManager().sleepTimerRemainingNotifier,
            builder: (context, remaining, child) {
              return ListTile(
                leading: const Icon(Icons.timer_outlined, color: Colors.green),
                title: const Text('Hẹn giờ tắt nhạc'),
                trailing: Text(
                  _formatDuration(remaining), 
                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)
                ),
                onTap: _showSleepTimerDialog,
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Đăng xuất', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
