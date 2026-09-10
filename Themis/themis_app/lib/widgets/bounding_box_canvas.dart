import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/compliance_report.dart';
import '../services/glass_perf_service.dart';
import '../theme/glass_theme.dart';
import '../theme/sober_theme.dart';

class BoundingBoxCanvas extends StatefulWidget {
  final File imageFile;
  final List<OcrToken> tokens;
  final Function(OcrToken)? onTokenSelected;
  final int? panelIndex;
  final int? totalPanels;
  final VoidCallback? onPreviousPanel;
  final VoidCallback? onNextPanel;

  const BoundingBoxCanvas({
    super.key,
    required this.imageFile,
    required this.tokens,
    this.onTokenSelected,
    this.panelIndex,
    this.totalPanels,
    this.onPreviousPanel,
    this.onNextPanel,
  });

  @override
  State<BoundingBoxCanvas> createState() => _BoundingBoxCanvasState();
}

class _BoundingBoxCanvasState extends State<BoundingBoxCanvas> {
  Size? _imageNaturalSize;
  OcrToken? _selectedToken;
  bool _showBoxes = true;

  @override
  void initState() {
    super.initState();
    _resolveImageSize();
  }

  @override
  void didUpdateWidget(covariant BoundingBoxCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageFile.path != widget.imageFile.path) {
      _resolveImageSize();
    }
  }

  void _resolveImageSize() {
    final image = Image.file(widget.imageFile);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _imageNaturalSize = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            );
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sober: saffron evidence boxes (reference red). Toggle rebuilds the
    // painter; the image itself stays cached.
    return ListenableBuilder(
      listenable: GlassPerfService.instance,
      builder: (context, _) {
        final sober = GlassPerfService.instance.soberMode;
        return _buildBody(sober);
      },
    );
  }

  Widget _buildBody(bool sober) {
    if (_imageNaturalSize == null) {
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: GlassTheme.glassSurfaceLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: GlassTheme.borderAmbient),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: SoberTheme.swap(GlassTheme.bgNeonCyan, sober),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xCC090A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: GlassTheme.borderHighlight.withValues(alpha: 0.3)),
        ),
        child: Stack(
          children: [
            // Interactive Zoom / Pan Viewport
            InteractiveViewer(
              minScale: 1.0,
              maxScale: 6.0,
              boundaryMargin: const EdgeInsets.all(20),
              child: Center(
                child: AspectRatio(
                  aspectRatio: _imageNaturalSize!.width / _imageNaturalSize!.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        widget.imageFile,
                        fit: BoxFit.contain,
                      ),
                      if (_showBoxes)
                        CustomPaint(
                          painter: _BBoxPainter(
                            tokens: widget.tokens,
                            naturalSize: _imageNaturalSize!,
                            selectedToken: _selectedToken,
                            sober: sober,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Top overlay bar: box toggle and selected token chip
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xB30E1026),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: GlassTheme.borderHighlight.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      '${widget.tokens.length} TOKENS DETECTED',
                      style: const TextStyle(
                        color: GlassTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (widget.totalPanels != null && widget.totalPanels! > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xB30E1026),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: GlassTheme.borderHighlight.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.chevron_left, size: 12, color: Colors.white),
                            onPressed: widget.onPreviousPanel,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            splashRadius: 14,
                            tooltip: 'Previous panel',
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'PANEL ${(widget.panelIndex ?? 0) + 1}/${widget.totalPanels}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.chevron_right, size: 12, color: Colors.white),
                            onPressed: widget.onNextPanel,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                            splashRadius: 14,
                            tooltip: 'Next panel',
                          ),
                        ],
                      ),
                    ),
                  InkWell(
                    onTap: () => setState(() => _showBoxes = !_showBoxes),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xB30E1026),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: GlassTheme.borderHighlight.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.viewfinder,
                            color: SoberTheme.swap(
                                GlassTheme.bgNeonCyan, sober),
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _showBoxes ? 'HIDE BOXES' : 'SHOW BOXES',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BBoxPainter extends CustomPainter {
  final List<OcrToken> tokens;
  final Size naturalSize;
  final OcrToken? selectedToken;
  final bool sober;

  _BBoxPainter({
    required this.tokens,
    required this.naturalSize,
    this.selectedToken,
    this.sober = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (naturalSize.width == 0 || naturalSize.height == 0) return;

    final scaleX = size.width / naturalSize.width;
    final scaleY = size.height / naturalSize.height;

    final boxBase = SoberTheme.swap(GlassTheme.bgNeonCyan, sober);
    final defaultBoxPaint = Paint()
      ..color = boxBase.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final defaultFillPaint = Paint()
      ..color = boxBase.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    final selectedBoxPaint = Paint()
      ..color = boxBase
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final selectedFillPaint = Paint()
      ..color = boxBase.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    for (final token in tokens) {
      final rect = Rect.fromLTWH(
        token.bbox.x * scaleX,
        token.bbox.y * scaleY,
        token.bbox.width * scaleX,
        token.bbox.height * scaleY,
      );

      final isSelected = selectedToken == token;
      canvas.drawRect(rect, isSelected ? selectedBoxPaint : defaultBoxPaint);
      canvas.drawRect(rect, isSelected ? selectedFillPaint : defaultFillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BBoxPainter oldDelegate) {
    return oldDelegate.tokens != tokens ||
        oldDelegate.selectedToken != selectedToken ||
        oldDelegate.sober != sober ||
        oldDelegate.naturalSize != naturalSize;
  }
}
