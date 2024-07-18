library dart_svgplot;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';


class SvgGraphFigure {
  final Rect absoluteGeometry;
  final List<SvgGraphAxis> axes = [];
  final SvgGraphUnit lengthUnit;
  final Map<String, String> style = {
    'fill': '#ffffff',
    'stroke': 'none'
  };

  SvgGraphFigure({
    required this.absoluteGeometry,
    this.lengthUnit = SvgGraphUnit.millimeter,
    Map<String, String> style = const {}
  }) {
    this.style.addAll(style);
  }

  SvgGraphAxis axis(
    {
      Rect relativePosition = const Rect.fromLTRB(0.15, 0.05, 0.95, 0.85),
      TickLabelGenerator xTickLabelGenerator = _defaultTickLabelGenerator,
      TickLabelGenerator yTickLabelGenerator = _defaultTickLabelGenerator,
      TickLabelGenerator? topAxisTickLabelGenerator,
      TickLabelGenerator? rightAxisTickLabelGenerator,
      Map<String, String> style = const {},
      bool boxed = true,
      bool grid = false,
      Map<String, String> labelTextStyle = const {},
      Map<String, String> tickLabelTextStyle = const {},
      String xlabel = '',
      String ylabel = '',
      Point xlabelRelativePosition = const Point(0.55, 0.95),
      Point ylabelRelativePosition = const Point(0.05, 0.45),
    }
  ){
    final axis = SvgGraphAxis(this);
    axis.relativePositionInFigure = relativePosition;
    axis.bottomAxisTickLabelGenerator = xTickLabelGenerator;
    axis.leftAxisTickLabelGenerator = yTickLabelGenerator;
    axis.topAxisTickLabelGenerator = topAxisTickLabelGenerator;
    axis.rightAxisTickLabelGenerator = rightAxisTickLabelGenerator;
    axis.style.addAll(style);
    axis.boxed = boxed;
    axis.grid = grid;
    axis.labelTextStyle.addAll(labelTextStyle);
    axis.tickLabelTextStyle.addAll(tickLabelTextStyle);
    axis.xlabel = xlabel;
    axis.ylabel = ylabel;
    axis.xlabelRelativePositionInFigure = xlabelRelativePosition;
    axis.ylabelRelativePositionInFigure = ylabelRelativePosition;
    axes.add(axis);
    return axis;
  }

  XmlDocument toSvgXml(){
    final builder = XmlBuilder();
    final tagGenerator = SvgTagGenerator();
    builder.processing('xml', 'version="1.0" encoding="UTF-8" standalone="no"');
    builder.element(
      'svg', 
      attributes: {
        'width': '${absoluteGeometry.width}$lengthUnit',
        'height': '${absoluteGeometry.height}$lengthUnit',
        'viewBox': '${absoluteGeometry.topLeft.dx} ${absoluteGeometry.topLeft.dy} ${absoluteGeometry.width} ${absoluteGeometry.height}',

        'version': "1.1",
        'id': tagGenerator.newTag('svg'),
        'sodipodi:docname': "test.svg",
        'xmlns:sodipodi': "http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd",
        'xmlns': "http://www.w3.org/2000/svg",
        'xmlns:svg': "http://www.w3.org/2000/svg",
      },
      nest: () {
        builder.element(
          'rect', 
          attributes: {
            'id': tagGenerator.newTag('rect'),
            'width': '${absoluteGeometry.width}',
            'height': '${absoluteGeometry.height}',
            'x': '${absoluteGeometry.topLeft.dx}',
            'y': '${absoluteGeometry.topLeft.dy}',
            'vector-effect': "non-scaling-stroke",
            'style': asCssString(style),
          }
        );
        builder.element(
          'sodipodi:namedview',
          attributes: {
            "id": tagGenerator.newTag('namedview'),
            "pagecolor": "#ffffff",
            "bordercolor": "#000000",
            "borderopacity": "0.25",
          }
        );
        builder.element(
          'defs',
          attributes: {
            "id": tagGenerator.newTag('defs'),
          },
          nest: () {
            for (final axis in axes){
              axis.buildDefsXml(builder, tagGenerator);
            }
          }
        );
        builder.element(
          'g',
          attributes: {
            "id": "layer1",
          },
          nest: () {
            for (final axis in axes){
              axis.buildXml(builder, tagGenerator);
            }
          }
        );
      }
    );
    return builder.buildDocument();
  }
}

