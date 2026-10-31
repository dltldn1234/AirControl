# YOLO Hand Pose Evaluation

Updated: 2026-11-01. This is a source and licensing assessment only; AirControl does not contain a YOLO model or run YOLO inference.

## Repository evidence

- The current camera path calls Apple's `VNDetectHumanHandPoseRequest` and normalizes observations into `HandJoint` values.
- No `.mlmodel`, `.mlpackage`, ONNX, or TFLite hand-pose model is currently present in the repository.
- The cursor pipeline already consumes the confidently detected index fingertip. Any future provider must preserve that priority and the existing cursor-control and Accessibility gates.

## Model fit and licensing

- Ultralytics' standard COCO pose model is trained for 17 body keypoints such as shoulders, wrists, hips, knees, and ankles. It does not provide the 21 finger landmarks AirControl needs for pinch recognition. See [COCO Pose keypoint schema](https://docs.ultralytics.com/datasets/pose/coco/).
- Ultralytics documents a separate 21-keypoint hand dataset. Its source images are distributed under CC BY-NC-SA 4.0, so that dataset is not a drop-in choice for a commercial product. See [Hand Keypoints dataset and license](https://docs.ultralytics.com/datasets/pose/hand-keypoints/).
- Ultralytics states that its code, architectures, training pipelines, and trained models require the whole project to comply with AGPL-3.0 or an Enterprise License. The latter is paid and has not been requested or purchased. See [Ultralytics licensing terms](https://www.ultralytics.com/license).

These are the vendors' published terms, not legal advice. No model weights or derived artifacts are added until the project's intended distribution and license compatibility are clear.

## Decision needed before integration

Choose one path for Issue #13:

1. Accept the published AGPL obligations for the full AirControl project and review that choice before integrating an Ultralytics model.
2. Obtain and review an appropriate commercial license; no paid service or purchase is authorized by this work.
3. Select a different hand-landmark model whose weights, training data, and conversion/runtime terms permit the intended use, then validate CoreML export and landmark ordering.
4. Keep Apple Vision as the only supported detector.

## Integration criteria

If a compatible model is selected, add a testable provider boundary, keep Vision as the default and safe fallback, convert model landmarks to the canonical `HandJoint` names and normalized camera coordinates, and compare confidence, inference latency, dropped frames, and index-tip stability on fixed fixtures. Do not let the alternative provider bypass the existing explicit control and Accessibility gates. Fixture results must remain distinct from live-camera measurements.
