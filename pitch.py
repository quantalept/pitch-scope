import librosa
import numpy as np
import json

# Load MP3
y, sr = librosa.load("assets/songs/Bhairavi_ragam.mp3", sr=22050)

# Extract pitch using YIN
f0 = librosa.yin(y, fmin=80, fmax=1000)

# ✅ Interpolate NaNs to avoid zeros
mask = np.isnan(f0)
f0[mask] = np.interp(
    np.flatnonzero(mask),
    np.flatnonzero(~mask),
    f0[~mask]
)

# 🔹 Take the first 200 points (beginning of Raga)
f0 = f0[:200]

# Optional: smooth to make it visually Raga-like
window_size = 5
f0_smooth = np.convolve(f0, np.ones(window_size)/window_size, mode='same')

# ✅ Prepare JSON with timestamps
hop_length = 256
timestamps = librosa.frames_to_time(np.arange(len(f0_smooth)), sr=sr, hop_length=hop_length)

data = {
    "timestamps": timestamps.tolist(),
    "pitch": f0_smooth.tolist()
}

# Save JSON to Flutter asset folder
with open("assets/pitch/bhairavi_pitch.json", "w") as f:
    json.dump(data, f)

print("✅ First 200 points of Bhairavi Raga saved with smooth pitch curve!")