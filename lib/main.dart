import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/game/audio_service.dart';
import 'src/game/game_controller.dart';
import 'src/game/wallet.dart';
import 'src/ui/app_theme.dart';
import 'src/ui/slot_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A slot machine is a portrait cabinet, and the reels are laid out for it.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.feltDeep,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const SlotGameApp());
}

class SlotGameApp extends StatefulWidget {
  const SlotGameApp({super.key});

  @override
  State<SlotGameApp> createState() => _SlotGameAppState();
}

class _SlotGameAppState extends State<SlotGameApp> {
  late final GameController _game = GameController(wallet: PreferencesWallet());
  late final AudioService _audio = PlayerAudioService();

  @override
  void initState() {
    super.initState();
    // Both are best effort: the machine is playable before either resolves, and
    // stays playable if audio is unavailable entirely.
    _game.load();
    _audio.load();
  }

  @override
  void dispose() {
    _game.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lucky Five',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: Scaffold(
        body: SlotScreen(game: _game, audio: _audio),
      ),
    );
  }
}
