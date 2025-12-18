import 'package:app/Pages/settingPage.dart';
import 'package:app/AgoraLogic/agora_logic.dart';
import 'package:app/Services/VolunteerService.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VolunteerHome extends StatefulWidget {
  const VolunteerHome({Key? key}) : super(key: key);

  @override
  State<VolunteerHome> createState() => _VolunteerHomeState();
}

class _VolunteerHomeState extends State<VolunteerHome> {
  final VolunteerService _volunteerService = VolunteerService();
  final FlutterTts flutterTts = FlutterTts();

  AgoraLogic? _agoraLogic;

  String userName = '';
  String userEmail = '';
  String userType = '';

  bool inCall = false;
  bool isMuted = false;
  bool isCameraOff = false;
  String connectionStatus = "Disconnected";

  String? currentRequestId;
  String? currentRequestUserName;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _agoraLogic?.cleanup();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  Future<void> _loadUserData() async {
    final userData = await _volunteerService.loadUserData();
    if (userData != null) {
      setState(() {
        userName = userData['firstName'] ?? 'Volunteer';
        userEmail = userData['email'] ?? '';
        userType = userData['userType'] ?? '';
      });
      await _volunteerService.setupNotifications(userType);
      _speak("Welcome $userName");
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    if (inCall) return;

    setState(() {
      inCall = true;
      connectionStatus = "Connecting...";
      currentRequestId = request['requestId'];
      currentRequestUserName = request['userName'];
    });

    _speak("Connecting with ${request['userName']}");

    const agoraAppId = 'ad016719e08149d3b8176049cbbe8024';

    _agoraLogic = AgoraLogic(
      appId: agoraAppId,
      channel: request['channelId'],
      onRemoteUserJoined: (_) => setState(() {}),
      onRemoteUserLeft: (_) => setState(() {}),
    );

    await _agoraLogic!.initialize();
    await _agoraLogic!.requestPermissions();
    await _agoraLogic!.setupLocalVideo();
    await _agoraLogic!.joinChannel();

    await _volunteerService.acceptRequestInFirestore(
      request['requestId'],
      userName,
    );

    setState(() => connectionStatus = "Live");
    _speak("Call is live");
  }

  void endCall() async {
    if (currentRequestId != null) {
      _volunteerService.completeRequestInFirestore(currentRequestId!);
    }

    await _agoraLogic?.cleanup();
    _agoraLogic = null;

    setState(() {
      inCall = false;
      isMuted = false;
      isCameraOff = false;
      connectionStatus = "Disconnected";
      currentRequestId = null;
      currentRequestUserName = null;
    });

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

  void _logout() async {
    await _volunteerService.logout();
    Navigator.pushNamedAndRemoveUntil(
      context,
      'splashPage',
      (_) => false,
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          userName: userName,
          userEmail: userEmail,
          onLogout: _logout,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text("be my guide"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: inCall
            ? Column(
                children: [
                  const SizedBox(height: 10),
                  Text(
                    connectionStatus,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

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
                          right: 16,
                          bottom: 16,
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

                  const SizedBox(height: 10),

                  /// 🎛 Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(isMuted ? Icons.mic_off : Icons.mic),
                        color: Colors.greenAccent,
                        iconSize: 32,
                        onPressed: toggleMute,
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        icon: Icon(
                          isCameraOff
                              ? Icons.videocam_off
                              : Icons.videocam,
                        ),
                        color: Colors.greenAccent,
                        iconSize: 32,
                        onPressed: toggleCamera,
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        icon: const Icon(Icons.call_end),
                        color: Colors.redAccent,
                        iconSize: 32,
                        onPressed: endCall,
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        icon: const Icon(Icons.cameraswitch),
                        color: Colors.greenAccent,
                        iconSize: 32,
                        onPressed: () => _agoraLogic?.switchCamera(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              )

            
            : StreamBuilder<QuerySnapshot>(
                stream: _volunteerService.getRequestsStream(userType),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  final requests = docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return {
                      'userName': data['userName'],
                      'requestId': doc.id,
                      'status': data['status'],
                      'channelId': data['channelId'],
                    };
                  }).toList();

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      return ListTile(
                        title: Text(
                          req['userName'],
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          "Tap to accept call",
                          style: TextStyle(color: Colors.grey),
                        ),
                        onTap: () => _acceptRequest(req),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
