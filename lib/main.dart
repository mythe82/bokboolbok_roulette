import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ✅ 추가: Localization 지원
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  AdHelper.loadInterstitialAd();
  final playerProvider = PlayerProvider();
  await playerProvider.loadFromPrefs();
  runApp(
    ChangeNotifierProvider(
      create: (_) => playerProvider,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        // locale: const Locale('en'), // ← 여기에 강제로 영어 설정

        // ✅ Localization 추가
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('ko'),
        ],

        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xFFF7FDFC),
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.teal,
            accentColor: Colors.orangeAccent,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 81, 146, 231),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color.fromARGB(255, 0, 102, 255),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.teal),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0.5,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        home: const MainScreen(),
      ),
    ),
  );
}
// ✅ AdHelper
class AdHelper {
  static InterstitialAd? _interstitialAd;
  static bool _isAdLoaded = false;

  static bool isAdReady() => _isAdLoaded;

  static void loadInterstitialAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;

    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial ad failed to load: $error');
          _isAdLoaded = false;
        },
      ),
    );
  }

  static void showInterstitialAd(VoidCallback onAdClosedAfterDelay) {
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          _isAdLoaded = false;
          loadInterstitialAd();
          Future.delayed(const Duration(seconds: 3), onAdClosedAfterDelay);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
          _isAdLoaded = false;
          loadInterstitialAd();
          onAdClosedAfterDelay();
        },
      );
      _interstitialAd!.show();
      _isAdLoaded = false;
    } else {
      onAdClosedAfterDelay();
    }
  }
}

// ✅ MyBannerAd
class MyBannerAd extends StatefulWidget {
  const MyBannerAd({super.key});

  @override
  State<MyBannerAd> createState() => _MyBannerAdState();
}

class _MyBannerAdState extends State<MyBannerAd> {
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() {}),
        onAdFailedToLoad: (ad, error) {
          print('Ad failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bannerAd == null) return const SizedBox.shrink();
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

// ✅ Player, PlayerProvider
class Player {
  final String name;
  Player(this.name);
}

class PlayerProvider with ChangeNotifier {
  final List<Player> _players = [];
  Map<String, int> _history = {};

  List<Player> get players => _players;
  Map<String, int> get history => _history;

  void addPlayer(String name) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty &&
        !_players.any((p) => p.name.toLowerCase() == trimmed.toLowerCase())) {
      _players.add(Player(trimmed));
      _saveToPrefs();
      notifyListeners();
    }
  }

  void removePlayer(int index) {
    _players.removeAt(index);
    _saveToPrefs();
    notifyListeners();
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList('players') ?? [];
    _players.clear();
    _players.addAll(names.map((e) => Player(e)));
    await loadHistory();
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('players', _players.map((e) => e.name).toList());
  }

  Future<void> addHistory(String name) async {
    _history[name] = (_history[name] ?? 0) + 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('history', _encodeHistory());
    notifyListeners();
  }

  String _encodeHistory() {
    return _history.entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  Map<String, int> _decodeHistory(String encoded) {
    final Map<String, int> map = {};
    for (final pair in encoded.split('|')) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        map[parts[0]] = int.tryParse(parts[1]) ?? 0;
      }
    }
    return map;
  }

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('history');
    _history = encoded != null ? _decodeHistory(encoded) : {};
  }

  Future<void> clearHistory() async {
    _history.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('history');
    notifyListeners();
  }
}
// ✅ MainScreen
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const ParticipantsPage(),
    const RoulettePage(),
    const HistoryPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color.fromARGB(255, 81, 146, 231),
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.group),
            label: AppLocalizations.of(context)!.participants,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.casino),
            label: AppLocalizations.of(context)!.roulette,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: AppLocalizations.of(context)!.history,
          ),
        ],
      ),
    );
  }
}

// ✅ ParticipantsPage
class ParticipantsPage extends StatefulWidget {
  const ParticipantsPage({super.key});

  @override
  State<ParticipantsPage> createState() => _ParticipantsPageState();
}