enum SvgGraphUnit {
  cantimeter('cm'),
  millimeter('mm'),
  inch('in'),
  em('em'),
  ex('ex'),
  point('pt'),
  pica('mm'),
  pixel('px');
  
  final String string;

  const SvgGraphUnit(this.string);

  @override
  String toString() => string;
}

String _defaultTickLabelGenerator(double value, AxisInfo ax) {
  const smallShift = 0.1;
  final span = ax.max - ax.min;
  final exponenta = (log(span) / ln10 + smallShift).floor();
  int digitsAfterComma = -exponenta + 1;
  return value.toStringAsFixed(digitsAfterComma > 0 ? digitsAfterComma : 0);
}

typedef TickLabelGenerator = String Function(double value, AxisInfo ax);

class SvgGraphAxis {
  final SvgGraphFigure parent;
  Rect relativePositionInFigure = const Rect.fromLTRB(0.15, 0.05, 0.95, 0.85);
  List<SvgGraphPlot> plots = [];
  Map<String, String> style = {
    'fill': 'none',
    'stroke': '#000000',
    'stroke-width': '0.5pt',
    'stroke-dasharray': 'none',
    'stroke-opacity': '1',
  };
  
  TickLabelGenerator? topAxisTickLabelGenerator;
  TickLabelGenerator? bottomAxisTickLabelGenerator = _defaultTickLabelGenerator;
  TickLabelGenerator? leftAxisTickLabelGenerator = _defaultTickLabelGenerator;
  TickLabelGenerator? rightAxisTickLabelGenerator;
  
  bool xAxisAutoSet = true;
  bool yAxisAutoSet = true;

  bool boxed = true;
  bool grid = false;
  bool xAxisTight = true;
  bool yAxisTight = true;

  double xmin = double.infinity;
  double xmax = double.negativeInfinity;
  double ymin = double.infinity;
  double ymax = double.negativeInfinity;
  Rect get dataUnitsGeometry => Rect.fromLTRB(xmin, ymin, xmax, ymax);

  String? _clipPathTag;


  List<double> xTicks = [];
  List<double> yTicks = [];

  TickPositionGenerator xTickPositionGenerator = TickPositionGenerators.goodIntervals();
  TickPositionGenerator yTickPositionGenerator = TickPositionGenerators.goodIntervals();

  String xlabel = '';
  String ylabel = '';

  Point xlabelRelativePositionInFigure = const Point(0.55, 0.02);
  Point ylabelRelativePositionInFigure = const Point(0.45, 0.02);

  Map<String, String> labelTextStyle = {};
  Map<String, String> tickLabelTextStyle = {};


  SvgGraphAxis(this.parent);

  void plot(
    List<Point> data,
    {
      bool lines = true,
      SvgGraphMarker? marker,
      Map<String, String> lineStyle = const {},
      Map<String, String> markerStyle = const {
        'fill': '#000000',
        'stroke': '#000000',
        'stroke-width': '0.5pt',
        'stroke-dasharray': 'none',
        'stroke-opacity': '1',
      },
    }
  ){
    if (xAxisAutoSet) {
      final xFinite = data.map((e) => e.x).where((e) => e.isFinite);
      if (xFinite.isNotEmpty) {
        autoSetXLimits(xFinite.reduce(min), xFinite.reduce(max));
      }
    }
    if (yAxisAutoSet) {
      final yFinite = data.map((e) => e.y).where((e) => e.isFinite);
      if (yFinite.isNotEmpty) {
        autoSetYLimits(yFinite.reduce(min), yFinite.reduce(max));
      }
    }

    final List<SvgGraphPoint> processedPoints =
      data
      .map((Point pointInCanvas) =>
        SvgGraphPoint(
          pointInCanvas,
          marker: marker,
          style: markerStyle,
        )
      )
      .toList();
    final newPlot = SvgGraphPlot(
      parent: this,
      dataPoints: processedPoints, 
    );
    newPlot.style.addAll(lineStyle);
    plots.add(newPlot);
  }

