import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NgrNeoApp());
}

class NgrNeoApp extends StatelessWidget {
  const NgrNeoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NGR Neo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: NeoColors.bg,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: NeoColors.cyan,
          secondary: NeoColors.blue,
          surface: NeoColors.card,
        ),
      ),
      home: const NeoRoot(),
    );
  }
}

class NeoColors {
  static const bg = Color(0xFF05070D);
  static const bg2 = Color(0xFF08121A);
  static const card = Color(0x1FFFFFFF);
  static const cardStrong = Color(0x33FFFFFF);
  static const border = Color(0x26FFFFFF);
  static const white = Color(0xFFEFF4FF);
  static const muted = Color(0xFF8C95A6);
  static const dim = Color(0xFF5F6878);
  static const cyan = Color(0xFF5DE6F2);
  static const blue = Color(0xFF70A6FF);
  static const green = Color(0xFF39E27D);
  static const red = Color(0xFFFF6B8A);
  static const yellow = Color(0xFFFFD56B);
  static const purple = Color(0xFFA48BFF);
}

class AppData {
  double virtualKm;
  double fuelLiters;
  double fuelPrice;
  double kmPerLiter;
  double moneyBudget;
  List<Map<String, dynamic>> kmLogs;
  List<Map<String, dynamic>> fuelLogs;
  List<Map<String, dynamic>> moneyLogs;
  List<Map<String, dynamic>> problems;
  List<Map<String, dynamic>> routes;
  Map<String, dynamic> serviceDoneKm;
  Map<String, dynamic> serviceDoneDate;

  AppData({
    required this.virtualKm,
    required this.fuelLiters,
    required this.fuelPrice,
    required this.kmPerLiter,
    required this.moneyBudget,
    required this.kmLogs,
    required this.fuelLogs,
    required this.moneyLogs,
    required this.problems,
    required this.routes,
    required this.serviceDoneKm,
    required this.serviceDoneDate,
  });

  factory AppData.fresh() {
    final now = DateTime.now().toIso8601String();
    return AppData(
      virtualKm: 0,
      fuelLiters: 0,
      fuelPrice: 10000,
      kmPerLiter: 55,
      moneyBudget: 250000,
      kmLogs: [],
      fuelLogs: [],
      moneyLogs: [],
      problems: [],
      routes: [],
      serviceDoneKm: {
        'oli_mesin': 0.0,
        'oli_gardan': 0.0,
        'busi': 0.0,
        'cvt': 0.0,
      },
      serviceDoneDate: {
        'oli_mesin': now,
        'oli_gardan': now,
        'busi': now,
        'cvt': now,
      },
    );
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      virtualKm: _toDouble(json['virtualKm'], 0),
      fuelLiters: _toDouble(json['fuelLiters'], 0),
      fuelPrice: _toDouble(json['fuelPrice'], 10000),
      kmPerLiter: _toDouble(json['kmPerLiter'], 55),
      moneyBudget: _toDouble(json['moneyBudget'], 250000),
      kmLogs: _listMap(json['kmLogs']),
      fuelLogs: _listMap(json['fuelLogs']),
      moneyLogs: _listMap(json['moneyLogs']),
      problems: _listMap(json['problems']),
      routes: _listMap(json['routes']),
      serviceDoneKm: Map<String, dynamic>.from(json['serviceDoneKm'] ?? AppData.fresh().serviceDoneKm),
      serviceDoneDate: Map<String, dynamic>.from(json['serviceDoneDate'] ?? AppData.fresh().serviceDoneDate),
    );
  }

  Map<String, dynamic> toJson() => {
        'virtualKm': virtualKm,
        'fuelLiters': fuelLiters,
        'fuelPrice': fuelPrice,
        'kmPerLiter': kmPerLiter,
        'moneyBudget': moneyBudget,
        'kmLogs': kmLogs,
        'fuelLogs': fuelLogs,
        'moneyLogs': moneyLogs,
        'problems': problems,
        'routes': routes,
        'serviceDoneKm': serviceDoneKm,
        'serviceDoneDate': serviceDoneDate,
      };

  static double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static List<Map<String, dynamic>> _listMap(dynamic value) {
    if (value is List) {
      return value.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return [];
  }
}

class ServiceSpec {
  final String id;
  final String name;
  final IconData icon;
  final double intervalKm;
  final int intervalDays;
  final String note;

  const ServiceSpec(this.id, this.name, this.icon, this.intervalKm, this.intervalDays, this.note);
}

const serviceSpecs = [
  ServiceSpec('oli_mesin', 'Oli Mesin', CupertinoIcons.drop_fill, 2000, 60, 'Paling penting buat mesin.'),
  ServiceSpec('oli_gardan', 'Oli Gardan', CupertinoIcons.gear_alt_fill, 8000, 180, 'Buat area gardan matic.'),
  ServiceSpec('busi', 'Busi', CupertinoIcons.bolt_fill, 8000, 180, 'Cek kalau susah starter/brebet.'),
  ServiceSpec('cvt', 'CVT', CupertinoIcons.circle_grid_hex_fill, 8000, 180, 'Cek kalau tarikan berat/getar.'),
];

class NeoRoot extends StatefulWidget {
  const NeoRoot({super.key});

  @override
  State<NeoRoot> createState() => _NeoRootState();
}

