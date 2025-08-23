import torch
import torch.nn as nn
from torchvision import models
import joblib
import cv2
import albumentations as A
from albumentations.pytorch import ToTensorV2
from collections import OrderedDict

# --- MODEL DEFINITION (from your notebook) ---
class SkinClassifier(nn.Module):
    def __init__(self, num_classes, dropout_rate=0.4):
        super().__init__()
        self.backbone = models.efficientnet_b0(weights=models.EfficientNet_B0_Weights.DEFAULT)
        in_features = self.backbone.classifier[1].in_features
        self.backbone.classifier = nn.Sequential(
            nn.Dropout(p=dropout_rate),
            nn.Linear(in_features, 512),
            nn.ReLU(),
            nn.BatchNorm1d(512),
            nn.Dropout(p=dropout_rate / 2),
            nn.Linear(512, num_classes)
        )
    def forward(self, x):
        return self.backbone(x)

# --- TRANSFORMS DEFINITION (from your notebook) ---
def get_inference_transforms():
    return A.Compose([
        A.Resize(224, 224),
        A.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
        ToTensorV2(),
    ])

# --- MODEL AND ENCODER LOADING (with logs) ---
def load_model_and_encoder(model_path, encoder_path):
    """Loads the model and label encoder with detailed logging."""
    print("\n" + "="*60)
    print("DERMACARE AI: Initializing Model Loading Process...")
    print("="*60)
    
    # Load encoder
    print(f"[LOG] Attempting to load label encoder from: {encoder_path}")
    with open(encoder_path, 'rb') as f:
        label_encoder = joblib.load(f)
    print("[SUCCESS] Label encoder loaded successfully.")
    
    # Get number of classes
    num_classes = len(label_encoder.classes_)
    print(f"[INFO] Detected {num_classes} classes from the encoder.")
    print(f"[INFO] Classes: {list(label_encoder.classes_)}")
    
    # Instantiate model
    print(f"[LOG] Initializing SkinClassifier model architecture for {num_classes} classes...")
    model = SkinClassifier(num_classes=num_classes)
    print("[SUCCESS] Model architecture created.")

    # Load model weights
    print(f"[LOG] Attempting to load model weights from: {model_path}")
    state_dict = torch.load(model_path, map_location=torch.device('cpu'))
    model.load_state_dict(state_dict)
    model.eval()
    print("[SUCCESS] Model weights loaded and model set to evaluation mode.")
    
    print("\n" + "="*60)
    print("DERMACARE AI: Model is ready for predictions.")
    print("="*60 + "\n")
    
    return model, label_encoder

# --- PREDICTION FUNCTION (with logs) ---
def predict_image(image_path, model, label_encoder):
    """Makes a prediction on a single image with detailed logging."""
    print("\n" + "-"*60)
    print("DERMACARE AI: Received new image for prediction.")
    print(f"[INFO] Image path: {image_path}")
    print("-"*60)
    
    # Get transforms
    transform = get_inference_transforms()
    
    # Load image
    print("[LOG] Loading image with OpenCV...")
    image = cv2.imread(image_path)
    if image is None:
        print(f"[ERROR] Failed to read image at path: {image_path}")
        raise FileNotFoundError(f"Image not found or could not be read at {image_path}")
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    print("[SUCCESS] Image loaded and color space converted to RGB.")

    # Apply transformations
    print("[LOG] Applying Albumentations transformations (Resize, Normalize, ToTensor)...")
    preprocessed_image = transform(image=image)['image']
    image_tensor = preprocessed_image.unsqueeze(0)
    print(f"[SUCCESS] Image transformed. Tensor shape: {image_tensor.shape}")

    # Make prediction
    print("[LOG] Performing model inference (torch.no_grad)...")
    with torch.no_grad():
        outputs = model(image_tensor)
        probabilities = torch.nn.functional.softmax(outputs, dim=1)
        confidence, predicted_idx = torch.max(probabilities, 1)
    print("[SUCCESS] Model inference complete.")

    # Decode the prediction
    predicted_label = label_encoder.inverse_transform([predicted_idx.item()])[0]
    final_confidence = confidence.item()
    
    print("\n--- Prediction Result ---")
    print(f"  -> Predicted Class: '{predicted_label}'")
    print(f"  -> Confidence Score: {final_confidence:.4f}")
    print("-------------------------\n")
    
    return {
        'predicted_class': predicted_label,
        'confidence': final_confidence
    }