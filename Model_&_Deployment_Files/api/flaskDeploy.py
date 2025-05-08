from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
import torch
import torch.nn as nn
from torchvision import models, transforms
from torchvision.models import EfficientNet_B5_Weights
from PIL import Image, UnidentifiedImageError
import os
from google.cloud import storage
import tempfile

app = Flask(__name__)

# ======== Config =========
BUCKET_NAME = "fyp-model-bucket"  # Replace with your actual bucket name
MODEL_FILENAME = "best_model.pth"
CLASS_NAMES = ["Fake", "Real"]
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}
ALLOWED_MIME_TYPES = {'image/jpeg', 'image/png'}

# ======== Device =========
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# ======== Helpers =========
def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# ======== Define get_model() FIRST to avoid yellow underline =========
def get_model():
    model = models.efficientnet_b5(weights=EfficientNet_B5_Weights.IMAGENET1K_V1)

    # Freeze pretrained layers
    for param in model.features.parameters():
        param.requires_grad = False

    # Replace classifier for 2-class problem
    num_features = model.classifier[1].in_features
    model.classifier = nn.Sequential(
        nn.Dropout(p=0.4),
        nn.Linear(num_features, 2)
    )

    return model.to(device)

# ======== Load Model (with transfer learning setup) =========
def load_model():
    model = get_model()
    model.load_state_dict(torch.load("best_model.pth", map_location=device))
    model.eval()
    return model

model = load_model()

# ======== Define Transform =========
transform = transforms.Compose([
    transforms.Resize((456, 456)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
])

# ======== Prediction Route =========
@app.route('/predict', methods=['POST'])
def predict():
    if 'image' not in request.files:
        return jsonify({"error": "No image uploaded"}), 400

    file = request.files['image']
    filename = secure_filename(file.filename)

    if not allowed_file(filename):
        return jsonify({"error": "Unsupported file type or MIME format. Only JPEG and PNG are allowed."}), 400

    try:
        image = Image.open(file).convert("RGB")
        image = transform(image).unsqueeze(0)

        with torch.no_grad():
            outputs = model(image)
            probabilities = torch.softmax(outputs[0], dim=0)
            confidence = {CLASS_NAMES[i]: round(probabilities[i].item(), 4) for i in range(2)}
            predicted_index = torch.argmax(probabilities).item()
            predicted_class = CLASS_NAMES[predicted_index]

        return jsonify({
            "prediction": predicted_class,
            "confidence": confidence
        })

    except UnidentifiedImageError:
        return jsonify({"error": "Uploaded file is not a valid image."}), 400

    except Exception as e:
        return jsonify({"error": f"Server error: {str(e)}"}), 500

# ======== Run Locally =========
if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