class _ParticipantsPageState extends State<ParticipantsPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final players = provider.players;

    return Scaffold(
      appBar: AppBar(
        title: Text("👥 ${AppLocalizations.of(context)!.participants}"),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    onSubmitted: (value) {
                      provider.addPlayer(value);
                      _controller.clear();
                    },
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.enterParticipantName,
                      hintText: AppLocalizations.of(context)!.exampleName,
                      prefixIcon: const Icon(Icons.person_add_alt),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () {
                          provider.addPlayer(_controller.text);
                          _controller.clear();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: players.isEmpty
                        ? Center(child: Text(AppLocalizations.of(context)!.noParticipants))
                        : ListView.builder(
                            itemCount: players.length,
                            itemBuilder: (context, index) {
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.teal.shade100,
                                    child: Text(
                                      players[index].name.characters.first,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(players[index].name),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Color.fromARGB(255, 245, 56, 43)),
                                    onPressed: () =>
                                        provider.removePlayer(index),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const MyBannerAd(),
        ],
      ),
    );
  }
}
class RoulettePage extends StatefulWidget {
  const RoulettePage({super.key});

  @override
  State<RoulettePage> createState() => _RoulettePageState();
}

class _RoulettePageState extends State<RoulettePage> {
  final StreamController<int> _selected = StreamController<int>.broadcast();
  late ConfettiController _confettiController;
  final Random _random = Random();
  List<int> selectedIndexes = [];
  List<int> confirmedIndexes = [];
  int? resultIndex;
  bool _isSpinning = false;
  int spinCount = 1;
  List<Player> players = [];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _selected.close();
    _confettiController.dispose();
    super.dispose();
  }

  void _startSpinning(List<Player> p) {
    if (_isSpinning || p.length < 2) return;

    setState(() {
      _isSpinning = true;
      players = p;
      selectedIndexes.clear();
      confirmedIndexes.clear();
    });

    AdHelper.showInterstitialAd(() {
      if (spinCount == 1) {
        resultIndex = 0;
        _selected.add(resultIndex!);
        Future.delayed(const Duration(milliseconds: 300), _spinNext);
      } else {
        _spinNext();
      }
    });
  }

  void _spinNext() {
    final available = List.generate(players.length, (i) => i)
        .where((i) => !selectedIndexes.contains(i))
        .toList();

    if (selectedIndexes.length >= spinCount || available.isEmpty) {
      setState(() => _isSpinning = false);
      return;
    }

    resultIndex = available[_random.nextInt(available.length)];
    _selected.add(resultIndex!);
  }

  void _resetGame() {
    setState(() {
      resultIndex = null;
      selectedIndexes.clear();
      confirmedIndexes.clear();
      _isSpinning = false;
    });
  }

  String _ordinal(int n) {
    const units = [
      '첫번째', '두번째', '세번째', '네번째', '다섯번째',
      '여섯번째', '일곱번째', '여덟번째', '아홉번째', '열번째'
    ];
    return n <= units.length ? units[n - 1] : '$n번째';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        final p = provider.players;

        if (p.length > 1 && spinCount >= p.length) {
          spinCount = p.length - 1;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text("🎯 ${AppLocalizations.of(context)!.roulette}"),
          ),
          body: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  const SizedBox(height: 8),

                  /// 당첨자 수 + 돌리기 버튼
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${AppLocalizations.of(context)!.winner}:'),
                      const SizedBox(width: 8),
                      Opacity(
                        opacity: _isSpinning ? 0.5 : 1.0,
                        child: IgnorePointer(
                          ignoring: _isSpinning,
                          child: DropdownButton<int>(
                            value: spinCount,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  spinCount = value;
                                  _resetGame();
                                });
                              }
                            },
                            items: List.generate(
                              p.length <= 1 ? 1 : p.length - 1,
                              (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text('${i + 1}${AppLocalizations.of(context)!.personUnit}'),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!_isSpinning && AdHelper.isAdReady() && p.length >= 2)
                        ElevatedButton.icon(
                          onPressed: () {
                            _resetGame();
                            _startSpinning(p);
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: Text(AppLocalizations.of(context)!.spinRoulette),
                        ),
                      if (_isSpinning)
                        const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: CircularProgressIndicator(strokeWidth: 3),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  /// 룰렛
                  AspectRatio(
                    aspectRatio: 1, // 정사각형 유지
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.grey.shade300,
                              Colors.white,
                            ],
                            center: Alignment.topLeft,
                            radius: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              offset: const Offset(0, 8),
                              blurRadius: 12,
                            ),
                            BoxShadow(
                              color: Colors.tealAccent.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: p.length < 2
                            ? Center(
                                child: Text(AppLocalizations.of(context)!.noParticipants),
                              )
                            : FortuneWheel(
                                selected: _selected.stream,
                                animateFirst: false,
                                indicators: const [
                                  FortuneIndicator(
                                    alignment: Alignment.topCenter,
                                    child: TriangleIndicator(
                                      color: Colors.redAccent,
                                      width: 24,
                                      height: 24,
                                    ),
                                  ),
                                ],
                                physics: CircularPanPhysics(
                                  duration: const Duration(seconds: 2),
                                  curve: Curves.easeOutCubic,
                                ),
                                items: p.asMap().entries.map((e) {
                                  final pastelColors = [
                                    Colors.amber.shade100,
                                    Colors.cyan.shade100,
                                    Colors.pink.shade100,
                                    Colors.lime.shade100,
                                    Colors.indigo.shade100,
                                    Colors.deepOrange.shade100,
                                    Colors.green.shade100,
                                    Colors.purple.shade100,
                                    Colors.blue.shade100,
                                    Colors.teal.shade100,
                                  ];
                                  final borderColors = [
                                    Colors.amber.shade400,
                                    Colors.cyan.shade400,
                                    Colors.pink.shade400,
                                    Colors.lime.shade400,
                                    Colors.indigo.shade400,
                                    Colors.deepOrange.shade400,
                                    Colors.green.shade400,
                                    Colors.purple.shade400,
                                    Colors.blue.shade400,
                                    Colors.teal.shade400,
                                  ];
                                  return FortuneItem(
                                    child: Transform.scale(
                                      scale: 1.2,
                                      child: Text(
                                        e.value.name,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    style: FortuneItemStyle(
                                      color: pastelColors[e.key % pastelColors.length],
                                      borderColor: borderColors[e.key % borderColors.length],
                                      borderWidth: 3,
                                    ),
                                  );
                                }).toList(),
                                onAnimationEnd: () {
                                  if (resultIndex == null || resultIndex! >= p.length) return;

                                  final confirmedIndex = resultIndex!;
                                  final name = p[confirmedIndex].name;

                                  provider.addHistory(name);

                                  setState(() {
                                    selectedIndexes.add(confirmedIndex);
                                    confirmedIndexes.add(confirmedIndex);
                                  });

                                  if (confirmedIndexes.length == spinCount) {
                                    _confettiController.play();
                                  }

                                  Future.delayed(const Duration(milliseconds: 800), _spinNext);
                                },
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// 당첨자 리스트
                  Expanded(
                    child: confirmedIndexes.isNotEmpty
                        ? ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: confirmedIndexes.length,
                            itemBuilder: (context, index) {
                              final name = p[confirmedIndexes[index]].name;
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.emoji_events,
                                    color: Colors.orange.shade800,
                                  ),
                                  title: Text('${_ordinal(index + 1)} 당첨자: $name'),
                                ),
                              );
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),

              // 🎊 축하 이펙트
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                emissionFrequency: 0.05,
                numberOfParticles: 30,
                maxBlastForce: 20,
                minBlastForce: 5,
                gravity: 0.3,
              ),
            ],
          ),
        );
      },
    );
  }
}
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final entries = provider.history.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // 내림차순 정렬

    return Scaffold(
      appBar: AppBar(
        title: Text("📜 ${AppLocalizations.of(context)!.history}"),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context)!.noHistory,
                        style: const TextStyle(fontSize: 16),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            itemCount: entries.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final e = entries[index];
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.teal.shade100,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    e.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  trailing: Text(
                                    '${e.value}${AppLocalizations.of(context)!.times}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(AppLocalizations.of(context)!.resetHistory),
                                content: Text(AppLocalizations.of(context)!.confirmResetHistory),
                                actions: [
                                  TextButton(
                                    child: Text(AppLocalizations.of(context)!.cancel),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  TextButton(
                                    child: Text(AppLocalizations.of(context)!.reset),
                                    onPressed: () {
                                      provider.clearHistory();
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.delete_forever),
                          label: Text(AppLocalizations.of(context)!.resetHistory),
                        ),
                      ],
                    ),
            ),
          ),
          const MyBannerAd(), // 하단 배너
        ],
      ),
    );
  }
}