  void autoSetXLimits(num xmin, num xmax){
    if (xmin == xmax && this.xmin.isInfinite) {
      if (xmax == 0 || xmax.isNaN) {
        this.xmin = -1.0;
        this.xmax = 1.0;
      } else if (xmax < 0) {
        this.xmin = xmax * 0.8;
        this.xmax = xmax * 1.2;
      } else {
        this.xmin = xmax * 1.2;
        this.xmax = xmax * 0.8;
      }
    } else {
      this.xmin = (this.xmin > xmin ? xmin : this.xmin).toDouble();
      this.xmax = (this.xmax < xmin ? xmax : this.xmax).toDouble();
    }
    xTicks = xTickPositionGenerator(AxisInfo(min: this.xmin, max: this.xmax));
  }

  void autoSetYLimits(num ymin, num ymax){
    if (ymin == ymax && this.ymin.isInfinite) {
      if (ymax == 0 || ymax.isNaN) {
        this.ymin = -1.0;
        this.ymax = 1.0;
      } else if (ymax < 0) {
        this.ymin = ymax * 1.2;
        this.ymax = ymax * 0.8;
      } else {
        this.ymin = ymax * 0.8;
        this.ymax = ymax * 1.2;
      }
    } else {
      this.ymin = (this.ymin > ymin ? ymin : this.ymin).toDouble();
      this.ymax = (this.ymax < ymin ? ymax : this.ymax).toDouble();
    }
    yTicks = yTickPositionGenerator(AxisInfo(min: this.ymin, max: this.ymax));
  }

  void buildXml(XmlBuilder builder, SvgTagGenerator tagGenerator){
    // box
    builder.element(
      'rect', 
      attributes: {
        'id': tagGenerator.newTag('rect'),
        'width': '${relativePositionInFigure.relativeTo(parent.absoluteGeometry).width}',
        'height': '${relativePositionInFigure.relativeTo(parent.absoluteGeometry).height}',
        'x': '${relativePositionInFigure.relativeTo(parent.absoluteGeometry).topLeft.dx}',
        'y': '${relativePositionInFigure.relativeTo(parent.absoluteGeometry).topLeft.dy}',
        'vector-effect': "non-scaling-stroke",
        'style': asCssString(style)
      }
    );

    const double tickSize = 5;
    const TickDirection dir = TickDirection.inward;
    
    for (double tick in xTicks){
      drawTickXml(builder, tagGenerator, tick, axisSide: AxisSide.bottom, tickDirection: dir, tickSize: tickSize, labelTextGenerator: bottomAxisTickLabelGenerator);
      drawTickXml(builder, tagGenerator, tick, axisSide: AxisSide.top, tickDirection: dir, tickSize: tickSize, labelTextGenerator: topAxisTickLabelGenerator);
    }

    for (double tick in yTicks){
      drawTickXml(builder, tagGenerator, tick, axisSide: AxisSide.left, tickDirection: dir, tickSize: tickSize, labelTextGenerator: leftAxisTickLabelGenerator);
      drawTickXml(builder, tagGenerator, tick, axisSide: AxisSide.right, tickDirection: dir, tickSize: tickSize, labelTextGenerator: rightAxisTickLabelGenerator);
    }

    final xlabelAbsolutePosition = parent.absoluteGeometry.getAbsolutePosition(xlabelRelativePositionInFigure);
    final ylabelAbsolutePosition = parent.absoluteGeometry.getAbsolutePosition(ylabelRelativePositionInFigure);
    builder.element(
      'text', 
      attributes: {
        'id': tagGenerator.newTag('text'),
        'x': '${xlabelAbsolutePosition.x}',
        'y': '${xlabelAbsolutePosition.y}',
        'style': asCssString(labelTextStyle),
        'vector-effect': "non-scaling-stroke",
        'xml-space': 'preserve'
      },
      nest: () {
        builder.element(
          'tspan',
          attributes: {
            'id': tagGenerator.newTag('tspan'),
            'x': '${xlabelAbsolutePosition.x}',
            'y': '${xlabelAbsolutePosition.y}',
            'vector-effect': "non-scaling-stroke",
            'xml-space': 'preserve',
            'dominant-baseline': 'middle',
            'text-anchor': 'middle',
          },
          nest: () {
            builder.text(xlabel);
          }
        );
      }
    );

    builder.element(
      'text', 
      attributes: {
        'id': tagGenerator.newTag('text'),
        'x': '${ylabelAbsolutePosition.x}',
        'y': '${ylabelAbsolutePosition.y}',
        'style': asCssString(labelTextStyle),
        'vector-effect': "non-scaling-stroke",
        'xml-space': 'preserve',
        'transform': 'rotate(-90, ${ylabelAbsolutePosition.x}, ${ylabelAbsolutePosition.y})',
      },
      nest: () {
        builder.element(
          'tspan',
          attributes: {
            'id': tagGenerator.newTag('tspan'),
            'x': '${ylabelAbsolutePosition.x}',
            'y': '${ylabelAbsolutePosition.y}',
            'vector-effect': "non-scaling-stroke",
            'xml-space': 'preserve',
            'dominant-baseline': 'middle',
            'text-anchor': 'middle',
          },
          nest: () {
            builder.text(ylabel);
          }
        );
      }
    );
    
    
    // plots
    for (final plot in plots) {
      plot.buildXml(builder, tagGenerator);
    }
  }

