import 'package:flutter/material.dart';

/// Define a paleta de cores central do aplicativo (Design System).
/// Garante consistência visual e suporte integrado ao Material Design 3.
class AppColors {
  // Construtor privado para evitar instanciação acidental da classe.
  AppColors._();

  // ==========================================
  // 1. CORES DE MARCA (BRAND COLORS)
  // ==========================================
  
  /// Cor Primária (Ex: Verde Agronômico, cor principal da marca)
  static const Color primary = Color(0xFF2E7D32); // Verde folha escuro
  
  /// Cor Secundária (Ex: Tons terrosos para elementos de apoio)
  static const Color secondary = Color(0xFF795548); // Marrom terra
  
  /// Cor Terciária (Ex: Destaques vibrantes como sol/colheita)
  static const Color tertiary = Color(0xFFF57F17); // Laranja/Amarelo sol

  // ==========================================
  // 2. CORES SEMÂNTICAS (FEEDBACK)
  // ==========================================
  
  static const Color success = Color(0xFF388E3C); // Verde sucesso
  static const Color warning = Color(0xFFFBC02D); // Amarelo atenção
  static const Color error = Color(0xFFD32F2F);   // Vermelho erro
  static const Color info = Color(0xFF1976D2);    // Azul informação

  // ==========================================
  // 3. CORES NEUTRAS E FUNDOS (BACKGROUND)
  // ==========================================
  
  static const Color backgroundLight = Color(0xFFF5F7FA); // Fundo cinza bem claro (usado no app)
  static const Color surfaceLight = Colors.white;         // Fundo de cards e modais
  
  static const Color backgroundDark = Color(0xFF121212);  // Fundo escuro (Dark Mode)
  static const Color surfaceDark = Color(0xFF1E1E1E);     // Cards no Dark Mode

  // ==========================================
  // 4. GERAÇÃO DE COLOR SCHEME (MATERIAL 3)
  // ==========================================
  
  /// Tema Claro
  static ColorScheme lightScheme() => ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        background: backgroundLight,
        surface: surfaceLight,
        error: error,
        brightness: Brightness.light,
      );

  /// Tema Escuro
  static ColorScheme darkScheme() => ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        background: backgroundDark,
        surface: surfaceDark,
        error: error,
        brightness: Brightness.dark,
      );
}