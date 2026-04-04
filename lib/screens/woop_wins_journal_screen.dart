// lib/screens/woop_wins_journal_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/manifestation_repository.dart';

abstract class _Tokens {
  static const Color ink = Color(0xFF0A0A0F);
  static const Color surfaceElevated = Color(0xFF1C1C28);
  static const Color border = Color(0xFF2A2A38);
  static const Color borderSubtle = Color(0xFF1E1E2A);

  static const Color primary = Color(0xFFE8D5B7);
  static const Color accent = Color(0xFFC9A96E);

  static const Color textPrimary = Color(0xFFF5F0E8);
  static const Color textSecondary = Color(0xFF8A8699);
  static const Color textTertiary = Color(0xFF4A4858);

  static const double spaceXS = 4;
  static const double spaceSM = 8;
  static const double spaceMD = 16;
  static const double spaceLG = 24;
  static const double spaceXL = 32;

  static const double radiusLG = 22;

  static const String fontDisplay = 'Georgia';

  static const Duration durationFast = Duration(milliseconds: 180);
}

class WoopWinsJournalScreen extends StatefulWidget {
  const WoopWinsJournalScreen({super.key});

  @override
  State<WoopWinsJournalScreen> createState() => _WoopWinsJournalScreenState();
}

class _WoopWinsJournalScreenState extends State<WoopWinsJournalScreen> {
  final _repository = ManifestationRepository();
  bool _isLoading = true;
  List<Map<String, dynamic>> _wins =[];
  Map<String, List<Map<String, dynamic>>> _groupedWins = {};

  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
    _loadWins();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadWins() async {
    try {
      final wins = await _repository.getWoopWins();
      
      // Agrupar por Mes y Año (Estilo iOS)
      Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var win in wins) {
        final dt = DateTime.parse(win['created_at']).toLocal();
        final monthStr = DateFormat('MMMM yyyy', 'es_CO').format(dt);
        final key = monthStr[0].toUpperCase() + monthStr.substring(1);
        
        grouped.putIfAbsent(key, () =>[]).add(win);
      }

      if (mounted) {
        setState(() {
          _wins = wins;
          _groupedWins = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _appBarOpacity => (_scrollOffset / 80).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _Tokens.ink,
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: AnimatedBuilder(
            animation: _scrollController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  color: _Tokens.ink.withOpacity(_appBarOpacity * 0.95),
                  border: Border(
                    bottom: BorderSide(
                      color: _Tokens.border.withOpacity(_appBarOpacity),
                      width: 0.5,
                    ),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _Tokens.spaceMD),
                    child: Row(
                      children:[
                        _IconBtn(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: _Tokens.spaceMD),
                        AnimatedOpacity(
                          opacity: _appBarOpacity,
                          duration: _Tokens.durationFast,
                          child: const Text(
                            'Diario de Victorias',
                            style: TextStyle(
                              fontFamily: _Tokens.fontDisplay,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _Tokens.textPrimary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _Tokens.accent, strokeWidth: 2),
              )
            : CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers:[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        _Tokens.spaceLG,
                        MediaQuery.of(context).padding.top + 72,
                        _Tokens.spaceLG,
                        _Tokens.spaceLG,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:[
                          const Text(
                            'Tu historial de',
                            style: TextStyle(
                              fontSize: 13,
                              color: _Tokens.accent,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: _Tokens.spaceXS),
                          const Text(
                            'Victorias',
                            style: TextStyle(
                              fontFamily: _Tokens.fontDisplay,
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              color: _Tokens.textPrimary,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: _Tokens.spaceMD),
                          Container(height: 0.5, color: _Tokens.border),
                          const SizedBox(height: _Tokens.spaceMD),
                          const Text(
                            'Cada pequeña acción reconfigura tu mente y te acerca a tus sueños. Aquí está la evidencia de tu progreso.',
                            style: TextStyle(
                              fontSize: 14,
                              color: _Tokens.textSecondary,
                              height: 1.5,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_wins.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:[
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _Tokens.surfaceElevated,
                                border: Border.all(color: _Tokens.border, width: 0.5),
                              ),
                              child: const Icon(
                                Icons.emoji_events_outlined,
                                size: 32,
                                color: _Tokens.textTertiary,
                              ),
                            ),
                            const SizedBox(height: _Tokens.spaceLG),
                            const Text(
                              'Aún no hay victorias',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _Tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: _Tokens.spaceSM),
                            const Text(
                              'Tus logros aparecerán aquí cuando\nvences un obstáculo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: _Tokens.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: _Tokens.spaceMD),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final monthKey = _groupedWins.keys.elementAt(index);
                            final monthWins = _groupedWins[monthKey]!;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: _Tokens.spaceLG),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children:[
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8, bottom: 12),
                                    child: Text(
                                      monthKey,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: _Tokens.textPrimary,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: _Tokens.surfaceElevated,
                                      borderRadius: BorderRadius.circular(_Tokens.radiusLG),
                                      border: Border.all(color: _Tokens.borderSubtle, width: 0.5),
                                    ),
                                    child: Column(
                                      children: List.generate(monthWins.length, (i) {
                                        final win = monthWins[i];
                                        final isLast = i == monthWins.length - 1;
                                        return _WinListTile(win: win, isLast: isLast);
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          childCount: _groupedWins.keys.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: _Tokens.spaceXL)),
                ],
              ),
      ),
    );
  }
}

class _WinListTile extends StatelessWidget {
  final Map<String, dynamic> win;
  final bool isLast;

  const _WinListTile({required this.win, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.parse(win['created_at']).toLocal();
    final dayFormatted = DateFormat('dd MMM', 'es_CO').format(dt);
    final timeFormatted = DateFormat('h:mm a').format(dt);
    final manifestationTitle = win['manifestations']?['title'] ?? 'Manifestación';
    final actionTaken = win['action_taken'] ?? '';

    return Column(
      children:[
        Padding(
          padding: const EdgeInsets.all(_Tokens.spaceMD),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _Tokens.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: _Tokens.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: _Tokens.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:[
                    Text(
                      actionTaken,
                      style: const TextStyle(
                        color: _Tokens.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children:[
                        Flexible(
                          child: Text(
                            manifestationTitle,
                            style: const TextStyle(
                              color: _Tokens.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '•',
                            style: TextStyle(color: _Tokens.textTertiary, fontSize: 12),
                          ),
                        ),
                        Text(
                          '$dayFormatted, $timeFormatted',
                          style: const TextStyle(
                            color: _Tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 72),
            child: Container(
              height: 0.5,
              color: _Tokens.borderSubtle,
            ),
          ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _Tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _Tokens.border, width: 0.5),
        ),
        child: Icon(icon, size: 16, color: _Tokens.textSecondary),
      ),
    );
  }
}