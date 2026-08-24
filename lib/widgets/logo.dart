import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ported 1:1 from the web app's Logo.jsx.
///
/// - The signal-glyph SVG is rendered via flutter_svg from the exact
///   same markup as the React version (converted from JSX camelCase
///   attributes to standard SVG kebab-case), not a hand-reconstructed
///   CustomPainter, since the glyph's 4 concentric arcs are non-trivial
///   to derive correctly without being able to visually verify the
///   result.
/// - The wordmark uses Poppins SemiBold (weight 600), matching the
///   original design system doc's note that this is deliberately
///   different from the app-wide Manrope body font.
///
/// Props match the React component:
///  - compact: true  -> glyph only (collapsed sidebar / favicon-style)
///  - compact: false -> full "eye <glyph> ty" lockup
///  - size:    wordmark text size in logical px (default 32); the glyph
///             scales proportionally, same ratios as the React version.
class Logo extends StatelessWidget {
  final bool compact;
  final double size;

  const Logo({super.key, this.compact = false, this.size = 32});

  static const _svgMarkup = '''
<svg viewBox="0 0 42 32" xmlns="http://www.w3.org/2000/svg">
  <circle cx="21" cy="16" r="5.6" fill="#D29A4A" />
  <g stroke="#D29A4A" stroke-width="3.4" fill="none" stroke-linecap="round">
    <path d="M13.5 7.5 A11.5 11.5 0 0 0 13.5 24.5" />
    <path d="M8.5 3.5 A17.5 17.5 0 0 0 8.5 28.5" />
    <path d="M28.5 7.5 A11.5 11.5 0 0 1 28.5 24.5" />
    <path d="M33.5 3.5 A17.5 17.5 0 0 1 33.5 28.5" />
  </g>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    // Same proportions as the React version's inline math:
    // glyphHeight = size * 0.95, glyphWidth = glyphHeight * 1.31
    // (1.31 ~= the SVG viewBox's own 42:32 aspect ratio).
    final glyphHeight = size * 0.95;
    final glyphWidth = glyphHeight * 1.31;
    final compactGlyphHeight = size * 1.15;
    final compactGlyphWidth = compactGlyphHeight * 1.31;

    final finalGlyphHeight = compact ? compactGlyphHeight : glyphHeight;
    final finalGlyphWidth = compact ? compactGlyphWidth : glyphWidth;

    final glyph = SvgPicture.string(
      _svgMarkup,
      width: finalGlyphWidth,
      height: finalGlyphHeight,
    );

    final content = compact
        ? Center(child: glyph)
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'eye',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: size,
                  color: const Color(0xFFF5F7FA),
                  letterSpacing: size * 0.01,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Transform.translate(
                  // Matches the React version's transform: translateY(5%)
                  // on the glyph wrapper - 5% of the glyph's OWN height,
                  // per CSS's percentage-transform spec.
                  offset: Offset(0, finalGlyphHeight * 0.05),
                  child: glyph,
                ),
              ),
              Text(
                'ty',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: size,
                  color: const Color(0xFFF5F7FA),
                  letterSpacing: size * 0.01,
                  height: 1,
                ),
              ),
            ],
          );

    return Semantics(
      label: 'Eyeoty',
      child: content,
    );
  }
}