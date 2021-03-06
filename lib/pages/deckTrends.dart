import 'dart:convert';
import 'dart:core';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:http/http.dart' as http;

import 'package:HSmeta/data/deck.dart';
import 'package:HSmeta/components/text.dart';


const String usage = "The deck trends of the month";

class NumericComboLinePointChart extends StatelessWidget {
  final List<charts.Series> seriesList;
  final bool animate;
  final double startPoint;
  final double endPoint;

  NumericComboLinePointChart(this.seriesList, {this.animate, this.startPoint, this.endPoint});

  var axis = charts.NumericAxisSpec(
      renderSpec: charts.GridlineRendererSpec(
        labelRotation: 90,
        labelStyle: charts.TextStyleSpec(
            fontSize: 16,
            color: charts.MaterialPalette.white
        ), //change white color as per your requirement.
      ));

  @override
  Widget build(BuildContext context) {
    return new charts.NumericComboChart(seriesList,
        animate: animate,
        behaviors: [charts.SeriesLegend(
            desiredMaxColumns: 2,
            entryTextStyle: charts.TextStyleSpec(
                color: charts.Color(r: 255, g: 255, b: 255),
                fontFamily: 'EncodeSansExpanded',
                fontSize: 12))],
        defaultRenderer: new charts.LineRendererConfig(includePoints: true),
        domainAxis: new charts.NumericAxisSpec(
            renderSpec: new charts.SmallTickRendererSpec(
                labelStyle: new charts.TextStyleSpec(
                    fontSize: 16, // size in Pts.
                    color: charts.MaterialPalette.white),
                lineStyle: new charts.LineStyleSpec(
                    color: charts.MaterialPalette.white)),
            viewport: new charts.NumericExtents(startPoint, endPoint)),
        primaryMeasureAxis: new charts.NumericAxisSpec(
            tickProviderSpec: new charts.BasicNumericTickProviderSpec(
              //dataIsInWholeNumbers: true,
                desiredTickCount: 10
            ),
            renderSpec: new charts.GridlineRendererSpec(
                labelStyle: new charts.TextStyleSpec(
                    fontSize: 18, // size in Pts.
                    color: charts.MaterialPalette.white),
                lineStyle: new charts.LineStyleSpec(
                    color: charts.MaterialPalette.white))),
        customSeriesRenderers: [
          new charts.PointRendererConfig(
              customRendererId: 'customPoint')
        ]);
  }
}

Future<List<DecksRankings>> fetchRankings(http.Client client) async {
  final response =
  await client.get('https://tempostorm.com/api/snapshots/findOne?filter={%22where%22:{%22slug%22:%222020-12-14%22,%22snapshotType%22:%22standard%22},%22include%22:[{%22relation%22:%22deckTiers%22,%22scope%22:{%22include%22:[{%22relation%22:%22deck%22,%22scope%22:{%22fields%22:[%22id%22,%22name%22,%22slug%22,%22playerClass%22],%22include%22:{%22relation%22:%22slugs%22,%22scope%22:{%22fields%22:[%22linked%22,%22slug%22]}}}},{%22relation%22:%22deckTech%22,%22scope%22:{%22include%22:[{%22relation%22:%22cardTech%22,%22scope%22:{%22include%22:[{%22relation%22:%22card%22,%22scope%22:{%22fields%22:[%22name%22]}}]}}]}}]}}]}');

  // Use the compute function to run parsePhotos in a separate isolate.
  return compute(parseRankings, response.body);
  // return parseRankings(response.body);
}

List<DecksRankings> parseRankings(String responseBody) {
  final Map<String, dynamic> parsed = jsonDecode(responseBody);

  List<DecksRankings> result = new List<DecksRankings>();
  int snapNum = parsed['snapNum'];
  List<dynamic> deckTiers = parsed['deckTiers'];
  for (var x in deckTiers) {
    result.add(DecksRankings.fromJson(snapNum, x));
  }

  return result;
}

