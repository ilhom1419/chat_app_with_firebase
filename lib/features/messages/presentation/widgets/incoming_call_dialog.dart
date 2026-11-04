import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../pages/call_page.dart';
import '../../../../core/design_system/app_colors.dart';

class IncomingCallListener extends StatefulWidget {
  final Widget child;

  const IncomingCallListener({
    super.key,
    required this.child,
  });

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener> {
  StreamSubscription? _callSubscription;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _startListeningForCalls();
  }

  void _startListeningForCalls() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty && !_isDialogShowing) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        final callId = doc.id;
        final callerName = data['callerName'] ?? 'Someone';
        final isVideo = data['isVideo'] ?? false;
        final chatId = data['chatId'] ?? '';

        _showIncomingCallDialog(callId, chatId, callerName, isVideo, user.uid);
      }
    });
  }

  void _showIncomingCallDialog(
    String callId,
    String chatId,
    String callerName,
    bool isVideo,
    String currentUserId,
  ) {
    _isDialogShowing = true;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F172A).withOpacity(0.95),
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 54,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: Text(
                      callerName.isNotEmpty ? callerName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    callerName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isVideo ? Icons.videocam : Icons.call,
                        color: Colors.greenAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isVideo ? 'Incoming Video Call...' : 'Incoming Audio Call...',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 80),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Reject Button
                      GestureDetector(
                        onTap: () async {
                          _isDialogShowing = false;
                          Navigator.of(context).pop();
                          try {
                            await FirebaseFirestore.instance
                                .collection('calls')
                                .doc(callId)
                                .update({'status': 'rejected'});
                          } catch (_) {}
                        },
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.redAccent,
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),

                      // Accept Button
                      GestureDetector(
                        onTap: () {
                          _isDialogShowing = false;
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CallPage(
                                chatId: chatId,
                                currentUserId: currentUserId,
                                otherUserName: callerName,
                                isVideo: isVideo,
                                isCaller: false,
                                existingCallId: callId,
                              ),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.green,
                          child: const Icon(
                            Icons.call,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
