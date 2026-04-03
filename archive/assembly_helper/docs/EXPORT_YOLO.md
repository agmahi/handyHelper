# YOLOv8 CoreML Export Guide

To use YOLOv8 object detection on iOS, we need to export the standard Ultralytics PyTorch model into Apple's CoreML format (`.mlpackage`).

We will use the ultra-fast nano model (`yolov8n`), which is pre-trained on the COCO dataset (80 common object classes like 'bottle', 'cell phone', 'laptop', 'book', etc.). This is perfect for proving the real-time pipeline before you train a custom IKEA parts model.

## 1. Setup Python Environment
Run this in your terminal on your Mac:
```bash
pip install ultralytics coremltools
```

## 2. Export the Model
Create a python script named `export_yolo.py` and run it:

```python
from ultralytics import YOLO

# 1. Load the pre-trained YOLOv8 nano model
model = YOLO('yolov8n.pt')

# 2. Export to CoreML format (specifying nms=True bakes Non-Maximum Suppression into the CoreML model, which is essential for iOS Vision framework compatibility)
model.export(format='coreml', nms=True, imgsz=640)

print("Export complete! You should now have a folder named 'yolov8n.mlpackage'")
```

Run the script:
```bash
python export_yolo.py
```

## 3. Add to Xcode
1. Locate the generated `yolov8n.mlpackage` folder.
2. Drag and drop it into your Xcode project navigator (make sure "Copy items if needed" and your target `handyHelper` are checked).
3. Build and run the app. The `PartDetectionService` will automatically detect the model and switch from OCR mode to Real-time Object Detection mode!
