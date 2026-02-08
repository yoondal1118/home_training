import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:confetti/confetti.dart';
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
        return Icons.fitness_center;
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
        return '전신이 보이게 서세요';
      case ExerciseType.pushup:
        return '플랭크 자세를 취하세요';
      case ExerciseType.lunge:
        return '전신이 보이게 서세요';
      case ExerciseType.dumbbell:
        return '전신이 보이게 서세요';
    }
  }

  String get imagePath {
    switch (this) {
      case ExerciseType.squat:
        return 'assets/images/squat.png';
      case ExerciseType.pushup:
        return 'assets/images/pushup.png';
      case ExerciseType.lunge:
        return 'assets/images/lunge.png';
      case ExerciseType.dumbbell:
        return 'assets/images/dumbbell.png';
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
                            builder: (context) => ExerciseGoalScreen(
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
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                exercise.imagePath,
                width: 70,
                height: 70,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    exercise.icon,
                    size: 60,
                    color: Colors.white,
                  );
                },
              ),
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

// 할당량 설정 화면
class ExerciseGoalScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ExerciseType exerciseType;

  const ExerciseGoalScreen({
    super.key,
    required this.cameras,
    required this.exerciseType,
  });

  @override
  State<ExerciseGoalScreen> createState() => _ExerciseGoalScreenState();
}

class _ExerciseGoalScreenState extends State<ExerciseGoalScreen> {
  int targetCount = 20;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = targetCount.toString();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _incrementCount() {
    setState(() {
      targetCount++;
      _controller.text = targetCount.toString();
    });
  }

  void _decrementCount() {
    setState(() {
      if (targetCount > 1) {
        targetCount--;
        _controller.text = targetCount.toString();
      }
    });
  }

