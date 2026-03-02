# Donut to CoreML Conversion Guide

To run the Document Understanding Transformer (Donut) locally on iOS, you must convert the PyTorch model into an Apple CoreML `.mlpackage`. This allows the model to run efficiently on the iPhone's Neural Engine (ANE) without cloud API costs.

## Prerequisites
Run this on your Mac (requires Python 3.8+):
```bash
pip install torch transformers coremltools Pillow
```

## The Conversion Script (`convert_donut.py`)

Save the following Python code and run it. It downloads a base Donut model, traces its execution graph, and exports it for iOS.

```python
import torch
import coremltools as ct
from transformers import DonutProcessor, VisionEncoderDecoderModel
from PIL import Image

print("1. Loading HuggingFace Model...")
# Replace this with your fine-tuned IKEA model repository if you have one
model_id = "naver-clova-ix/donut-base"
processor = DonutProcessor.from_pretrained(model_id)
model = VisionEncoderDecoderModel.from_pretrained(model_id)
model.eval()

print("2. Preparing Dummy Input for Tracing...")
# Donut expects a specific tensor size (usually 2560x1920 or similar based on config)
# We create a dummy image tensor to let coremltools trace the computation graph
dummy_image = torch.rand(1, 3, 2560, 1920)

print("3. Tracing PyTorch Model...")
# We must trace the encoder part of the model for CoreML
traced_model = torch.jit.trace(model.encoder, dummy_image)

print("4. Converting to CoreML...")
# Convert the traced model to the modern .mlpackage format
coreml_model = ct.convert(
    traced_model,
    inputs=[ct.TensorType(name="image", shape=dummy_image.shape)],
    minimum_deployment_target=ct.target.iOS16,
    compute_precision=ct.precision.FLOAT16 # Optimize for mobile size
)

print("5. Saving Model...")
coreml_model.save("IKEADonut.mlpackage")
print("Conversion Complete! Drag IKEADonut.mlpackage into your Xcode project.")
```

## Xcode Integration
1. Drag the generated `IKEADonut.mlpackage` into your Xcode project navigator.
2. Xcode will automatically generate a Swift class named `IKEADonut`.
3. Open `LocalDocumentTransformer.swift` in your project and uncomment the model initialization code to connect the pipeline.