  void drawTickXml(
    XmlBuilder builder,
    SvgTagGenerator tagGenerator,
    num where,
    { 
      required AxisSide axisSide,
      TickDirection tickDirection = TickDirection.inward,
      double tickSize = 2,
      double tickToLabelDistance = 5,
      TickLabelGenerator? labelTextGenerator
  }){
    AxisInfo axisInfo = switch (axisSide) {
      AxisSide.top || AxisSide.bottom => AxisInfo(min: xmin, max: xmax),
      AxisSide.left || AxisSide.right => AxisInfo(min: ymin, max: ymax),
    };
    // Rect canvasInDataUnits = Rect.fromLTRB(xmin, ymin, xmax, ymax);
    Point tickPoint = switch (axisSide) {
      AxisSide.top => Point(where, ymax),  
      AxisSide.bottom => Point(where, ymin),
      AxisSide.left => Point(xmin, where),
      AxisSide.right => Point(xmax, where),
    };
    double tickShiftLength = (tickDirection == TickDirection.symmetric) ? tickSize / 2 : tickSize;
    Point tickShift = switch (axisSide) {
      AxisSide.top => Point(0, -tickShiftLength),  
      AxisSide.bottom => Point(0, tickShiftLength),
      AxisSide.left => Point(-tickShiftLength, 0),
      AxisSide.right => Point(tickShiftLength, 0),
    };
    Point labelShift = switch (axisSide) {
      AxisSide.top => Point(0, tickToLabelDistance),  
      AxisSide.bottom => Point(0, -tickToLabelDistance),
      AxisSide.left => Point(tickToLabelDistance, 0),
      AxisSide.right => Point(-tickToLabelDistance, 0),
    };
    Point tickPointAbsolute = relativePositionInFigure
      .relativeTo(parent.absoluteGeometry)
      .getAbsolutePosition(
        dataUnitsGeometry
        .getRelativePosition(tickPoint)
        .yFlip
      );
    Point tickStart = switch (tickDirection) {
      TickDirection.inward => tickPointAbsolute,
      TickDirection.outward => tickPointAbsolute + tickShift,
      TickDirection.symmetric => tickPointAbsolute + tickShift,
    };
    Point tickEnd = switch (tickDirection) {
      TickDirection.inward => tickPointAbsolute - tickShift,
      TickDirection.outward => tickPointAbsolute,
      TickDirection.symmetric => tickPointAbsolute - tickShift,
    };
    String dominantBaseline = switch (axisSide) {
      AxisSide.top => 'text-top',  
      AxisSide.bottom => 'hanging',
      AxisSide.left || AxisSide.right => 'middle',
    };
    String textAnchor = switch (axisSide) {
      AxisSide.left => 'end',  
      AxisSide.right => 'start',
      AxisSide.top || AxisSide.bottom => 'middle',
    };

    builder.element(
      'path', 
      attributes: {
        'id': tagGenerator.newTag('path'),
        'd': 'M ${tickStart.x},${tickStart.y} L ${tickEnd.x},${tickEnd.y}',
        'style': asCssString(style),
        'vector-effect': "non-scaling-stroke",
      },
    );

    if (labelTextGenerator != null) {
      builder.element(
        'text', 
        attributes: {
          'id': tagGenerator.newTag('text'),
          'x': '${(tickStart - labelShift).x}',
          'y': '${(tickStart - labelShift).y}',
          'style': asCssString(tickLabelTextStyle),
          'vector-effect': "non-scaling-stroke",
          'xml-space': 'preserve'
        },
        nest: () {
          builder.element(
            'tspan',
            attributes: {
              'id': tagGenerator.newTag('tspan'),
              'x': '${(tickStart - labelShift).x}',
              'y': '${(tickStart - labelShift).y}',
              // 'style': asCssString(textStyle),
              'vector-effect': "non-scaling-stroke",
              'xml-space': 'preserve',
              'dominant-baseline': dominantBaseline,
              'text-anchor': textAnchor,
            },
            nest: () {
              builder.text(labelTextGenerator(where.toDouble(), axisInfo));
            }
          );
        }
      );
    }
  }

