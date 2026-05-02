import 'package:flutter/material.dart';
import 'dart:io';

// Widget personalizado para exibir imagens de receitas de forma consistente
class RecipeImageWidget extends StatelessWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;
  final double fallbackIconSize;
  final Color? fallbackIconColor;
  final BorderRadius? borderRadius;
  
  // Construtor do widget de imagem
  const RecipeImageWidget({
    super.key,
    this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover, // Valor padrão para ajuste da imagem
    this.fallbackIcon = Icons.restaurant, // Ícone padrão
    this.fallbackIconSize = 64, // Tamanho padrão do ícone
    this.fallbackIconColor,
    this.borderRadius,
  });

  // Método privado que constrói o widget de fallback (quando não há imagem)
  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200], 
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Icon(
          fallbackIcon,
          size: fallbackIconSize,
          color: fallbackIconColor ?? Colors.grey[400],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Verifica se não há caminho de imagem especificado
    if (imagePath == null || imagePath!.isEmpty) {
      return _buildFallback();
    }

    final isAsset = imagePath!.startsWith('assets/');

    // Constrói o widget com a imagem
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(borderRadius: borderRadius),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: isAsset ? Image.asset(
          imagePath!, // Carrega a imagem do asset
          width: width,
          height: height,
          fit: fit,
          cacheWidth: 800,
          filterQuality: FilterQuality.medium,
          // Define o que fazer quando há erro ao carregar a imagem
          errorBuilder: (context, error, stackTrace) {
            return _buildFallback();
          },
        ) : Image.file(
          File(imagePath!), // Carrega a imagem do arquivo
          width: width,
          height: height,
          fit: fit,
          cacheWidth: 800, // Limite confortável para qualidade
          filterQuality: FilterQuality.medium, // Reduz serrilhado/granulação
          errorBuilder: (context, error, stackTrace) {
            return _buildFallback();
          },
        ),
      ),
    );
  }
}
