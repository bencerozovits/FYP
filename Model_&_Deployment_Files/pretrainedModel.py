from matplotlib import pyplot as plt
import torch
import torch.nn as nn
import torch.optim as optim
import torchvision.transforms as transforms
import torchvision.datasets as datasets
from torch.utils.data import DataLoader
from torchvision import models
from torchvision.models import EfficientNet_B5_Weights
from sklearn.metrics import precision_score, recall_score, f1_score, confusion_matrix
import seaborn as sns
import pandas as pd
import os

# Checks if CUDA (GPU) is available
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using device: {device}")

# Defines Data Transformations
data_transforms = {
    "train": transforms.Compose([
        transforms.Resize((456, 456)),  # EfficientNet-B5 input size
        transforms.RandomHorizontalFlip(),
        transforms.RandomRotation(10),
        transforms.ColorJitter(brightness=0.2),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ]),
    "val": transforms.Compose([
        transforms.Resize((456, 456)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ]),
    "test": transforms.Compose([
        transforms.Resize((456, 456)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ]),
}

# Loads Data (From vetements_data/train, val, test)
data_dir = "vetements_data"
datasets_dict = {
    "train": datasets.ImageFolder(os.path.join(data_dir, "train"), transform=data_transforms["train"]),
    "val": datasets.ImageFolder(os.path.join(data_dir, "val"), transform=data_transforms["val"]),
    "test": datasets.ImageFolder(os.path.join(data_dir, "test"), transform=data_transforms["test"]),
}

# Create DataLoaders
batch_size = 4  # Adjust based on your GPU memory
dataloaders = {
    "train": DataLoader(datasets_dict["train"], batch_size=batch_size, shuffle=True, num_workers=4),
    "val": DataLoader(datasets_dict["val"], batch_size=batch_size, shuffle=False, num_workers=4),
    "test": DataLoader(datasets_dict["test"], batch_size=batch_size, shuffle=False, num_workers=4),
}

# Define the Model
def get_model():
    model = models.efficientnet_b5(weights=EfficientNet_B5_Weights.IMAGENET1K_V1)
    
    # Freeze pretrained feature extractor layers
    for param in model.features.parameters():
        param.requires_grad = False
    
    # Extract number of input features of the last FC layer
    num_features = model.classifier[1].in_features
    
    # Replace classifier with a new Linear layer for 2 classes (Real vs Fake)
    model.classifier = nn.Sequential(
        nn.Dropout(p=0.4),  # Retain dropout for regularization
        nn.Linear(num_features, 2)  # 2 output classes
    )
    
    return model.to(device)

# Initialise Model, Loss Function, Optimizer
model = get_model()
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=0.0003)

# Training Function
def train_model(model, dataloaders, criterion, optimizer, num_epochs=10):
    best_val_loss = float("inf")

    for epoch in range(num_epochs):
        print(f"\nEpoch {epoch+1}/{num_epochs}")
        print("-" * 30)

        for phase in ["train", "val"]:
            if phase == "train":
                model.train()
            else:
                model.eval()

            running_loss = 0.0
            correct = 0
            total = 0

            for images, labels in dataloaders[phase]:
                images, labels = images.to(device), labels.to(device)
                optimizer.zero_grad()

                with torch.set_grad_enabled(phase == "train"):
                    outputs = model(images)
                    loss = criterion(outputs, labels)

                    if phase == "train":
                        loss.backward()
                        optimizer.step()

                running_loss += loss.item()
                _, predicted = torch.max(outputs, 1)
                total += labels.size(0)
                correct += (predicted == labels).sum().item()

            epoch_loss = running_loss / len(dataloaders[phase])
            accuracy = 100 * correct / total

            print(f"{phase.capitalize()} - Loss: {epoch_loss:.4f}, Accuracy: {accuracy:.2f}%")

            # Save the Best Model
            if phase == "val" and epoch_loss < best_val_loss:
                best_val_loss = epoch_loss
                torch.save(model.state_dict(), "best_model.pth")
                print("Model saved")

    print("\nTraining Complete!")

    # Test the Model
def test_model(model, dataloader, class_names):
    """Evaluates the model and saves predictions to a CSV file, including Precision, Recall, and F1-Score."""
    
    model.load_state_dict(torch.load("best_model.pth"))
    model.eval()

    correct = 0
    total = 0
    predictions = []
    y_true = []
    y_pred = []

    with torch.no_grad():
        for images, labels in dataloader:
            images, labels = images.to(device), labels.to(device)
            outputs = model(images)
            _, predicted = torch.max(outputs, 1)

            total += labels.size(0)
            correct += (predicted == labels).sum().item()

            y_true.extend(labels.cpu().numpy())
            y_pred.extend(predicted.cpu().numpy())

            # Save each prediction with filename, actual, and predicted class
            start_idx = len(y_pred) - len(images)
            for i in range(len(images)):
                image_name = dataloader.dataset.imgs[start_idx + i][0]
                actual_label = class_names[labels[i].item()]
                predicted_label = class_names[predicted[i].item()]
                predictions.append([image_name, actual_label, predicted_label])

    # Save to CSV for analysis
    df = pd.DataFrame(predictions, columns=["Image Path", "Actual Label", "Predicted Label"])
    df.to_csv("test_predictions.csv", index=False)

    # Print Overall Accuracy
    accuracy = 100 * correct / total

    # Print Evaluation Metrics
    precision = precision_score(y_true, y_pred, average='macro')
    recall = recall_score(y_true, y_pred, average='macro')
    f1 = f1_score(y_true, y_pred, average='macro')

    print(f"\nTest Accuracy: {accuracy:.2f}%")
    print(f"Precision: {precision:.4f}")
    print(f"Recall: {recall:.4f}")
    print(f"F1 Score: {f1:.4f}")
    print("Predictions saved to 'test_predictions.csv'.")

    # Print Some Correct and Incorrect Predictions
    print("\n🔍 Sample Predictions:")
    print(df.head(10))  # Show first 10 predictions
    
        # Confusion Matrix
    cm = confusion_matrix(y_true, y_pred)
    plt.figure(figsize=(6, 4))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', xticklabels=class_names, yticklabels=class_names)
    plt.title('Confusion Matrix')
    plt.xlabel('Predicted Label')
    plt.ylabel('Actual Label')
    plt.tight_layout()
    plt.savefig("confusion_matrix.png")
    plt.show()

# Entry Point
if __name__ == '__main__':
    torch.multiprocessing.set_start_method('spawn', force=True)
    
    # Train the model
    train_model(model, dataloaders, criterion, optimizer, num_epochs=10)
    
    # Evaluate the model on the test set
    class_names = ["Fake", "Real"]
    test_model(model, dataloaders["test"], class_names)

