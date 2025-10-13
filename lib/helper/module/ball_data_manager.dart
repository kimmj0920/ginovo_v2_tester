import 'dart:math';

import 'package:ginovo_result/helper/module/rotation_tracker.dart';
import 'package:vector_math/vector_math_64.dart';

mixin BallDataManagerInterface {
  init();
}

class BallDataManager with BallDataManagerInterface {
  static BallDataManager instance = BallDataManager();
  static Quaternion? initialQT;
  static Quaternion? currentQT;
  static Quaternion? previousQT;
  static const double ballRadius = 0.021335; // 단위: 미터
  static List<double> wList = [];
  static List<double> xList = [];
  static List<double> yList = [];
  static List<double> zList = [];
  static List<DateTime> timestamp = [];
  static List<Quaternion> quaternionList = [];
  static List<Quaternion> quaternionRelativeList = [];
  static List<Vector3> directionVectors = [];

  static RotationTracker rotationTracker = RotationTracker();
  @override
  init() {}

  translateData(String message) {
    List<double> insList =
        message.split(',').map((e) => double.parse(e)).toList();
    return insList;
  }

  Quaternion eulerToQuaternion(double pitch, double yaw, double roll) {
    // 피치, 요, 롤 값을 라디안으로 변환
    double pitchRad = radians(pitch);
    double yawRad = radians(yaw);
    double rollRad = radians(roll);

    // 쿼터니언 계산
    double qw = cos(yawRad / 2) * cos(pitchRad / 2) * cos(rollRad / 2) +
        sin(yawRad / 2) * sin(pitchRad / 2) * sin(rollRad / 2);
    double qx = sin(yawRad / 2) * cos(pitchRad / 2) * cos(rollRad / 2) -
        cos(yawRad / 2) * sin(pitchRad / 2) * sin(rollRad / 2);
    double qy = cos(yawRad / 2) * sin(pitchRad / 2) * cos(rollRad / 2) +
        sin(yawRad / 2) * cos(pitchRad / 2) * sin(rollRad / 2);
    double qz = cos(yawRad / 2) * cos(pitchRad / 2) * sin(rollRad / 2) -
        sin(yawRad / 2) * sin(pitchRad / 2) * cos(rollRad / 2);

    // 쿼터니언 반환
    return Quaternion(qw, qx, qy, qz);
  }

  Vector3 getRelativeDirection(
      Quaternion initialQuaternion, Quaternion newQuaternion) {
    Quaternion container = initialQuaternion;
    container.conjugate();
    // 두 쿼터니언의 차이를 구하기 위해, 새로운 쿼터니언에 초기 쿼터니언의 켤레를 곱한다.
    Quaternion relativeQuaternion = newQuaternion * container;

    // 상대 회전 벡터 (회전 축)를 구합니다. 회전 벡터는 회전된 쿼터니언에서 회전 축을 나타냅니다.
    Vector3 rotationAxis = relativeQuaternion.axis;

    return rotationAxis;
  }

  void convert(Quaternion q) {
    if (initialQT == null) {
      initialQT = q;
      rotationTracker.lastQuaternion = q;
      return;
    } else {
      // 상대 회전 방향 벡터 계산
      currentQT = q;

      bool isTurned = rotationTracker.checkFullRotation(q);

      print("회전 여부:  ${isTurned}");
    }
  }

  /// 두 쿼터니언의 차이로 이동 벡터 계산
  List<double> quaternionDifferenceToMoveVector(
      Quaternion qPrev, Quaternion qCurrent) {
    // qRelative = qPrev.inverse() * qCurrent
    Quaternion qRelative = qPrev.customInverse().multiply(qCurrent);

    // 상대 쿼터니언으로부터 회전축과 각도 계산
    Map<String, dynamic> rotationData = qRelative.toRotationAxisAndAngle();
    double theta = rotationData['angle'];
    List<double> axis = rotationData['axis'];
    print("theta: " +
        theta.toStringAsFixed(1) +
        " axis: " +
        rotationData['axis'].toString());
    // 이동 벡터 계산: 축 * 각도
    return [axis[0] * theta, axis[1] * theta, axis[2] * theta];
  }

  static clear() {
    initialQT = null;
    currentQT = null;
    previousQT = null;
    wList.clear();
    xList.clear();
    yList.clear();
    zList.clear();
    timestamp.clear();
    quaternionList.clear();
    quaternionRelativeList.clear();
    directionVectors.clear();
    rotationTracker = RotationTracker();
  }
}
