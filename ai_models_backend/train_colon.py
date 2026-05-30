"""
Train ResNet34 on NCT-CRC-HE-100K colon pathology dataset.
Dataset structure: datasets/colon/train/CLASS_imageid.jpg
Classes: ADI, BACK, DEB, LYM, MUC, MUS, NORM, STR, TUM
"""

import os
import torch
import torch.nn as nn
import torchvision.models as tv_models
from torchvision import transforms, datasets
from torch.utils.data import DataLoader, random_split
from pathlib import Path

# ── Config ──────────────────────────────────────────────────────────────────────
DATASET_DIR   = Path(__file__).parent / "datasets" / "colon" / "train"
OUTPUT_PATH   = Path(__file__).parent / "trained_models" / "Best_Colon_Cancer_Resnet34.pth"
CLASS_NAMES   = ["ADI", "BACK", "DEB", "LYM", "MUC", "MUS", "NORM", "STR", "TUM"]
NUM_CLASSES   = len(CLASS_NAMES)
BATCH_SIZE    = 32
EPOCHS        = 10
LR            = 1e-4
VAL_SPLIT     = 0.2
DROPOUT       = 0.3
DEVICE        = torch.device("cuda" if torch.cuda.is_available() else "cpu")

print(f"Device: {DEVICE}")
print(f"Dataset: {DATASET_DIR}")

# ── Dataset uses flat folder with CLASS_id.jpg naming ───────────────────────────
# We create a custom dataset that reads files named CLASS_*.jpg
from torch.utils.data import Dataset
from PIL import Image
import re

class FlatColonDataset(Dataset):
    def __init__(self, folder, class_names, transform=None):
        self.samples = []
        self.transform = transform
        self.class_to_idx = {c: i for i, c in enumerate(class_names)}
        folder = Path(folder)
        for f in folder.iterdir():
            if not f.suffix.lower() in ('.jpg', '.jpeg', '.png', '.tif', '.tiff'):
                continue
            cls = f.name.split('_')[0]
            if cls in self.class_to_idx:
                self.samples.append((f, self.class_to_idx[cls]))
        print(f"Found {len(self.samples)} images")

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        path, label = self.samples[idx]
        img = Image.open(path).convert('RGB')
        if self.transform:
            img = self.transform(img)
        return img, label

# ── Transforms ──────────────────────────────────────────────────────────────────
train_tf = transforms.Compose([
    transforms.Resize(156),
    transforms.RandomCrop(128),
    transforms.RandomHorizontalFlip(),
    transforms.RandomVerticalFlip(),
    transforms.ColorJitter(brightness=0.2, contrast=0.2),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

val_tf = transforms.Compose([
    transforms.Resize(156),
    transforms.CenterCrop(128),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

# ── Load dataset ────────────────────────────────────────────────────────────────
full_ds = FlatColonDataset(DATASET_DIR, CLASS_NAMES, transform=None)
n_val   = int(len(full_ds) * VAL_SPLIT)
n_train = len(full_ds) - n_val
train_ds, val_ds = random_split(full_ds, [n_train, n_val],
                                generator=torch.Generator().manual_seed(42))

# Apply transforms after split
class TransformDataset(Dataset):
    def __init__(self, subset, transform):
        self.subset = subset
        self.transform = transform
    def __len__(self):
        return len(self.subset)
    def __getitem__(self, idx):
        path, label = self.subset.dataset.samples[self.subset.indices[idx]]
        img = Image.open(path).convert('RGB')
        return self.transform(img), label

train_loader = DataLoader(TransformDataset(train_ds, train_tf),
                          batch_size=BATCH_SIZE, shuffle=True, num_workers=0)
val_loader   = DataLoader(TransformDataset(val_ds, val_tf),
                          batch_size=BATCH_SIZE, shuffle=False, num_workers=0)

print(f"Train: {n_train} | Val: {n_val}")

# ── Model ────────────────────────────────────────────────────────────────────────
model = tv_models.resnet34(weights=tv_models.ResNet34_Weights.DEFAULT)
model.fc = nn.Sequential(nn.Dropout(DROPOUT), nn.Linear(model.fc.in_features, NUM_CLASSES))
model = model.to(DEVICE)

optimizer = torch.optim.Adam(model.parameters(), lr=LR)
scheduler = torch.optim.lr_scheduler.StepLR(optimizer, step_size=3, gamma=0.5)
criterion = nn.CrossEntropyLoss()

# ── Train ────────────────────────────────────────────────────────────────────────
best_acc = 0.0
OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

for epoch in range(1, EPOCHS + 1):
    model.train()
    running_loss, correct, total = 0, 0, 0
    for imgs, labels in train_loader:
        imgs, labels = imgs.to(DEVICE), labels.to(DEVICE)
        optimizer.zero_grad()
        out = model(imgs)
        loss = criterion(out, labels)
        loss.backward()
        optimizer.step()
        running_loss += loss.item() * imgs.size(0)
        correct += (out.argmax(1) == labels).sum().item()
        total += imgs.size(0)

    train_acc = correct / total
    train_loss = running_loss / total

    model.eval()
    val_correct, val_total = 0, 0
    with torch.no_grad():
        for imgs, labels in val_loader:
            imgs, labels = imgs.to(DEVICE), labels.to(DEVICE)
            out = model(imgs)
            val_correct += (out.argmax(1) == labels).sum().item()
            val_total += imgs.size(0)
    val_acc = val_correct / val_total

    print(f"Epoch {epoch}/{EPOCHS} | Loss: {train_loss:.4f} | Train Acc: {train_acc:.4f} | Val Acc: {val_acc:.4f}")
    scheduler.step()

    if val_acc > best_acc:
        best_acc = val_acc
        torch.save({"model_state_dict": model.state_dict()}, OUTPUT_PATH)
        print(f"  [SAVED] Best model (val_acc={val_acc:.4f})")

print(f"\nDone! Best val acc: {best_acc:.4f}")
print(f"Model saved to: {OUTPUT_PATH}")
