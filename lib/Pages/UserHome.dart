import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:app/AgoraLogic/agora_logic.dart';
import 'package:app/Services/UserService.dart';
import 'package:app/Pages/settingPage.dart';

class UserHome extends StatefulWidget {
  const UserHome({Key? key}) : super(key: key);

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  final UserService _userService = UserService();
  final FlutterTts flutterTts = FlutterTts();

  AgoraLogic? _agoraLogic;
  Timer? _reminderTimer;

  bool inCall = false;
  bool isMuted = false;
  bool isCameraOff = false;
  String connectionStatus = "Disconnected";
  String userName = '';
  String userType = '';
  String? currentRequestId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _startReminderTimer();
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    _agoraLogic?.cleanup();
    super.dispose();
  }

  void _startReminderTimer() {
    _reminderTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!inCall) {
        _speak("press the button to request assistance");
      }
    });
  }

  Future<void> _speak(String text) async {
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  Future<void> _loadUserData() async {
    final data = await _userService.loadUserData();
    if (data != null) {
      setState(() {
        userName = data['firstName'] ?? 'User';
        userType = data['userType'] ?? '';
      });
      _speak("Welcome $userName");
    }
  }

  Future<void> requestAssistance() async {
    final user = _userService.currentUser;
    if (user == null) return;

    setState(() {
      inCall = true;
      connectionStatus = "Connecting...";
    });

    _speak("Requesting assistance");

    const appId = 'ad016719e08149d3b8176049cbbe8024';
    final channelId = user.uid;

    _agoraLogic = AgoraLogic(
      appId: appId,
      channel: channelId,
      onRemoteUserJoined: (_) => setState(() {}),
      onRemoteUserLeft: (_) => setState(() {}),
    );

    await _agoraLogic!.initialize();
    await _agoraLogic!.requestPermissions();
    await _agoraLogic!.setupLocalVideo();
    await _agoraLogic!.joinChannel();

    currentRequestId = await _userService.createRequest(
      userName: userName,
      userType: userType,
      channelId: channelId,
    );

    setState(() => connectionStatus = "Live");
    _speak("Call started");
  }

  void endCall() async {
    await _agoraLogic?.cleanup();
    _agoraLogic = null;

    setState(() {
      inCall = false;
      isMuted = false;
      isCameraOff = false;
      connectionStatus = "Disconnected";
    });

    if (currentRequestId != null) {
      _userService.completeRequest(currentRequestId!);
    }

    _speak("Call ended");
  }

  void toggleMute() {
    setState(() => isMuted = !isMuted);
    _agoraLogic?.toggleLocalAudio(isMuted);
  }

  void toggleCamera() {
    setState(() => isCameraOff = !isCameraOff);
    _agoraLogic?.toggleLocalVideo(isCameraOff);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("be my guide"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    userName: userName,
                    userEmail: '',
                    onLogout: () async {
                      await _userService.logout();
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        'splashPage',
                        (_) => false,
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (inCall)
                Text(
                  connectionStatus,
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              const SizedBox(height: 12),

              if (inCall && _agoraLogic != null)
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _agoraLogic!.remoteVideoView(),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        right: 16,
                        width: 120,
                        height: 160,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _agoraLogic!.localVideoView(),
                        ),
                      ),
                    ],
                  ),
                ),

            
              if (!inCall)
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: requestAssistance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          "Request Visual Assistance",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Call a volunteer now",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (inCall) const SizedBox(height: 12),

              if (inCall)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(isMuted ? Icons.mic_off : Icons.mic),
                      iconSize: 32,
                      color: Colors.blueAccent,
                      onPressed: toggleMute,
                    ),
                    IconButton(
                      icon: Icon(
                        isCameraOff
                            ? Icons.videocam_off
                            : Icons.videocam,
                      ),
                      iconSize: 32,
                      color: Colors.blueAccent,
                      onPressed: toggleCamera,
                    ),
                    IconButton(
                      icon: const Icon(Icons.call_end),
                      iconSize: 32,
                      color: Colors.redAccent,
                      onPressed: endCall,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
