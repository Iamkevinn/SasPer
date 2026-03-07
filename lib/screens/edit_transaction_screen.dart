// lib/screens/edit_transaction_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER · Editar Transacción — Apple-first redesign
//
// Eliminado:
// · SliverAppBar expandedHeight:140 + FlexibleSpaceBar + LinearGradient
//   (red/green según tipo) → header blur sticky
// · _buildTransactionInfoCard: LinearGradient + Border.all variable +
//   chip "No editable" + monto 28px bold red/green → header inline limpio
// · _amountController: campo que NUNCA se pasa a updateTransaction() →
//   eliminado completamente. Era dead code que confundía al usuario.
// · SegmentedButton<String> Material → _SegmentedControl iOS patrón app
// · DropdownButtonFormField Material en Container/Border → _AccountTile
// · _buildCategorySelector Wrap chips InkWell → _CategoryTile sheet patrón app
// · _buildMoodSelector Wrap chips InkWell → fila horizontal de íconos
// · _buildDescriptionField OutlineInputBorder + surfaceContainerHighest → _InputField
// · FilledButton "Guardar Cambios" Material → _SaveBtn patrón app
// · .animate().fadeIn(delay:100ms→600ms) × 7 + .scale() → FadeTransition 280ms
// · showDialog AlertDialog × 2 (deuda + confirmar borrar) → _ConfirmSheet blur
// · navigatorKey.currentContext! → context directo
// · WidgetsBinding.instance.addPostFrameCallback → NotificationHelper directo
// · Botón eliminar en AppBar actions → zona destructiva al final del formulario
// · Section headers Row(Icon + Text) × 5 → _GroupLabel 11px uppercase
// · Icon decorativos de 20px en cada header → eliminados
// · colorScheme.surfaceContainerHighest × 4 → opacity-based surfaces
// · GoogleFonts.poppins + TextStyle sin fuente mezclados → _T tokens DM Sans
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:developer' as developer;

import 'package:sasper/config/app_config.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/models/enums/transaction_mood_enum.dart';
import 'package:sasper/screens/place_search_screen.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

