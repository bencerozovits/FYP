# Imports
import praw
import requests
import os
import json
import csv
import random
from datetime import datetime
from shutil import move

# Reddit API Credentials
client_id = "WZq4Mwxr8ytFtEhHELRSfg"
client_secret = "HXtsjc-RE4nXOX3xR5djnp2KyZg2EQ"
user_agent = "VetementsScraper by /u/YT-PROFIFX"

# Initialize Reddit API
reddit = praw.Reddit(client_id=client_id,
                     client_secret=client_secret,
                     user_agent=user_agent)

# Subreddit Insertion
subreddit_name = "VETEMENTS"
subreddit = reddit.subreddit(subreddit_name)

# Temporary Limit variables
maxReal = 280  # Maximum Real posts/images
maxFake = 280  # Maximum Fake posts/images
maxUncertain = 280  # Maximum Uncertain posts/images
imageCount = 0
realCount = 0
fakeCount = 0
uncertainCount = 0

# Log data for JSON/CSV
log_data = []

# Keywords for classification
REAL_KEYWORDS = ["real", "authentic", "legit", "genuine", "verified"]
FAKE_KEYWORDS = ["fake", "replica", "counterfeit", "unauthentic", "not real"]

# Ensure dataset structure exists
for split in ["train", "val", "test"]:
    for category in ["Real", "Fake"]:
        os.makedirs(f"vetements_data/{split}/{category}", exist_ok=True)
os.makedirs("vetements_data/Test_Data", exist_ok=True)  # Keep Test_Data for uncertain posts

# Function to classify comments based on keywords
def classify_comments(comments):
    real_count = sum(any(keyword in comment.lower() for keyword in REAL_KEYWORDS) for comment in comments)
    fake_count = sum(any(keyword in comment.lower() for keyword in FAKE_KEYWORDS) for comment in comments)
    if real_count > fake_count:
        return "Real", real_count, fake_count
    elif fake_count > real_count:
        return "Fake", real_count, fake_count
    else:
        return None, real_count, fake_count  # Skip posts if classification is uncertain

# Function to download images
def download_images(url, postID, count):
    try:
        clean_url = url.split("?")[0]
        response = requests.get(url, timeout=10)
        if response.status_code != 200:
            print(f"[ERROR] Failed to download image: {url}")
            return None
        ext = clean_url.split(".")[-1] if "." in clean_url else "jpg"
        image_path = f"{postID}_img{count}.{ext}"
        with open(image_path, "wb") as img_file:
            for chunk in response.iter_content(1024):
                img_file.write(chunk)
        print(f"[DOWNLOADED] {image_path}")
        return image_path
    except requests.exceptions.RequestException as e:
        print(f"[ERROR] Exception while downloading {url}: {e}")
        return None

# Fetch posts
for submission in subreddit.new(limit=None):  # No hard limit; stop based on category limits
    if realCount >= maxReal and fakeCount >= maxFake and uncertainCount >= maxUncertain:
        print("[INFO] Reached maximum limits for all categories. Stopping.")
        break

    postID = submission.id
    post_timestamp = datetime.utcfromtimestamp(submission.created_utc).strftime('%Y-%m-%d %H:%M:%S')
    print(f"\n[PROCESSING] Post: {submission.title}")

    imagesDownloaded = []

    if hasattr(submission, "media_metadata"):  # Gallery posts
        for count, media in enumerate(submission.media_metadata.values(), start=1):
            if isinstance(media, dict) and "s" in media and "u" in media["s"]:  # Check if 's' and 'u' exist
                image_url = media["s"]["u"].replace("&amp;", "&")  # Get high-quality URL
                path = download_images(image_url, postID, count)
                if path:
                    imagesDownloaded.append((image_url, path))
                    imageCount += 1
                else:
                    print(f"[WARNING] Skipping media in post '{submission.title}' due to missing 's' key.")

    elif hasattr(submission, "url"):  # Single image posts
        if submission.url.endswith(("jpg", "jpeg", "png")):  # Check for image URLs
            path = download_images(submission.url, postID, 1)
            if path:
                imagesDownloaded.append((submission.url, path))
                imageCount += 1

    # Comment scraping and classification
    submission.comments.replace_more(limit=None)  # Load all comments
    comments = [comment.body for comment in submission.comments.list()]
    
    # **RESET REAL/FAKE COUNT FOR THIS POST ONLY**
    post_real_count, post_fake_count = 0, 0
    classification, post_real_count, post_fake_count = classify_comments(comments)

    print(f"[INFO] Real count: {post_real_count}, Fake count: {post_fake_count}")
    print(f"[INFO] Total comments analysed: {len(comments)}")

    # Skip post if max limit for classification is reached
    if classification == "Real" and realCount >= maxReal:
        for _, image_path in imagesDownloaded:
            os.remove(image_path)
        print(f"[INFO] Real max reached. Images for post '{submission.title}' removed.\n")
        continue

    if classification == "Fake" and fakeCount >= maxFake:
        for _, image_path in imagesDownloaded:
            os.remove(image_path)
        print(f"[INFO] Fake max reached. Images for post '{submission.title}' removed.\n")
        continue

    # Assign dataset split
    dataset_split = random.choices(["train", "val", "test"], weights=[0.8, 0.1, 0.1])[0]
    
    if classification is None:
        if uncertainCount < maxUncertain:
            print(f"[SKIPPED] Uncertain classification for post: {submission.title} \n")
            dataset_folder = "vetements_data/Test_Data"
            os.makedirs(dataset_folder, exist_ok=True)
            for image_url, path in imagesDownloaded:
                new_path = os.path.join(dataset_folder, os.path.basename(path))
                move(path, new_path)
                log_data.append({"Post ID": postID, "Image URL": image_url, "Classification": "Uncertain", "Timestamp": post_timestamp, "Dataset Split": dataset_split})
            uncertainCount += 1
        else:
            for _, image_path in imagesDownloaded:
                os.remove(image_path)
            print(f"[INFO] Uncertain max reached. Images for post '{submission.title}' removed.\n")
        continue

    dataset_folder = f"vetements_data/{dataset_split}/{classification}"
    os.makedirs(dataset_folder, exist_ok=True)

    # Move images to assigned dataset folder
    for i, (image_url, image_path) in enumerate(imagesDownloaded, start=1):
        new_path = os.path.join(dataset_folder, os.path.basename(image_path))
        move(image_path, new_path)
        log_data.append({"Post ID": postID, "Image URL": image_url, "Classification": classification, "Timestamp": post_timestamp, "Dataset Split": dataset_split})

    # Increase classification counts
    if classification == "Real":
        realCount += 1
    elif classification == "Fake":
        fakeCount += 1

    print(f"[CLASSIFIED] Post classified as {classification}\n")

# Save log as JSON and CSV
os.makedirs("vetements_data", exist_ok=True)
log_json_file = "vetements_data/log.json"
with open(log_json_file, "w") as f:
    json.dump(log_data, f, indent=4)

log_csv_file = "vetements_data/log.csv"
with open(log_csv_file, "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=["Post ID", "Image URL", "Classification", "Timestamp", "Dataset Split"])
    writer.writeheader()
    writer.writerows(log_data)

# Final script summary
print(f"\n[DONE] Real: {realCount}, Fake: {fakeCount}, Uncertain: {uncertainCount}. Total images downloaded: {imageCount}.")
print(f"[INFO] Logs saved to {log_json_file} and {log_csv_file}")
