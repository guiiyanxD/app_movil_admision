import 'package:app_movil/features/internaciones/domain/entities/cama_tablero.dart';
import 'package:flutter/material.dart';

/// Configuración estética de cada estado de cama idéntica a la aplicación web.
class EstiloCamaVisual {
  const EstiloCamaVisual({
    required this.colorPrincipal,
    required this.fondoClaro,
    required this.fondoOscuro,
    required this.icono,
    required this.etiqueta,
  });

  factory EstiloCamaVisual.para(EstadoCamaVisual estado) => switch (estado) {
        EstadoCamaVisual.disponible => const EstiloCamaVisual(
            colorPrincipal: Color(0xFF0E7490),
            fondoClaro: Color(0xFFE1F3F6),
            fondoOscuro: Color(0xFF103A42),
            icono: Icons.hotel_outlined,
            etiqueta: 'Disponible',
          ),
        EstadoCamaVisual.ocupada => const EstiloCamaVisual(
            colorPrincipal: Color(0xFF4F46E5),
            fondoClaro: Color(0xFFECEBFD),
            fondoOscuro: Color(0xFF1C1D42),
            icono: Icons.person_outline,
            etiqueta: 'Ocupada',
          ),
        EstadoCamaVisual.prestada => const EstiloCamaVisual(
            colorPrincipal: Color(0xFFA21CAF),
            fondoClaro: Color(0xFFFAE6FA),
            fondoOscuro: Color(0xFF3B133F),
            icono: Icons.repeat,
            etiqueta: 'Cama prestada',
          ),
        EstadoCamaVisual.critica => const EstiloCamaVisual(
            colorPrincipal: Color(0xFFC0392B),
            fondoClaro: Color(0xFFFBEAE7),
            fondoOscuro: Color(0xFF3A1714),
            icono: Icons.warning_amber_rounded,
            etiqueta: 'Crítico (+30 días)',
          ),
        EstadoCamaVisual.aislamiento => const EstiloCamaVisual(
            colorPrincipal: Color(0xFFA84D06),
            fondoClaro: Color(0xFFFBEEDD),
            fondoOscuro: Color(0xFF3A2312),
            icono: Icons.shield_outlined,
            etiqueta: 'Aislamiento',
          ),
        EstadoCamaVisual.fueraDeServicio => const EstiloCamaVisual(
            colorPrincipal: Color(0xFF587277),
            fondoClaro: Color(0xFFE7F3F5),
            fondoOscuro: Color(0xFF123138),
            icono: Icons.block,
            etiqueta: 'Fuera de servicio',
          ),
      };

  final Color colorPrincipal;
  final Color fondoClaro;
  final Color fondoOscuro;
  final IconData icono;
  final String etiqueta;

  Color resolverFondo(Brightness brillo) =>
      brillo == Brightness.dark ? fondoOscuro : fondoClaro;
}