// ── Tokens ───────────────────────────────────────────────────────────────────
class _T {
  static TextStyle display(double s,
          {Color? c, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.dmSans(
          fontSize: s, fontWeight: w, color: c,
          letterSpacing: -0.4, height: 1.1);

  static TextStyle label(double s,
          {Color? c, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c);

  static TextStyle mono(double s,
          {Color? c, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.dmMono(fontSize: s, fontWeight: w, color: c);
}

// ── Paleta iOS ────────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF0A84FF);
const _kGreen  = Color(0xFF30D158);
const _kRed    = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class EditTransactionScreen extends StatefulWidget {
  final Transaction transaction;
  const EditTransactionScreen({super.key, required this.transaction});

  @override
  State<EditTransactionScreen> createState() =>
      _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen>
    with SingleTickerProviderStateMixin {
  final _txRepo       = TransactionRepository.instance;
  final _accountRepo  = AccountRepository.instance;
  final _categoryRepo = CategoryRepository.instance;
  final _formKey      = GlobalKey<FormState>();

  // _amountController eliminado — updateTransaction() nunca lo usaba.
  late final TextEditingController _descCtrl;

  String?          _categoryName;
  late String      _type;
  String?          _accountId;
  TransactionMood? _mood;
  bool             _loading          = false;
  bool             _fetchingLocation = false;
  String?          _locationName;
  double?          _lat;
  double?          _lng;

  late final Future<List<Account>>  _accountsFuture;
  late final Future<List<Category>> _categoriesFuture;

  // Fade-in único
  late final AnimationController _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    final tx        = widget.transaction;
    _descCtrl       = TextEditingController(text: tx.description ?? '');
    _type           = tx.type;
    _categoryName   = tx.category;
    _accountId      = tx.accountId;
    _mood           = tx.mood;
    _locationName   = tx.locationName;
    _lat            = tx.latitude;
    _lng            = tx.longitude;
    _accountsFuture   = _accountRepo.getAccounts();
    _categoriesFuture = _categoryRepo.getCategories();
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<void> _update() async {
    FocusScope.of(context).unfocus();

    if (_categoryName == null || _accountId == null) {
      HapticFeedback.heavyImpact();
      NotificationHelper.show(
          message: 'Selecciona cuenta y categoría.',
          type: NotificationType.error);
      return;
    }
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact(); return;
    }

    setState(() => _loading = true);

    try {
      await _txRepo.updateTransaction(
        transactionId:   widget.transaction.id,
        accountId:       _accountId!,
        type:            _type,
        category:        _categoryName!,
        description:     _descCtrl.text.trim(),
        mood:            _mood,
        transactionDate: widget.transaction.transactionDate,
        locationName:    _locationName,
        latitude:        _lat,
        longitude:       _lng,
      );

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      EventService.instance.fire(AppEvent.transactionUpdated);
      Navigator.of(context).pop(true);
      NotificationHelper.show(
          message: 'Transacción actualizada',
          type: NotificationType.success);
    } catch (e) {
      developer.log('Error al actualizar: $e',
          name: 'EditTransactionScreen');
      if (mounted) {
        HapticFeedback.heavyImpact();
        NotificationHelper.show(
            message: 'Error al actualizar.',
            type: NotificationType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  // Si la transacción está vinculada a deuda → sheet informativo (no error).
  // Si no → sheet de confirmación con botón destructivo.

  Future<void> _delete() async {
    HapticFeedback.mediumImpact();

    if (widget.transaction.debtId != null) {
      await _showDebtLinkedSheet();
      return;
    }

    final confirmed = await _showConfirmDeleteSheet();
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await _txRepo.deleteTransaction(widget.transaction.id);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      EventService.instance.fire(AppEvent.transactionDeleted);
      Navigator.of(context).pop(true);
      NotificationHelper.show(
          message: 'Transacción eliminada',
          type: NotificationType.success);
    } catch (e) {
      developer.log('Error al eliminar: $e', name: 'EditTransactionScreen');
      if (mounted) {
        HapticFeedback.heavyImpact();
        NotificationHelper.show(
            message: 'Error al eliminar.',
            type: NotificationType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Sheet informativo — transacción vinculada a deuda
  Future<void> _showDebtLinkedSheet() {
    return showModalBottomSheet(
      context:         context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final theme  = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final bg     = isDark ? const Color(0xFF1C1C1E) : Colors.white;
        final onSurf = theme.colorScheme.onSurface;

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: bg,
              padding: EdgeInsets.only(
                  left: 24, right: 24, top: 8,
                  bottom: MediaQuery.of(context).padding.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: onSurf.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: _kOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Center(
                        child: Icon(Iconsax.link_2, size: 22,
                            color: _kOrange)),
                  ),
                  const SizedBox(height: 14),
                  Text('Transacción vinculada',
                      style: _T.display(19, c: onSurf)),
                  const SizedBox(height: 8),
                  Text(
                    'Esta transacción está asociada a una deuda. Para gestionarla o eliminarla, ve a la sección de Deudas.',
                    textAlign: TextAlign.center,
                    style: _T.label(14,
                        c: onSurf.withOpacity(0.55),
                        w: FontWeight.w400),
                  ),
                  const SizedBox(height: 24),
                  _SheetBtn(
                    label: 'Entendido',
                    color: _kBlue,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Sheet de confirmación de borrado
  Future<bool?> _showConfirmDeleteSheet() {
    return showModalBottomSheet<bool>(
      context:         context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final theme  = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final bg     = isDark ? const Color(0xFF1C1C1E) : Colors.white;
        final onSurf = theme.colorScheme.onSurface;
        final fmt    = NumberFormat.currency(
            locale: 'es_CO', symbol: '\$', decimalDigits: 0);

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: bg,
              padding: EdgeInsets.only(
                  left: 24, right: 24, top: 8,
                  bottom: MediaQuery.of(context).padding.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: onSurf.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: _kRed.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Center(
                        child: Icon(Iconsax.trash, size: 22, color: _kRed)),
                  ),
                  const SizedBox(height: 14),
                  Text('Eliminar transacción',
                      style: _T.display(19, c: onSurf)),
                  const SizedBox(height: 6),
                  // Mostramos el monto aquí como contexto — no editable
                  Text(
                    fmt.format(widget.transaction.amount.abs()),
                    style: _T.mono(22,
                        c: widget.transaction.type == 'Gasto'
                            ? _kRed : _kGreen),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Esta acción no se puede deshacer.',
                    textAlign: TextAlign.center,
                    style: _T.label(14,
                        c: onSurf.withOpacity(0.50),
                        w: FontWeight.w400),
                  ),
                  const SizedBox(height: 24),
                  _SheetBtn(
                    label: 'Eliminar',
                    color: _kRed,
                    onTap: () => Navigator.pop(context, true),
                  ),
                  const SizedBox(height: 10),
                  _SheetBtn(
                    label: 'Cancelar',
                    color: onSurf.withOpacity(0.08),
                    textColor: onSurf,
                    onTap: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Category sheet ────────────────────────────────────────────────────────

  // ── Location ─────────────────────────────────────────────────────────────

  Future<void> _pickLocation() async {
    HapticFeedback.selectionClick();
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const PlaceSearchScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _locationName = result['name'];
        _lat          = result['lat'];
        _lng          = result['lng'];
      });
    }
  }

  Future<void> _getGpsLocation() async {
    setState(() => _fetchingLocation = true);
    HapticFeedback.lightImpact();
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        NotificationHelper.show(
            message: 'Permiso de ubicación denegado',
            type: NotificationType.warning);
        if (mounted) setState(() => _fetchingLocation = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final name = await _reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _lat              = pos.latitude;
          _lng              = pos.longitude;
          _locationName     = name;
          _fetchingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final res = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=\${AppConfig.googlePlacesApiKey}'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
    } catch (_) {}
    return 'Ubicación actual';
  }

  void _openCategorySheet(List<Category> cats) {
    HapticFeedback.mediumImpact();
    final expected = _type == 'Gasto' ? 'expense' : 'income';
    final filtered = cats.where((c) => c.type.name == expected).toList();

    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize:     0.90,
        expand:           false,
        builder: (_, ctrl) => _CategorySheet(
          categories:          filtered,
          selectedName:        _categoryName,
          scrollController:    ctrl,
          onSelected: (name) {
            HapticFeedback.selectionClick();
            setState(() => _categoryName = name);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final onSurf  = theme.colorScheme.onSurface;
    final statusH = MediaQuery.of(context).padding.top;
    final bottomP = MediaQuery.of(context).viewInsets.bottom;
    final tx      = widget.transaction;
    final isExp   = _type == 'Gasto';
    final fmt     = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final dateF   = DateFormat.yMMMd('es_CO');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(children: [
          // ── Header blur sticky ─────────────────────────────────────────
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: theme.scaffoldBackgroundColor.withOpacity(0.93),
                padding: EdgeInsets.only(
                    top: statusH + 10, left: 8, right: 16, bottom: 14),
                child: Row(children: [
                  _BackBtn(),
                  const SizedBox(width: 4),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('SASPER',
                          style: _T.label(10,
                              w: FontWeight.w700,
                              c: onSurf.withOpacity(0.35))),
                      Text('Editar transacción',
                          style: _T.display(28, c: onSurf)),
                    ],
                  )),
                ]),
              ),
            ),
          ),

          // ── Scroll ────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: bottomP > 0 ? bottomP + 100 : 120,
              ),
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      // ── Contexto — monto original (no editable) ────
                      // El monto no se pasa a updateTransaction(), por
                      // lo tanto no se muestra como campo editable.
                      // Aparece como contexto para que el usuario sepa
                      // qué transacción está editando.
                      _ContextHeader(
                        amount:   fmt.format(tx.amount.abs()),
                        date:     dateF.format(tx.transactionDate),
                        category: tx.category ?? '—',
                        isExpense: tx.type == 'Gasto',
                      ),
                      const SizedBox(height: 28),

                      // ── Tipo ───────────────────────────────────────
                      _GroupLabel('TIPO'),
                      const SizedBox(height: 10),
                      _TypeControl(
                        selected: _type,
                        onChanged: (t) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _type = t;
                            _categoryName = null; // reset al cambiar tipo
                          });
                        },
                      ),
                      const SizedBox(height: 28),

                      // ── Cuenta ─────────────────────────────────────
                      _GroupLabel('CUENTA'),
                      const SizedBox(height: 10),
                      FutureBuilder<List<Account>>(
                        future: _accountsFuture,
                        builder: (ctx, snap) {
                          if (!snap.hasData) return _SkeletonTile();
                          final accounts = snap.data!;
                          // Validar que el account guardado sigue existiendo
                          if (_accountId != null &&
                              !accounts.any((a) => a.id == _accountId)) {
                            _accountId = null;
                          }
                          return _AccountSelector(
                            accounts:   accounts,
                            selectedId: _accountId,
                            onChanged:  (id) {
                              HapticFeedback.selectionClick();
                              setState(() => _accountId = id);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 28),

                      // ── Categoría ──────────────────────────────────
                      _GroupLabel('CATEGORÍA'),
                      const SizedBox(height: 10),
                      FutureBuilder<List<Category>>(
                        future: _categoriesFuture,
                        builder: (ctx, snap) {
                          if (!snap.hasData) return _SkeletonTile();
                          return _CategoryTrigger(
                            selectedName: _categoryName,
                            categories:   snap.data!,
                            type:         _type,
                            onTap: () => _openCategorySheet(snap.data!),
                          );
                        },
                      ),
                      const SizedBox(height: 28),

                      // ── Estado de ánimo (solo gastos) ──────────────
                      if (isExp) ...[
                        _GroupLabel('ESTADO DE ÁNIMO  ·  OPCIONAL'),
                        const SizedBox(height: 10),
                        _MoodSelector(
                          selected: _mood,
                          onChanged: (m) {
                            HapticFeedback.selectionClick();
                            setState(() => _mood = m);
                          },
                        ),
                        const SizedBox(height: 28),
                      ],

                      // ── Descripción ────────────────────────────────
                      _GroupLabel('NOTA  ·  OPCIONAL'),
                      const SizedBox(height: 10),
                      _NoteField(controller: _descCtrl),
                      const SizedBox(height: 28),

                      // ── Ubicación ──────────────────────────────────
                      _GroupLabel('UBICACIÓN  ·  OPCIONAL'),
                      const SizedBox(height: 10),
                      _LocationTile(
                        locationName:    _locationName,
                        fetchingLocation: _fetchingLocation,
                        onPickPlace:     _pickLocation,
                        onGps:           _getGpsLocation,
                        onClear: () => setState(() {
                          _locationName = null;
                          _lat          = null;
                          _lng          = null;
                        }),
                      ),
                      const SizedBox(height: 40),

                      // ── Zona destructiva — eliminar ────────────────
                      // Al final del formulario, lejos del scroll top.
                      // No en el AppBar donde el dedo puede rozarlo.
                      _DestructiveZone(
                        isLinkedToDebt: tx.debtId != null,
                        loading:        _loading,
                        onDelete:       _delete,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Botón guardar sticky ───────────────────────────────────────
          _SaveBtn(loading: _loading, onTap: _update),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTEXT HEADER — información de la transacción original (read-only)
// ─────────────────────────────────────────────────────────────────────────────
// No editable. Sin LinearGradient ni Border.all de colores.
// El monto con _T.mono comunica que es un valor fijo (tipografía monoespaciada
// = datos, no entrada). La fecha y categoría original como contexto.

class _ContextHeader extends StatelessWidget {
  final String amount, date, category;
  final bool   isExpense;
  const _ContextHeader({
    required this.amount, required this.date,
    required this.category, required this.isExpense,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final onSurf  = Theme.of(context).colorScheme.onSurface;
    final bg      = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.03);
    final color   = isExpense ? _kRed : _kGreen;
    final typeStr = isExpense ? 'Gasto' : 'Ingreso';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        // Indicador de tipo — cuadrado pequeño con color semántico
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Icon(
            isExpense
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
            size: 16, color: color,
          )),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category,
                style: _T.label(13, w: FontWeight.w600, c: onSurf)),
            const SizedBox(height: 1),
            Text('$typeStr · $date',
                style: _T.label(11,
                    c: onSurf.withOpacity(0.40))),
          ],
        )),
        // Monto en mono — communica "dato fijo, no editable"
        Text(amount,
            style: _T.mono(16,
                c: color, w: FontWeight.w700)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPE CONTROL — segmented control iOS
// ─────────────────────────────────────────────────────────────────────────────

class _TypeControl extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _TypeControl({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.black.withOpacity(0.06);
    final pillBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;

    const options = ['Gasto', 'Ingreso'];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: options.map((opt) {
          final isSel  = selected == opt;
          final color  = opt == 'Gasto' ? _kRed : _kGreen;

          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSel ? pillBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSel && !isDark
                      ? [BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSel) ...[
                      Icon(
                        opt == 'Gasto'
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        size: 13,
                        color: isSel ? color : onSurf.withOpacity(0.45),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(opt,
                        style: _T.label(13,
                            w: isSel ? FontWeight.w700 : FontWeight.w500,
                            c: isSel ? color : onSurf.withOpacity(0.45))),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNT SELECTOR — trigger tile que abre un bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
// Igual que _CategoryTrigger. Escala a cualquier número de cuentas sin
// ocupar espacio vertical en el formulario. El sheet muestra la lista
// completa con el mismo patrón que el selector de categorías.

class _AccountSelector extends StatefulWidget {
  final List<Account>         accounts;
  final String?               selectedId;
  final ValueChanged<String?> onChanged;
  const _AccountSelector({
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
  });
  @override State<_AccountSelector> createState() => _AccountSelectorState();
}

class _AccountSelectorState extends State<_AccountSelector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  void _openSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        maxChildSize:     0.80,
        expand:           false,
        builder: (_, ctrl) => _AccountSheet(
          accounts:         widget.accounts,
          selectedId:       widget.selectedId,
          scrollController: ctrl,
          onSelected: (id) {
            HapticFeedback.selectionClick();
            widget.onChanged(id);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final onSurf   = Theme.of(context).colorScheme.onSurface;
    final bg       = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    final selected = widget.accounts
        .cast<Account?>()
        .firstWhere((a) => a!.id == widget.selectedId, orElse: () => null);

    return GestureDetector(
      onTapDown:   (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:     (_) { _c.reverse(); _openSheet(); },
      onTapCancel: ()  => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.99, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: _kBlue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(child: Icon(
                    Iconsax.wallet_3, size: 15, color: _kBlue)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(
                selected?.name ?? 'Selecciona una cuenta',
                style: _T.label(14,
                    w: FontWeight.w600,
                    c: selected != null
                        ? onSurf
                        : onSurf.withOpacity(0.38)),
              )),
              if (selected != null) ...[
                Text(
                  NumberFormat.currency(
                      locale: 'es_CO', symbol: '\$', decimalDigits: 0)
                      .format(selected!.balance),
                  style: _T.mono(13,
                      c: selected!.balance >= 0 ? _kGreen : _kRed,
                      w: FontWeight.w600),
                ),
                const SizedBox(width: 6),
              ],
              Icon(Icons.chevron_right_rounded, size: 17,
                  color: onSurf.withOpacity(0.22)),
            ]),
          ),
        ),
      ),
    );
  }
}

// Sheet de selección de cuenta

class _AccountSheet extends StatelessWidget {
  final List<Account>        accounts;
  final String?              selectedId;
  final ScrollController     scrollController;
  final ValueChanged<String> onSelected;
  const _AccountSheet({
    required this.accounts, required this.selectedId,
    required this.scrollController, required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: bg,
          child: Column(children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: onSurf.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Cuenta', style: _T.display(22, c: onSurf)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                controller:  scrollController,
                physics:     const BouncingScrollPhysics(),
                padding:     const EdgeInsets.symmetric(horizontal: 20),
                itemCount:   accounts.length,
                separatorBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(left: 34 + 12),
                  child: Container(
                      height: 0.5,
                      color: onSurf.withOpacity(0.07)),
                ),
                itemBuilder: (_, i) {
                  final acc   = accounts[i];
                  final isSel = acc.id == selectedId;
                  return _AccountSheetRow(
                    account:    acc,
                    isSelected: isSel,
                    onTap:      () => onSelected(acc.id),
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ]),
        ),
      ),
    );
  }
}

class _AccountSheetRow extends StatefulWidget {
  final Account      account;
  final bool         isSelected;
  final VoidCallback onTap;
  const _AccountSheetRow({
    required this.account, required this.isSelected, required this.onTap});
  @override State<_AccountSheetRow> createState() => _AccountSheetRowState();
}

class _AccountSheetRowState extends State<_AccountSheetRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTapDown:   (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:     (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: ()  => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Opacity(
          opacity: lerpDouble(1.0, 0.50, _c.value)!,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              // Dot de color — positivo/negativo como en add_transaction
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.account.balance >= 0 ? _kGreen : _kRed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.account.name,
                  style: _T.label(14, w: FontWeight.w600, c: onSurf))),
              // Balance — dato real, mismo patrón add_transaction
              Text(
                NumberFormat.currency(
                    locale: 'es_CO', symbol: '\$', decimalDigits: 0)
                    .format(widget.account.balance),
                style: _T.mono(13,
                    c: widget.account.balance >= 0 ? _kGreen : _kRed,
                    w: FontWeight.w600),
              ),
              const SizedBox(width: 10),
              AnimatedOpacity(
                opacity: widget.isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.check_rounded, size: 17, color: _kBlue),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY TRIGGER — tile que abre el sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryTrigger extends StatefulWidget {
  final String?        selectedName;
  final List<Category> categories;
  final String         type;
  final VoidCallback   onTap;
  const _CategoryTrigger({
    required this.selectedName, required this.categories,
    required this.type, required this.onTap,
  });
  @override State<_CategoryTrigger> createState() => _CategoryTriggerState();
}

class _CategoryTriggerState extends State<_CategoryTrigger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    final expected = widget.type == 'Gasto' ? 'expense' : 'income';
    final cat = widget.categories
        .where((c) => c.type.name == expected)
        .cast<Category?>()
        .firstWhere(
          (c) => c!.name == widget.selectedName,
          orElse: () => null,
        );
    final color = cat?.colorAsObject ?? _kBlue;

    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.99, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Icon(
                  cat?.icon ?? Iconsax.category,
                  size: 15, color: color,
                )),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(
                widget.selectedName ?? 'Selecciona una categoría',
                style: _T.label(14,
                    w: FontWeight.w600,
                    c: widget.selectedName != null
                        ? onSurf
                        : onSurf.withOpacity(0.38)),
              )),
              Icon(Icons.chevron_right_rounded, size: 17,
                  color: onSurf.withOpacity(0.22)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY SHEET — lista vertical con color semántico
// ─────────────────────────────────────────────────────────────────────────────

class _CategorySheet extends StatelessWidget {
  final List<Category>      categories;
  final String?             selectedName;
  final ScrollController    scrollController;
  final ValueChanged<String> onSelected;
  const _CategorySheet({
    required this.categories,
    required this.selectedName,
    required this.scrollController,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: bg,
          child: Column(children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: onSurf.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Categoría', style: _T.display(22, c: onSurf)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                controller:  scrollController,
                physics:     const BouncingScrollPhysics(),
                padding:     const EdgeInsets.symmetric(horizontal: 20),
                itemCount:   categories.length,
                separatorBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(left: 34 + 12),
                  child: Container(
                      height: 0.5,
                      color: onSurf.withOpacity(0.07)),
                ),
                itemBuilder: (ctx, i) {
                  final cat   = categories[i];
                  final isSel = cat.name == selectedName;
                  return _SheetCategoryRow(
                    category:   cat,
                    isSelected: isSel,
                    onTap:      () => onSelected(cat.name),
                  );
                },
              ),
            ),
            SizedBox(
                height: MediaQuery.of(context).padding.bottom + 20),
          ]),
        ),
      ),
    );
  }
}

class _SheetCategoryRow extends StatefulWidget {
  final Category category;
  final bool     isSelected;
  final VoidCallback onTap;
  const _SheetCategoryRow({
    required this.category, required this.isSelected,
    required this.onTap,
  });
  @override State<_SheetCategoryRow> createState() =>
      _SheetCategoryRowState();
}

class _SheetCategoryRowState extends State<_SheetCategoryRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final color  = widget.category.colorAsObject;

    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Opacity(
          opacity: lerpDouble(1.0, 0.50, _c.value)!,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Icon(
                    widget.category.icon ?? Iconsax.category,
                    size: 15, color: color)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.category.name,
                  style: _T.label(14, w: FontWeight.w600, c: onSurf))),
              AnimatedOpacity(
                opacity: widget.isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.check_rounded,
                    size: 17, color: _kBlue),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOOD SELECTOR — cuadrícula Wrap, escala a cualquier número de moods
// ─────────────────────────────────────────────────────────────────────────────
// Wrap + LayoutBuilder en lugar de Row: 4 columnas uniformes.
// Si hay más de 4 moods la segunda fila se forma automáticamente sin overflow.

class _MoodSelector extends StatelessWidget {
  final TransactionMood? selected;
  final ValueChanged<TransactionMood?> onChanged;
  const _MoodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final moods  = TransactionMood.values;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(14)),
      child: LayoutBuilder(
        builder: (_, constraints) {
          const cols    = 4;
          const spacing = 8.0;
          final cellW   = (constraints.maxWidth - spacing * (cols - 1)) / cols;

          return Wrap(
            spacing:    spacing,
            runSpacing: spacing,
            children: moods.map((mood) {
              final isSel = selected == mood;
              return SizedBox(
                width: cellW,
                child: _MoodBtn(
                  mood:       mood,
                  isSelected: isSel,
                  onTap: () => onChanged(isSel ? null : mood),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _MoodBtn extends StatefulWidget {
  final TransactionMood mood;
  final bool            isSelected;
  final VoidCallback    onTap;
  const _MoodBtn({
    required this.mood, required this.isSelected, required this.onTap});
  @override State<_MoodBtn> createState() => _MoodBtnState();
}

class _MoodBtnState extends State<_MoodBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.80, _c.value)!,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? _kBlue.withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(child: Icon(
                    widget.mood.icon,
                    size: 22,
                    color: widget.isSelected
                        ? _kBlue
                        : onSurf.withOpacity(0.35),
                  )),
                ),
                const SizedBox(height: 4),
                AnimatedOpacity(
                  opacity: widget.isSelected ? 1.0 : 0.40,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    widget.mood.displayName,
                    style: _T.label(10,
                        c: widget.isSelected
                            ? _kBlue : onSurf,
                        w: widget.isSelected
                            ? FontWeight.w700 : FontWeight.w400),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTE FIELD — campo de texto para descripción
// ─────────────────────────────────────────────────────────────────────────────

class _NoteField extends StatefulWidget {
  final TextEditingController controller;
  const _NoteField({required this.controller});
  @override State<_NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<_NoteField> {
  final _focus = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() =>
        setState(() => _hasFocus = _focus.hasFocus));
  }

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: _hasFocus
            ? Border.all(color: _kBlue.withOpacity(0.60), width: 1.5)
            : Border.all(color: Colors.transparent, width: 1.5),
      ),
      child: TextFormField(
        controller:  widget.controller,
        focusNode:   _focus,
        maxLines:    3,
        style:       _T.label(14, c: onSurf),
        decoration: InputDecoration(
          hintText:  'Añade una nota...',
          hintStyle: _T.label(14, c: onSurf.withOpacity(0.28)),
          border:    InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DESTRUCTIVE ZONE — zona de borrado al final del formulario
// ─────────────────────────────────────────────────────────────────────────────
// Lejos del AppBar y del area de scroll superior.
// El botón de eliminar al final del scroll sigue el patrón de Settings > Delete
// Account en iOS — acción destructiva al final, no en la barra de navegación.
// Si está vinculada a deuda: el botón se muestra deshabilitado con un indicador
// de por qué — no se oculta, se comunica el estado.

class _DestructiveZone extends StatelessWidget {
  final bool     isLinkedToDebt;
  final bool     loading;
  final VoidCallback onDelete;
  const _DestructiveZone({
    required this.isLinkedToDebt,
    required this.loading,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Separador visual antes de la zona peligrosa
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
              height: 0.5, color: onSurf.withOpacity(0.07)),
        ),

        // Si está vinculada a deuda: muestra por qué no se puede borrar
        if (isLinkedToDebt)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Icon(Iconsax.link_2, size: 13,
                  color: _kOrange.withOpacity(0.70)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'Vinculada a una deuda · gestiona desde Deudas',
                style: _T.label(12,
                    c: onSurf.withOpacity(0.40),
                    w: FontWeight.w400),
              )),
            ]),
          ),

        _DeleteBtn(
          enabled: !isLinkedToDebt && !loading,
          onTap:   onDelete,
        ),
      ],
    );
  }
}

class _DeleteBtn extends StatefulWidget {
  final bool         enabled;
  final VoidCallback onTap;
  const _DeleteBtn({required this.enabled, required this.onTap});
  @override State<_DeleteBtn> createState() => _DeleteBtnState();
}

class _DeleteBtnState extends State<_DeleteBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 80));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark
        ? _kRed.withOpacity(0.12)
        : _kRed.withOpacity(0.07);

    return GestureDetector(
      onTapDown: (_) {
        if (widget.enabled) {
          _c.forward(); HapticFeedback.mediumImpact();
        }
      },
      onTapUp:     (_) { _c.reverse(); if (widget.enabled) widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.98, _c.value)!,
          child: AnimatedOpacity(
            opacity: widget.enabled ? 1.0 : 0.35,
            duration: const Duration(milliseconds: 200),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.trash, size: 15, color: _kRed),
                  const SizedBox(width: 8),
                  Text('Eliminar transacción',
                      style: _T.label(14,
                          c: _kRed, w: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAVE BUTTON — sticky bottom
// ─────────────────────────────────────────────────────────────────────────────

class _SaveBtn extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _SaveBtn({required this.loading, required this.onTap});
  @override State<_SaveBtn> createState() => _SaveBtnState();
}

class _SaveBtnState extends State<_SaveBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 80));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: theme.scaffoldBackgroundColor.withOpacity(0.93),
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          child: GestureDetector(
            onTapDown: (_) {
              if (!widget.loading) {
                _c.forward(); HapticFeedback.mediumImpact();
              }
            },
            onTapUp:     (_) { _c.reverse(); if (!widget.loading) widget.onTap(); },
            onTapCancel: () => _c.reverse(),
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => Transform.scale(
                scale: lerpDouble(1.0, 0.97, _c.value)!,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 54,
                  decoration: BoxDecoration(
                    color: widget.loading
                        ? _kBlue.withOpacity(0.55) : _kBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: widget.loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white))
                        : Text('Guardar cambios',
                            style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET BUTTON — botón dentro de bottom sheets
// ─────────────────────────────────────────────────────────────────────────────

class _SheetBtn extends StatefulWidget {
  final String     label;
  final Color      color;
  final Color?     textColor;
  final VoidCallback onTap;
  const _SheetBtn({
    required this.label, required this.color,
    required this.onTap, this.textColor,
  });
  @override State<_SheetBtn> createState() => _SheetBtnState();
}

class _SheetBtnState extends State<_SheetBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 80));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDestructive = widget.textColor == null;
    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.mediumImpact(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.97, _c.value)!,
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(
              widget.label,
              style: _T.label(16,
                  c: widget.textColor ?? Colors.white,
                  w: FontWeight.w700),
            )),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// LOCATION TILE — idéntico al patrón _buildLocationSection de add_transaction
// ─────────────────────────────────────────────────────────────────────────────
// Buscar lugar (PlaceSearchScreen) + GPS actual + limpiar.
// El tile muestra el nombre del lugar guardado o placeholder.
// El ícono GPS activa _getGpsLocation() con spinner mientras carga.
// Al tener ubicación, aparece la X para limpiar — sin confirmación
// (limpiar ubicación no es destructivo).

class _LocationTile extends StatefulWidget {
  final String?      locationName;
  final bool         fetchingLocation;
  final VoidCallback onPickPlace;
  final VoidCallback onGps;
  final VoidCallback onClear;
  const _LocationTile({
    required this.locationName,
    required this.fetchingLocation,
    required this.onPickPlace,
    required this.onGps,
    required this.onClear,
  });
  @override State<_LocationTile> createState() => _LocationTileState();
}

class _LocationTileState extends State<_LocationTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final onSurf  = Theme.of(context).colorScheme.onSurface;
    final bg      = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final hasLoc  = widget.locationName != null;

    return GestureDetector(
      onTapDown:   (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:     (_) { _c.reverse(); widget.onPickPlace(); },
      onTapCancel: ()  => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.99, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: hasLoc
                      ? _kBlue.withOpacity(0.10)
                      : onSurf.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Icon(
                  Iconsax.location,
                  size: 15,
                  color: hasLoc ? _kBlue : onSurf.withOpacity(0.30),
                )),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(
                widget.locationName ?? 'Buscar lugar',
                style: _T.label(14,
                    w: FontWeight.w600,
                    c: hasLoc ? onSurf : onSurf.withOpacity(0.38)),
                overflow: TextOverflow.ellipsis,
              )),
              const SizedBox(width: 8),
              // GPS — spinner mientras carga, ícono cuando no
              GestureDetector(
                onTap:           widget.fetchingLocation ? null : widget.onGps,
                behavior:        HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: widget.fetchingLocation
                      ? SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: _kBlue,
                          ))
                      : Icon(Iconsax.gps,
                          size: 17,
                          color: hasLoc
                              ? _kBlue
                              : onSurf.withOpacity(0.28)),
                ),
              ),
              // Limpiar — solo cuando hay ubicación
              if (hasLoc) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onClear();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.close_rounded,
                        size: 15, color: onSurf.withOpacity(0.28)),
                  ),
                ),
              ] else
                Icon(Icons.chevron_right_rounded, size: 17,
                    color: onSurf.withOpacity(0.22)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Text(text,
        style: _T.label(11,
            w: FontWeight.w700, c: onSurf.withOpacity(0.35)));
  }
}

class _SkeletonTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    return Container(
        height: 52,
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(14)));
  }
}

class _BackBtn extends StatefulWidget {
  @override State<_BackBtn> createState() => _BackBtnState();
}

class _BackBtnState extends State<_BackBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); Navigator.of(context).pop(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.85, _c.value)!,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: _kBlue),
          ),
        ),
      ),
    );
  }
}