class DecksRankings {
  final int snapNumber;
  final int amount;
  final int maxRank;
  final String name;
  final int tier;
  final List<int> ranks;

  DecksRankings(this.snapNumber, this.amount, this.maxRank, this.name, this.tier, [this.ranks]);

  factory DecksRankings.fromJson(int snapNum, dynamic json) {
    return DecksRankings(
        snapNum,
        List.from(json['ranks']).length,
        List.from(json['ranks']).reduce((curr, next) => curr > next? curr: next),
        json['name'] as String,
        json['tier'] as int,
        List.from(json['ranks']));
  }
}

class LinearDecksRankings {
  final int snapNum;
  final int rank;

  LinearDecksRankings(this.snapNum, this.rank);
}

List<charts.Series<LinearDecksRankings, int>> transformRankingData(List<Deck> data, int tier) {
  Map<String, List<LinearDecksRankings>> tempResult = new Map<String, List<LinearDecksRankings>>();

  for (var x in data) {
    if (x.tier == tier) {
      int currSnapNum = x.snapNumber;
      List<LinearDecksRankings> linearRankings = new List<LinearDecksRankings>();
      for (var y in x.rank) {
        linearRankings.add(new LinearDecksRankings(currSnapNum, y != 0 ? y : null));
        --currSnapNum;
      }
      tempResult[x.name] = linearRankings;
    }
  }

  List<charts.Series<LinearDecksRankings, int>> result = new List<charts.Series<LinearDecksRankings, int>>();
  tempResult.forEach((key, value) {
    charts.Color c = charts.ColorUtil.fromDartColor(Colors.primaries[Random().nextInt(Colors.primaries.length)]);
    result.add(
        new charts.Series<LinearDecksRankings, int>(
          id: key,
          colorFn: (_, __) => c,
          domainFn: (LinearDecksRankings element, _) => element.snapNum,
          measureFn: (LinearDecksRankings element, _) => element.rank,
          data: value,
        ));
  }
  );

  return result;
}

class DeckTrendsPage extends StatefulWidget {
  final List<Deck> data;

  DeckTrendsPage({Key key, @required this.data}) : super(key: key);

  @override
  DeckTrendsPageState createState() => DeckTrendsPageState();
}

class DeckTrendsPageState extends State<DeckTrendsPage> {
  String selectedValue = 'Tier 1';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration:
            BoxDecoration(
              color: Color.fromRGBO(0, 0, 0, 0.4),
              image: DecorationImage(
                image: AssetImage('images/bcg1.png'),
                colorFilter: ColorFilter.mode(Colors.black87, BlendMode.overlay),
                fit: BoxFit.cover,
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          title: textWidgets.header('HSmeta', context),
        ),
        body: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                  image: ExactAssetImage("images/bcg3.png"),
                  fit: BoxFit.fill
              ),
            ),
            child:Padding(
              padding: EdgeInsets.only(left: 10.0, top: 0.0, right: 30.0, bottom: 10.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                            image: ExactAssetImage("images/bcg1.png"),
                            fit: BoxFit.fitHeight
                        ),
                      ),
                      margin: const EdgeInsets.all(10.0),
                      child: DropdownButton<String>(
                        dropdownColor: Colors.transparent,
                        value: selectedValue,
                        onChanged: (String result) { setState(() { selectedValue = result; });},
                        items: <String>['Tier 1', 'Tier 2', 'Tier 3', 'Tier 4', 'Tier 5']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: textWidgets.text(value, context),
                          );
                        }).toList(),
                      )
                  ),
                  Expanded(
                      child: NumericComboLinePointChart(
                          transformRankingData(widget.data, int.parse(selectedValue[selectedValue.length - 1])),
                          animate: false,
                          startPoint: (widget.data[0].snapNumber - widget.data[0].amount).toDouble(),
                          endPoint: (widget.data[0].snapNumber).toDouble())
                  ),
                ],
              ),
            )
        )
    );
  }

}
