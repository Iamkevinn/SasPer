// lib/screens/sasper_academy_screen.dart
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

// ─── TOKENS ──────────────────────────────────────────────────────────────────
class _T {
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
  static Color bg(BuildContext context) => isDark(context) ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
  static Color surface(BuildContext context) => isDark(context) ? const Color(0xFF1C1C1E) : Colors.white;
  static Color onSurface(BuildContext context) => Theme.of(context).colorScheme.onSurface;

  static TextStyle display(double s, {Color? c, FontWeight w = FontWeight.w800}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c, letterSpacing: -0.5, height: 1.1);
  static TextStyle label(double s, {Color? c, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c, height: 1.4);
      static TextStyle mono(double s, {Color? c, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.dmMono(fontSize: s, fontWeight: w, color: c);
}

// ─── MODELOS DE LECCIONES ────────────────────────────────────────────────────
enum SlideType { text, interactiveBurger, interactiveEA, interactiveDates }

class LessonSlide {
  final String title;
  final String content;
  final SlideType type;
  final String? emoji;

  LessonSlide({required this.title, required this.content, this.type = SlideType.text, this.emoji});
}

class AcademyLesson {
  final String id;
  final String title;
  final String category;
  final IconData icon;
  final List<Color> gradient;
  final List<LessonSlide> slides;

  AcademyLesson({required this.id, required this.title, required this.category, required this.icon, required this.gradient, required this.slides});
}

// ─── BASE DE DATOS LOCAL (Reemplazable por Supabase en el futuro) ────────────
final List<AcademyLesson> _mockLessons = [
  // ── LECCIONES EXISTENTES ─────────────────────────────────────────────────
  AcademyLesson(
    id: '1',
    title: 'La trampa de las 12 cuotas',
    category: 'Tarjetas de Crédito',
    icon: Iconsax.card_pos,
    gradient: const [Color(0xFFFF453A), Color(0xFFFF9F0A)],
    slides: [
      LessonSlide(
        title: 'El antojo de viernes 🍔',
        content:
            'Saliste con tus amigos y pagaste una cena de \$50,000 con tu tarjeta de crédito. El mesero te preguntó: "¿A cuántas cuotas?". Respondiste: "A 12, para que quede bajito".',
        emoji: '🤔',
      ),
      LessonSlide(
        title: '¿Qué acaba de pasar?',
        type: SlideType.interactiveBurger,
        content:
            'Mueve el deslizador para ver cómo crece el costo real de esa hamburguesa mes a mes gracias a los intereses.',
      ),
      LessonSlide(
        title: 'La regla de oro 🥇',
        content:
            'Las cosas que te comes, te bebes o desaparecen rápido, se pagan a 1 CUOTA (0% interés). Deja las cuotas solo para bienes duraderos (neveras, computadores) y, si puedes, búscalas a 0% interés.',
        emoji: '💡',
      ),
    ],
  ),
  AcademyLesson(
    id: '2',
    title: 'Día de Corte vs Pago',
    category: 'Bancos',
    icon: Iconsax.calendar_tick,
    gradient: const [Color(0xFFBF5AF2), Color(0xFF0A84FF)],
    slides: [
      LessonSlide(
        title: 'Dos fechas vitales 📅',
        content:
            'Tener una tarjeta de crédito y no saber estas dos fechas es como jugar ruleta rusa con tus finanzas. Vamos a diferenciarlas.',
        emoji: '🎯',
      ),
      LessonSlide(
        title: 'La foto vs La factura',
        type: SlideType.interactiveDates,
        content:
            'Toca las tarjetas para ver qué significa cada fecha en la vida real.',
      ),
      LessonSlide(
        title: 'El superpoder de 45 días 🦸‍♂️',
        content:
            'Si compras un día DESPUÉS de tu fecha de corte, tendrás casi 45 días para pagar esa compra sin un solo peso de interés (siempre que la pongas a 1 cuota).',
        emoji: '⏱️',
      ),
    ],
  ),
  AcademyLesson(
    id: '3',
    title: '¿Qué diablos es la Tasa EA?',
    category: 'Tasas',
    icon: Iconsax.chart_2,
    gradient: const [Color(0xFF30D158), Color(0xFF0A84FF)],
    slides: [
      LessonSlide(
        title: 'El idioma de los bancos 🏦',
        content:
            'EA significa "Efectiva Anual". Es la tasa real que te van a cobrar en el transcurso de un año si te prestan plata, sumando el interés sobre el interés (interés compuesto).',
        emoji: '📈',
      ),
      LessonSlide(
        title: '¿Por qué importa?',
        type: SlideType.interactiveEA,
        content:
            'Usa el simulador para comparar un préstamo de 1 millón en un banco tradicional vs uno con tasa de usura.',
      ),
      LessonSlide(
        title: 'Resumen',
        content:
            'En Colombia, las tarjetas de crédito suelen estar rozando la "Tasa de Usura" (el máximo legal permitido, cerca al 30% EA). Por eso financiar compras diarias sale tan caro.',
        emoji: '💸',
      ),
    ],
  ),

  // ── LECCIONES NUEVAS ─────────────────────────────────────────────────────
  AcademyLesson(
    id: '4',
    title: '¿Qué es el flujo de caja?',
    category: 'Conceptos Clave',
    icon: Iconsax.money_recive,
    gradient: const [Color(0xFF0A84FF), Color(0xFF30D158)],
    slides: [
      LessonSlide(
        title: 'Tu dinero tiene pulso 💓',
        content:
            'El flujo de caja es simplemente la diferencia entre el dinero que entra y el que sale en un período. No importa cuánto tengas ahorrado: si sale más de lo que entra, estás en problemas.',
        emoji: '🔄',
      ),
      LessonSlide(
        title: 'El caso del médico broke',
        content:
            'Un médico que gana \$8,000,000 al mes pero paga \$3M de arriendo, \$2M de crédito del carro, \$1.5M de colegio y gasta \$2M en ropa... tiene flujo de caja NEGATIVO de \$500,000. Gana bien, pero se está hundiendo.',
        emoji: '😰',
      ),
      LessonSlide(
        title: 'Flujo positivo = libertad',
        content:
            'Cuando tus ingresos superan tus gastos, ese excedente es el que te permite ahorrar, invertir y construir riqueza. Sin flujo positivo, solo estás sobreviviendo. Con él, estás construyendo.',
        emoji: '🚀',
      ),
    ],
  ),

  AcademyLesson(
    id: '5',
    title: 'Liquidez: el oxígeno financiero',
    category: 'Conceptos Clave',
    icon: Iconsax.drop,
    gradient: const [Color(0xFF00C7BE), Color(0xFF0A84FF)],
    slides: [
      LessonSlide(
        title: '¿Qué es liquidez? 💧',
        content:
            'Liquidez es qué tan rápido puedes convertir algo en efectivo para pagar tus cuentas. El dinero en tu cuenta corriente es 100% líquido. Tu apartamento, no.',
        emoji: '💧',
      ),
      LessonSlide(
        title: 'Rico pero sin plata',
        content:
            'Imagina que tienes un apartamento de \$500,000,000 pero debes \$2,000,000 de arriendo mañana. No puedes vender el apartamento en una noche. Eso es tener patrimonio pero cero liquidez. Y duele.',
        emoji: '😬',
      ),
      LessonSlide(
        title: 'La regla del colchón 🛏️',
        content:
            'Los expertos recomiendan tener entre 3 y 6 meses de tus gastos fijos en un lugar líquido (cuenta de ahorros, CDT a corto plazo). Eso es tu fondo de emergencia. Sin él, cualquier imprevisto te destruye.',
        emoji: '🛡️',
      ),
    ],
  ),

  AcademyLesson(
    id: '6',
    title: 'Patrimonio: lo que realmente vales',
    category: 'Conceptos Clave',
    icon: Iconsax.strongbox,
    gradient: const [Color(0xFFFF9F0A), Color(0xFFFF453A)],
    slides: [
      LessonSlide(
        title: 'La fórmula más simple 🧮',
        content:
            'Patrimonio = Lo que tienes (activos) menos lo que debes (pasivos). Si tienes \$50M en ahorros y debes \$80M en créditos, tu patrimonio es NEGATIVO. No importa lo que aparentes.',
        emoji: '⚖️',
      ),
      LessonSlide(
        title: 'Activos vs Pasivos',
        content:
            'Un ACTIVO te pone plata en el bolsillo: una propiedad en arriendo, acciones, un negocio. Un PASIVO te saca plata del bolsillo: un crédito de consumo, una deuda de tarjeta. El objetivo es acumular activos, no pasivos.',
        emoji: '📊',
      ),
      LessonSlide(
        title: 'El juego largo 🏆',
        content:
            'Construir patrimonio no es rápido ni sexy. Es comprar activos consistentemente, reducir deudas, y dejar que el tiempo haga su trabajo. Cada peso que no gastas en intereses es un peso que puede trabajar para ti.',
        emoji: '🌱',
      ),
    ],
  ),

  AcademyLesson(
    id: '7',
    title: 'Presupuesto que sí funciona',
    category: 'Hábitos',
    icon: Iconsax.calculator,
    gradient: const [Color(0xFFBF5AF2), Color(0xFFFF453A)],
    slides: [
      LessonSlide(
        title: 'El presupuesto no es una dieta',
        content:
            'La mayoría fracasa con los presupuestos porque los tratan como una restricción. Un buen presupuesto no te dice que no puedes gastar: te dice exactamente cuánto puedes gastar en cada cosa sin culpa.',
        emoji: '🎯',
      ),
      LessonSlide(
        title: 'La regla 50-30-20',
        content:
            '50% de tus ingresos van a necesidades (arriendo, comida, servicios). 30% a gustos (salidas, ropa, entretenimiento). 20% a ahorro e inversión. No es perfecta, pero es un punto de partida brutal.',
        emoji: '📐',
      ),
      LessonSlide(
        title: 'El truco del sobre 💌',
        content:
            'En cuanto te paguen, mueve inmediatamente el 20% de ahorro a otra cuenta que no toques. Paga primero tu futuro, luego vive con el resto. Si esperas a "lo que sobre", nunca sobra nada.',
        emoji: '🏦',
      ),
    ],
  ),

  AcademyLesson(
    id: '8',
    title: 'Interés compuesto: la magia del tiempo',
    category: 'Inversión',
    icon: Iconsax.trend_up,
    gradient: const [Color(0xFF30D158), Color(0xFF00C7BE)],
    slides: [
      LessonSlide(
        title: 'Einstein tenía razón ☝️',
        content:
            'Se dice que Einstein llamó al interés compuesto "la octava maravilla del mundo". El que lo entiende, lo gana. El que no, lo paga. Con las deudas ya viste cómo te destruye. Ahora veamos cómo te construye.',
        emoji: '✨',
      ),
      LessonSlide(
        title: 'El poder de empezar hoy',
        content:
            'Si inviertes \$200,000 al mes desde los 25 años a un rendimiento del 10% anual, a los 65 tendrás cerca de \$1,200,000,000. Si empiezas a los 35, tendrás menos de \$450,000,000. Diez años de diferencia cuestan casi \$800 millones.',
        emoji: '⏰',
      ),
      LessonSlide(
        title: 'No necesitas ser rico para empezar',
        content:
            'El interés compuesto no requiere grandes sumas. Requiere tiempo y consistencia. \$50,000 al mes invertidos hoy valen más que \$500,000 invertidos en 10 años. El mejor momento para empezar fue ayer. El segundo mejor es hoy.',
        emoji: '🌊',
      ),
    ],
  ),

  AcademyLesson(
    id: '9',
    title: 'Deuda buena vs deuda mala',
    category: 'Deudas',
    icon: Iconsax.receipt_2,
    gradient: const [Color(0xFFFF453A), Color(0xFFBF5AF2)],
    slides: [
      LessonSlide(
        title: 'No toda deuda es el enemigo',
        content:
            'Una deuda que te genera más dinero del que te cuesta es una deuda BUENA. Un crédito para comprar una máquina que te produce ingresos, o una hipoteca para un inmueble que se valoriza: esas pueden tener sentido.',
        emoji: '🤝',
      ),
      LessonSlide(
        title: 'La deuda mala te roba el futuro',
        content:
            'Una deuda de consumo (ropa, viajes, restaurantes pagados a cuotas) no genera ningún retorno. Solo hace que esas experiencias te cuesten 30% más de lo que valen. Estás hipotecando tu futuro para pagar el pasado.',
        emoji: '⚠️',
      ),
      LessonSlide(
        title: 'La pregunta que lo cambia todo',
        content:
            'Antes de endeudarte, pregúntate: ¿este dinero prestado va a generar más de lo que me va a costar en intereses? Si la respuesta es sí, puede ser una deuda inteligente. Si es no, es una trampa disfrazada de solución.',
        emoji: '🔑',
      ),
    ],
  ),

  AcademyLesson(
    id: '10',
    title: 'Inflación: el ladrón silencioso',
    category: 'Economía',
    icon: Iconsax.graph,
    gradient: const [Color(0xFFFF9F0A), Color(0xFF30D158)],
    slides: [
      LessonSlide(
        title: 'Tu plata pierde valor sola',
        content:
            'La inflación es el aumento general de precios. Si la inflación es del 10% anual y tienes \$1,000,000 bajo el colchón, en un año ese millón compra lo mismo que hoy comprarían \$900,000. No hiciste nada y ya perdiste.',
        emoji: '📉',
      ),
      LessonSlide(
        title: 'La cuenta de ahorros no salva',
        content:
            'Si tu cuenta de ahorros te paga 4% anual pero la inflación es 10%, estás perdiendo 6% de poder adquisitivo al año. Guardar plata sin invertirla en algo que rinda más que la inflación es perder dinero en cámara lenta.',
        emoji: '🏦',
      ),
      LessonSlide(
        title: 'Cómo ganarle a la inflación',
        content:
            'La clave es que tu dinero crezca más rápido que los precios. Acciones, fondos de inversión, CDTs con tasas competitivas, o bienes raíces históricamente han superado la inflación en el largo plazo. Invertir no es un lujo: es defensa.',
        emoji: '🛡️',
      ),
    ],
  ),
];

// ─── PANTALLA HUB (LISTA DE LECCIONES) ───────────────────────────────────────
class SasperAcademyScreen extends StatelessWidget {
  const SasperAcademyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = _T.bg(context);
    final onSurf = _T.onSurface(context);
    final statusH = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:[
          // HEADER
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: bg.withOpacity(0.9),
                padding: EdgeInsets.fromLTRB(20, statusH + 10, 20, 14),
                child: Row(
                  children:[
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: _T.surface(context), shape: BoxShape.circle),
                        child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: onSurf),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:[
                        Text('APRENDE', style: _T.label(10, w: FontWeight.w700, c: onSurf.withOpacity(0.4))),
                        Text('Sasper Academy', style: _T.display(24, c: onSurf)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // LISTA DE LECCIONES
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              itemCount: _mockLessons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final lesson = _mockLessons[index];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => LessonPlayerScreen(lesson: lesson)));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: lesson.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow:[BoxShadow(color: lesson.gradient.last.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                          child: Text(lesson.category.toUpperCase(), style: _T.label(10, c: Colors.white, w: FontWeight.w700)),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children:[
                            Expanded(child: Text(lesson.title, style: _T.display(22, c: Colors.white))),
                            Icon(lesson.icon, size: 40, color: Colors.white.withOpacity(0.5)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children:[
                            const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('2 min', style: _T.label(13, c: Colors.white, w: FontWeight.w600)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: Icon(Icons.play_arrow_rounded, size: 16, color: lesson.gradient.first),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

// ─── REPRODUCTOR DE LECCIÓN TIPO "STORIES" ───────────────────────────────────
class LessonPlayerScreen extends StatefulWidget {
  final AcademyLesson lesson;
  const LessonPlayerScreen({super.key, required this.lesson});

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  final PageController _pageCtrl = PageController();
  int _currentIndex = 0;

  void _nextSlide() {
    if (_currentIndex < widget.lesson.slides.length - 1) {
      HapticFeedback.selectionClick();
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    } else {
      HapticFeedback.mediumImpact();
      Navigator.pop(context); // Fin de la lección
    }
  }

  void _prevSlide() {
    if (_currentIndex > 0) {
      HapticFeedback.selectionClick();
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.lesson.gradient.first.withOpacity(0.1), // Fondo sutil adaptado
      body: SafeArea(
        child: Column(
          children:[
            // BARRA DE PROGRESO TIPO INSTAGRAM
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children:[
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded, size: 24, color: _T.onSurface(context).withOpacity(0.6)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: List.generate(widget.lesson.slides.length, (index) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            height: 4,
                            decoration: BoxDecoration(
                              color: index <= _currentIndex ? widget.lesson.gradient.first : _T.onSurface(context).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            // CONTENIDO (PAGE VIEW)
            Expanded(
              child: GestureDetector(
                onTapUp: (details) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  if (details.globalPosition.dx < screenWidth * 0.3) {
                    _prevSlide(); // Tocar lado izquierdo retrocede
                  } else {
                    _nextSlide(); // Tocar lado derecho avanza
                  }
                },
                child: PageView.builder(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(), // Deshabilita el swipe libre para obligar a leer/interactuar
                  onPageChanged: (idx) => setState(() => _currentIndex = idx),
                  itemCount: widget.lesson.slides.length,
                  itemBuilder: (context, index) {
                    final slide = widget.lesson.slides[index];
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children:[
                          if (slide.emoji != null) Text(slide.emoji!, style: const TextStyle(fontSize: 64)),
                          const SizedBox(height: 24),
                          Text(slide.title, textAlign: TextAlign.center, style: _T.display(32, c: _T.onSurface(context))),
                          const SizedBox(height: 20),
                          Text(slide.content, textAlign: TextAlign.center, style: _T.label(18, c: _T.onSurface(context).withOpacity(0.7))),
                          const SizedBox(height: 40),
                          
                          // WIDGETS INTERACTIVOS ESPECÍFICOS
                          if (slide.type == SlideType.interactiveBurger) _InteractiveBurger(gradient: widget.lesson.gradient),
                          if (slide.type == SlideType.interactiveEA) _InteractiveEA(gradient: widget.lesson.gradient),
                          if (slide.type == SlideType.interactiveDates) _InteractiveDates(gradient: widget.lesson.gradient),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // BOTÓN DE CONTINUAR
            Padding(
              padding: const EdgeInsets.all(24),
              child: GestureDetector(
                onTap: _nextSlide,
                child: Container(
                  height: 56, width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: widget.lesson.gradient),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      _currentIndex == widget.lesson.slides.length - 1 ? 'Terminar Lección' : 'Continuar', 
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                    )
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ─── WIDGETS INTERACTIVOS ────────────────────────────────────────────────────

// INTERACTIVO 1: La hamburguesa a cuotas
class _InteractiveBurger extends StatefulWidget {
  final List<Color> gradient;
  const _InteractiveBurger({required this.gradient});
  @override State<_InteractiveBurger> createState() => _InteractiveBurgerState();
}
class _InteractiveBurgerState extends State<_InteractiveBurger> {
  double _cuotas = 1;
  final double _precioBase = 50000;
  final double _tasaMensual = 0.025; // 2.5% EM aprox (34% EA)

  @override
  Widget build(BuildContext context) {
    // Cálculo real de anualidad
    double cuotaMensual = _precioBase;
    double totalPagado = _precioBase;
    
    if (_cuotas > 1) {
      cuotaMensual = (_precioBase * _tasaMensual) / (1 - math.pow(1 + _tasaMensual, -_cuotas));
      totalPagado = cuotaMensual * _cuotas;
    }
    
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final onSurf = _T.onSurface(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _T.surface(context), borderRadius: BorderRadius.circular(24)),
      child: Column(
        children:[
          Text('${_cuotas.toInt()} ${_cuotas == 1 ? 'Cuota' : 'Cuotas'}', style: _T.display(24, c: widget.gradient.first)),
          Slider.adaptive(
            value: _cuotas, min: 1, max: 12, divisions: 11,
            activeColor: widget.gradient.first,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _cuotas = v);
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                Text('Total pagado', style: _T.label(12, c: onSurf.withOpacity(0.5))),
                Text(fmt.format(totalPagado), style: _T.mono(20, c: _cuotas > 1 ? const Color(0xFFFF453A) : onSurf)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children:[
                Text('Intereses (A la basura)', style: _T.label(12, c: onSurf.withOpacity(0.5))),
                Text(fmt.format(totalPagado - _precioBase), style: _T.mono(20, c: onSurf)),
              ]),
            ],
          )
        ],
      ),
    );
  }
}

// INTERACTIVO 2: Fechas
class _InteractiveDates extends StatefulWidget {
  final List<Color> gradient;
  const _InteractiveDates({required this.gradient});
  @override State<_InteractiveDates> createState() => _InteractiveDatesState();
}

class _InteractiveDatesState extends State<_InteractiveDates> {
  bool _showCorte = true;

  @override
  Widget build(BuildContext context) {
    final surface = _T.surface(context);
    final onSurf = _T.onSurface(context);

    // Definimos los textos explicativos
    final corteText = 'Es el día en que el banco "toma una foto" de todos los gastos que hiciste en el último mes y genera tu factura.';
    final pagoText = 'Es la fecha límite que tienes para pagar la factura que se generó en tu día de corte. ¡No te pases de esta fecha!';

    // 👈 1. Envolvemos todo en una Column
    return Column( 
      children: [
        Row(
          children:[
            Expanded(
              child: GestureDetector(
                onTap: () { HapticFeedback.mediumImpact(); setState(() => _showCorte = true); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _showCorte ? widget.gradient.first : surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _showCorte ? Colors.transparent : onSurf.withOpacity(0.1)),
                  ),
                  child: Column(
                    children:[
                      Icon(Iconsax.camera, size: 32, color: _showCorte ? Colors.white : onSurf),
                      const SizedBox(height: 12),
                      Text('Día de\nCorte', textAlign: TextAlign.center, style: _T.display(16, c: _showCorte ? Colors.white : onSurf)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () { HapticFeedback.mediumImpact(); setState(() => _showCorte = false); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: !_showCorte ? widget.gradient.last : surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: !_showCorte ? Colors.transparent : onSurf.withOpacity(0.1)),
                  ),
                  child: Column(
                    children:[
                      Icon(Iconsax.money_send, size: 32, color: !_showCorte ? Colors.white : onSurf),
                      const SizedBox(height: 12),
                      Text('Día de\nPago', textAlign: TextAlign.center, style: _T.display(16, c: !_showCorte ? Colors.white : onSurf)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        
        // 👈 2. Agregamos el texto explicativo con animación
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            _showCorte ? corteText : pagoText,
            // Clave para que el switcher sepa que el widget cambió
            key: ValueKey<bool>(_showCorte), 
            textAlign: TextAlign.center,
            style: _T.label(16, c: onSurf.withOpacity(0.8)),
          ),
        ),
      ],
    );
  }
}

// INTERACTIVO 3: Simulador EA
class _InteractiveEA extends StatefulWidget {
  final List<Color> gradient;
  const _InteractiveEA({required this.gradient});
  @override State<_InteractiveEA> createState() => _InteractiveEAState();
}
class _InteractiveEAState extends State<_InteractiveEA> {
  bool _isUsura = true;

  @override
  Widget build(BuildContext context) {
    final onSurf = _T.onSurface(context);
    final tem = _isUsura ? 0.024 : 0.012; // 33% EA vs 15% EA aprox
    final cuota = (1000000 * tem) / (1 - math.pow(1 + tem, -12));
    final total = cuota * 12;
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _T.surface(context), borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:[
              Text('Préstamo: \$1.000.000 a 12 meses', style: _T.label(13, c: onSurf.withOpacity(0.6))),
              Switch.adaptive(
                value: _isUsura, activeColor: const Color(0xFFFF453A),
                onChanged: (v) { HapticFeedback.selectionClick(); setState(() => _isUsura = v); }
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(_isUsura ? 'Tasa de Usura (33% EA)' : 'Crédito Bueno (15% EA)', style: _T.display(20, c: _isUsura ? const Color(0xFFFF453A) : const Color(0xFF30D158))),
          const SizedBox(height: 16),
          Container(height: 1, color: onSurf.withOpacity(0.1)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:[
              Text('Total a pagar:', style: _T.label(16, c: onSurf)),
              Text(fmt.format(total), style: _T.mono(22, c: onSurf, w: FontWeight.w700)),
            ],
          )
        ],
      ),
    );
  }
}