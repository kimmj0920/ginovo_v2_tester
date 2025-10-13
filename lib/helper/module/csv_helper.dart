import 'dart:io';
import 'package:csv/csv.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart';

class CsvHelper {
  Future<String> _generateFilePath(String prefix, [String? deviceName]) async {
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      throw Exception("외부 저장소 디렉터리를 찾을 수 없습니다.");
    }

    List<String> folders = directory.path.split("/");
    String path = "";
    for (int i = 1; i < folders.length; i++) {
      if (folders[i] != "Android") {
        path += "/${folders[i]}";
      } else {
        break;
      }
    }
    path += "/Documents";

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = deviceName != null
        ? "${prefix}_${deviceName}_$timestamp.csv"
        : "${prefix}_$timestamp.csv";

    return "$path/$filename";
  }

  Future<void> saveToCsv(List<double> w, List<double> x, List<double> y,
      List<double> z, List<DateTime> timestamp) async {
    if (w.length != x.length || w.length != y.length || w.length != z.length) {
      throw Exception("pitch, yaw, roll 데이터의 길이가 같아야 합니다.");
    }

    List<List<dynamic>> rows = [
      ["w", "x", "y", "z", "timestamp"]
    ];

    for (int i = 0; i < w.length; i++) {
      rows.add([w[i], x[i], y[i], z[i], timestamp[i].millisecondsSinceEpoch]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final path = await _generateFilePath("data");
    await File(path).writeAsString(csvData);
    print("CSV 파일이 저장되었습니다: $path");
  }

  Future<void> saveToCsvAccRaw(List<double> w, List<double> x, List<double> y,
      List<double> z, List<DateTime> timestamp) async {
    if (w.length != x.length || w.length != y.length || w.length != z.length) {
      throw Exception("pitch, yaw, roll 데이터의 길이가 같아야 합니다.");
    }

    List<List<dynamic>> rows = [
      ["x", "y", "z", "timestamp"]
    ];

    for (int i = 0; i < w.length; i++) {
      rows.add([w[i], x[i], y[i], timestamp[i].millisecondsSinceEpoch]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final path = await _generateFilePath("accRawData");
    await File(path).writeAsString(csvData);
    print("CSV 파일이 저장되었습니다: $path");
  }

  Future<void> saveVectorsToCsv(
      List<Vector3> vectors, List<DateTime> timestamp) async {
    List<List<dynamic>> rows = [
      ["x", "y", "z", "timestamp"]
    ];

    for (int i = 0; i < vectors.length; i++) {
      rows.add([
        vectors[i].x,
        vectors[i].y,
        vectors[i].z,
        timestamp[i].millisecondsSinceEpoch
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final path = await _generateFilePath("vector");
    await File(path).writeAsString(csvData);
    Fluttertoast.showToast(msg: "파일이 저장되었습니다.");
    print("CSV 파일이 저장되었습니다: $path");
  }

  Future<void> saveAccVecToCsv(List<double> w, List<DateTime> timestamp) async {
    List<List<dynamic>> rows = [
      ["accVec", "timestamp"]
    ];

    for (int i = 0; i < w.length; i++) {
      rows.add([w[i], timestamp[i].millisecondsSinceEpoch]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final path = await _generateFilePath("accVector");
    await File(path).writeAsString(csvData);
    Fluttertoast.showToast(msg: "파일이 저장되었습니다.");
    print("CSV 파일이 저장되었습니다: $path");
  }

  Future<void> saveBatteryStatus(List<String> value, List<bool> isChg,
      List<DateTime> timestamp, String deviceName) async {
    if (value.length != timestamp.length) {
      throw Exception("데이터의 길이가 같아야 합니다.");
    }

    List<List<dynamic>> rows = [
      ["timestamp(KST)", "value(%)", "isChg"]
    ];

    for (int i = 0; i < value.length; i++) {
      rows.add([timestamp[i], value[i], isChg[i] ? 1 : 0]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final path = await _generateFilePath("BatteryStatusData", deviceName);
    await File(path).writeAsString(csvData);
    print("CSV 파일이 저장되었습니다: $path");
  }
}