class _NeoRootState extends State<NeoRoot> {
  int index = 0;
  AppData data = AppData.fresh();
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('ngr_neo_data');
    if (raw != null) {
      try {
        data = AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        data = AppData.fresh();
      }
    }
    setState(() => loaded = true);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ngr_neo_data', jsonEncode(data.toJson()));
  }

  void _mutate(void Function() run) {
    setState(run);
    _save();
  }

  String _todayKey([DateTime? dt]) {
    final d = dt ?? DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool get inputToday => data.kmLogs.any((e) => e['dateKey'] == _todayKey());

  int get streak {
    final keys = data.kmLogs.map((e) => '${e['dateKey']}').toSet();
    var count = 0;
    var cursor = DateTime.now();
    if (!keys.contains(_todayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (keys.contains(_todayKey(cursor))) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  double servicePercent(ServiceSpec spec) {
    final doneKm = AppData._toDouble(data.serviceDoneKm[spec.id], 0);
    final kmUsed = math.max(0, data.virtualKm - doneKm);
    final kmRemainPct = 1 - (kmUsed / spec.intervalKm);
    final rawDate = data.serviceDoneDate[spec.id]?.toString();
    final doneDate = DateTime.tryParse(rawDate ?? '') ?? DateTime.now();
    final daysUsed = DateTime.now().difference(doneDate).inDays;
    final dayRemainPct = 1 - (daysUsed / spec.intervalDays);
    final pct = math.min(kmRemainPct, dayRemainPct) * 100;
    return pct.clamp(0, 100).toDouble();
  }

  int get health {
    final avg = serviceSpecs.map(servicePercent).fold<double>(0, (a, b) => a + b) / serviceSpecs.length;
    return avg.round().clamp(0, 100);
  }

  double monthMoney({String? category}) {
    final now = DateTime.now();
    return data.moneyLogs.where((e) {
      final dt = DateTime.tryParse('${e['time']}');
      final sameMonth = dt != null && dt.month == now.month && dt.year == now.year;
      final catOk = category == null || e['category'] == category;
      return sameMonth && catOk;
    }).fold<double>(0, (sum, e) => sum + AppData._toDouble(e['amount'], 0));
  }

  void addKm(double km, {String source = 'Daily KM', String note = ''}) {
    final now = DateTime.now();
    final fuelUsed = km <= 0 ? 0 : km / math.max(1, data.kmPerLiter);
    _mutate(() {
      data.virtualKm += km;
      data.fuelLiters = math.max(0, data.fuelLiters - fuelUsed);
      data.kmLogs.insert(0, {
        'time': now.toIso8601String(),
        'dateKey': _todayKey(now),
        'km': km,
        'source': source,
        'note': note,
        'fuelUsed': fuelUsed,
      });
    });
    showNeoSnack(context, km == 0 ? 'Hari ini ditandai libur motor.' : '+${fmt(km)} km masuk. Fuel turun estimasi ${fmt(fuelUsed)} L.');
  }

  void addFuel(double liters, {String name = 'Pertalite'}) {
    final now = DateTime.now();
    final cost = liters * data.fuelPrice;
    _mutate(() {
      data.fuelLiters += liters;
      data.fuelLogs.insert(0, {
        'time': now.toIso8601String(),
        'liters': liters,
        'name': name,
        'price': data.fuelPrice,
        'cost': cost,
      });
      data.moneyLogs.insert(0, {
        'time': now.toIso8601String(),
        'category': 'Fuel',
        'amount': cost,
        'note': '$name ${fmt(liters)} L',
      });
    });
    showNeoSnack(context, '$name ${fmt(liters)} L masuk. Range +${fmt(liters * data.kmPerLiter)} km.');
  }

  void addMoney(String category, double amount, String note) {
    _mutate(() {
      data.moneyLogs.insert(0, {
        'time': DateTime.now().toIso8601String(),
        'category': category,
        'amount': amount,
        'note': note,
      });
    });
    showNeoSnack(context, 'Expense $category Rp${rupiah(amount)} dicatat.');
  }

  void addProblem(String title, String level, String note) {
    _mutate(() {
      data.problems.insert(0, {
        'time': DateTime.now().toIso8601String(),
        'title': title,
        'level': level,
        'note': note,
        'status': 'Dipantau',
      });
    });
    showNeoSnack(context, 'Problem dicatat buat Kang Rusdi.');
  }

  void markServiceDone(ServiceSpec spec) {
    _mutate(() {
      data.serviceDoneKm[spec.id] = data.virtualKm;
      data.serviceDoneDate[spec.id] = DateTime.now().toIso8601String();
      data.moneyLogs.insert(0, {
        'time': DateTime.now().toIso8601String(),
        'category': 'Service',
        'amount': 0,
        'note': '${spec.name} selesai',
      });
    });
    showNeoSnack(context, '${spec.name} direset ke 100%.');
  }

  String rusdiScan() {
    final nearest = [...serviceSpecs]..sort((a, b) => servicePercent(a).compareTo(servicePercent(b)));
    final fuelRange = data.fuelLiters * data.kmPerLiter;
    final money = monthMoney();
    final buffer = StringBuffer();
    if (!inputToday) buffer.write('Hari ini belum input KM. ');
    if (fuelRange < 20) buffer.write('Bensin mepet, isi dulu kalau mau jauh. ');
    buffer.write('Service paling dekat: ${nearest.first.name} ${servicePercent(nearest.first).round()}%. ');
    if (money > data.moneyBudget * 0.8) {
      buffer.write('Money bulan ini udah tinggi, tahan modif dulu.');
    } else {
      buffer.write('Money bulan ini masih relatif aman.');
    }
    return buffer.toString();
  }

  void openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettingsSheet(
        data: data,
        onUpdate: (next) => _mutate(() => data = next),
      ),
    );
  }

  void openQuickAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickAddSheet(
        addKm: addKm,
        addFuel: addFuel,
        addMoney: addMoney,
        addProblem: addProblem,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    }

    final pages = [
      HomePage(
        data: data,
        health: health,
        streak: streak,
        inputToday: inputToday,
        servicePercent: servicePercent,
        monthMoney: monthMoney,
        addKm: addKm,
        addFuel: addFuel,
        addMoney: addMoney,
        markServiceDone: markServiceDone,
        openSettings: openSettings,
        rusdiScan: rusdiScan,
      ),
      MapsPage(
        data: data,
        addKm: addKm,
        saveRoute: (route) => _mutate(() => data.routes.insert(0, route)),
        rusdiScan: rusdiScan,
      ),
      FuelPage(data: data, addFuel: addFuel),
      MoneyPage(data: data, addMoney: addMoney, monthMoney: monthMoney),
      AssistPage(data: data, addProblem: addProblem, rusdiScan: rusdiScan),
    ];

    return Scaffold(
      body: NeoBackground(
        child: Stack(
          children: [
            SafeArea(bottom: false, child: pages[index]),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: LiquidNavBar(
                index: index,
                onTap: (i) => setState(() => index = i),
              ),
            ),
            Positioned(
              right: 20,
              bottom: 108,
              child: GestureDetector(
                onTap: openQuickAdd,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [NeoColors.blue, NeoColors.cyan]),
                    boxShadow: [BoxShadow(color: NeoColors.cyan.withOpacity(.28), blurRadius: 32, offset: const Offset(0, 12))],
                  ),
                  child: const Icon(CupertinoIcons.add, size: 36, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NeoBackground extends StatelessWidget {
  final Widget child;
  const NeoBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF05070D), Color(0xFF06111A), Color(0xFF03050A)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -120, left: -80, child: _Blob(color: NeoColors.blue.withOpacity(.18), size: 260)),
          Positioned(top: 180, right: -100, child: _Blob(color: NeoColors.cyan.withOpacity(.12), size: 260)),
          Positioned(bottom: 120, left: -120, child: _Blob(color: NeoColors.purple.withOpacity(.10), size: 280)),
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 90, spreadRadius: 30)],
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(.075),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(.10)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 30, offset: const Offset(0, 16))],
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

class PageFrame extends StatelessWidget {
  final Widget child;
  const PageFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 126),
      physics: const BouncingScrollPhysics(),
      child: child,
    );
  }
}

class NeoHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onSettings;
  const NeoHeader({super.key, required this.title, required this.subtitle, this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset('assets/ngr_icon.png', width: 54, height: 54),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.2)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 14, color: NeoColors.muted, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        if (onSettings != null)
          GlassCard(
            padding: EdgeInsets.zero,
            radius: 26,
            onTap: onSettings,
            child: const SizedBox(width: 58, height: 58, child: Icon(CupertinoIcons.gear_alt, size: 25)),
          ),
      ],
    );
  }
}

class HomePage extends StatelessWidget {
  final AppData data;
  final int health;
  final int streak;
  final bool inputToday;
  final double Function(ServiceSpec) servicePercent;
  final double Function({String? category}) monthMoney;
  final void Function(double, {String source, String note}) addKm;
  final void Function(double, {String name}) addFuel;
  final void Function(String, double, String) addMoney;
  final void Function(ServiceSpec) markServiceDone;
  final VoidCallback openSettings;
  final String Function() rusdiScan;

  const HomePage({
    super.key,
    required this.data,
    required this.health,
    required this.streak,
    required this.inputToday,
    required this.servicePercent,
    required this.monthMoney,
    required this.addKm,
    required this.addFuel,
    required this.addMoney,
    required this.markServiceDone,
    required this.openSettings,
    required this.rusdiScan,
  });

  @override
  Widget build(BuildContext context) {
    final range = data.fuelLiters * data.kmPerLiter;
    final sorted = [...serviceSpecs]..sort((a, b) => servicePercent(a).compareTo(servicePercent(b)));
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NeoHeader(title: 'NGR Neo', subtitle: 'Liquid Garage OS · Beat FI 2014', onSettings: openSettings),
          const SizedBox(height: 22),
          GlassCard(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                HealthRing(percent: health),
                const SizedBox(width: 18),
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      StatPill(title: 'Virtual KM', value: '${fmt(data.virtualKm)} km'),
                      StatPill(title: 'Fuel Range', value: '${fmt(range)} km'),
                      StatPill(title: 'Streak', value: '$streak hari'),
                      StatPill(title: 'Money', value: 'Rp${rupiah(monthMoney())}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          DailyKmCard(addKm: addKm, inputToday: inputToday, data: data),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: QuickTile(icon: CupertinoIcons.add, title: 'KM', onTap: () => askKm(context, addKm))),
              const SizedBox(width: 10),
              Expanded(child: QuickTile(icon: CupertinoIcons.drop_fill, title: 'Fuel', onTap: () => askFuel(context, addFuel))),
              const SizedBox(width: 10),
              Expanded(child: QuickTile(icon: CupertinoIcons.wrench_fill, title: 'Service', onTap: () => markServiceDone(sorted.first))),
              const SizedBox(width: 10),
              Expanded(child: QuickTile(icon: CupertinoIcons.creditcard_fill, title: 'Money', onTap: () => askMoney(context, addMoney))),
            ],
          ),
          const SizedBox(height: 24),
          SectionTitle('Service Priority', right: 'terdekat'),
          const SizedBox(height: 12),
          ...sorted.take(4).map((spec) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ServiceCompactCard(spec: spec, percent: servicePercent(spec), onDone: () => markServiceDone(spec)),
              )),
          const SizedBox(height: 18),
          SectionTitle('Kang Rusdi Scan', right: 'ringkas'),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rusdiScan(), style: const TextStyle(fontSize: 16, height: 1.45, color: NeoColors.white)),
                const SizedBox(height: 18),
                NeoButton(label: 'Buka NGR Assist', icon: CupertinoIcons.sparkles, onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HealthRing extends StatelessWidget {
  final int percent;
  const HealthRing({super.key, required this.percent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 126,
      height: 126,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 126,
            height: 126,
            child: CircularProgressIndicator(
              value: percent / 100,
              strokeWidth: 13,
              strokeCap: StrokeCap.round,
              color: percent > 55 ? NeoColors.green : percent > 25 ? NeoColors.yellow : NeoColors.red,
              backgroundColor: Colors.white.withOpacity(.08),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$percent%', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
              const Text('Health', style: TextStyle(color: NeoColors.muted, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  final String title;
  final String value;
  const StatPill({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -.4)),
        const SizedBox(height: 5),
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 1.6, color: NeoColors.muted, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class DailyKmCard extends StatelessWidget {
  final void Function(double, {String source, String note}) addKm;
  final bool inputToday;
  final AppData data;
  const DailyKmCard({super.key, required this.addKm, required this.inputToday, required this.data});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      color: const Color(0x1A3AA4FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Daily KM', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.4))),
              StatusPill(text: inputToday ? 'Sudah input' : 'Belum input', ok: inputToday),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Input harian biar streak gak putus. GPS dibuang.', style: TextStyle(color: NeoColors.muted, fontSize: 15, height: 1.35)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ChipButton(label: '0 km', onTap: () => addKm(0, note: 'Libur motor'))),
              const SizedBox(width: 9),
              Expanded(child: ChipButton(label: '+5', onTap: () => addKm(5))),
              const SizedBox(width: 9),
              Expanded(child: ChipButton(label: '+10', onTap: () => addKm(10))),
              const SizedBox(width: 9),
              Expanded(child: ChipButton(label: '+15', onTap: () => addKm(15))),
              const SizedBox(width: 9),
              Expanded(child: ChipButton(label: 'Custom', onTap: () => askKm(context, addKm))),
            ],
          ),
          const SizedBox(height: 16),
          StreakCalendar(logs: data.kmLogs),
        ],
      ),
    );
  }
}

class StreakCalendar extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  const StreakCalendar({super.key, required this.logs});

  String keyOf(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final keys = logs.map((e) => '${e['dateKey']}').toSet();
    final today = DateTime.now();
    final days = List.generate(14, (i) => today.subtract(Duration(days: 13 - i)));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: days.map((d) {
        final active = keys.contains(keyOf(d));
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 44,
          height: 54,
          decoration: BoxDecoration(
            color: active ? NeoColors.green.withOpacity(.20) : Colors.white.withOpacity(.055),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? NeoColors.green.withOpacity(.45) : Colors.white.withOpacity(.08)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(dayName(d.weekday), style: TextStyle(fontSize: 11, color: active ? NeoColors.green : NeoColors.dim, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${d.day}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ]),
        );
      }).toList(),
    );
  }
}

class QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const QuickTile({super.key, required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      radius: 24,
      child: Column(children: [
        Icon(icon, size: 27, color: NeoColors.white),
        const SizedBox(height: 10),
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class ServiceCompactCard extends StatelessWidget {
  final ServiceSpec spec;
  final double percent;
  final VoidCallback onDone;
  const ServiceCompactCard({super.key, required this.spec, required this.percent, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final color = percent > 55 ? NeoColors.green : percent > 25 ? NeoColors.yellow : NeoColors.red;
    return GlassCard(
      onTap: onDone,
      padding: const EdgeInsets.all(16),
      radius: 24,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: Colors.white.withOpacity(.07), borderRadius: BorderRadius.circular(18)),
            child: Icon(spec.icon, color: color, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(spec.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('${spec.note} · ${spec.intervalKm.round()} km / ${spec.intervalDays} hari', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: NeoColors.muted, height: 1.25)),
            ]),
          ),
          const SizedBox(width: 10),
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(.9)),
            child: Text('${percent.round()}%', style: const TextStyle(color: Color(0xFF03100A), fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class MapsPage extends StatefulWidget {
  final AppData data;
  final void Function(double, {String source, String note}) addKm;
  final void Function(Map<String, dynamic>) saveRoute;
  final String Function() rusdiScan;
  const MapsPage({super.key, required this.data, required this.addKm, required this.saveRoute, required this.rusdiScan});

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  final start = TextEditingController(text: 'Rumah');
  final end = TextEditingController(text: 'Sekolah');
  final km = TextEditingController();

  @override
  void dispose() {
    start.dispose();
    end.dispose();
    km.dispose();
    super.dispose();
  }

  double get distance => double.tryParse(km.text.replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final fuel = distance / math.max(1, widget.data.kmPerLiter);
    final cost = fuel * widget.data.fuelPrice;
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NeoHeader(title: 'Maps', subtitle: 'Route planner tanpa GPS live'),
          const SizedBox(height: 18),
          GlassCard(
            padding: EdgeInsets.zero,
            radius: 32,
            child: SizedBox(
              height: 380,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Stack(
                  children: [
                    const Positioned.fill(child: _NeoMapPreview()),
                    Positioned(
                      left: 18,
                      top: 18,
                      child: StatusPill(text: 'Map engine slot', ok: true),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 18,
                      child: GlassCard(
                        radius: 24,
                        padding: const EdgeInsets.all(16),
                        child: const Text(
                          'Phase ini fokus Flutter UI dulu. MapLibre/MapTiler tinggal masuk di slot ini setelah core stabil, biar gak blank kayak versi web.',
                          style: TextStyle(color: NeoColors.white, height: 1.35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Route Input', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                NeoField(controller: start, label: 'Start'),
                const SizedBox(height: 10),
                NeoField(controller: end, label: 'Tujuan'),
                const SizedBox(height: 10),
                NeoField(controller: km, label: 'Jarak ikut jalan (km)', keyboard: TextInputType.number, onChanged: (_) => setState(() {})),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: StatPill(title: 'Est. Fuel', value: '${fmt(fuel)} L')),
                  const SizedBox(width: 10),
                  Expanded(child: StatPill(title: 'Est. Cost', value: 'Rp${rupiah(cost)}')),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: NeoButton(
                      label: 'Simpan Rute',
                      icon: CupertinoIcons.bookmark,
                      onTap: distance <= 0
                          ? null
                          : () {
                              widget.saveRoute({
                                'time': DateTime.now().toIso8601String(),
                                'start': start.text,
                                'end': end.text,
                                'km': distance,
                              });
                              showNeoSnack(context, 'Rute disimpan.');
                            },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: NeoButton(
                      label: 'Tambah ke KM',
                      icon: CupertinoIcons.plus_circle,
                      onTap: distance <= 0 ? null : () => widget.addKm(distance, source: 'Route', note: '${start.text} → ${end.text}'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionTitle('Rute Favorit', right: '${widget.data.routes.length} item'),
          const SizedBox(height: 12),
          if (widget.data.routes.isEmpty)
            const EmptyCard(text: 'Belum ada rute favorit. Simpan rute harian kayak Rumah → Sekolah di sini.'),
          ...widget.data.routes.take(5).map((route) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(CupertinoIcons.map, color: NeoColors.blue),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${route['start']} → ${route['end']}', style: const TextStyle(fontWeight: FontWeight.w800))),
                    Text('${fmt(AppData._toDouble(route['km'], 0))} km', style: const TextStyle(color: NeoColors.muted, fontWeight: FontWeight.w800)),
                  ]),
                ),
              )),
          const SizedBox(height: 18),
          GlassCard(
            child: Text('Rusdi Route Scan: ${widget.rusdiScan()}', style: const TextStyle(height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _NeoMapPreview extends StatelessWidget {
  const _NeoMapPreview();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MapPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..shader = const LinearGradient(colors: [Color(0xFF07101B), Color(0xFF0A1A23)]).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);
    final road = Paint()
      ..color = Colors.white.withOpacity(.08)
      ..strokeWidth = 2;
    for (var i = 0.0; i < size.width; i += 42) {
      canvas.drawLine(Offset(i, 0), Offset(i + 80, size.height), road);
    }
    for (var y = 0.0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 40), road);
    }
    final path = Path()
      ..moveTo(size.width * .16, size.height * .72)
      ..cubicTo(size.width * .26, size.height * .50, size.width * .45, size.height * .74, size.width * .54, size.height * .46)
      ..cubicTo(size.width * .62, size.height * .22, size.width * .76, size.height * .36, size.width * .86, size.height * .18);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 15
      ..color = NeoColors.cyan.withOpacity(.15);
    canvas.drawPath(path, glow);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..shader = const LinearGradient(colors: [NeoColors.blue, NeoColors.cyan]).createShader(Offset.zero & size);
    canvas.drawPath(path, line);
    final dotPaint = Paint()..color = NeoColors.green;
    canvas.drawCircle(Offset(size.width * .16, size.height * .72), 8, dotPaint);
    dotPaint.color = NeoColors.red;
    canvas.drawCircle(Offset(size.width * .86, size.height * .18), 8, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FuelPage extends StatelessWidget {
  final AppData data;
  final void Function(double, {String name}) addFuel;
  const FuelPage({super.key, required this.data, required this.addFuel});

  @override
  Widget build(BuildContext context) {
    final range = data.fuelLiters * data.kmPerLiter;
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NeoHeader(title: 'Fuel', subtitle: 'Bensin, range, dan riwayat'),
          const SizedBox(height: 18),
          GlassCard(
            color: NeoColors.green.withOpacity(.08),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Fuel Balance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: BigNumber(value: '${fmt(data.fuelLiters)} L', label: 'sisa bensin')),
                Expanded(child: BigNumber(value: '${fmt(range)} km', label: 'estimasi range')),
              ]),
              const SizedBox(height: 18),
              Wrap(spacing: 9, runSpacing: 9, children: [
                ChipAction('Pertalite 1L', () => addFuel(1, name: 'Pertalite')),
                ChipAction('Pertalite 2L', () => addFuel(2, name: 'Pertalite')),
                ChipAction('Pertamax 1L', () => addFuel(1, name: 'Pertamax')),
                ChipAction('Custom', () => askFuel(context, addFuel)),
              ]),
            ]),
          ),
          const SizedBox(height: 18),
          SectionTitle('Fuel Chart', right: 'naik/turun'),
          const SizedBox(height: 12),
          GlassCard(child: FuelMiniChart(logs: data.fuelLogs)),
          const SizedBox(height: 18),
          SectionTitle('History', right: '${data.fuelLogs.length} log'),
          const SizedBox(height: 12),
          if (data.fuelLogs.isEmpty) const EmptyCard(text: 'Belum ada isi BBM.'),
          ...data.fuelLogs.take(8).map((e) => LogTile(
                icon: CupertinoIcons.drop_fill,
                title: '${e['name']} ${fmt(AppData._toDouble(e['liters'], 0))} L',
                subtitle: formatDate('${e['time']}'),
                trailing: 'Rp${rupiah(AppData._toDouble(e['cost'], 0))}',
              )),
        ],
      ),
    );
  }
}

class FuelMiniChart extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  const FuelMiniChart({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 150, child: CustomPaint(painter: _ChartPainter(logs)));
  }
}

class _ChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> logs;
  _ChartPainter(this.logs);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withOpacity(.07)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (logs.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(text: 'Chart muncul setelah isi BBM.', style: TextStyle(color: NeoColors.muted, fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }
    final points = logs.reversed.take(12).toList();
    final maxLiters = points.map((e) => AppData._toDouble(e['liters'], 0)).fold<double>(1, math.max);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1 ? size.width / 2 : size.width * i / (points.length - 1);
      final value = AppData._toDouble(points[i]['liters'], 0);
      final y = size.height - (value / maxLiters * size.height * .75) - 10;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4
      ..shader = const LinearGradient(colors: [NeoColors.green, NeoColors.cyan]).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => oldDelegate.logs != logs;
}

class MoneyPage extends StatelessWidget {
  final AppData data;
  final void Function(String, double, String) addMoney;
  final double Function({String? category}) monthMoney;
  const MoneyPage({super.key, required this.data, required this.addMoney, required this.monthMoney});

  @override
  Widget build(BuildContext context) {
    final total = monthMoney();
    final pct = (total / math.max(1, data.moneyBudget)).clamp(0, 1).toDouble();
    return PageFrame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const NeoHeader(title: 'Money', subtitle: 'Expense, budget, celengan'),
        const SizedBox(height: 18),
        GlassCard(
          color: NeoColors.purple.withOpacity(.07),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bulan Ini', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text('Rp${rupiah(total)}', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1.4)),
            const SizedBox(height: 6),
            Text('Budget Rp${rupiah(data.moneyBudget)} · ${(pct * 100).round()}%', style: const TextStyle(color: NeoColors.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: pct, minHeight: 10, color: pct > .85 ? NeoColors.red : NeoColors.cyan, backgroundColor: Colors.white.withOpacity(.08)),
            ),
            const SizedBox(height: 18),
            NeoButton(label: 'Tambah Expense', icon: CupertinoIcons.plus, onTap: () => askMoney(context, addMoney)),
          ]),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: CategoryCard(title: 'Fuel', value: monthMoney(category: 'Fuel'), icon: CupertinoIcons.drop_fill)),
          const SizedBox(width: 10),
          Expanded(child: CategoryCard(title: 'Service', value: monthMoney(category: 'Service'), icon: CupertinoIcons.wrench_fill)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: CategoryCard(title: 'Modif', value: monthMoney(category: 'Modif'), icon: CupertinoIcons.sparkles)),
          const SizedBox(width: 10),
          Expanded(child: CategoryCard(title: 'Tools', value: monthMoney(category: 'Tools'), icon: CupertinoIcons.hammer_fill)),
        ]),
        const SizedBox(height: 18),
        SectionTitle('Riwayat', right: '${data.moneyLogs.length} log'),
        const SizedBox(height: 12),
        if (data.moneyLogs.isEmpty) const EmptyCard(text: 'Belum ada expense.'),
        ...data.moneyLogs.take(10).map((e) => LogTile(
              icon: CupertinoIcons.creditcard_fill,
              title: '${e['category']} · ${e['note'] ?? ''}',
              subtitle: formatDate('${e['time']}'),
              trailing: 'Rp${rupiah(AppData._toDouble(e['amount'], 0))}',
            )),
      ]),
    );
  }
}

class AssistPage extends StatelessWidget {
  final AppData data;
  final void Function(String, String, String) addProblem;
  final String Function() rusdiScan;
  const AssistPage({super.key, required this.data, required this.addProblem, required this.rusdiScan});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const NeoHeader(title: 'NGR Assist', subtitle: 'Kang Rusdi, FI, emergency'),
        const SizedBox(height: 18),
        GlassCard(
          color: NeoColors.blue.withOpacity(.08),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(CupertinoIcons.sparkles, color: NeoColors.cyan),
              SizedBox(width: 10),
              Text('Kang Rusdi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 12),
            Text(rusdiScan(), style: const TextStyle(fontSize: 16, height: 1.45)),
            const SizedBox(height: 14),
            const Text('AI online bisa disambung nanti. Phase ini Rusdi pakai rule lokal dulu biar ringan.', style: TextStyle(color: NeoColors.muted, height: 1.35)),
          ]),
        ),
        const SizedBox(height: 18),
        SectionTitle('Emergency Road Assist', right: 'cepat'),
        const SizedBox(height: 12),
        GuideCard(
          icon: CupertinoIcons.exclamationmark_triangle_fill,
          title: 'Motor mati di jalan',
          steps: const ['Pinggirkan motor dulu.', 'Cek bensin dan indikator FI.', 'Cek starter/aki/sekring.', 'Kalau ada alat, cek busi.', 'Jangan paksa kalau bunyi kasar.'],
          onLog: () => askProblem(context, addProblem, preset: 'Motor mati di jalan'),
        ),
        GuideCard(
          icon: CupertinoIcons.bolt_fill,
          title: 'Busi lemah / mati',
          steps: const ['Gejala: susah starter, brebet, langsam gak stabil.', 'Cek cop busi rapat.', 'Kalau basah/hitam parah, bersihkan/ganti.', 'Kalau mogok total, bawa busi cadangan.'],
          onLog: () => askProblem(context, addProblem, preset: 'Curiga busi'),
        ),
        GuideCard(
          icon: CupertinoIcons.battery_25,
          title: 'Aki / starter lemah',
          steps: const ['Lampu redup atau starter cetek-cetek.', 'Cek terminal aki kendor/korosi.', 'Pakai kick starter kalau ada.', 'Kalau sering drop, cek kiprok/aki.'],
          onLog: () => askProblem(context, addProblem, preset: 'Aki/starter lemah'),
        ),
        GuideCard(
          icon: CupertinoIcons.dot_radiowaves_left_right,
          title: 'FI Code Helper',
          steps: const ['Kedipan panjang = puluhan.', 'Kedipan pendek = satuan.', 'Contoh 1 panjang + 2 pendek = 12.', 'Catat kode, jangan asal bongkar sensor.'],
          onLog: () => askProblem(context, addProblem, preset: 'FI kedip'),
        ),
        const SizedBox(height: 18),
        SectionTitle('Problem Diary', right: '${data.problems.length} log'),
        const SizedBox(height: 12),
        NeoButton(label: 'Catat Problem', icon: CupertinoIcons.plus, onTap: () => askProblem(context, addProblem)),
        const SizedBox(height: 12),
        if (data.problems.isEmpty) const EmptyCard(text: 'Belum ada problem. Kalau ada gejala aneh, catat biar gak lupa.'),
        ...data.problems.take(8).map((e) => LogTile(
              icon: CupertinoIcons.doc_text,
              title: '${e['title']} · ${e['level']}',
              subtitle: '${e['note'] ?? ''}\n${formatDate('${e['time']}')}',
              trailing: '${e['status']}',
            )),
      ]),
    );
  }
}

class LiquidNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const LiquidNavBar({super.key, required this.index, required this.onTap});

  static const items = [
    _NavItem(CupertinoIcons.house, 'Home'),
    _NavItem(CupertinoIcons.map, 'Maps'),
    _NavItem(CupertinoIcons.drop, 'Fuel'),
    _NavItem(CupertinoIcons.creditcard, 'Money'),
    _NavItem(CupertinoIcons.sparkles, 'Assist'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          height: 84,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xCC111720),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: Colors.white.withOpacity(.12)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.45), blurRadius: 30, offset: const Offset(0, 18))],
          ),
          child: Row(
            children: List.generate(items.length, (i) {
              final active = i == index;
              final item = items[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: active ? NeoColors.blue.withOpacity(.24) : Colors.transparent,
                      borderRadius: BorderRadius.circular(26),
                      border: active ? Border.all(color: NeoColors.blue.withOpacity(.32)) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon, color: active ? NeoColors.white : NeoColors.muted, size: 24),
                        const SizedBox(height: 5),
                        Text(item.label, style: TextStyle(fontSize: 12, color: active ? NeoColors.white : NeoColors.muted, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? right;
  const SectionTitle(this.title, {super.key, this.right});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.5))),
      if (right != null) Text(right!, style: const TextStyle(color: NeoColors.muted, fontWeight: FontWeight.w800)),
    ]);
  }
}

