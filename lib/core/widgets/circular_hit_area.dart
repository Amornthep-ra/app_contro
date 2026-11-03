import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Takes touches only inside a circle of [radius] around its centre, and
/// every touch inside it (even where its child paints nothing).
///
/// Touches outside the circle are not claimed, so they reach whatever is
/// underneath (for example a neighbouring control whose box overlaps).
class CircularHitArea extends SingleChildRenderObjectWidget {
  const CircularHitArea({super.key, required this.radius, super.child});

  final double radius;

  @override
  RenderCircularHitArea createRenderObject(BuildContext context) =>
      RenderCircularHitArea(radius);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCircularHitArea renderObject,
  ) {
    renderObject.radius = radius;
  }
}

class RenderCircularHitArea extends RenderProxyBox {
  RenderCircularHitArea(this.radius);

  double radius;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if ((position - size.center(Offset.zero)).distance > radius) return false;
    return super.hitTest(result, position: position);
  }

  @override
  bool hitTestSelf(Offset position) => true;
}