  void _showNumberInput() {
    showDialog(
      context: context,
      builder: (context) {
        final dialogController = TextEditingController(text: targetCount.toString());
        return AlertDialog(
          backgroundColor: const Color(0xFF16213e),
          title: const Text(
            '목표 횟수 입력',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: dialogController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 24),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1a1a2e),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(dialogController.text);
                if (value != null && value > 0) {
                  setState(() {
                    targetCount = value;
                    _controller.text = targetCount.toString();
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('확인', style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바
            Padding(
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
                  Text(
                    widget.exerciseType.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: widget.exerciseType.color,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 44), // 균형을 위한 공간
                ],
              ),
            ),
            // 메인 콘텐츠
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '목표 횟수를 설정하세요',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 50),
                  // 카운터 컨트롤
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 감소 버튼
                      GestureDetector(
                        onTap: _decrementCount,
                        child: Container(
                          width: 60,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF16213e),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 30),
                      // 숫자 표시 (클릭하여 직접 입력)
                      GestureDetector(
                        onTap: _showNumberInput,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.exerciseType.color,
                              width: 5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$targetCount',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 30),
                      // 증가 버튼
                      GestureDetector(
                        onTap: _incrementCount,
                        child: Container(
                          width: 60,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF16213e),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 시작 버튼
            Padding(
              padding: const EdgeInsets.all(30),
              child: GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExerciseCounterScreen(
                        cameras: widget.cameras,
                        exerciseType: widget.exerciseType,
                        targetCount: targetCount,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.exerciseType.color,
                        widget.exerciseType.color.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: widget.exerciseType.color.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '시작하기',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
}

// 운동 카운터 화면
class ExerciseCounterScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ExerciseType exerciseType;
  final int targetCount;

  const ExerciseCounterScreen({
    super.key,
    required this.cameras,
    required this.exerciseType,
    required this.targetCount,
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

  // TTS
  late FlutterTts flutterTts;
  bool _isSpeaking = false;

  // 자세 유지 시간 체크용
  DateTime? poseHoldStartTime;
  static const Duration requiredHoldDuration = Duration(milliseconds: 1000);
  double holdProgress = 0.0; // 0.0 ~ 1.0

  // 애니메이션 컨트롤러
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _initTts();
    _updateStatusMessage();

    // 애니메이션 설정 (2초 주기로 반복)
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    // 0 -> 1로 갔다가 1->0으로 돌아옴
    _animationController.repeat(reverse: true);

    // 카메라 초기화
    CameraLensDirection preferredDirection = CameraLensDirection.front;
    // 전면 카메라 쓰라는 코드
    final camera = widget.cameras.firstWhere(
      (cam) => cam.lensDirection == preferredDirection,
      orElse: () => widget.cameras.first,
    );
    // 카메라 화질 설정
    controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    
    controller?.initialize().then((_) {
      // 화면이 꺼졌다면 중단
      if (!mounted) return;
      controller?.startImageStream((image) => processImage(image));
      setState(() {});
    });
  }

  // TTS 초기화
  Future<void> _initTts() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage('ko-KR');
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
    
    flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });
    
    flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });
    
    flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
    });
  }

  // TTS로 메시지 읍기
  Future<void> _speak(String message) async {
    if (_isSpeaking) {
      await flutterTts.stop();
    }
    await flutterTts.speak(message);
  }

  // 운동 메시지
  void _updateStatusMessage() {
    String newMessage;
    if (phase == ExercisePhase.waitingForReady) {
      newMessage = widget.exerciseType.readyPoseDescription;
    } else {
      switch (widget.exerciseType) {
        case ExerciseType.squat:
          newMessage = currentState == ExerciseState.down ? "올라오세요!" : "앉으세요!";
          break;
        case ExerciseType.pushup:
          newMessage = currentState == ExerciseState.down ? "올라오세요!" : "내려가세요!";
          break;
        case ExerciseType.lunge:
          newMessage = currentState == ExerciseState.down ? "올라오세요!" : "무릎을 굽히세요!";
          break;
        case ExerciseType.dumbbell:
          newMessage = currentState == ExerciseState.up ? "들어올리세요!" : "내리세요!";
          break;
      }
    }
    
    // 메시지가 변경되었을 때만 TTS 실행
    if (statusMessage != newMessage) {
      statusMessage = newMessage;
      _speak(newMessage);
    }
  }

  // 목표 달성 시 호출
  void _onGoalReached() {
    // 카메라 스트림 중지
    controller?.stopImageStream();
    
    // 축하 페이지로 이동
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseCompleteScreen(
          cameras: widget.cameras,
          exerciseType: widget.exerciseType,
          completedCount: exerciseCount,
        ),
      ),
    );
  }

  // 전원 끄기 함수
  @override
  void dispose() {
    flutterTts.stop();
    _animationController.dispose();
    controller?.dispose();
    poseDetector.close();
    super.dispose();
  }
  // 카메라가 보내준 데이터를 AI가 이해할 수 있는 언어로 번역 & 분석결과를 가져오는 함수
  Future<void> processImage(CameraImage image) async {
    if (isBusy || controller == null) return;
    // 분석중
    isBusy = true;
    // inputImage : AI가 이해할 수 있는 형식의 이미지
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        isBusy = false;
        return;
      }
      // AI 분석
      final poses = await poseDetector.processImage(inputImage);
      // 사람이 보일 경우, 첫 번째 사람의 관절 정보를 가져와 판독
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
            
            // 목표 달성 체크
            if (exerciseCount >= widget.targetCount) {
              _onGoalReached();
            }
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

  // 관절의 신뢰도 체크 (likelihood 기준)
  static const double _minLikelihood = 0.7;

  // 전신 관절 확인 (서있는 자세용: 스쿼트, 런지, 아령)
  bool _checkStandingFullBodyVisible(Pose pose) {
    final requiredLandmarks = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];
    
    for (final landmarkType in requiredLandmarks) {
      final landmark = pose.landmarks[landmarkType];
      if (landmark == null || landmark.likelihood < _minLikelihood) {
        return false;
      }
    }
    return true;
  }

  // 전신 관절 확인 (플랭크 자세용: 팔굽혀펴기)
  bool _checkPlankFullBodyVisible(Pose pose) {
    final requiredLandmarks = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];
    
    for (final landmarkType in requiredLandmarks) {
      final landmark = pose.landmarks[landmarkType];
      if (landmark == null || landmark.likelihood < _minLikelihood) {
        return false;
      }
    }
    return true;
  }

  Map<String, double>? _getExerciseAngles(Pose pose) {
    switch (widget.exerciseType) {
      case ExerciseType.squat:
      case ExerciseType.lunge:
        // 전신이 보이는지 먼저 확인
        if (!_checkStandingFullBodyVisible(pose)) {
          return null;
        }
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
        // 플랭크 자세에서 전신이 보이는지 확인
        if (!_checkPlankFullBodyVisible(pose)) {
          return null;
        }
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

      case ExerciseType.dumbbell:
        // 전신이 보이는지 먼저 확인
        if (!_checkStandingFullBodyVisible(pose)) {
          return null;
        }
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

  // 준비 자세 체크
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
  // 준비 완료되면 운동 시작
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
  // 카운트 되려면 다시 돌아와야 함
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
  // 운동 각도 제기
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
    // 카메라 센서가 얼마나 돌아가 있는지 체크
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    // 안드로이드
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
    // 아이폰
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotation.rotation0deg;
    }

    if (rotation == null) return null;
    // 안드로이드 처리
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
    // 안드로이드 제외 다른 플랫폼
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
  // CPU가 가장 효율적으로 데이터를 읽을 수 있도록 메모리 레이아웃을 재배치
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
  // 운동 화면
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
                margin: const EdgeInsets.all(8.0),
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
                margin: const EdgeInsets.all(8.0),
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
                    color: Colors.red.withValues(alpha: 0.8),
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
              color: widget.exerciseType.color.withValues(alpha: 0.8),
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
              color: Colors.yellow.withValues(alpha: 0.9),
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
    // progress 0 = 팔 펴 (위), progress 1 = 팔 굽힘 (아래)
    final bodyDrop = progress * 30 * scale;

    // 바닥 라인
    final groundY = cy + 60 * scale;
    canvas.drawLine(
        Offset(cx - 80 * scale, groundY),
        Offset(cx + 80 * scale, groundY),
        paint..color = Colors.white38);
    paint.color = Colors.white;

    // 몸통 위치 (수평으로 유지, 내려갈 때 bodyDrop만큼 내려감)
    final bodyY = cy - 10 * scale + bodyDrop;
    
    // 머리 (오른쪽)
    final headX = cx + 55 * scale;
    canvas.drawCircle(Offset(headX, bodyY - 5 * scale), 12 * scale, fillPaint);
    
    // 몸통 (어깨에서 엉덩이까지)
    final shoulderX = cx + 35 * scale;
    final hipX = cx - 35 * scale;
    canvas.drawLine(Offset(shoulderX, bodyY), Offset(hipX, bodyY), paint);

    // 팔 (어깨에서 바닥으로) - 팔꿈치가 굽혀지는 모습
    final handY = groundY;
    final elbowBend = progress * 25 * scale; // 팔꿈치가 바깥으로 굽혀지는 정도
    final elbowY = bodyY + (handY - bodyY) * 0.5; // 팔꿈치는 어깨와 손 중간
    final elbowX = shoulderX + elbowBend; // 팔꿈치가 오른쪽으로 굽혀짐
    
    // 어깨 → 팔꿈치
    canvas.drawLine(Offset(shoulderX, bodyY), Offset(elbowX, elbowY), paint);
    // 팔꿈치 → 손 (손은 바닥에 고정)
    canvas.drawLine(Offset(elbowX, elbowY), Offset(shoulderX, handY), paint);

    // 다리 (엉덩이에서 발까지)
    final footX = cx - 70 * scale;
    canvas.drawLine(Offset(hipX, bodyY), Offset(footX, groundY), paint);
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

// 운동 완료 축하 화면
class ExerciseCompleteScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ExerciseType exerciseType;
  final int completedCount;

  const ExerciseCompleteScreen({
    super.key,
    required this.cameras,
    required this.exerciseType,
    required this.completedCount,
  });

  @override
  State<ExerciseCompleteScreen> createState() => _ExerciseCompleteScreenState();
}

