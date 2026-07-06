# Face Registration & Verification Notes (MVP Scope)

This document describes the design, implementation, limitations, and future upgrade path for the Face Registration and Verification systems in SmartPresence.

---

## 1. What the MVP Face System Does

The current system serves as an **MVP anti-proxy attendance mechanism** for attended sessions (e.g., in classrooms or offices where a proctor or manager is present).

### Face Registration
During the organization admin/receptionist's creation of a new user:
1. **Camera Capture:** The user captures a front-facing photo of the member.
2. **Face Detection (ML Kit):** On mobile devices, the system runs Google ML Kit Face Detection to ensure:
   - Exactly **one face** is present in the frame.
   - The face is **front-facing** (head yaw angle $\le 25^\circ$, pitch angle $\le 15^\circ$).
   - The face is **sufficiently large** (occupies $\ge 8\%$ of the frame area).
3. **Landmark Extraction:** The system extracts coordinates for 6 key face landmarks:
   - Left eye, right eye
   - Nose base
   - Mouth left, mouth right, mouth bottom
4. **Data Normalization & Storage:** Coordinates are normalized relative to the bounding box/image dimensions and saved in the `faceRegistrations/{userId}` Firestore collection.
5. **Quality Scoring:** A quality score is calculated based on pose accuracy, size, and landmark detection confidence. High-quality registration is required to proceed.

### Face Verification (Attendance Marking)
When a member scans a dynamic QR code:
1. **Live Camera Capture:** The front-facing camera opens.
2. **Landmark Ratio Comparison:** Instead of absolute pixel distances (which change with distance from the camera), the system computes relative ratios between key landmarks:
   - **Eye-to-Nose Ratio:** Distance from eye midpoint to nose base normalized by inter-eye distance.
   - **Mouth Width Ratio:** Distance between mouth corners normalized by inter-eye distance.
   - **Nose-to-Mouth Ratio:** Distance from nose base to mouth bottom normalized by inter-eye distance.
   - **Eye-to-Mouth Ratio:** Distance from eye midpoint to mouth bottom normalized by inter-eye distance.
   - **Nose Offset:** Horizontal offset of the nose from the eye midpoint normalized by inter-eye distance.
3. **Validation:** Ratios are compared against the registered values. If the relative difference is within the allowed threshold ($\le 25\%$), the verification passes.
4. **Verification Proof:** The verification photo is captured and stored in Firebase Storage as a proof of presence.

---

## 2. Platform Fallbacks (Desktop/Web)

On desktop or web environments where Google ML Kit is not natively available or supported via standard Flutter bindings:
- **No Face Detection is performed.**
- The system captures a live camera photo.
- The photo is stored in Firebase Storage and marked in Firestore with the metadata `provider: 'manual_photo'` (for registration) or `verificationMethod: 'photo_proof'` (for attendance).
- This ensures the app remains fully functional on all platforms while providing administrators with audit logs containing visual proof of presence.

---

## 3. What the MVP Does NOT Do (Limitations)

- **No Embedding Generation:** It does not extract facial embedding vectors (e.g., using FaceNet or ArcFace models).
- **No Biometric Template Matching:** Ratios are heuristic-based and have higher false accept/reject rates compared to certified biometric templates.
- **No Liveness Detection / Anti-Spoofing:** The current implementation cannot distinguish between a live person and a high-resolution photo/video shown to the camera. It relies on the presence of a session proctor to prevent spoofing.

---

## 4. Architecture Upgrade Path

The face registration and verification models are designed to be easily extensible. 

### Data Schema Extensibility
The Firestore schema contains:
- `provider`: String identifier of the face service (currently `google_mlkit_face_detection` or `manual_photo`).
- `faceData`: Extensible map of landmarks and metadata.

### Swapping the Comparison Algorithm
To upgrade to enterprise-grade face recognition (e.g., using TensorFlow Lite + FaceNet):
1. **Integrate FaceNet TFLite Interpreter:** Add the `tflite_flutter` package.
2. **Update Registration:** During capture, crop the detected face bounding box, feed it to the TFLite interpreter, and extract a 512-dimensional floating-point embedding vector. Store this vector in `faceData.embedding` under `faceRegistrations/{userId}`.
3. **Update Verification:** Perform the same embedding extraction on the live frame and calculate the Euclidean/Cosine distance between the live embedding and the registered embedding. Pass verification if the distance is below a strict threshold (e.g., $\le 0.6$ for Euclidean distance).
4. **Update Provider Name:** Set the `provider` field to `tflite_facenet` to mark that the record uses high-fidelity embeddings.
