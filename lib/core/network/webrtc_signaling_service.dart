import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef StreamStateCallback = void Function(MediaStream stream);

class WebRTCSignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ]
      }
    ]
  };

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  StreamStateCallback? onAddRemoteStream;
  VoidCallback? onCallEnded;

  StreamSubscription? _callSubscription;
  StreamSubscription? _candidatesSubscription;

  Future<void> openUserMedia(
    RTCVideoRenderer localRenderer,
    RTCVideoRenderer remoteRenderer, {
    required bool isVideo,
  }) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': isVideo
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };

    try {
      localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = localStream;

      // Initialize an empty MediaStream for remote — will be populated via onTrack
      remoteStream = await createLocalMediaStream('remoteStream');
      remoteRenderer.srcObject = remoteStream;
    } catch (e) {
      debugPrint('Error opening user media: $e');
    }
  }

  Future<String> createRoom(
    RTCVideoRenderer remoteRenderer, {
    required String chatId,
    required String callerId,
    required String callerName,
    required String receiverId,
    required bool isVideo,
  }) async {
    final callDocRef = _firestore.collection('calls').doc();
    final callId = callDocRef.id;

    peerConnection = await createPeerConnection(configuration);
    registerPeerConnectionListeners();

    if (localStream != null) {
      localStream!.getTracks().forEach((track) {
        peerConnection?.addTrack(track, localStream!);
      });
    }

    final callerCandidatesCollection = callDocRef.collection('callerCandidates');

    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      callerCandidatesCollection.add(candidate.toMap());
    };

    peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        event.streams[0].getTracks().forEach((track) {
          remoteStream?.addTrack(track);
        });
        remoteRenderer.srcObject = event.streams[0];
        if (onAddRemoteStream != null) {
          onAddRemoteStream!(event.streams[0]);
        }
      }
    };

    // Create SDP Offer
    RTCSessionDescription offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);

    Map<String, dynamic> roomWithOffer = {
      'callId': callId,
      'chatId': chatId,
      'callerId': callerId,
      'callerName': callerName,
      'receiverId': receiverId,
      'isVideo': isVideo,
      'status': 'ringing', // ringing, accepted, rejected, ended
      'offer': {
        'type': offer.type,
        'sdp': offer.sdp,
      },
      'createdAt': FieldValue.serverTimestamp(),
    };

    await callDocRef.set(roomWithOffer);

    // Listen for remote answer SDP
    _callSubscription = callDocRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      final status = data['status'];
      if (status == 'ended' || status == 'rejected') {
        if (onCallEnded != null) onCallEnded!();
        return;
      }

      if (peerConnection?.getRemoteDescription() == null && data['answer'] != null) {
        var answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        await peerConnection?.setRemoteDescription(answer);
      }
    });

    // Listen for receiver ICE candidates
    _candidatesSubscription =
        callDocRef.collection('receiverCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          peerConnection?.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      }
    });

    return callId;
  }

  Future<void> joinRoom(
    String callId,
    RTCVideoRenderer remoteRenderer,
  ) async {
    final callDocRef = _firestore.collection('calls').doc(callId);
    final callSnapshot = await callDocRef.get();

    if (!callSnapshot.exists) return;

    peerConnection = await createPeerConnection(configuration);
    registerPeerConnectionListeners();

    if (localStream != null) {
      localStream!.getTracks().forEach((track) {
        peerConnection?.addTrack(track, localStream!);
      });
    }

    final receiverCandidatesCollection = callDocRef.collection('receiverCandidates');
    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      receiverCandidatesCollection.add(candidate.toMap());
    };

    peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        event.streams[0].getTracks().forEach((track) {
          remoteStream?.addTrack(track);
        });
        remoteRenderer.srcObject = event.streams[0];
        if (onAddRemoteStream != null) {
          onAddRemoteStream!(event.streams[0]);
        }
      }
    };

    // Fetch SDP offer
    var data = callSnapshot.data() as Map<String, dynamic>;
    var offer = data['offer'];
    if (offer != null) {
      await peerConnection!.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );
    }

    // Create SDP Answer
    var answer = await peerConnection!.createAnswer();
    await peerConnection!.setLocalDescription(answer);

    Map<String, dynamic> roomWithAnswer = {
      'answer': {'type': answer.type, 'sdp': answer.sdp},
      'status': 'accepted',
    };

    await callDocRef.update(roomWithAnswer);

    // Listen for caller ICE candidates
    _candidatesSubscription =
        callDocRef.collection('callerCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          peerConnection?.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      }
    });

    // Listen for hangup
    _callSubscription = callDocRef.snapshots().listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data != null && (data['status'] == 'ended' || data['status'] == 'rejected')) {
        if (onCallEnded != null) onCallEnded!();
      }
    });
  }

  Future<void> rejectCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({'status': 'rejected'});
    } catch (e) {
      debugPrint('Error rejecting call: $e');
    }
  }

  Future<void> hangUp(
    RTCVideoRenderer localRenderer,
    RTCVideoRenderer remoteRenderer,
    String? callId,
  ) async {
    if (callId != null && callId.isNotEmpty) {
      try {
        await _firestore.collection('calls').doc(callId).update({'status': 'ended'});
      } catch (_) {}
    }

    await _callSubscription?.cancel();
    await _candidatesSubscription?.cancel();

    localStream?.getTracks().forEach((track) {
      track.stop();
    });
    remoteStream?.getTracks().forEach((track) {
      track.stop();
    });

    await localStream?.dispose();
    await remoteStream?.dispose();

    localStream = null;
    remoteStream = null;

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    await peerConnection?.close();
    await peerConnection?.dispose();
    peerConnection = null;
  }

  void toggleMic(bool isMuted) {
    if (localStream != null) {
      for (var track in localStream!.getAudioTracks()) {
        track.enabled = !isMuted;
      }
    }
  }

  void toggleCamera(bool isVideoOff) {
    if (localStream != null) {
      for (var track in localStream!.getVideoTracks()) {
        track.enabled = !isVideoOff;
      }
    }
  }

  void switchCamera() {
    if (localStream != null && localStream!.getVideoTracks().isNotEmpty) {
      Helper.switchCamera(localStream!.getVideoTracks()[0]);
    }
  }

  void registerPeerConnectionListeners() {
    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      debugPrint('ICE gathering state changed: $state');
    };

    peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('Connection state change: $state');
    };

    peerConnection?.onSignalingState = (RTCSignalingState state) {
      debugPrint('Signaling state change: $state');
    };
  }
}
