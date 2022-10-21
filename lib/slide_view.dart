library slide_view;

import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// A SlideView.
class SlideView extends StatefulWidget {
  const SlideView({
    super.key,
    required this.child,
    this.collapsedChild,
    this.background,
    this.duration,
    this.curve,
    this.collapsedHeight = 70,
    this.onChange,
  });

  final Widget child;
  final Widget? collapsedChild;
  final Widget? background;
  final Duration? duration;
  final Curve? curve;
  final double collapsedHeight;
  final void Function(bool isOpen)? onChange;

  @override
  State<StatefulWidget> createState() => SlideViewState();
}

class SlideViewState extends State<SlideView> with TickerProviderStateMixin {
  late AnimationController _ac;
  late CurvedAnimation _curved;

  /// 效果
  static const Cubic _curve = Curves.easeOutExpo;

  /// 标准的滑动效果时长,
  /// 且该时长下的滑动效果是最缓慢的了, 再慢
  /// 就感觉不真实
  ///
  /// 该时长仅适用于以上定义的默认效果,
  /// 其它效果可能不自然
  static const Duration defaultDuration = Duration(milliseconds: 600);

  /// height of this view
  late double height;

  /// offset of this view
  /// only y is valid
  ///
  /// 初始值无效, 因为此时无法获取高度来计算它
  Offset _offset = Offset.zero;

  /// copy of the offset, 跨函数计算用
  Offset _offsetSnapshot = Offset.zero;

  /// 按下的全局坐标
  Offset? _dragDownPos;

  /// 是否希望偏移值设为原点, 即希望动画效果是否向上滑动,
  /// 否则向下滑动
  bool _wantOffsetZero = true;

  /// 当前的偏移值是否为原点, 即当前抽屉的状态为打开,
  /// 否则抽屉状态为关闭
  bool _isCurOffsetZero = false;

  ///
  void Function(void Function())? _setStateInner;

  /// max offset allowed
  double _maxOffsetY() => height - widget.collapsedHeight;

  /// 当前偏移量与原点的距离的百分比值,
  /// range: 0.0-1.0
  ///
  /// 可用于同步计算其它动画效果等
  Offset _offsetPercentage() => Offset(0.0, _offset.dy / _maxOffsetY());

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: widget.duration ?? defaultDuration,
      value: 0.0,
    );

    _curved = CurvedAnimation(
      parent: _ac,
      curve: widget.curve ?? _curve,
    )..addListener(() {
        _setStateInner?.call(() {
          var leftDistance = _wantOffsetZero
              ? _offsetSnapshot.dy
              : _maxOffsetY() - _offsetSnapshot.dy;
          _offset = Offset(
              _offsetSnapshot.dx,
              _offsetSnapshot.dy +
                  (_wantOffsetZero ? -leftDistance : leftDistance) *
                      _curved.value);
        });
      });
    //height = MediaQuery.of(context).size.height;
  }

  @override
  void dispose() {
    _curved.dispose();
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: ((context, p1) {
      //这里可能会被调用多次, 且前几次获取到的height值可能不是最新的,
      //比如可能为0
      height = p1.biggest.height;
      //每次height值改变即更新
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        //initialize the offset
        _offset = Offset(0.0, _isCurOffsetZero ? 0.0 : _maxOffsetY());
        //无论setState是否为空都在它外面进行赋值操作
        //避免setState为空时赋值操作未被执行
        _setStateInner?.call(() {});
      });

      var slidePanel = StatefulBuilder(builder: ((context, setState) {
        _setStateInner = setState;
        var offsetPercentage = _offsetPercentage();
        //collapsed view
        var collapsedView = SizedBox(
          height: widget.collapsedHeight,
          child: IgnorePointer(
            ignoring: offsetPercentage.dy == 0.0,
            child: Opacity(
              opacity: offsetPercentage.dy,
              child: widget.collapsedChild,
            ),
          ),
        );

        return Transform.translate(
          offset: Offset(0.0, _offset.dy),
          //`Transform.translate`的`child`默认会被expand,
          //如有需要, 这里可以指定alignment和size
          child: SizedBox(
            child: GestureDetector(
              onVerticalDragDown: _handleOnVDragDown,
              onVerticalDragUpdate: _handleOnVDragUpdate,
              onVerticalDragEnd: _handleOnVDragEnd,
              child: Stack(children: [
                widget.child,
                Align(
                  alignment: Alignment.topCenter,
                  child: collapsedView,
                ),
              ]),
            ),
          ),
        );
      }));

      return Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: widget.collapsedHeight),
            child: widget.background,
          ),
          slidePanel,
        ],
      );
    }));
  }

  /// 改变抽屉的状态
  ///
  /// 若当前抽屉状态已处于目标状态, 则不做任何事.
  /// 否则取消当前正在进行的动画, 并改变抽屉为目标状态
  ///
  /// 返回的Future得到值后代表动画结束, 已改变抽屉为目标状态,
  /// 或者当前的动画被取消, 抽屉状态未知
  Future<void> change(bool opening) async {
    // ignore: unnecessary_this
    if (this._isCurOffsetZero == _wantOffsetZero &&
        this._isCurOffsetZero == opening) {
      return;
    }
    _wantOffsetZero = opening;
    _ac.duration = widget.duration ?? defaultDuration;
    _offsetSnapshot = _offset;
    try {
      await _ac.forward(from: 0.0).orCancel;
      if (_isCurOffsetZero == _wantOffsetZero) {
        return;
      }
      _isCurOffsetZero = _wantOffsetZero;
      widget.onChange?.call(_isCurOffsetZero);
    } catch (err) {
      //print("anim canceled");
    }
  }

  void _handleOnVDragDown(DragDownDetails details) {
    _ac.stop();
    _dragDownPos = details.globalPosition;
    _offsetSnapshot = _offset;
  }

  void _handleOnVDragUpdate(DragUpdateDetails details) {
    if (_dragDownPos == null) {
      return;
    }
    _setStateInner?.call(() {
      //抽屉位置
      _offset = _offsetSnapshot + (details.globalPosition - _dragDownPos!);
      //限定y分量值
      _offset = Offset(_offset.dx, max(0, min(_maxOffsetY(), _offset.dy)));
    });
  }

  void _handleOnVDragEnd(DragEndDetails details) {
    var velocity = details.primaryVelocity ?? 0.0;
    _wantOffsetZero = () {
      if (velocity < 0) {
        return true;
      } else if (velocity > 0) {
        return false;
      } else {
        return _offset.dy <= height * 0.5;
      }
    }();
    _ac.duration = () {
      if (velocity == 0) {
        return widget.duration ?? defaultDuration;
      } else {
        return Duration(
            milliseconds: (widget.duration ?? defaultDuration).inMilliseconds ~/
                max(1, velocity.abs() / 1000));
      }
    }();
    _offsetSnapshot = _offset;
    _ac.forward(from: 0.0).orCancel.then((value) {
      if (_isCurOffsetZero != _wantOffsetZero) {
        _isCurOffsetZero = _wantOffsetZero;
        widget.onChange?.call(_isCurOffsetZero);
      }
    }).catchError((err) {
      //print("anim canceled");
    });
  }
}
