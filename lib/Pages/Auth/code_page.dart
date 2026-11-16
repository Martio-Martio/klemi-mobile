import 'dart:async';

import 'package:flutter/material.dart';

import '../../Configuration/app_theme.dart';
import '../../Widgets/klemi_widgets.dart';
import 'langue_page.dart';

/// 1.3 · Saisie du code WhatsApp (6 chiffres) avec clavier intégré.
class CodePage extends StatefulWidget {
  final String numero;
  const CodePage({super.key, this.numero = ''});

  @override
  State<CodePage> createState() => _CodePageState();
}

class _CodePageState extends State<CodePage> {
  String _code = '';
  int _secondes = 42;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondes == 0) {
        t.cancel();
      } else {
        setState(() => _secondes--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _taper(String d) {
    if (_code.length < 6) setState(() => _code += d);
  }

  void _effacer() {
    if (_code.isNotEmpty) setState(() => _code = _code.substring(0, _code.length - 1));
  }

  String get _numeroMasque {
    final n = widget.numero.replaceAll(' ', '');
    if (n.length < 4) return '+223 70 •• •• ••';
    return '+223 ${n.substring(0, 2)} •• •• ${n.substring(n.length - 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final complet = _code.length == 6;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const BoutonRetour(),
                  Image.asset('assets/logos/logo_klemi.png', width: 44, height: 44),
                  const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: AppTheme.whatsapp, shape: BoxShape.circle),
                child: const Icon(Icons.chat_bubble_outline, size: 30, color: Color(0xFF06192B)),
              ),
              const SizedBox(height: 14),
              Text('Entre le code reçu', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14, height: 1.5, color: AppTheme.texteSecondaire, fontFamily: 'Lato'),
                  children: [
                    const TextSpan(text: "Nous l'avons envoyé sur WhatsApp au "),
                    TextSpan(
                      text: _numeroMasque,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.navy),
                    ),
                    const TextSpan(text: '. '),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: const Text('Modifier',
                            style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.bleuFonce)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  for (var i = 0; i < 6; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.blanc,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            width: 2,
                            color: i == _code.length
                                ? AppTheme.bleu
                                : (i < _code.length ? AppTheme.navy : AppTheme.bordure),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          i < _code.length ? _code[i] : '',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    if (i < 5) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              KlemiBouton(
                libelle: 'Valider',
                icone: Icons.arrow_forward,
                onPressed: complet
                    ? () => Navigator.of(context).pushAndRemoveUntil(
                          routeGlissante(const LanguePage()),
                          (_) => false,
                        )
                    : null,
              ),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 13, color: AppTheme.texteSecondaire),
                  children: [
                    const TextSpan(text: 'Pas reçu ? '),
                    TextSpan(
                      text: _secondes > 0
                          ? 'Renvoyer dans 0:${_secondes.toString().padLeft(2, '0')}'
                          : 'Renvoyer le code',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _secondes > 0 ? AppTheme.texteSecondaire : AppTheme.bleuFonce,
                      ),
                    ),
                    const TextSpan(text: ' · '),
                    const TextSpan(
                      text: 'Recevoir par SMS',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.bleuFonce),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _Clavier(onChiffre: _taper, onEffacer: _effacer),
            ],
          ),
        ),
      ),
    );
  }
}

class _Clavier extends StatelessWidget {
  final ValueChanged<String> onChiffre;
  final VoidCallback onEffacer;
  const _Clavier({required this.onChiffre, required this.onEffacer});

  @override
  Widget build(BuildContext context) {
    final touches = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.9,
      children: [
        for (final t in touches)
          if (t.isEmpty)
            const SizedBox()
          else
            Material(
              color: t == '⌫' ? AppTheme.sable : AppTheme.blanc,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => t == '⌫' ? onEffacer() : onChiffre(t),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t == '⌫' ? Colors.transparent : AppTheme.bordure),
                  ),
                  alignment: Alignment.center,
                  child: Text(t,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
      ],
    );
  }
}
