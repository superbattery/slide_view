library slide_view;

import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// A SlideView.
class SlideView extends StatefulWidget {
  const SlideView({
    super.key,
    required this.child,
    this.background,
    this.duration,
    this.cubic,
    this.collapsedHeight = 70,
    this.onChange,
  });

  final Widget child;
  final Widget? background;
  final Duration? duration;
  final Cubic? cubic;
  final double collapsedHeight;
  final void Function(bool isOpen)? onChange;

  @override
  State<StatefulWidget> createState() => SlideViewState();
}

class SlideViewState extends State<SlideView> with TickerProviderStateMixin {
  late AnimationController _ac;
  late CurvedAnimation _curved;

  /// 效果
  static const Cubic _cubic = Curves.easeOutExpo;

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
  Offset _offset = Offset.zero;

  /// copy of the offset, 跨函数计算用
  Offset _offsetSnapshot = Offset.zero;

  /// 按下的全局坐标
  Offset? _dragDownPos;

  /// 动画效果是否向上滑动
  bool _animTargetDirection = true;

  /// 抽屉的状态
  bool isOpen = false;

  ///
  void Function(void Function())? _setStateInner;

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
      curve: widget.cubic ?? _cubic,
    )..addListener(() {
        _setStateInner?.call(() {
          var leftDistance = _animTargetDirection
              ? _offsetSnapshot.dy
              : (height - widget.collapsedHeight) - _offsetSnapshot.dy;
          _offset = Offset(
              _offsetSnapshot.dx,
              _offsetSnapshot.dy +
                  (_animTargetDirection ? -leftDistance : leftDistance) *
                      _curved.value);

          //百分比, 用于同步计算其它效果
          var percent = 1 - _offset.dy / (height - widget.collapsedHeight);
          //TODO: 背景透明度
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
        _offset = Offset(0.0, isOpen ? 0.0 : height - widget.collapsedHeight);
        //无论setState是否为空都在它外面进行赋值操作
        //避免setState为空时赋值操作未被执行
        _setStateInner?.call(() {});
      });
      return Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: widget.collapsedHeight),
            child: widget.background,
          ),
          StatefulBuilder(builder: ((context, setState) {
            _setStateInner = setState;
            return Transform.translate(
              offset: Offset(0.0, _offset.dy),
              //`Transform.translate`的`child`默认会被expand,
              //如有需要, 这里可以指定alignment和size
              child: SizedBox(
                child: GestureDetector(
                  onVerticalDragDown: _handleOnVDragDown,
                  onVerticalDragUpdate: _handleOnVDragUpdate,
                  onVerticalDragEnd: _handleOnVDragEnd,
                  child: widget.child,
                ),
              ),
            );
          })),
        ],
      );
    }));
  }

  Future<void> change(bool opening) async {
    if (this.isOpen == opening) {
      return;
    }
    _animTargetDirection = opening;
    _ac.duration = widget.duration ?? defaultDuration;
    _offsetSnapshot = _offset;
    try {
      await _ac.forward(from: 0.0).orCancel;
      if (isOpen == _animTargetDirection) {
        return;
      }
      isOpen = _animTargetDirection;
      widget.onChange?.call(isOpen);
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
      _offset = Offset(
          _offset.dx, max(0, min(height - widget.collapsedHeight, _offset.dy)));

      //百分比, 用于同步计算其它效果
      var percent = 1 - _offset.dy / (height - widget.collapsedHeight);

      //TODO: 背景透明度
    });
  }

  void _handleOnVDragEnd(DragEndDetails details) {
    var velocity = details.primaryVelocity ?? 0.0;
    _animTargetDirection = () {
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
      if (isOpen != _animTargetDirection) {
        isOpen = _animTargetDirection;
        widget.onChange?.call(isOpen);
      }
    }).catchError((err) {
      //print("anim canceled");
    });
  }
}