  void buildDefsXml(XmlBuilder builder, SvgTagGenerator tagGenerator){
    _clipPathTag = tagGenerator.newTag('rectAxisClip');
    builder.element(
      'clipPath',
      attributes: {
        'id': _clipPathTag!,
      },
      nest: (){
        builder.element(
          'rect', 
          attributes: {
            'id': tagGenerator.newTag('rect'),
            'width': '${relativePositionInFigure.relativeTo(parent.absoluteGeometry).width}',
            'height': '${relativePositionInFigure.relativeTo(parent.absoluteGeometry).height}',
            'x': '${relativePositionInFigure.relativeTo(parent.absoluteGeometry).topLeft.dx}',
            'y': '${relativePositionInFigure.relativeTo(parent.absoluteGeometry).topLeft.dy}'
          }
        );
      }
    );
  }
}


extension RelativeFlip on Point {
  Point get yFlip => Point(x, 1.0 - y);
}

enum AxisSide {
  top, bottom, left, right
}

enum TickDirection {
  inward,
  outward,
  symmetric
}

class SvgGraphPlot {
  final SvgGraphAxis parent;
  final List<SvgGraphPoint> dataPoints;
  final Map<String, String> style = {
    'fill': 'none',
    'stroke': '#000000',
    'stroke-width': '0.5pt',
    'stroke-dasharray': 'none',
    'stroke-opacity': '1',
  };

  SvgGraphPlot({
    required this.parent,
    required this.dataPoints,
  });

  void buildXml(XmlBuilder builder, SvgTagGenerator tagGenerator){
    if (dataPoints.isEmpty) {
      return;
    }

    builder.element(
      'path', 
      attributes: {
        'id': tagGenerator.newTag('path'),
        'd': getPathCommands().join(' '),
        'style': asCssString(style),
        'vector-effect': 'non-scaling-stroke',
        if (parent._clipPathTag != null)
          'clip-path': 'url(#${parent._clipPathTag!})',
      },
    );
    
    // Draw markers
    for (final marker in dataPoints) {
      marker.buildXml(
        builder,
        tagGenerator,
        clipPathTag: parent._clipPathTag,
        getAbsolutePosition: (Point datum) => 
          parent.relativePositionInFigure
            .relativeTo(parent.parent.absoluteGeometry)
            .getAbsolutePosition(
              parent.dataUnitsGeometry
              .getRelativePosition(datum)
              .yFlip
            )
        );
    }
  }

