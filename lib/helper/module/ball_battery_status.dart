import 'dart:convert';

class BallBatteryStatus {
  String value = "";
  bool isChg = false;
  DateTime timestamp = DateTime.now();

  BallBatteryStatus(String message, this.timestamp) {
    final bool isDisconnected = message.contains("DisConnect");

    if (isDisconnected) {
      value = message;
      isChg = false;
    } else {
      final data = getBatteryValue(message);
      value = data['batt'] ?? "null";
      isChg = data['isChg'] ?? false;
    }
  }

  Map<String, dynamic> getBatteryValue(String message) {
    try {
      final Map<String, dynamic> data = jsonDecode(message);
      return {
        "batt": data['batt']?.toString() ?? "null",
        "isChg": (data['isChg'] == 1), // 1이면 true, 아니면 false
      };
    } catch (e) {
      print("유효한 JSON 형식이 아닙니다: $e");
      return {
        "batt": "null",
        "isChg": false,
      };
    }
  }

  List<String> toList() {
    return [
      value.toString(),
      isChg ? "true" : "false",
      timestamp.toIso8601String(), // 날짜를 문자열로 변환
    ];
  }
}
