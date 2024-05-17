import 'dart:io';
import 'dart:math';

import 'package:dart_svgplot/dart_svgplot.dart';
import 'package:flutter/material.dart';

const String outputFilePath = 'test.svg';

void main() async {
  List<double> x = List.generate(55, (i) => i / 5);
  final plot = SvgGraphFigure(
    absoluteGeometry: Rect.fromLTWH(0, 0, 453.5, 283.5),
    lengthUnit: SvgGraphUnit.point
  );
  final ax = plot.axis(
    labelTextStyle: {
      'font-size': '14'
    },
    tickLabelTextStyle: {
      'font-size': '11'
    },
    xlabel: 'Time, s',
    ylabel: 'Signal, V',
  );
  ax.plot(
    x.map((x) => Point(x, sin(x))).toList(),
    marker: SvgGraphMarker.circle,
    lineStyle: {
      'stroke': 'none'
    }
  );
  ax.plot(
    x.map((x) => Point(x, 1.5 * cos(x))).toList(),
    lineStyle: {
      'stroke': '#0000ff',
    },
  );
  final document = plot.toSvgXml();
  (await File(outputFilePath)).writeAsString(document.toXmlString());
}
