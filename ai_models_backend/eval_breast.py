"""
Breast cancer model evaluation — sampled (fast).
Uses at most MAX_SAMPLES images to avoid scanning 555k files.
"""
import torch, random
from torch.utils.data import Dataset, DataLoader
from pathlib import Path
from PIL import Image
import sys

sys.path.insert(0, str(Path(__file__).parent))
from models import MyResnet, DEVICE, BREAST_TRANSFORM

DATASET_DIR = Path(__file__).parent / 'datasets/breast'
MODEL_PATH  = Path(__file__).parent / 'trained_models/best_breast_ Custom_Resnet.pth'
MAX_SAMPLES = 5000   # stratified sample (half normal, half IDC)
BATCH_SIZE  = 64
SEED        = 42

print('Scanning dataset (fast)...', flush=True)

normal_imgs, idc_imgs = [], []
random.seed(SEED)

for patient_dir in sorted(DATASET_DIR.iterdir()):
    if not patient_dir.is_dir(): continue
    for cls_name, store in [('0', normal_imgs), ('1', idc_imgs)]:
        cls_dir = patient_dir / cls_name
        if cls_dir.is_dir():
            store.extend(cls_dir.iterdir())

print(f'Normal: {len(normal_imgs)} | IDC: {len(idc_imgs)}', flush=True)

# balanced sample
half = MAX_SAMPLES // 2
sample_normal = random.sample(normal_imgs, min(half, len(normal_imgs)))
sample_idc    = random.sample(idc_imgs,    min(half, len(idc_imgs)))
samples = [(p, 0) for p in sample_normal] + [(p, 1) for p in sample_idc]
random.shuffle(samples)
print(f'Evaluating on {len(samples)} images (balanced sample)...', flush=True)

class SampleDataset(Dataset):
    def __init__(self, samples):
        self.samples = samples
    def __len__(self): return len(self.samples)
    def __getitem__(self, idx):
        path, label = self.samples[idx]
        return BREAST_TRANSFORM(Image.open(path).convert('RGB')), label

loader = DataLoader(SampleDataset(samples), batch_size=BATCH_SIZE, shuffle=False, num_workers=0)

model = MyResnet(num_classes=2)
model.load_state_dict(torch.load(MODEL_PATH, map_location=DEVICE))
model.to(DEVICE).eval()
print('Model loaded. Running inference...', flush=True)

correct = total = tp = fp = fn = tn = 0
with torch.no_grad():
    for imgs, labels in loader:
        imgs, labels = imgs.to(DEVICE), labels.to(DEVICE)
        probs = torch.softmax(model(imgs), dim=1)
        preds = (probs[:, 1] >= 0.3).long()
        correct += (preds == labels).sum().item()
        total   += labels.size(0)
        tp += ((preds==1)&(labels==1)).sum().item()
        fp += ((preds==1)&(labels==0)).sum().item()
        fn += ((preds==0)&(labels==1)).sum().item()
        tn += ((preds==0)&(labels==0)).sum().item()

acc  = correct/total
prec = tp/(tp+fp) if tp+fp else 0
rec  = tp/(tp+fn) if tp+fn else 0
f1   = 2*prec*rec/(prec+rec) if prec+rec else 0

print('='*50, flush=True)
print('BREAST CANCER MODEL EVALUATION', flush=True)
print('='*50, flush=True)
print(f'Device    : {DEVICE}', flush=True)
print(f'Sample    : {len(samples)} images (balanced)', flush=True)
print(f'Threshold : 0.3', flush=True)
print(f'Accuracy  : {acc*100:.2f}%  ({correct}/{total})', flush=True)
print(f'Precision : {prec*100:.2f}%', flush=True)
print(f'Recall    : {rec*100:.2f}%', flush=True)
print(f'F1 Score  : {f1*100:.2f}%', flush=True)
print(f'Confusion : TP={tp}  FP={fp}  FN={fn}  TN={tn}', flush=True)