  List<String> getPathCommands() {
    const String moveButDoNotDrawCommand = 'M';
    const String drawLineCommand = 'L';
    // Pre-allocate the list for efficiency
    final List<String> commands = List.filled(dataPoints.length, '');
    bool canDrawLine = false;
    for(int i = 0; i < dataPoints.length; i++){
      final dataPoint = dataPoints[i];
      if(dataPoint.datum.x.isFinite && dataPoint.datum.y.isFinite) {
        final Point absolutePosition =
          parent.relativePositionInFigure
            .relativeTo(parent.parent.absoluteGeometry)
            .getAbsolutePosition(
              parent.dataUnitsGeometry
              .getRelativePosition(dataPoint.datum)
              .yFlip
            );
        if (canDrawLine) {
          // The point is valid, can draw
          commands[i] = '$drawLineCommand ${absolutePosition.x},${absolutePosition.y}';
        } else {
          // This point is valid, but the previous one wasn't. Therefore we
          // only move to this point, but do not draw yet. On the next step,
          // we will draw a line that connects this (valid) point with the
          // next point (if it is also valid).
          commands[i] = '$moveButDoNotDrawCommand ${absolutePosition.x},${absolutePosition.y}';
          canDrawLine = true;
        }
      } else {
        // NaN or Inf occurred, we cannot draw here. Skip this point entirely.
        // We want a plot which has a line disconnect at this point.
        // As we remain at the previous point, we must tell the painter not to
        // draw the line from the previous point to the next one, so that it
        // we have a disconnected line.
        canDrawLine = false;
      }
    }
    return commands;
  }
}

class SvgGraphPoint {
  final Point datum;
  final SvgGraphMarker? marker;
  final Map<String, String>? style;
  final double markerSize;

  SvgGraphPoint(
    this.datum,
  {
    this.marker,
    this.style,
    this.markerSize = 2.5,
  });

  void buildXml(XmlBuilder builder, SvgTagGenerator tagGenerator, 
      {String? clipPathTag, required Point Function(Point) getAbsolutePosition}) {
    if(marker == null || style == null || !datum.x.isFinite || !datum.y.isFinite) {
      return;
    }
    final Point absolutePosition = getAbsolutePosition(datum);
    switch (marker) {
      case SvgGraphMarker.square:
        builder.element(
          'rect', 
          attributes: {
            'id': tagGenerator.newTag('rect'),
            'width': '$markerSize',
            'height': '$markerSize',
            'x': '${absolutePosition.x - markerSize/2}',
            'y': '${absolutePosition.y - markerSize/2}',
            'style': asCssString(style),
            'vector-effect': "non-scaling-stroke",
            if (clipPathTag != null)
              'clip-path': 'url(#${clipPathTag})',
          }
        );
        break;
      case SvgGraphMarker.circle:
        builder.element(
          'ellipse', 
          attributes: {
            'id': tagGenerator.newTag('ellipse'),
            'rx': '${markerSize / 2}',
            'ry': '${markerSize / 2}',
            'cx': '${absolutePosition.x}',
            'cy': '${absolutePosition.y}',
            'style': asCssString(style),
            'vector-effect': "non-scaling-stroke",
            if (clipPathTag != null)
              'clip-path': 'url(#${clipPathTag})',
          }
        );
        break;
      case SvgGraphMarker.point:
        builder.element(
          'ellipse', 
          attributes: {
            'id': tagGenerator.newTag('ellipse'),
            'rx': '${markerSize / 4}',
            'ry': '${markerSize / 4}',
            'cx': '${absolutePosition.x}',
            'cy': '${absolutePosition.y}',
            'vector-effect': "non-scaling-stroke",
            'style': asCssString(style),
            if (clipPathTag != null)
              'clip-path': 'url(#${clipPathTag})',
          }
        );
        break;
      default:
    }
  }
}