class StatusPill extends StatelessWidget {
  final String text;
  final bool ok;
  const StatusPill({super.key, required this.text, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (ok ? NeoColors.green : NeoColors.red).withOpacity(.15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: (ok ? NeoColors.green : NeoColors.red).withOpacity(.24)),
      ),
      child: Text(text, style: TextStyle(color: ok ? NeoColors.green : NeoColors.red, fontWeight: FontWeight.w900)),
    );
  }
}

class ChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const ChipButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.075),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withOpacity(.10)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class ChipAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const ChipAction(this.label, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white.withOpacity(.10))),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class NeoButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const NeoButton({super.key, required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: enabled ? const LinearGradient(colors: [Color(0xFF356DFF), Color(0xFF53E4F1)]) : null,
            color: enabled ? null : Colors.white.withOpacity(.08),
            borderRadius: BorderRadius.circular(20),
            boxShadow: enabled ? [BoxShadow(color: NeoColors.cyan.withOpacity(.16), blurRadius: 22, offset: const Offset(0, 10))] : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))),
          ]),
        ),
      ),
    );
  }
}

class NeoField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboard;
  final ValueChanged<String>? onChanged;
  const NeoField({super.key, required this.controller, required this.label, this.keyboard, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      onChanged: onChanged,
      style: const TextStyle(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: NeoColors.muted),
        filled: true,
        fillColor: Colors.white.withOpacity(.065),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.white.withOpacity(.10))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: NeoColors.cyan)),
      ),
    );
  }
}

