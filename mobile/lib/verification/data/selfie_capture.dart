import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Takes the verification selfie. Its own small seam (rather than the screen
/// calling `ImagePicker` directly) so tests can hand the screen a photo without
/// a camera, and so the two rules that matter live in one place:
///
/// - **Camera only, front-facing.** There is no gallery option on purpose: a
///   verification selfie has to be taken now, showing the pose asked for.
/// - **Capped size.** The server re-encodes and rejects images over 4096px, and a
///   1600px selfie is plenty for a face match while keeping the upload small.
class SelfieCapture {
  const SelfieCapture();

  /// The path of the captured photo, or null if the person backed out.
  Future<String?> capture() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    return file?.path;
  }
}

final selfieCaptureProvider = Provider<SelfieCapture>(
  (ref) => const SelfieCapture(),
);