enum SvgGraphMarker {
  square('s'),
  // asterisk('*'),
  // upperTriangle('^'),
  circle('o'),
  point('.'),
  // plus('+'),
  // lowerTriangle('v'),
  // rightTriangle('>'),
  // leftTriangle('<'),
  ;
  
  final String string;

  const SvgGraphMarker(this.string);

  static SvgGraphMarker fromString(String s) => SvgGraphMarker.values.firstWhere((element) => element.string == s);

  @override
  String toString() => string;
}

String asCssString(Map<String, String>? css)
    => css == null
      ? ''
      : css
        .entries
        .map((MapEntry<String, String> e) => '${e.key}:${e.value}')
        .join(';');

extension RelativeToRect on Rect {
  Rect relativeTo(Rect canvas) => Rect.fromCenter(
    center: Offset.zero,
    width: this.width * canvas.width,
    height: this.height * canvas.height
  ).translate(center.dx * canvas.width, center.dy * canvas.height);

  Point getAbsolutePosition(Point relative) => Point(
    (relative.x - 0.5) * width + center.dx,
    (relative.y - 0.5) * height + center.dy
  );

  Point getRelativePosition(Point absolute) => Point(
    (absolute.x - center.dx) / width + 0.5,
    (absolute.y - center.dy) / height + 0.5
  );
}


class SvgTagGenerator {
  final Map<String, int> prefixToNumber = {};

  String newTag(String prefix) {
    prefixToNumber[prefix] = prefixToNumber.containsKey(prefix) ? (prefixToNumber[prefix]! + 1) : 1;
    return '$prefix${prefixToNumber[prefix]}';
  }
}

typedef TickPositionGenerator = List<double> Function(AxisInfo ax);
class TickPositionGenerators {
  static TickPositionGenerator goodIntervals({
    List<double> goodIntervals = const [0.1, 0.2, 0.25, 0.5, 1, 2, 4, 5],
    int desiredTickCount = 6,
    bool forceTicksAtAxisEnds = false
  }) => (AxisInfo ax) {
    if (!ax.max.isFinite || !ax.min.isFinite || (ax.max - ax.min) == 0){
      return [];
    }
    double tickIntervalFirstGuess = (ax.max - ax.min) / desiredTickCount.toDouble();
    if (!(log(tickIntervalFirstGuess) / ln10).isFinite) {
      return [];
    }
    final intervalOrderOfMagnitude = pow(10, (log(tickIntervalFirstGuess) / ln10).floor());
    final List<double> intervalGuesses = 
        goodIntervals.map((e) => e * intervalOrderOfMagnitude).toList()
      + goodIntervals.map((e) => e * intervalOrderOfMagnitude * 10).toList()
      + goodIntervals.map((e) => e * intervalOrderOfMagnitude * 0.1).toList();
    _IntervalAndTickCount bestInterval =
        intervalGuesses
          .map(
            (double interval) => _IntervalAndTickCount(interval, ((ax.max - ax.min) / interval).floor() + 1)
          )
          .reduce(
            (_IntervalAndTickCount a, _IntervalAndTickCount b) {
              return ((a.tickCount - desiredTickCount).abs()
                    < (b.tickCount - desiredTickCount).abs()) 
                    ? a
                    : b;
            }
          );
    int minShiftedInTickIntervals = (ax.min / bestInterval.interval).ceil();
    return List<double>.generate(
      bestInterval.tickCount,
      (index) => (minShiftedInTickIntervals + index) * bestInterval.interval
    );
  };
  
  static TickPositionGenerator fixed(
    int desiredTickCount,
  ) => (AxisInfo ax) {
    return List<double>.generate(
      desiredTickCount,
      (index) => (ax.min + index) * (ax.max - ax.min) / (desiredTickCount - 1)
    );
  };
}

@immutable
class AxisInfo {
  final double min;
  final double max;

  const AxisInfo({required this.min, required this.max});
}

@immutable
class _IntervalAndTickCount {
  final double interval;
  final int tickCount;

  const _IntervalAndTickCount(this.interval, this.tickCount);
}
