import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/themes/spo_theme.dart';
import '../../services/storage_service.dart';
import 'login_screen.dart';

class ServerConfigScreen extends StatefulWidget {
  const ServerConfigScreen({super.key});

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  final _urlController = TextEditingController();
  bool _useSSL = false;
  bool _isLoading = false;

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

  Future<void> _saveConfig() async {
    if (_urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server URL is required'),
          backgroundColor: SPOColors.conflictRed,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      String url = _urlController.text.trim();

      // Add protocol if missing
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = (_useSSL ? 'https://' : 'http://') + url;
      }

      await StorageService.saveServerConfig(url, _useSSL);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server configuration saved'),
            backgroundColor: SPOColors.accentGreen,
          ),
        );
        // Navigator.pop(context, true);
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: SPOColors.conflictRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  //
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LogoWithTitle(
        title: "Configuration",
        subText: "Configure your server connection",
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    hintText: "192.168.1.100 or api.spogroup.com",
                    labelText: 'Server URL / IP Address',
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    prefixIcon: Icon(
                      Icons.dns_outlined,
                    ),
                    filled: true,
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(50)),
                    ),
                  ),
                  keyboardType: TextInputType.url,
                  onSaved: (url) {},
                  onChanged: (value) {},
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Server URL / IP Address is required";
                    }
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text(
                    'Use HTTPS (SSL)',
                  ),
                  subtitle: Text(
                    'Disable for local 192.x.x.x networks',
                  ),
                  value: _useSSL,
                  activeColor: SPOColors.limeGreen,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() => _useSSL = val);
                  },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate() && !_isLoading) {
                      _saveConfig();
                    }
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text("Continue"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
