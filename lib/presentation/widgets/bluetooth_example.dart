import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ginovo_result/helper/module/ball_battery_status.dart';
import 'package:ginovo_result/helper/module/ball_data_manager.dart';
import 'package:ginovo_result/helper/module/csv_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'direction_painter.dart';

class BluetoothExample extends StatefulWidget {
  @override
  _BluetoothExampleState createState() => _BluetoothExampleState();
}

class _BluetoothExampleState extends State<BluetoothExample> {
  final String targetDeviceName = "GINOVO"; // 연결할 장치 이름
  BluetoothDevice? targetDevice;
  List<BluetoothCharacteristic> characteristicList = [];
  BluetoothCharacteristic? targetCharacteristic;
  List<BluetoothDevice> bleDevices = [];

  String connectStatus = "연결 상태 없음";
  String connectDevice = "없음";
  String scanStatus = "로딩중";
  List<String> receivedMessages = ["wait"]; // 수신된 메시지 리스트
  bool isSendMessageButtonDisabled = false;
  bool isaccRawMode = false;
  bool isaccVecMode = false;

  String batteryTxt = "";
  String batteryTestStatus = "대기중";
  List<BallBatteryStatus> batteryStatusList = [];
  Timer? _timer;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Map<String, StreamSubscription<List<int>>?> notificationSubscriptions = {};

  //Vector? relativeVector;
  @override
  void initState() {
    super.initState();
    requestStoragePermission().then((e) {
      startScan();
      print("스캔 시작");
    });
  }

