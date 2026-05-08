"""
Simple test model for Axon evaluation.

This model reads training labels, learns the distribution,
and predicts the most common label for each test image.
It's a naive baseline — but it proves the Docker evaluation pipeline works.
"""

import csv
import os
from collections import Counter

def main():
    print("=== Axon Test Model v1.0 ===")
    
    # 1. Read training labels
    train_csv = "/data/train/train_labels.csv"
    if not os.path.exists(train_csv):
        print(f"ERROR: {train_csv} not found!")
        return
    
    labels = []
    with open(train_csv, "r") as f:
        reader = csv.DictReader(f)
        for row in reader:
            labels.append(row["label"])
    
    print(f"Training set: {len(labels)} images")
    label_counts = Counter(labels)
    print(f"Label distribution: {dict(label_counts)}")
    
    # 2. "Train" — just find the most common label
    most_common_label = label_counts.most_common(1)[0][0]
    print(f"Most common label (our prediction): {most_common_label}")
    
    # 3. Read test images
    test_dir = "/data/test"
    test_images = [f for f in os.listdir(test_dir) if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
    print(f"Test set: {len(test_images)} images")
    
    # 4. Write predictions
    os.makedirs("/output", exist_ok=True)
    output_path = "/output/predictions.csv"
    
    with open(output_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["filename", "predicted_label"])
        for img in sorted(test_images):
            writer.writerow([img, most_common_label])
    
    print(f"Predictions written to {output_path} ({len(test_images)} predictions)")
    print("=== Evaluation complete ===")

if __name__ == "__main__":
    main()
