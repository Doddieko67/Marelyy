// classroom_mejorado/theme/app_colors.dart
import 'package:flutter/material.dart';

const Color bgColor = Color(0xFFF3EFFF); // Originalmente para fondo claro
const Color textDarkColor = Color(
  0xFF4A235A,
); // Originalmente para texto oscuro
const Color textMediumColor = Color(
  0xFF7D3C98,
); // Originalmente para texto medio
const Color inputFillColor = Color(
  0xFFD2B4DE,
); // Originalmente para relleno de input claro
const Color primaryAccentColor = Color(0xFFE197FF); // Acento principal
const Color borderColor = Color(0xFFC39BD3); // Originalmente para bordes claros

// --- Colores adaptados para el tema oscuro ---
const Color darkScaffoldBg = textDarkColor; // El púrpura oscuro será el fondo
const Color darkPrimaryText =
    bgColor; // El lavanda muy claro será el texto principal
const Color darkSecondaryText =
    borderColor; // El púrpura más claro como texto secundario
const Color darkInputFill = Color(
  0xFF5F3A6A,
); // Un púrpura más oscuro para el relleno de inputs
const Color darkElementBackground = Color(
  0xFF6A447A,
); // Para fondos de elementos como botones sociales

// ¡Nuevo! Color para la barra de navegación inferior (interpretación del diseño)
const Color bottomNavBarBgColor = Color(
  0xFF3A3250,
); // Un púrpura oscuro que contrasta bien
