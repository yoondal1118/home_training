import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:async';

// 운동 종류 enum
enum ExerciseType {
  squat,
  pushup,
  lunge,
  dumbbell,
}

// 운동 단계
enum ExercisePhase {
  waitingForReady, // 준비자세 대기
  ready,           // 준비완료
  exercising,      // 운동 중
}

// 운동 상태 (동작)
enum ExerciseState {
  up,   // 올라간 상태 (스쿼트: 서있음, 팔굽: 팔 폄, 아령: 팔 폄)
  down, // 내려간 상태 (스쿼트: 앉음, 팔굽: 팔 굽힘, 아령: 팔 굽힘)
}

extension ExerciseTypeExtension on ExerciseType {
  String get name {
    switch (this) {
      case ExerciseType.squat:
        return '스쿼트';
      case ExerciseType.pushup:
        return '팔굽혀펴기';
      case ExerciseType.lunge:
        return '런지';
      case ExerciseType.dumbbell:
        return '아령';
    }
  }

  IconData get icon {
    switch (this) {
      case ExerciseType.squat:
        return Icons.accessibility_new;
      case ExerciseType.pushup:
        return Icons.fitness_center;
      case ExerciseType.lunge:
        return Icons.directions_walk;
      case ExerciseType.dumbbell:
        return Icons.sports_gymnastics;
    }
  }

  Color get color {
    switch (this) {
      case ExerciseType.squat:
        return Colors.blue;
      case ExerciseType.pushup:
        return Colors.red;
      case ExerciseType.lunge:
        return Colors.green;
      case ExerciseType.dumbbell:
        return Colors.orange;
    }
  }

  String get readyPoseDescription {
    switch (this) {
      case ExerciseType.squat:
        return '똑바로 서세요';
      case ExerciseType.pushup:
        return '팔을 쭉 펴세요';
      case ExerciseType.lunge:
        return '똑바로 서세요';
      case ExerciseType.dumbbell:
        return '팔을 내리세요';
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MaterialApp(
    home: ExerciseSelectionScreen(cameras: cameras),
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primarySwatch: Colors.blue,
      fontFamily: 'Roboto',
    ),
  ));
}

