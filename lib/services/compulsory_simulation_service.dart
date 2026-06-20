import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

class SimDeptOption {
  final String code; // e.g. "B500"
  final String displayName; // e.g. "資訊管理學系"

  SimDeptOption({required this.code, required this.displayName});

  @override
  String toString() => '$displayName ($code)';
}

class CompulsorySimulationService {
  static final CompulsorySimulationService instance =
      CompulsorySimulationService._internal();
  CompulsorySimulationService._internal();

  static const String URL_A =
      "https://selcrs.nsysu.edu.tw/menu1/CourseQuery.asp?HIS=1&eng=0";
  static const String URL_B =
      "https://selcrs.nsysu.edu.tw/stu_query/crs_mst_qry/crs_mst_query_top.asp";
  static const String QUERY_URL =
      "https://selcrs.nsysu.edu.tw/stu_query/crs_mst_qry/crs_mst_query.asp?action=3";

  // Standard request headers matching Python
  static const Map<String, String> _headers = {
    "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept-Language": "zh-TW,zh;q=0.9",
  };

  /// Fetch and compute undergraduate department options (B-prefixed)
  Future<List<SimDeptOption>> fetchSimulationDepts() async {
    try {
      // 1. Fetch URL_A options
      final resA = await http.get(Uri.parse(URL_A), headers: _headers);
      if (resA.statusCode != 200) {
        throw Exception("無法取得課程類別選項 (A連結)");
      }
      // Big5 or UTF-8. The page is in Big5 or UTF-8, let's decode using bodyBytes and utf8.
      final htmlA = utf8.decode(resA.bodyBytes, allowMalformed: true);
      final docA = html_parser.parse(htmlA);

      final selectA = docA.querySelector("span#DPT_ID select") ??
          docA.querySelector("select[name=D1]");
      final Map<String, String> aDict = {};
      if (selectA != null) {
        for (var opt in selectA.querySelectorAll("option")) {
          final val = opt.attributes['value']?.trim() ?? '';
          final label = opt.text.trim();
          if (val.isNotEmpty) {
            // Exclude names ending in "碩專", "碩", "博"
            final excludeReg = RegExp(r'(碩專|碩|博)$');
            if (excludeReg.hasMatch(label)) continue;
            aDict["${val}0"] = label;
          }
        }
      }

      // 2. Fetch URL_B options
      final resB = await http.get(Uri.parse(URL_B), headers: _headers);
      if (resB.statusCode != 200) {
        throw Exception("無法取得科系選項 (B連結)");
      }
      final htmlB = utf8.decode(resB.bodyBytes, allowMalformed: true);
      final docB = html_parser.parse(htmlB);

      final selectB = docB.querySelector("select[name=DPT1]");
      final Set<String> bSet = {};
      if (selectB != null) {
        for (var opt in selectB.querySelectorAll("option")) {
          final val = opt.attributes['value']?.trim() ?? '';
          if (val.isNotEmpty) {
            bSet.add(val);
          }
        }
      }

      // 3. Intersect: aDict's key (val + "0") in bSet, and key starts with "B"
      final List<SimDeptOption> intersect = [];
      aDict.forEach((aKey, aLabel) {
        if (bSet.contains(aKey) && aKey.startsWith("B")) {
          intersect.add(SimDeptOption(code: aKey, displayName: aLabel));
        }
      });

      return intersect;
    } catch (e) {
      debugPrint("CompulsorySimulationService fetchSimulationDepts error: $e");
      rethrow;
    }
  }

  /// Query general compulsory courses for department [dpt1] and academic year [yy1]
  Future<List<String>> fetchCompulsoryCourses(String yy1, String dpt1) async {
    try {
      final response = await http.post(
        Uri.parse(QUERY_URL),
        headers: _headers,
        body: {"YY1": yy1, "DPT1": dpt1},
      );

      if (response.statusCode != 200) {
        throw Exception("連線失敗，無法查詢必修課程");
      }

      final htmlText = utf8.decode(response.bodyBytes, allowMalformed: true);
      final doc = html_parser.parse(htmlText);

      final List<String> results = [];
      bool capture = false;
      int captureCount = 0;
      int rowspanLimit = 0;

      for (var td in doc.querySelectorAll("td")) {
        final text = td.text.trim();

        if (text.contains("一般必修")) {
          capture = true;
          rowspanLimit = int.tryParse(td.attributes['rowspan'] ?? '1') ?? 1;
          captureCount = 0;
          continue;
        }

        if (capture) {
          final bgcolor = td.attributes['bgcolor']?.toUpperCase() ?? '';
          // Allow both #C0C0C0 and C0C0C0
          if (bgcolor == "#C0C0C0" || bgcolor == "C0C0C0") {
            if (!text.contains("【") && !text.contains("】") && text.isNotEmpty) {
              results.add(text);
              captureCount++;
            }
          }

          if (captureCount >= rowspanLimit) {
            capture = false;
          }
        }
      }

      return results;
    } catch (e) {
      debugPrint("CompulsorySimulationService fetchCompulsoryCourses error: $e");
      rethrow;
    }
  }
}
