import io
from pathlib import Path

import torch
import torch.nn as nn
import torchvision.models as tv_models
from torchvision import transforms
from PIL import Image


BASE_DIR = Path(__file__).resolve().parent
MODELS_DIR = BASE_DIR / "models"

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")


# =========================================================
# Transforms
# =========================================================

COLON_TRANSFORM = transforms.Compose([
    transforms.Resize(156),
    transforms.CenterCrop(128),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485, 0.456, 0.406],
        std=[0.229, 0.224, 0.225]
    )
])


# Important:
# Breast model was trained on 64x64 images.
# If you trained it using ImageNet normalization, replace mean/std with:
# mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]
BREAST_TRANSFORM = transforms.Compose([
    transforms.Resize((64, 64)),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485, 0.456, 0.406],
        std=[0.229, 0.224, 0.225]
    )
])


# =========================================================
# Helpers
# =========================================================

def get_state_dict(checkpoint):
    """
    Supports:
    1) checkpoint["model_state_dict"]
    2) checkpoint["model_state"]
    3) raw state_dict
    """

    if isinstance(checkpoint, dict):
        if "model_state_dict" in checkpoint:
            return checkpoint["model_state_dict"]

        if "model_state" in checkpoint:
            return checkpoint["model_state"]

    return checkpoint


def clean_state_dict_keys(state_dict):
    """
    Removes 'module.' prefix if model was saved from DataParallel.
    """

    cleaned = {}

    for key, value in state_dict.items():
        if key.startswith("module."):
            key = key.replace("module.", "", 1)

        cleaned[key] = value

    return cleaned


def detect_head_info(state_dict):
    """
    Detect if ResNet fc was:
    1) nn.Linear(...)
       keys: fc.weight, fc.bias

    2) nn.Sequential(nn.Dropout(), nn.Linear(...))
       keys: fc.1.weight, fc.1.bias
    """

    if "fc.1.weight" in state_dict:
        num_classes = state_dict["fc.1.weight"].shape[0]
        return {
            "num_classes": num_classes,
            "sequential_head": True
        }

    if "fc.weight" in state_dict:
        num_classes = state_dict["fc.weight"].shape[0]
        return {
            "num_classes": num_classes,
            "sequential_head": False
        }

    raise ValueError("Could not detect classifier head from checkpoint.")


# =========================================================
# Colon ResNet34 Model
# =========================================================

def build_resnet34(num_classes, sequential_head=True, dropout_p=0.3):
    model = tv_models.resnet34(weights=None)

    in_features = model.fc.in_features

    if sequential_head:
        model.fc = nn.Sequential(
            nn.Dropout(p=dropout_p),
            nn.Linear(in_features, num_classes)
        )
    else:
        model.fc = nn.Linear(in_features, num_classes)

    return model


class ImageClassifier:
    def __init__(self, model_name, model_path, class_names, dropout_p=0.3):
        self.model_name = model_name
        self.model_path = Path(model_path)
        self.class_names = class_names
        self.dropout_p = dropout_p
        self.model = None

    def is_ready(self):
        return self.model_path.exists()

    def load(self):
        if self.model is not None:
            return self.model

        if not self.model_path.exists():
            return None

        checkpoint = torch.load(self.model_path, map_location=DEVICE)
        state_dict = get_state_dict(checkpoint)
        state_dict = clean_state_dict_keys(state_dict)

        head_info = detect_head_info(state_dict)
        num_classes = head_info["num_classes"]
        sequential_head = head_info["sequential_head"]

        if num_classes != len(self.class_names):
            raise ValueError(
                f"Class count mismatch for {self.model_name}: "
                f"checkpoint has {num_classes}, but class_names has {len(self.class_names)}"
            )

        model = build_resnet34(
            num_classes=num_classes,
            sequential_head=sequential_head,
            dropout_p=self.dropout_p
        )

        model.load_state_dict(state_dict)
        model.to(DEVICE)
        model.eval()

        self.model = model
        return self.model

    def predict(self, image_bytes):
        model = self.load()

        if model is None:
            return {
                "success": False,
                "message": f"{self.model_name} model is not ready. Model file is missing."
            }

        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        input_tensor = COLON_TRANSFORM(image).unsqueeze(0).to(DEVICE)

        with torch.no_grad():
            outputs = model(input_tensor)
            probs = torch.softmax(outputs, dim=1)[0]

        top_k = min(3, len(self.class_names))
        top_probs, top_indices = torch.topk(probs, k=top_k)

        predicted_idx = top_indices[0].item()
        predicted_class = self.class_names[predicted_idx]
        confidence = top_probs[0].item()

        top_predictions = []

        for prob, idx in zip(top_probs, top_indices):
            top_predictions.append({
                "class": self.class_names[idx.item()],
                "confidence": round(prob.item(), 4)
            })

        return {
            "success": True,
            "predicted_class": predicted_class,
            "confidence": round(confidence, 4),
            "top_predictions": top_predictions,
            "message": "This AI result is for medical assistance only and is not a final diagnosis."
        }


# =========================================================
# Breast Custom Model
# =========================================================