// 메인 화면 - 운동 선택
class ExerciseSelectionScreen extends StatelessWidget {
  final List<CameraDescription> cameras;
  const ExerciseSelectionScreen({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                '🏋️ 운동 선택',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '원하는 운동을 선택하세요',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.all(20),
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  children: ExerciseType.values.map((exercise) {
                    return _ExerciseCard(
                      exercise: exercise,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExerciseCounterScreen(
                              cameras: cameras,
                              exerciseType: exercise,
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final ExerciseType exercise;
  final VoidCallback onTap;

  const _ExerciseCard({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              exercise.color.withValues(alpha: 0.8),
              exercise.color.withValues(alpha: 0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: exercise.color.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              exercise.icon,
              size: 60,
              color: Colors.white,
            ),
            const SizedBox(height: 15),
            Text(
              exercise.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 운동 카운터 화면
class ExerciseCounterScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ExerciseType exerciseType;

  const ExerciseCounterScreen({
    super.key,
    required this.cameras,
    required this.exerciseType,
  });

  @override
  State<ExerciseCounterScreen> createState() => _ExerciseCounterScreenState();
}

class _ExerciseCounterScreenState extends State<ExerciseCounterScreen>
    with TickerProviderStateMixin {
  CameraController? controller;
  PoseDetector poseDetector = PoseDetector(options: PoseDetectorOptions());
  bool isBusy = false;
  int exerciseCount = 0;
  ExerciseState currentState = ExerciseState.up;
  ExercisePhase phase = ExercisePhase.waitingForReady;
  String statusMessage = "";

  // 자세 유지 시간 체크용
  DateTime? poseHoldStartTime;
  static const Duration requiredHoldDuration = Duration(milliseconds: 1500);
  double holdProgress = 0.0; // 0.0 ~ 1.0

  // 애니메이션 컨트롤러
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _updateStatusMessage();

    // 애니메이션 설정 (2초 주기로 반복)
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);

    // 카메라 초기화
    CameraLensDirection preferredDirection = CameraLensDirection.front;

    final camera = widget.cameras.firstWhere(
      (cam) => cam.lensDirection == preferredDirection,
      orElse: () => widget.cameras.first,
    );

    controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    controller?.initialize().then((_) {
      if (!mounted) return;
      controller?.startImageStream((image) => processImage(image));
      setState(() {});
    });
  }

  void _updateStatusMessage() {
    if (phase == ExercisePhase.waitingForReady) {
      statusMessage = widget.exerciseType.readyPoseDescription;
      return;
    }

    switch (widget.exerciseType) {
      case ExerciseType.squat:
        statusMessage = currentState == ExerciseState.down ? "올라오세요!" : "앉으세요!";
        break;
      case ExerciseType.pushup:
        statusMessage = currentState == ExerciseState.down ? "올라오세요!" : "내려가세요!";
        break;
      case ExerciseType.lunge:
        statusMessage = currentState == ExerciseState.down ? "올라오세요!" : "무릎을 굽히세요!";
        break;
      case ExerciseType.dumbbell:
        statusMessage = currentState == ExerciseState.up ? "들어올리세요!" : "내리세요!";
        break;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    controller?.dispose();
    poseDetector.close();
    super.dispose();
  }

  Future<void> processImage(CameraImage image) async {
    if (isBusy || controller == null) return;
    isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        isBusy = false;
        return;
      }

      final poses = await poseDetector.processImage(inputImage);

      if (poses.isNotEmpty) {
        final pose = poses.first;
        _processPose(pose);
      }
    } catch (e) {
      debugPrint("AI 분석 에러: ${e.toString()}");
      if (e is PlatformException) {
        debugPrint("에러 코드: ${e.code}");
        debugPrint("에러 메시지: ${e.message}");
        debugPrint("에러 상세: ${e.details}");
      }
    } finally {
      isBusy = false;
    }
  }

  void _processPose(Pose pose) {
    final angles = _getExerciseAngles(pose);
    if (angles == null) return;

    final currentAngle = angles['current'] ?? 0;
    final isInReadyPosition = _checkReadyPosition(currentAngle);
    final isInDownPosition = _checkDownPosition(currentAngle);
    final isInUpPosition = _checkUpPosition(currentAngle);

    setState(() {
      // 준비자세 대기 단계
      if (phase == ExercisePhase.waitingForReady) {
        if (isInReadyPosition) {
          if (poseHoldStartTime == null) {
            poseHoldStartTime = DateTime.now();
          }
          final holdDuration = DateTime.now().difference(poseHoldStartTime!);
          holdProgress = (holdDuration.inMilliseconds / requiredHoldDuration.inMilliseconds).clamp(0.0, 1.0);

          if (holdDuration >= requiredHoldDuration) {
            phase = ExercisePhase.exercising;
            poseHoldStartTime = null;
            holdProgress = 0.0;
            _updateStatusMessage();
          }
        } else {
          poseHoldStartTime = null;
          holdProgress = 0.0;
        }
      }
      // 운동 중 단계
      else if (phase == ExercisePhase.exercising) {
        // 현재 UP 상태에서 DOWN으로 전환 체크
        if (currentState == ExerciseState.up && isInDownPosition) {
          if (poseHoldStartTime == null) {
            poseHoldStartTime = DateTime.now();
          }
          final holdDuration = DateTime.now().difference(poseHoldStartTime!);
          holdProgress = (holdDuration.inMilliseconds / requiredHoldDuration.inMilliseconds).clamp(0.0, 1.0);

          if (holdDuration >= requiredHoldDuration) {
            currentState = ExerciseState.down;
            poseHoldStartTime = null;
            holdProgress = 0.0;
            _updateStatusMessage();
          }
        }
        // 현재 DOWN 상태에서 UP으로 전환 체크 (카운트 증가)
        else if (currentState == ExerciseState.down && isInUpPosition) {
          if (poseHoldStartTime == null) {
            poseHoldStartTime = DateTime.now();
          }
          final holdDuration = DateTime.now().difference(poseHoldStartTime!);
          holdProgress = (holdDuration.inMilliseconds / requiredHoldDuration.inMilliseconds).clamp(0.0, 1.0);

          if (holdDuration >= requiredHoldDuration) {
            exerciseCount++;
            currentState = ExerciseState.up;
            poseHoldStartTime = null;
            holdProgress = 0.0;
            _updateStatusMessage();
          }
        }
        // 자세가 벗어나면 타이머 리셋
        else {
          poseHoldStartTime = null;
          holdProgress = 0.0;
        }
      }
    });
  }

  Map<String, double>? _getExerciseAngles(Pose pose) {
    switch (widget.exerciseType) {
      case ExerciseType.squat:
      case ExerciseType.lunge:
        final hip = pose.landmarks[PoseLandmarkType.leftHip];
        final knee = pose.landmarks[PoseLandmarkType.leftKnee];
        final ankle = pose.landmarks[PoseLandmarkType.leftAnkle];
        if (hip != null && knee != null && ankle != null) {
          return {'current': _getAngle(hip, knee, ankle)};
        }
        // 오른쪽도 체크
        final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
        final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
        final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
        if (rightHip != null && rightKnee != null && rightAnkle != null) {
          return {'current': _getAngle(rightHip, rightKnee, rightAnkle)};
        }
        return null;

      case ExerciseType.pushup:
      case ExerciseType.dumbbell:
        final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
        final elbow = pose.landmarks[PoseLandmarkType.leftElbow];
        final wrist = pose.landmarks[PoseLandmarkType.leftWrist];
        if (shoulder != null && elbow != null && wrist != null) {
          return {'current': _getAngle(shoulder, elbow, wrist)};
        }
        // 오른쪽도 체크
        final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
        final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
        final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
        if (rightShoulder != null && rightElbow != null && rightWrist != null) {
          return {'current': _getAngle(rightShoulder, rightElbow, rightWrist)};
        }
        return null;
    }
  }

  bool _checkReadyPosition(double angle) {
    switch (widget.exerciseType) {
      case ExerciseType.squat:
      case ExerciseType.lunge:
        return angle > 160; // 다리 펴고 서있음
      case ExerciseType.pushup:
        return angle > 160; // 팔 펴고 있음
      case ExerciseType.dumbbell:
        return angle > 150; // 팔 내리고 있음
    }
  }

  bool _checkDownPosition(double angle) {
    switch (widget.exerciseType) {
      case ExerciseType.squat:
        return angle < 100; // 무릎 굽힘
      case ExerciseType.pushup:
        return angle < 100; // 팔꿈치 굽힘
      case ExerciseType.lunge:
        return angle < 110; // 무릎 굽힘
      case ExerciseType.dumbbell:
        return angle < 70; // 팔 굽힘 (아령 들어올림)
    }
  }

  bool _checkUpPosition(double angle) {
    switch (widget.exerciseType) {
      case ExerciseType.squat:
      case ExerciseType.lunge:
        return angle > 160;
      case ExerciseType.pushup:
        return angle > 160;
      case ExerciseType.dumbbell:
        return angle > 150;
    }
  }

  double _getAngle(PoseLandmark p1, PoseLandmark p2, PoseLandmark p3) {
    double angle = (math.atan2(p3.y - p2.y, p3.x - p2.x) -
            math.atan2(p1.y - p2.y, p1.x - p2.x)) *
        180 /
        math.pi;
    angle = angle.abs();
    if (angle > 180) angle = 360 - angle;
    return angle;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = widget.cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );

    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (defaultTargetPlatform == TargetPlatform.android) {
      var rotationCompensation = sensorOrientation;
      if (rotationCompensation == 0) {
        rotation = InputImageRotation.rotation0deg;
      } else if (rotationCompensation == 90) {
        rotation = InputImageRotation.rotation90deg;
      } else if (rotationCompensation == 180) {
        rotation = InputImageRotation.rotation180deg;
      } else if (rotationCompensation == 270) {
        rotation = InputImageRotation.rotation270deg;
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotation.rotation0deg;
    }

    if (rotation == null) return null;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final nv21Bytes = _convertYUV420ToNV21(image);

      return InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Uint8List _convertYUV420ToNV21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = width * height ~/ 2;

    final nv21 = Uint8List(ySize + uvSize);

    final yPlane = image.planes[0];
    final yBuffer = yPlane.bytes;

    int yIndex = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        nv21[yIndex++] = yBuffer[y * yPlane.bytesPerRow + x];
      }
    }

    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    int uvIndex = ySize;
    final int uvWidth = width ~/ 2;
    final int uvHeight = height ~/ 2;

    final int pixelStride = (uPlane.bytesPerRow > uvWidth) ? 2 : 1;

    for (int y = 0; y < uvHeight; y++) {
      for (int x = 0; x < uvWidth; x++) {
        final int uvOffset = y * uPlane.bytesPerRow + x * pixelStride;
        if (uvOffset < vBuffer.length && uvOffset < uBuffer.length) {
          nv21[uvIndex++] = vBuffer[uvOffset];
          nv21[uvIndex++] = uBuffer[uvOffset];
        }
      }
    }

    return nv21;
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바 (뒤로가기, 운동이름, 카운트)
            _buildTopBar(),
            // 카메라 영역
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.exerciseType.color,
                    width: 3,
                  ),
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  children: [
                    CameraPreview(controller!),
                    // 진행률 표시 오버레이
                    if (holdProgress > 0)
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: _buildProgressBar(),
                      ),
                  ],
                ),
              ),
            ),
            // 상태 메시지
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                statusMessage,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: phase == ExercisePhase.waitingForReady
                      ? Colors.orange
                      : (currentState == ExerciseState.down
                          ? Colors.greenAccent
                          : Colors.white),
                ),
              ),
            ),
            // 애니메이션 영역
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213e),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ExerciseAnimationPainter(
                        exerciseType: widget.exerciseType,
                        phase: phase,
                        currentState: currentState,
                        animationValue: _animation.value,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
            ),
            // 리셋 버튼
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    exerciseCount = 0;
                    currentState = ExerciseState.up;
                    phase = ExercisePhase.waitingForReady;
                    poseHoldStartTime = null;
                    holdProgress = 0.0;
                    _updateStatusMessage();
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    '리셋',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: widget.exerciseType.color.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.exerciseType.name,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.yellow.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$exerciseCount',
              style: const TextStyle(
                fontSize: 24,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        Text(
          '자세 유지 중...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 5)],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: Colors.white30,
            borderRadius: BorderRadius.circular(5),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: holdProgress,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.greenAccent,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// 운동 애니메이션 페인터
class ExerciseAnimationPainter extends CustomPainter {
  final ExerciseType exerciseType;
  final ExercisePhase phase;
  final ExerciseState currentState;
  final double animationValue;

  ExerciseAnimationPainter({
    required this.exerciseType,
    required this.phase,
    required this.currentState,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scale = size.height / 200;

    // 애니메이션 진행도에 따라 자세 결정
    double progress;
    if (phase == ExercisePhase.waitingForReady) {
      // 준비자세 대기 중: 준비자세만 보여줌
      progress = 0.0;
    } else {
      // 운동 중: 현재 해야 할 동작 애니메이션
      if (currentState == ExerciseState.up) {
        // UP → DOWN 애니메이션 (내려가야 함)
        progress = animationValue;
      } else {
        // DOWN → UP 애니메이션 (올라와야 함)
        progress = 1.0 - animationValue;
      }
    }

    switch (exerciseType) {
      case ExerciseType.squat:
        _drawSquat(canvas, centerX, centerY, scale, progress, paint, fillPaint);
        break;
      case ExerciseType.pushup:
        _drawPushup(canvas, centerX, centerY, scale, progress, paint, fillPaint);
        break;
      case ExerciseType.lunge:
        _drawLunge(canvas, centerX, centerY, scale, progress, paint, fillPaint);
        break;
      case ExerciseType.dumbbell:
        _drawDumbbell(canvas, centerX, centerY, scale, progress, paint, fillPaint);
        break;
    }
  }

  void _drawSquat(Canvas canvas, double cx, double cy, double scale,
      double progress, Paint paint, Paint fillPaint) {
    // 스쿼트: 서있는 자세 → 앉은 자세
    // progress 0 = 서있음, progress 1 = 앉음

    final headY = cy - 70 * scale + progress * 30 * scale;
    final bodyY = cy - 40 * scale + progress * 30 * scale;
    final hipY = cy + progress * 20 * scale;
    final kneeY = cy + 40 * scale + progress * 10 * scale;
    final footY = cy + 80 * scale;

    final kneeAngle = progress * 60; // 무릎 굽힘 각도
    final kneeBend = math.sin(kneeAngle * math.pi / 180) * 30 * scale;

    // 머리
    canvas.drawCircle(Offset(cx, headY), 15 * scale, fillPaint);

    // 몸통
    canvas.drawLine(Offset(cx, headY + 15 * scale), Offset(cx, hipY), paint);

    // 왼쪽 다리
    canvas.drawLine(Offset(cx, hipY), Offset(cx - kneeBend, kneeY), paint);
    canvas.drawLine(Offset(cx - kneeBend, kneeY), Offset(cx - 15 * scale, footY), paint);

    // 오른쪽 다리
    canvas.drawLine(Offset(cx, hipY), Offset(cx + kneeBend, kneeY), paint);
    canvas.drawLine(Offset(cx + kneeBend, kneeY), Offset(cx + 15 * scale, footY), paint);

    // 팔
    final armY = cy - 30 * scale + progress * 25 * scale;
    canvas.drawLine(Offset(cx, bodyY), Offset(cx - 30 * scale, armY), paint);
    canvas.drawLine(Offset(cx, bodyY), Offset(cx + 30 * scale, armY), paint);
  }

  void _drawPushup(Canvas canvas, double cx, double cy, double scale,
      double progress, Paint paint, Paint fillPaint) {
    // 팔굽혀펴기: 팔 폄 → 팔 굽힘 (옆에서 본 모습)
    final bodyDrop = progress * 25 * scale;

    // 바닥 라인
    canvas.drawLine(
        Offset(cx - 80 * scale, cy + 60 * scale),
        Offset(cx + 80 * scale, cy + 60 * scale),
        paint..color = Colors.white38);
    paint.color = Colors.white;

    // 몸통 (수평)
    final bodyY = cy - 20 * scale + bodyDrop;
    canvas.drawLine(Offset(cx - 40 * scale, bodyY), Offset(cx + 40 * scale, bodyY), paint);

    // 머리
    canvas.drawCircle(Offset(cx + 50 * scale, bodyY), 12 * scale, fillPaint);

    // 팔 (앞쪽)
    final elbowY = cy + 20 * scale;
    final handY = cy + 55 * scale;
    canvas.drawLine(Offset(cx - 30 * scale, bodyY), Offset(cx - 30 * scale, elbowY), paint);
    canvas.drawLine(Offset(cx - 30 * scale, elbowY), Offset(cx - 30 * scale, handY), paint);

    // 다리
    canvas.drawLine(Offset(cx - 40 * scale, bodyY), Offset(cx - 60 * scale, cy + 55 * scale), paint);
  }

  void _drawLunge(Canvas canvas, double cx, double cy, double scale,
      double progress, Paint paint, Paint fillPaint) {
    // 런지: 서있는 자세 → 런지 자세
    final headY = cy - 70 * scale + progress * 25 * scale;
    final bodyY = cy - 40 * scale + progress * 25 * scale;
    final hipY = cy + progress * 15 * scale;

    // 머리
    canvas.drawCircle(Offset(cx, headY), 15 * scale, fillPaint);

    // 몸통
    canvas.drawLine(Offset(cx, headY + 15 * scale), Offset(cx, hipY), paint);

    // 앞다리 (왼쪽) - 런지 시 굽힘
    final frontKneeX = cx - 20 * scale - progress * 15 * scale;
    final frontKneeY = cy + 35 * scale + progress * 10 * scale;
    final frontFootX = cx - 40 * scale;
    final frontFootY = cy + 80 * scale;
    canvas.drawLine(Offset(cx, hipY), Offset(frontKneeX, frontKneeY), paint);
    canvas.drawLine(Offset(frontKneeX, frontKneeY), Offset(frontFootX, frontFootY), paint);

    // 뒷다리 (오른쪽) - 런지 시 뒤로 뻗음
    final backKneeX = cx + 25 * scale + progress * 20 * scale;
    final backKneeY = cy + 50 * scale + progress * 15 * scale;
    final backFootX = cx + 50 * scale + progress * 20 * scale;
    final backFootY = cy + 80 * scale;
    canvas.drawLine(Offset(cx, hipY), Offset(backKneeX, backKneeY), paint);
    canvas.drawLine(Offset(backKneeX, backKneeY), Offset(backFootX, backFootY), paint);

    // 팔
    canvas.drawLine(Offset(cx, bodyY), Offset(cx - 25 * scale, cy - 20 * scale + progress * 20 * scale), paint);
    canvas.drawLine(Offset(cx, bodyY), Offset(cx + 25 * scale, cy - 20 * scale + progress * 20 * scale), paint);
  }

  void _drawDumbbell(Canvas canvas, double cx, double cy, double scale,
      double progress, Paint paint, Paint fillPaint) {
    // 아령: 팔 내림 → 팔 굽힘 (컬)
    final headY = cy - 60 * scale;
    final shoulderY = cy - 30 * scale;
    final hipY = cy + 30 * scale;

    // 머리
    canvas.drawCircle(Offset(cx, headY), 15 * scale, fillPaint);

    // 몸통
    canvas.drawLine(Offset(cx, headY + 15 * scale), Offset(cx, hipY), paint);

    // 다리
    canvas.drawLine(Offset(cx, hipY), Offset(cx - 15 * scale, cy + 80 * scale), paint);
    canvas.drawLine(Offset(cx, hipY), Offset(cx + 15 * scale, cy + 80 * scale), paint);

    // 팔 - 아령 컬 모션
    final elbowAngle = progress * 120; // 팔꿈치 굽힘 각도
    final forearmLength = 35 * scale;

    // 왼팔
    final leftElbowX = cx - 25 * scale;
    final leftElbowY = shoulderY + 30 * scale;
    canvas.drawLine(Offset(cx, shoulderY), Offset(leftElbowX, leftElbowY), paint);

    final leftWristX = leftElbowX - math.cos((90 - elbowAngle) * math.pi / 180) * forearmLength;
    final leftWristY = leftElbowY - math.sin((90 - elbowAngle) * math.pi / 180) * forearmLength;
    canvas.drawLine(Offset(leftElbowX, leftElbowY), Offset(leftWristX, leftWristY), paint);

    // 왼쪽 아령
    final dumbbellPaint = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 8 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(leftWristX - 8 * scale, leftWristY),
        Offset(leftWristX + 8 * scale, leftWristY),
        dumbbellPaint);

    // 오른팔
    final rightElbowX = cx + 25 * scale;
    final rightElbowY = shoulderY + 30 * scale;
    canvas.drawLine(Offset(cx, shoulderY), Offset(rightElbowX, rightElbowY), paint);

    final rightWristX = rightElbowX + math.cos((90 - elbowAngle) * math.pi / 180) * forearmLength;
    final rightWristY = rightElbowY - math.sin((90 - elbowAngle) * math.pi / 180) * forearmLength;
    canvas.drawLine(Offset(rightElbowX, rightElbowY), Offset(rightWristX, rightWristY), paint);

    // 오른쪽 아령
    canvas.drawLine(
        Offset(rightWristX - 8 * scale, rightWristY),
        Offset(rightWristX + 8 * scale, rightWristY),
        dumbbellPaint);
  }

  @override
  bool shouldRepaint(covariant ExerciseAnimationPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.currentState != currentState ||
        oldDelegate.phase != phase;
  }
}
