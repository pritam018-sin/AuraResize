<p align="center">
  <h1 align="center">🖼️ AuraResize</h1>
  <p align="center">
    <strong>Blazing-Fast Lossless Batch Image Resizer, Compressor & Document Prep Studio.</strong><br>
    Target exact KB sizes • Custom dimensions • Background removal • 100% Free & Open-Source
  </p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="License" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Web%20%7C%20Desktop-brightgreen.svg?style=for-the-badge" alt="Platforms" />
</p>

---

## 🌟 Overview

**AuraResize** is an essential utility tool built to solve the frustration of strict file upload requirements on government portals, job applications, college submissions, and web forms. 

Whether you need a passport photo under 50 KB, a signature resized to exact pixel dimensions (e.g. 200x230), or batch image compression without quality degradation, AuraResize handles it in milliseconds.

---

## 🚀 Key Features

- **🎯 Target File Size Compression:** Specify an exact maximum size (e.g., *under 20 KB*, *50 KB*, *100 KB*) and let the compression algorithm optimize automatically.
- **📐 Pixel & Aspect Ratio Control:** Resize by exact width × height, percentage scale, or standard passport/signature presets.
- **✨ Background Removal:** Integrated clean background cutout pipeline for professional headshots and signatures.
- **⚡ Batch Processing:** Process multiple photos simultaneously with unified export settings.
- **🛡️ 100% Client-Side / Offline Privacy:** Image compression and resizing happen directly on your device.
- **🔄 Universal Format Support:** Supports JPEG, PNG, WebP with instant preview comparisons before export.

---

## 🏗️ Tech Stack

- **Framework:** [Flutter](https://flutter.dev) (Dart)
- **Image Engine:** Native Dart `image` package & platform channels
- **Architecture:** Clean, reactive, offline-first

---

## 🛠️ Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.0+)
- Android Studio / VS Code

### Installation & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/pritam018-sin/AuraResize.git
   cd AuraResize
   ```

2. **Setup environment:**
   ```bash
   cp .env.example .env
   # Add your optional REMBG API key in .env if using remote AI background removal
   ```

3. **Get dependencies & run:**
   ```bash
   flutter pub get
   flutter run
   ```

---

## 🤝 Contributing

Contributions, feedback, and feature requests are welcome! Feel free to open an issue or submit a pull request.

---

## 📄 License

This project is licensed under the **MIT License**.