class BigNumber extends StatelessWidget {
  final String value;
  final String label;
  const BigNumber({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
      const SizedBox(height: 4),
      Text(label.toUpperCase(), style: const TextStyle(color: NeoColors.muted, fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 11)),
    ]);
  }
}

class CategoryCard extends StatelessWidget {
  final String title;
  final double value;
  final IconData icon;
  const CategoryCard({super.key, required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: NeoColors.cyan),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('Rp${rupiah(value)}', style: const TextStyle(color: NeoColors.muted, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class GuideCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> steps;
  final VoidCallback onLog;
  const GuideCard({super.key, required this.icon, required this.title, required this.steps, required this.onLog});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: NeoColors.yellow),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 10),
          ...steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('• ', style: TextStyle(color: NeoColors.cyan, fontWeight: FontWeight.w900)),
                  Expanded(child: Text(s, style: const TextStyle(color: NeoColors.muted, height: 1.28))),
                ]),
              )),
          const SizedBox(height: 10),
          ChipAction('Catat Problem', onLog),
        ]),
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  final String text;
  const EmptyCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return GlassCard(child: Text(text, style: const TextStyle(color: NeoColors.muted, height: 1.35)));
  }
}

class LogTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  const LogTile({super.key, required this.icon, required this.title, required this.subtitle, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        radius: 22,
        child: Row(children: [
          Icon(icon, color: NeoColors.cyan),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: NeoColors.muted, height: 1.25)),
          ])),
          const SizedBox(width: 10),
          Text(trailing, style: const TextStyle(fontWeight: FontWeight.w900, color: NeoColors.white)),
        ]),
      ),
    );
  }
}

class SettingsSheet extends StatefulWidget {
  final AppData data;
  final ValueChanged<AppData> onUpdate;
  const SettingsSheet({super.key, required this.data, required this.onUpdate});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late final TextEditingController fuelPrice;
  late final TextEditingController kmPerLiter;
  late final TextEditingController budget;

  @override
  void initState() {
    super.initState();
    fuelPrice = TextEditingController(text: widget.data.fuelPrice.round().toString());
    kmPerLiter = TextEditingController(text: fmt(widget.data.kmPerLiter));
    budget = TextEditingController(text: widget.data.moneyBudget.round().toString());
  }

  @override
  void dispose() {
    fuelPrice.dispose();
    kmPerLiter.dispose();
    budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NeoSheet(
      title: 'Settings',
      child: Column(children: [
        NeoField(controller: fuelPrice, label: 'Harga BBM per liter', keyboard: TextInputType.number),
        const SizedBox(height: 10),
        NeoField(controller: kmPerLiter, label: 'Estimasi km/L', keyboard: TextInputType.number),
        const SizedBox(height: 10),
        NeoField(controller: budget, label: 'Budget motor bulanan', keyboard: TextInputType.number),
        const SizedBox(height: 16),
        NeoButton(
          label: 'Simpan Settings',
          icon: CupertinoIcons.check_mark,
          onTap: () {
            final next = AppData.fromJson(widget.data.toJson());
            next.fuelPrice = double.tryParse(fuelPrice.text) ?? widget.data.fuelPrice;
            next.kmPerLiter = double.tryParse(kmPerLiter.text.replaceAll(',', '.')) ?? widget.data.kmPerLiter;
            next.moneyBudget = double.tryParse(budget.text) ?? widget.data.moneyBudget;
            widget.onUpdate(next);
            Navigator.pop(context);
          },
        ),
        const SizedBox(height: 10),
        NeoButton(
          label: 'Copy Backup JSON',
          icon: CupertinoIcons.doc_on_doc,
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: jsonEncode(widget.data.toJson())));
            if (context.mounted) showNeoSnack(context, 'Backup JSON dicopy.');
          },
        ),
        const SizedBox(height: 10),
        NeoButton(
          label: 'Import JSON',
          icon: CupertinoIcons.arrow_down_doc,
          onTap: () => askImport(context, widget.onUpdate),
        ),
      ]),
    );
  }
}

