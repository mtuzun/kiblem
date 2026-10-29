import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Çocuğu verilen genişlikte yerleştirir; yüksekliği [maxHeight]'ı aşarsa içeriği oranlı
/// (yazılar, kutular, boşluklar birlikte) küçültür. Küçültme sırasında çocuğa daha geniş yer
/// verilir (genişlik / ölçek), böylece satır sayısı da azalır ve ekranın yarısı boşa gitmez.
class FitHeight extends SingleChildRenderObjectWidget {
  final double maxHeight;
  final double minScale;
  const FitHeight({super.key, required this.maxHeight, this.minScale = 0.55, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderFitHeight(maxHeight, minScale);

  @override
  void updateRenderObject(BuildContext context, RenderFitHeight renderObject) {
    renderObject
      ..maxHeight = maxHeight
      ..minScale = minScale;
  }
}

class RenderFitHeight extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  RenderFitHeight(this._maxHeight, this._minScale);

  double _maxHeight;
  double _minScale;
  double _scale = 1;

  double get scale => _scale;

  set maxHeight(double v) {
    if (v == _maxHeight) return;
    _maxHeight = v;
    markNeedsLayout();
  }

  set minScale(double v) {
    if (v == _minScale) return;
    _minScale = v;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(double width) => BoxConstraints(minWidth: width, maxWidth: width);

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    final w = constraints.hasBoundedWidth ? constraints.maxWidth : constraints.minWidth;
    c.layout(_childConstraints(w), parentUsesSize: true);
    var h = c.size.height;
    _scale = 1;
    if (h > _maxHeight && _maxHeight > 0) {
      final s = (_maxHeight / h).clamp(_minScale, 1.0);
      // Çocuk daha geniş yerde yeniden yerleşir (w / s); ölçekle çarpılınca yine w genişliğe oturur.
      c.layout(_childConstraints(w / s), parentUsesSize: true);
      _scale = s;
      h = c.size.height;
    }
    size = constraints.constrain(Size(w, h * _scale));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null) return;
    if (_scale == 1) {
      context.paintChild(c, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.diagonal3Values(_scale, _scale, 1),
      (context, offset) => context.paintChild(c, offset),
      oldLayer: layer as TransformLayer?,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(Matrix4.diagonal3Values(_scale, _scale, 1));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    return result.addWithPaintTransform(
      transform: Matrix4.diagonal3Values(_scale, _scale, 1),
      position: position,
      hitTest: (result, position) => c.hitTest(result, position: position),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) => child?.getMinIntrinsicHeight(width) ?? 0;
  @override
  double computeMaxIntrinsicHeight(double width) => child?.getMaxIntrinsicHeight(width) ?? 0;
  @override
  double computeMinIntrinsicWidth(double height) => child?.getMinIntrinsicWidth(height) ?? 0;
  @override
  double computeMaxIntrinsicWidth(double height) => child?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final c = child;
    if (c == null) return constraints.smallest;
    final w = constraints.hasBoundedWidth ? constraints.maxWidth : constraints.minWidth;
    final h = c.getDryLayout(_childConstraints(w)).height;
    final s = (h > _maxHeight && _maxHeight > 0) ? (_maxHeight / h).clamp(_minScale, 1.0) : 1.0;
    final h2 = s == 1 ? h : c.getDryLayout(_childConstraints(w / s)).height;
    return constraints.constrain(Size(w, h2 * s));
  }
}
