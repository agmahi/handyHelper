import os
try:
    from roboflow import Roboflow
except ImportError:
    print("Please install roboflow first: pip install roboflow")
    exit(1)

def download_ikea_dataset():
    print("--- IKEA Dataset Downloader ---")
    print("We are downloading a pre-labeled, open-source IKEA dataset from Roboflow Universe.")
    print("You will need a free API key from https://app.roboflow.com")
    
    api_key = input("
Enter your Roboflow API Key: ").strip()
    if not api_key:
        print("API key is required. Exiting.")
        return

    try:
        rf = Roboflow(api_key=api_key)
        
        # We are pulling from an open-source project called "ikea-furnitures"
        # It contains labeled images of panels, screws, tools, etc.
        project = rf.workspace("projet-ai").project("ikea-furnitures")
        
        # Download the dataset in YOLOv8 format
        print("
Downloading dataset... This may take a minute depending on your internet connection.")
        dataset = project.version(1).download("yolov8")
        
        print(f"
Success! Dataset downloaded to: {dataset.location}")
        print("You can now use this folder to train YOLOv8.")
        
    except Exception as e:
        print(f"
An error occurred: {e}")
        print("Ensure your API key is correct and you have internet access.")

if __name__ == "__main__":
    download_ikea_dataset()
