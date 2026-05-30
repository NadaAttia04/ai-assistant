"""
Train custom ResNet on IDC Breast Histopathology dataset.
Dataset structure: datasets/breast/patient_id/0_or_1/image.png
Classes: 0=Normal, 1=IDC (cancer)
"""

import torch
import torch.nn as nn
from torchvision import transforms
from torch.utils.data import Dataset, DataLoader, random_split
from pathlib import Path
from PIL import Image
import sys

# Add parent dir to import MyResnet from models
sys.path.insert(0, str(Path(__file__).parent))
from models import MyResnet

# ── Config ──────────────────────────────────────────────────────────────────────
DATASET_DIR = Path(__file__).parent / "datasets" / "breast"
OUTPUT_PATH = Path(__file__).parent / "trained_models" / "best_breast_ Custom_Resnet.pth"
NUM_CLASSES = 2
BATCH_SIZE  = 64
EPOCHS      = 10
LR          = 1e-3
VAL_SPLIT   = 0.2
DEVICE      = torch.device("cuda" if torch.cuda.is_available() else "cpu")

print(f"Device: {DEVICE}")
print(f"Dataset: {DATASET_DIR}")

# ── Dataset ──────────────────────────────────────────────────────────────────────
class IDCDataset(Dataset):
    def __init__(self, root, transform=None):
        self.samples = []
        self.transform = transform
        root = Path(root)
        for cls_dir in root.rglob("*"):
            if cls_dir.is_dir() and cls_dir.name in ('0', '1'):
                label = int(cls_dir.name)
                for img_path in cls_dir.iterdir():
                    if img_path.suffix.lower() in ('.png', '.jpg', '.jpeg'):
                        self.samples.append((img_path, label))
        print(f"Found {len(self.samples)} images")
        n0 = sum(1 for _, l in self.samples if l == 0)
        n1 = sum(1 for _, l in self.samples if l == 1)
        print(f"  Normal: {n0} | IDC: {n1}")

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
    transforms.Resize((64, 64)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomVerticalFlip(),
    transforms.ColorJitter(brightness=0.2, contrast=0.2),
    transforms.ToTensor(),
    transforms.Normalize([0.5, 0.5, 0.5], [0.5, 0.5, 0.5])
])

val_tf = transforms.Compose([
    transforms.Resize((64, 64)),
    transforms.ToTensor(),
    transforms.Normalize([0.5, 0.5, 0.5], [0.5, 0.5, 0.5])
])

# ── Load dataset ────────────────────────────────────────────────────────────────
class TransformWrapper(Dataset):
    def __init__(self, subset, transform):
        self.subset = subset
        self.transform = transform
    def __len__(self):
        return len(self.subset)
    def __getitem__(self, idx):
        path, label = self.subset.dataset.samples[self.subset.indices[idx]]
        img = Image.open(path).convert('RGB')
        return self.transform(img), label

full_ds = IDCDataset(DATASET_DIR)
n_val   = int(len(full_ds) * VAL_SPLIT)
n_train = len(full_ds) - n_val
train_ds, val_ds = random_split(full_ds, [n_train, n_val],
                                generator=torch.Generator().manual_seed(42))

train_loader = DataLoader(TransformWrapper(train_ds, train_tf),
                          batch_size=BATCH_SIZE, shuffle=True, num_workers=0)
val_loader   = DataLoader(TransformWrapper(val_ds, val_tf),
                          batch_size=BATCH_SIZE, shuffle=False, num_workers=0)

print(f"Train: {n_train} | Val: {n_val}")

# ── Model ────────────────────────────────────────────────────────────────────────
model = MyResnet(num_classes=NUM_CLASSES).to(DEVICE)
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
        torch.save(model.state_dict(), OUTPUT_PATH)
        print(f"  [SAVED] Best model (val_acc={val_acc:.4f})")

print(f"\nDone! Best val acc: {best_acc:.4f}")
print(f"Model saved to: {OUTPUT_PATH}")