class MyResnet(nn.Module):
    def __init__(self, num_classes=2,):
        super().__init__()

        self.conv_1 = nn.Sequential(
            nn.Conv2d(3, 64, kernel_size=3, padding=1),  # 64x64
            nn.BatchNorm2d(64),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(2),  # 32x32

            nn.Conv2d(64, 128, kernel_size=3, padding=1),  # 32x32
            nn.BatchNorm2d(128),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(2),  # 16x16
        )

        self.skip_conv_2 = nn.Sequential(
            nn.Conv2d(128, 128//2, kernel_size = 3, stride = 1, padding= 1),
            nn.BatchNorm2d(128//2),
            nn.ReLU(inplace=True),
            nn.Conv2d(128//2, 128, kernel_size = 3, stride = 1, padding= 1),
        )

        self.skip_conv_3 = nn.Sequential(
            nn.BatchNorm2d(128),
            nn.ReLU(inplace=True),

            nn.Conv2d(128, 128//2, kernel_size = 3, stride = 1, padding= 1),
            nn.BatchNorm2d(128//2),
            nn.ReLU(inplace=True),
            nn.Conv2d(128//2, 128, kernel_size = 3, stride = 1, padding= 1),
        )

        self.conv_4 = nn.Sequential(
            nn.BatchNorm2d(128),
            nn.ReLU(inplace=True),

            nn.Conv2d(128, 256, kernel_size = 3, stride = 1, padding= 1),
            nn.BatchNorm2d(256),
            nn.ReLU(inplace=True),
        )

        self.skip_conv_5 = nn.Sequential(
            nn.Conv2d(256, 256//2, kernel_size = 3, stride = 1, padding= 1),
            nn.BatchNorm2d(256//2),
            nn.ReLU(inplace=True),
            nn.Conv2d(256//2, 256, kernel_size = 3, stride = 1, padding= 1),

        )

        self.classifier = nn.Sequential(
            nn.AvgPool2d(2), # 8 x 8
            nn.Flatten(),
            nn.Linear(256 * 8 * 8, 512),
            nn.ReLU(inplace=True),
            nn.Dropout(0.5),
            nn.Linear(512, num_classes)
        )

    def forward(self, x):
        x = self.conv_1(x)

        x_skip_1 = x
        x  = self.skip_conv_2(x)
        x = x_skip_1 + x

        x_skip_2 = x
        x = self.skip_conv_3(x)
        x = x_skip_2 + x

        x = self.conv_4(x)
        # print(x.shape)

        x_skip_3 = x
        x = self.skip_conv_5(x)
        # print(x.shape)
        x = x_skip_3 + x

        x = self.classifier(x)

        return x


class BreastCancerClassifier:
    def __init__(self, model_name, model_path, class_names, threshold=0.3):
        self.model_name = model_name
        self.model_path = Path(model_path)
        self.class_names = class_names
        self.threshold = threshold
        self.model = None

    def is_ready(self):
        return self.model_path.exists()

    def load(self):
        if self.model is not None:
            return self.model

        if not self.model_path.exists():
            return None

        model = MyResnet(num_classes=2)

        # Breast model is saved as raw state_dict:
        # torch.save(model.state_dict(), path)
        state_dict = torch.load(self.model_path, map_location=DEVICE)
        state_dict = clean_state_dict_keys(state_dict)

        model.load_state_dict(state_dict)
        model.to(DEVICE)
        model.eval()

        self.model = model
        return self.model
    def predict(self, image_bytes):
        model = self.load()

        if model is None:
            return {
                "success": False,
                "message": "Breast cancer model is not ready. Model file is missing."
            }

        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        input_tensor = BREAST_TRANSFORM(image).unsqueeze(0).to(DEVICE)

        with torch.no_grad():
            outputs = model(input_tensor)

            # Case 1: one output logit
            if outputs.ndim == 1 or outputs.shape[1] == 1:
                positive_prob = torch.sigmoid(outputs.view(-1))[0].item()
                normal_prob = 1.0 - positive_prob

            # Case 2: two output logits with CrossEntropyLoss
            else:
                probs = torch.softmax(outputs, dim=1)[0]
                normal_prob = probs[0].item()
                positive_prob = probs[1].item()

        if positive_prob >= self.threshold:
            predicted_class = self.class_names[1]
            confidence = positive_prob
        else:
            predicted_class = self.class_names[0]
            confidence = normal_prob

        top_predictions = [
            {
                "class": self.class_names[0],
                "confidence": round(normal_prob, 4)
            },
            {
                "class": self.class_names[1],
                "confidence": round(positive_prob, 4)
            }
        ]

        top_predictions = sorted(
            top_predictions,
            key=lambda item: item["confidence"],
            reverse=True
        )

        return {
            "success": True,
            "predicted_class": predicted_class,
            "confidence": round(confidence, 4),
            "top_predictions": top_predictions,
            "message": "This AI result is for medical assistance only and is not a final diagnosis."
        }


# =========================================================
# Model Instances
# =========================================================

colon_class_names = [
    "ADI", "BACK", "DEB", "LYM", "MUC", "MUS", "NORM", "STR", "TUM"
]

breast_class_names = [
    "Normal",
    "IDC"
]


colon_model = ImageClassifier(
    model_name="colon_resnet34",
    model_path=BASE_DIR / "trained_models" / "Best_Colon_Cancer_Resnet34.pth",
    class_names=colon_class_names,
    dropout_p=0.3
)


breast_model = BreastCancerClassifier(
    model_name="breast_custom_resnet",
    model_path=BASE_DIR / "trained_models" / "best_breast_ Custom_Resnet.pth",
    class_names=breast_class_names,
    threshold=0.3
)


def get_models_status():
    return {
        "device": str(DEVICE),
        "models": {
            "colon_pathology": {
                "ready": colon_model.is_ready(),
                "endpoint": "/predict-pathology",
                "classes": colon_class_names
            },
            "breast_cancer": {
                "ready": breast_model.is_ready(),
                "endpoint": "/predict-breast",
                "classes": breast_class_names,
                "input_size": "64x64"
            }
        }
    }