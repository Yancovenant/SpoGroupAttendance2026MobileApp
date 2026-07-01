import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/storage_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pengaturan & Keamanan")),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 32, 12, 64),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text("Server Configuration"),
                subtitle: const Text("Ubah URL Server dan SSL"),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingConfigScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingConfigScreen extends StatefulWidget {
  const SettingConfigScreen({super.key});

  @override
  State<SettingConfigScreen> createState() => _SettingConfigScreenState();
}

class _SettingConfigScreenState extends State<SettingConfigScreen> {
  final _urlController = TextEditingController();
  bool _useSSL = false;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _testResult;
  Color? _testResultColor;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadInitialValue();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialValue() async {
    final savedUrl = await StorageService.getServerUrl();
    final usedSSL = await StorageService.getUseSSL();
    setState(() {
      _urlController.text = savedUrl ?? '';
      _useSSL = usedSSL;
    });
  }

  String _buildBaseUrl() {
    String url = _urlController.text.trim();
    if (url.isEmpty) return '';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = (_useSSL ? 'https://' : 'http://') + url;
    }
    return url;
  }

  Future<void> _testConnection() async {
    if (_urlController.text.trim().isEmpty) {
      setState(() { _testResult = "URL tidak boleh kosong"; _testResultColor = Colors.red; });
      return;
    }

    setState(() { _isTesting = true; _testResult = null; });

    final baseUrl = _buildBaseUrl();
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)));

    try {
      final response = await dio.get(baseUrl);
      setState(() {
        _testResult = "✅ Berhasil terhubung! (Status: ${response.statusCode})";
        _testResultColor = Colors.green;
        _isTesting = false;
      });
    } on DioException catch (e) {
      if (e.response != null) {
        // Server is reachable, just returned 404/405 because it's not a specific API endpoint
        setState(() {
          _testResult = "✅ Server terjangkau! (Status: ${e.response!.statusCode})";
          _testResultColor = Colors.green;
          _isTesting = false;
        });
      } else {
        setState(() {
          _testResult = "❌ Gagal terhubung: ${e.message ?? 'Server offline / IP salah'}";
          _testResultColor = Colors.red;
          _isTesting = false;
        });
      }
    } catch (e) {
      setState(() { _testResult = "❌ Error: $e"; _testResultColor = Colors.red; _isTesting = false; });
    }
  }

  Future<void> _saveConfig() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      final url = _buildBaseUrl();
      await StorageService.saveServerConfig(url, _useSSL);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konfigurasi berhasil disimpan'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Konfigurasi Server")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: "Server URL / IP Address",
                  hintText: "192.168.1.100 atau api.spogroup.com",
                  prefixIcon: Icon(Icons.dns_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                validator: (value) => (value == null || value.isEmpty) ? "URL wajib diisi" : null,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Gunakan HTTPS (SSL)'),
                subtitle: const Text('Matikan untuk jaringan lokal 192.x.x.x'),
                value: _useSSL,
                onChanged: (val) => setState(() => _useSSL = val),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering),
                  label: Text(_isTesting ? "Mengecek..." : "Test Koneksi"),
                ),
              ),
              if (_testResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testResultColor!.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _testResultColor!),
                  ),
                  child: Text(_testResult!, style: TextStyle(color: _testResultColor, fontWeight: FontWeight.w500)),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton(
            onPressed: _isSaving ? null : _saveConfig,
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            child: const Text("Simpan Konfigurasi"),
          ),
        ),
      ),
    );
  }
}
