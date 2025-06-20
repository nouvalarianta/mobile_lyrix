import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _offlineMode = false;
  bool _dataSaver = false;
  bool _autoPlay = true;
  bool _showNotifications = true;
  String _audioQuality = 'High';
  String _downloadQuality = 'Medium';
  bool _equalizerEnabled = false;
  bool _normalizationEnabled = true;

  final List<String> _audioQualityOptions = [
    'Low',
    'Medium',
    'High',
    'Very High'
  ];

  final List<Map<String, String>> _languageOptions = [
    {'code': 'id', 'name': 'Bahasa Indonesia'},
    {'code': 'en', 'name': 'English'},
    {'code': 'ja', 'name': 'Japanese'},
    {'code': 'ko', 'name': 'Korean'},
  ];
  String _selectedLanguage = 'id';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Tampilan'),
          _buildLanguageSelector(),
          const Divider(),
          _buildSectionHeader('Pemutaran'),
          SwitchListTile(
            title: const Text('Putar Otomatis'),
            subtitle:
                const Text('Putar lagu secara otomatis saat aplikasi dibuka'),
            value: _autoPlay,
            onChanged: (value) {
              setState(() {
                _autoPlay = value;
              });
            },
            activeColor: AppTheme.primaryColor,
          ),
          ListTile(
            title: const Text('Kualitas Audio'),
            subtitle: Text('Kualitas audio saat streaming: $_audioQuality'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showQualitySelector(true);
            },
          ),
          ListTile(
            title: const Text('Kualitas Unduhan'),
            subtitle: Text('Kualitas audio saat mengunduh: $_downloadQuality'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showQualitySelector(false);
            },
          ),
          SwitchListTile(
            title: const Text('Equalizer'),
            subtitle: const Text('Aktifkan equalizer untuk menyesuaikan audio'),
            value: _equalizerEnabled,
            onChanged: (value) {
              setState(() {
                _equalizerEnabled = value;
              });
              if (value) {
                _showEqualizerDialog();
              }
            },
            activeColor: AppTheme.primaryColor,
          ),
          SwitchListTile(
            title: const Text('Normalisasi Volume'),
            subtitle:
                const Text('Sesuaikan volume semua lagu ke level yang sama'),
            value: _normalizationEnabled,
            onChanged: (value) {
              setState(() {
                _normalizationEnabled = value;
              });
            },
            activeColor: AppTheme.primaryColor,
          ),
          const Divider(),
          _buildSectionHeader('Data'),
          SwitchListTile(
            title: const Text('Mode Offline'),
            subtitle: const Text('Putar hanya musik yang diunduh'),
            value: _offlineMode,
            onChanged: (value) {
              setState(() {
                _offlineMode = value;
              });
            },
            activeColor: AppTheme.primaryColor,
          ),
          SwitchListTile(
            title: const Text('Penghemat Data'),
            subtitle: const Text('Kurangi penggunaan data saat streaming'),
            value: _dataSaver,
            onChanged: (value) {
              setState(() {
                _dataSaver = value;

                if (value && _audioQuality == 'High') {
                  _audioQuality = 'Medium';
                }
              });
            },
            activeColor: AppTheme.primaryColor,
          ),
          ListTile(
            title: const Text('Hapus Cache'),
            subtitle: const Text('Hapus file sementara untuk menghemat ruang'),
            trailing: const Icon(Icons.cleaning_services_outlined),
            onTap: () {
              _showClearCacheDialog();
            },
          ),
          const Divider(),
          _buildSectionHeader('Notifikasi'),
          SwitchListTile(
            title: const Text('Notifikasi'),
            subtitle: const Text('Tampilkan notifikasi dari aplikasi'),
            value: _showNotifications,
            onChanged: (value) {
              setState(() {
                _showNotifications = value;
              });
            },
            activeColor: AppTheme.primaryColor,
          ),
          ListTile(
            title: const Text('Jenis Notifikasi'),
            subtitle: const Text('Pilih notifikasi yang ingin diterima'),
            trailing: const Icon(Icons.chevron_right),
            enabled: _showNotifications,
            onTap: _showNotifications
                ? () {
                    _showNotificationTypesDialog();
                  }
                : null,
          ),
          const Divider(),
          _buildSectionHeader('Akun'),
          ListTile(
            title: const Text('Kelola Langganan'),
            subtitle: const Text('Lihat dan ubah paket langganan Anda'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Privasi'),
            subtitle: const Text('Kelola pengaturan privasi dan data Anda'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          _buildSectionHeader('Tentang'),
          ListTile(
            title: const Text('Versi Aplikasi'),
            subtitle: const Text('1.0.0 (Build 100)'),
          ),
          ListTile(
            title: const Text('Syarat dan Ketentuan'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Kebijakan Privasi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Bantuan'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: OutlinedButton(
              onPressed: () {
                _showLogoutConfirmationDialog();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Keluar'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return ListTile(
      title: const Text('Bahasa'),
      subtitle: Text(_languageOptions
          .firstWhere((lang) => lang['code'] == _selectedLanguage)['name']!),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        _showLanguageDialog();
      },
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Pilih Bahasa'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _languageOptions.length,
            itemBuilder: (context, index) {
              final language = _languageOptions[index];
              return RadioListTile<String>(
                title: Text(language['name']!),
                value: language['code']!,
                groupValue: _selectedLanguage,
                onChanged: (value) {
                  setState(() {
                    _selectedLanguage = value!;
                  });
                  Navigator.pop(context);
                },
                activeColor: AppTheme.primaryColor,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  void _showQualitySelector(bool isStreaming) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(isStreaming ? 'Kualitas Audio' : 'Kualitas Unduhan'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _audioQualityOptions.length,
            itemBuilder: (context, index) {
              final quality = _audioQualityOptions[index];
              return RadioListTile<String>(
                title: Text(quality),
                subtitle: _getQualityDescription(quality),
                value: quality,
                groupValue: isStreaming ? _audioQuality : _downloadQuality,
                onChanged: (value) {
                  setState(() {
                    if (isStreaming) {
                      _audioQuality = value!;

                      if (_dataSaver && _audioQuality == 'High') {
                        _showDataSaverWarning();
                      }
                    } else {
                      _downloadQuality = value!;
                    }
                  });
                  Navigator.pop(context);
                },
                activeColor: AppTheme.primaryColor,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }

  Widget? _getQualityDescription(String quality) {
    switch (quality) {
      case 'Low':
        return const Text('32 kbps - Hemat data (~15MB/jam)');
      case 'Medium':
        return const Text('96 kbps - Seimbang (~40MB/jam)');
      case 'High':
        return const Text('160 kbps - Kualitas baik (~70MB/jam)');
      case 'Very High':
        return const Text('320 kbps - Kualitas terbaik (~150MB/jam)');
      default:
        return null;
    }
  }

  void _showDataSaverWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Penghemat Data Aktif'),
        content: const Text(
            'Penghemat data sedang aktif. Menggunakan kualitas audio tinggi akan meningkatkan penggunaan data. Apakah Anda ingin menonaktifkan penghemat data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _dataSaver = false;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Ya, Nonaktifkan'),
          ),
        ],
      ),
    );
  }

  void _showEqualizerDialog() {
    final List<double> bands = [3.0, 5.0, 7.0, 4.0, 2.0, 6.0, 8.0, 5.0];
    final List<String> frequencies = [
      '60Hz',
      '150Hz',
      '400Hz',
      '1kHz',
      '2.4kHz',
      '6kHz',
      '15kHz',
      '20kHz'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            title: const Text('Equalizer'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: Column(
                children: [
                  const Text(
                      'Sesuaikan frekuensi untuk pengalaman mendengarkan yang lebih baik'),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(bands.length, (index) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: Slider(
                                  value: bands[index],
                                  min: 0,
                                  max: 10,
                                  divisions: 20,
                                  activeColor: AppTheme.primaryColor,
                                  onChanged: (value) {
                                    setState(() {
                                      bands[index] = value;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              frequencies[index],
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    for (int i = 0; i < bands.length; i++) {
                      bands[i] = 5.0;
                    }
                  });
                },
                child: const Text('Reset'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pengaturan equalizer disimpan'),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Hapus Cache'),
        content: const Text(
            'Ini akan menghapus semua file cache aplikasi. Lagu yang diunduh tidak akan terpengaruh. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              _showClearingCacheDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showClearingCacheDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text('Menghapus cache...'),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache berhasil dihapus (15.2 MB)'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    });
  }

  void _showNotificationTypesDialog() {
    final Map<String, bool> notificationTypes = {
      'Pembaruan Artis': true,
      'Rilis Baru': true,
      'Rekomendasi Mingguan': true,
      'Aktivitas Teman': false,
      'Penawaran Khusus': false,
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            title: const Text('Jenis Notifikasi'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: notificationTypes.length,
                itemBuilder: (context, index) {
                  final type = notificationTypes.keys.elementAt(index);
                  return SwitchListTile(
                    title: Text(type),
                    value: notificationTypes[type]!,
                    onChanged: (value) {
                      setState(() {
                        notificationTypes[type] = value;
                      });
                    },
                    activeColor: AppTheme.primaryColor,
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pengaturan notifikasi disimpan'),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun Anda?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Anda telah keluar dari akun'),
                  backgroundColor: AppTheme.surfaceColor,
                ),
              );

              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}