class _ExerciseCompleteScreenState extends State<ExerciseCompleteScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    // 화면 진입 시 자동으로 폭죽 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: Stack(
        children: [
          // 메인 콘텐츠
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 100),
                // 축하 메시지
                const Text(
                  '🎉 축하합니다! 🎉',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  '할당된 운동을 완료하였습니다!',
                  style: TextStyle(
                    fontSize: 22,
                    color: widget.exerciseType.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 50),
                // 완료 정보
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213e),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.exerciseType.color.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          widget.exerciseType.imagePath,
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              widget.exerciseType.icon,
                              size: 80,
                              color: widget.exerciseType.color,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.exerciseType.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${widget.completedCount}회 완료!',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: widget.exerciseType.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // 다른 운동하기 버튼
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExerciseSelectionScreen(
                            cameras: widget.cameras,
                          ),
                        ),
                        (route) => false,
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.exerciseType.color,
                            widget.exerciseType.color.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: widget.exerciseType.color.withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '다른 운동하기',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 폭죽 효과 - 왼쪽
          Align(
            alignment: Alignment.topLeft,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: -math.pi / 4, // 오른쪽 아래 방향
              maxBlastForce: 20,
              minBlastForce: 10,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              shouldLoop: false,
              colors: const [
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.purple,
                Colors.orange,
                Colors.pink,
              ],
            ),
          ),
          // 폭죽 효과 - 오른쪽
          Align(
            alignment: Alignment.topRight,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: -3 * math.pi / 4, // 왼쪽 아래 방향
              maxBlastForce: 20,
              minBlastForce: 10,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              shouldLoop: false,
              colors: const [
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.purple,
                Colors.orange,
                Colors.pink,
              ],
            ),
          ),
          // 폭죽 효과 - 중앙 상단
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: math.pi / 2, // 아래 방향
              maxBlastForce: 15,
              minBlastForce: 5,
              emissionFrequency: 0.03,
              numberOfParticles: 30,
              gravity: 0.05,
              shouldLoop: false,
              colors: const [
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.purple,
                Colors.orange,
                Colors.pink,
              ],
            ),
          ),
        ],
      ),
    );
  }
}