class QuickAddSheet extends StatelessWidget {
  final void Function(double, {String source, String note}) addKm;
  final void Function(double, {String name}) addFuel;
  final void Function(String, double, String) addMoney;
  final void Function(String, String, String) addProblem;
  const QuickAddSheet({super.key, required this.addKm, required this.addFuel, required this.addMoney, required this.addProblem});

  @override
  Widget build(BuildContext context) {
    return NeoSheet(
      title: 'Quick Add',
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.65,
        children: [
          QuickTile(icon: CupertinoIcons.add, title: 'KM', onTap: () => askKm(context, addKm)),
          QuickTile(icon: CupertinoIcons.drop_fill, title: 'Fuel', onTap: () => askFuel(context, addFuel)),
          QuickTile(icon: CupertinoIcons.creditcard_fill, title: 'Money', onTap: () => askMoney(context, addMoney)),
          QuickTile(icon: CupertinoIcons.doc_text, title: 'Problem', onTap: () => askProblem(context, addProblem)),
        ],
      ),
    );
  }
}

class NeoSheet extends StatelessWidget {
  final String title;
  final Widget child;
  const NeoSheet({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 12, right: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            decoration: BoxDecoration(
              color: const Color(0xEE111720),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(.12)),
            ),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.white.withOpacity(.25), borderRadius: BorderRadius.circular(99)))),
                const SizedBox(height: 16),
                Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                child,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

void askKm(BuildContext context, void Function(double, {String source, String note}) addKm) {
  final c = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NeoSheet(
      title: 'Tambah KM',
      child: Column(children: [
        NeoField(controller: c, label: 'KM hari ini', keyboard: TextInputType.number),
        const SizedBox(height: 14),
        NeoButton(
          label: 'Simpan KM',
          icon: CupertinoIcons.check_mark,
          onTap: () {
            final km = double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
            addKm(km);
            Navigator.pop(context);
          },
        ),
      ]),
    ),
  );
}

void askFuel(BuildContext context, void Function(double, {String name}) addFuel) {
  final c = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NeoSheet(
      title: 'Isi BBM',
      child: Column(children: [
        NeoField(controller: c, label: 'Liter', keyboard: TextInputType.number),
        const SizedBox(height: 14),
        NeoButton(
          label: 'Simpan Fuel',
          icon: CupertinoIcons.drop_fill,
          onTap: () {
            final liters = double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
            if (liters > 0) addFuel(liters, name: 'Custom Fuel');
            Navigator.pop(context);
          },
        ),
      ]),
    ),
  );
}

void askMoney(BuildContext context, void Function(String, double, String) addMoney) {
  final amount = TextEditingController();
  final note = TextEditingController();
  var category = 'Service';
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => NeoSheet(
        title: 'Tambah Expense',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, children: ['Service', 'Fuel', 'Modif', 'Tools', 'Other'].map((cat) {
            return ChipAction(category == cat ? '✓ $cat' : cat, () => setState(() => category = cat));
          }).toList()),
          const SizedBox(height: 12),
          NeoField(controller: amount, label: 'Nominal', keyboard: TextInputType.number),
          const SizedBox(height: 10),
          NeoField(controller: note, label: 'Catatan'),
          const SizedBox(height: 14),
          NeoButton(
            label: 'Simpan Expense',
            icon: CupertinoIcons.check_mark,
            onTap: () {
              final value = double.tryParse(amount.text) ?? 0;
              if (value > 0) addMoney(category, value, note.text.trim().isEmpty ? category : note.text.trim());
              Navigator.pop(context);
            },
          ),
        ]),
      ),
    ),
  );
}

void askProblem(BuildContext context, void Function(String, String, String) addProblem, {String preset = ''}) {
  final title = TextEditingController(text: preset);
  final note = TextEditingController();
  var level = 'Ringan';
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => NeoSheet(
        title: 'Catat Problem',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NeoField(controller: title, label: 'Gejala'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: ['Ringan', 'Sedang', 'Bahaya'].map((l) => ChipAction(level == l ? '✓ $l' : l, () => setState(() => level = l))).toList()),
          const SizedBox(height: 10),
          NeoField(controller: note, label: 'Catatan'),
          const SizedBox(height: 14),
          NeoButton(
            label: 'Simpan Problem',
            icon: CupertinoIcons.check_mark,
            onTap: () {
              if (title.text.trim().isNotEmpty) addProblem(title.text.trim(), level, note.text.trim());
              Navigator.pop(context);
            },
          ),
        ]),
      ),
    ),
  );
}

void askImport(BuildContext context, ValueChanged<AppData> onUpdate) {
  final c = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NeoSheet(
      title: 'Import JSON',
      child: Column(children: [
        NeoField(controller: c, label: 'Paste backup JSON'),
        const SizedBox(height: 14),
        NeoButton(
          label: 'Import',
          icon: CupertinoIcons.arrow_down_doc,
          onTap: () {
            try {
              onUpdate(AppData.fromJson(jsonDecode(c.text) as Map<String, dynamic>));
              Navigator.pop(context);
              showNeoSnack(context, 'Import berhasil.');
            } catch (_) {
              showNeoSnack(context, 'JSON salah / rusak.');
            }
          },
        ),
      ]),
    ),
  );
}

void showNeoSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xEE111720),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

String fmt(double v) {
  if (v.abs() >= 100) return v.toStringAsFixed(0);
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}

String rupiah(double v) {
  final s = v.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final left = s.length - i;
    buffer.write(s[i]);
    if (left > 1 && left % 3 == 1) buffer.write('.');
  }
  return buffer.toString();
}

String dayName(int weekday) {
  const names = ['', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  return names[weekday];
}

String formatDate(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '-';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