  //블루투스 스캔 시작
  void startScan() async {
    bleDevices.clear();
    scanStatus = "스캔중...";
    try {
      await FlutterBluePlus.startScan(); // 스캔 시작
      await Future.delayed(Duration(seconds: 10)); // 10초 대기
      await FlutterBluePlus.stopScan(); // 10초 후 스캔 중지

      setState(() {
        scanStatus = "스캔 종료";
      });
    } catch (e) {
      print("블루투스 스캔 오류 발생: $e");
    }

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (result.device.advName.contains(targetDeviceName)) {
          if (!bleDevices
              .any((device) => device.advName == result.device.advName)) {
            print(
                "목표 장치 발견: ${result.device.platformName}, RSSI: ${result.rssi}");
            print("디바이스 추가됨.");
            setState(() {
              bleDevices.add(result.device);
            });
          }
        }
      }
    });
  }

  // 선택한 기기 블루투스 연결
  void clickToConnect(BluetoothDevice device) {
    setState(() {
      targetDevice = device;
      connectStatus = "연결 중...";
    });
    FlutterBluePlus.stopScan();
    scanStatus = "스캔 종료";
    connectToDevice();
  }

  // 블루투스 기기 연결
  void connectToDevice() async {
    if (targetDevice == null) return;

    try {
      await targetDevice!.connect();
      setState(() {
        connectDevice = "연결됨: ${targetDevice!.advName}";
      });

      // 연결 상태 감지 리스너 추가
      _connectionSubscription = targetDevice!.connectionState.listen((state) {
        setState(() {
          if (state == BluetoothConnectionState.connected) {
            connectStatus = "연결됨 ✅";
          } else if (state == BluetoothConnectionState.disconnected) {
            connectStatus = "연결 해제 ❌";
          } else {
            connectStatus = "연결 상태 알 수 없음";
          }
        });
      });

      // 장치의 서비스 탐색
      List<BluetoothService> services = await targetDevice!.discoverServices();
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.properties.write) {
            setState(() {
              print("송신 characteristic 발견: ${characteristic.uuid}");
              characteristicList.add(characteristic);
              targetCharacteristic = characteristic;
            });
          }
          if (characteristic.properties.notify) {
            if (!notificationSubscriptions
                .containsKey(characteristic.uuid.toString())) {
              print("수신 characteristic 발견: ${characteristic.uuid}");
              enableNotification(characteristic);
            }
          }
        }
      }
    } catch (e) {
      setState(() {
        connectStatus = "연결 실패 ($e)"; // 연결 실패 표시
      });
    }
  }

  //블루투스 데이터 수신
  void enableNotification(BluetoothCharacteristic characteristic) async {
    await characteristic.setNotifyValue(true);
    notificationSubscriptions[characteristic.uuid.toString()] =
        characteristic.onValueReceived.listen((value) {
      // 바이트 배열을 문자열로 변환
      String message = String.fromCharCodes(value);
      if (!message.contains("ready") &&
          !message.contains('{"batt":') &&
          !message.contains("state")) {
        print("수신된 메시지: $message");

        List<double> datas = BallDataManager.instance.translateData(message);
        if (datas.length == 3) {
          BallDataManager.wList.add(datas[0]);
          BallDataManager.xList.add(datas[1]);
          BallDataManager.yList.add(datas[2]);
          BallDataManager.zList.add(0);
          BallDataManager.timestamp.add(DateTime.now());
        } else if (datas.length == 1) {
          print("하나짜리 데이터 수신: ${datas[0]}");
          BallDataManager.wList.add(datas[0]);
          BallDataManager.xList.add(0);
          BallDataManager.yList.add(0);
          BallDataManager.zList.add(0);
          BallDataManager.timestamp.add(DateTime.now());
        }

        setState(() {
          receivedMessages.add(message); // 수신된 메시지를 리스트에 추가
        });
      } else if (message.contains('{"batt":')) {
        setState(() {
          batteryTxt = message;
          print("수신된 메시지: $message");

          batteryStatusList.add(BallBatteryStatus(message, DateTime.now()));
        });
      }
    });
    print("알림 활성화: ${characteristic.uuid}");
  }

  Future<void> sendMessage(
      BluetoothCharacteristic? bleCharacteristic, String message) async {
    if (bleCharacteristic == null) return;

    List<int> bytes = message.codeUnits; // 문자열을 바이트로 변환
    await bleCharacteristic!.write(bytes);
    print("메시지 전송: $message");
  }

  Future<void> requestStoragePermission() async {
    // Android 13 이상이면 별도 요청 필요
    if (await Permission.storage.isDenied || await Permission.photos.isDenied) {
      await [
        Permission.storage,
        Permission.photos,
      ].request();
    }

    if (await Permission.storage.status.isGranted ||
        await Permission.photos.isGranted) {
      print("저장소 권한 허용됨");
    } else {
      connectStatus = "저장소 권한 확인 필요!";
      print("저장소 권한이 필요합니다.");
    }
  }

  void disconnectDevice() async {
    if (targetDevice != null) {
      await targetDevice!.disconnect().whenComplete(() async {
        setState(() {
          connectStatus = "연결 해제됨 ❌";
          connectDevice = "없음";
          batteryTestStatus = "종료";
          targetDevice = null;
          characteristicList.clear();
        });
        for (var sub in notificationSubscriptions.values) {
          await sub?.cancel();
        }
        notificationSubscriptions.clear();
      });
    }
  }

  @override
  void dispose() {
    targetDevice?.disconnect();
    _scanSubscription?.cancel(); // 스캔 리스너 취소
    _connectionSubscription?.cancel(); // 연결 상태 리스너 취소
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('테스트'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: double.maxFinite,
              height: 200,
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...bleDevices
                      .map((e) => ElevatedButton(
                          onPressed: () {
                            clickToConnect(e);
                          },
                          child: Text(e.advName)))
                      .toList(),
                ],
              ),
            ),
            SizedBox(height: 15),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              Text(scanStatus),
              Text(connectStatus),
            ]),
            Text(connectDevice),
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: startScan,
                  child: Text('다시 스캔하기'),
                ),
                ElevatedButton(
                  onPressed: disconnectDevice,
                  child: Text('연결 해제'),
                ),
              ],
            ),
            SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: isSendMessageButtonDisabled
                      ? null
                      : () => {
                            BallDataManager.clear(),
                            sendMessageButton('{"cmd":"accRaw"}'),
                            setState(() {
                              isaccRawMode = true;
                            })
                          },
                  child: Text('accRaw 전송'),
                ),
                ElevatedButton(
                  onPressed: isSendMessageButtonDisabled
                      ? null
                      : () => {
                            BallDataManager.clear(),
                            sendMessageButton('{"cmd":"accVec"}'),
                            setState(() {
                              isaccVecMode = true;
                            })
                          },
                  child: Text('accVec 전송'),
                ),
                ElevatedButton(
                  onPressed: isSendMessageButtonDisabled
                      ? null
                      : () => sendMessageButton('{"cmd":"idle"}'),
                  child: Text('중지'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              '수신된 메시지:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(receivedMessages.isNotEmpty ? receivedMessages.last : '없음'),
            ElevatedButton(
              onPressed: () async {
                final csvHelper = CsvHelper();

                if (isaccRawMode) {
                  await csvHelper.saveToCsvAccRaw(
                    BallDataManager.wList,
                    BallDataManager.xList,
                    BallDataManager.yList,
                    BallDataManager.zList,
                    BallDataManager.timestamp,
                  );
                } else if (isaccVecMode) {
                  await csvHelper.saveAccVecToCsv(
                    BallDataManager.wList,
                    BallDataManager.timestamp,
                  );
                }

                showAutoDismissDialog(context, '저장 완료', 'CSV 파일 저장이 완료되었습니다.');
                setState(() {
                  isaccRawMode = false;
                  isaccVecMode = false;
                });
              },
              child: Text('csv 저장'),
            ),
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: isSendMessageButtonDisabled
                      ? null
                      : () => sendMessageButton('{"cmd":"batt"}'),
                  child: Text('배터리 잔량 확인'),
                ),
                Text(batteryTxt),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: startBatteryTest,
                  child: Text('배터리 테스트 시작'),
                ),
                Text(batteryTestStatus),
              ],
            ),
            ElevatedButton(
              onPressed: makeBatteryTestCSV,
              child: Text('배터리테스트 csv 저장'),
            ),
          ],
        ),
      ),
    );
  }

  void sendMessageButton(String message) {
    if (targetDevice != null && !isSendMessageButtonDisabled) {
      setState(() {
        isSendMessageButtonDisabled = true; // 버튼 비활성화
      });

      Future.delayed(Duration(seconds: 1), () {
        setState(() {
          isSendMessageButtonDisabled = false; // 2초 후 다시 활성화
        });
      });
      sendMessage(characteristicList[1], message);
    }
  }

  Future<void> makeBatteryTestCSV() async {
    List<String> values = [];
    List<bool> isChg = [];
    List<DateTime> timestamps = [];

    if (batteryStatusList.isEmpty) return;

    for (var status in batteryStatusList) {
      values.add(status.value);
      isChg.add(status.isChg);
      timestamps.add(status.timestamp);
    }

    final csvHelper = CsvHelper();
    await csvHelper
        .saveBatteryStatus(values, isChg, timestamps, targetDevice!.advName)
        .whenComplete(() => batteryStatusList.clear());
  }

  Future<void> startBatteryTest() async {
    if (targetDevice == null || targetCharacteristic == null) {
      batteryTestStatus = "장치가 연결되지 않음";
      return;
    }

    _timer?.cancel();
    batteryStatusList.clear();

    print("배터리 테스트 시작!");

    _timer = Timer.periodic(Duration(seconds: 60), (timer) {
      if (targetDevice != null) {
        sendMessage(characteristicList[1], '{"cmd":"batt"}');
        setState(() {
          batteryTestStatus = "진행 중";
        });
      } else {
        batteryStatusList.add(BallBatteryStatus("DisConnect", DateTime.now()));
        _timer?.cancel();
        setState(() {
          batteryTestStatus = "종료";
        });
      }
    });
  }

  void showAutoDismissDialog(
      BuildContext context, String title, String message) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: title,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Container(
            width: 200,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(message),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: Duration(milliseconds: 300),
    );

    // 3초 후 다이얼로그 닫기
    Future.delayed(Duration(seconds: 3), () {
      Navigator.of(context, rootNavigator: true).pop();
    });
  }
}
