// import 'package:flutter/material.dart';
// import '../core/themes/spo_theme.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// class ServerSettingsScreen extends StatefulWidget {
//   const ServerSettingsScreen({super.key});
//
//   @override
//   State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
// }
//
// class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
//   final _urlController = TextEditingController(text: "192.168.1.100");
//   bool _useSSL = false;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Server Configuration"), backgroundColor: Colors.transparent),
//       backgroundColor: const Color(0xFF0A1F0D),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             LiquidGlass.card(
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   children: [
//                     TextField(
//                       controller: _urlController,
//                       style: const TextStyle(color: Colors.white),
//                       decoration: InputDecoration(
//                         labelText: "Server IP / Domain",
//                         labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
//                         enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: SPOColors.accentGreen)),
//                       ),
//                     ),
//                     const SizedBox(height: 20),
//                     SwitchListTile(
//                       title: const Text("Use SSL (HTTPS)", style: TextStyle(color: Colors.white)),
//                       subtitle: const Text("Disable for local 192.x.x.x networks", style: TextStyle(color: Colors.white54, fontSize: 12)),
//                       value: _useSSL,
//                       activeColor: SPOColors.limeGreen,
//                       onChanged: (val) => setState(() => _useSSL = val),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: 30),
//             ElevatedButton(
//               onPressed: () async {
//                 final prefs = await SharedPreferences.getInstance();
//                 final protocol = _useSSL ? "https://" : "http://";
//                 await prefs.setString('server_url', protocol + _urlController.text);
//                 if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Server URL Updated & Saved Locally")));
//               },
//               child: const Text("Save Configuration"),
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }