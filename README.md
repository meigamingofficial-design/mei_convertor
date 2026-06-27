# 🌸 Mei Convertor

A beautiful, premium, and **100% offline-first** file conversion utility app built with Flutter.

Mei Convertor processes all files directly on the user's device. No files are uploaded to servers, no usage history is tracked, and no personal information is collected.

---

## ✨ Features

- **📁 PDF Tools**:
  - Merge multiple PDF files together.
  - Split specific page ranges into new documents.
  - Convert image collections and plain text to PDF.
- **🖼️ Image Tools**:
  - Convert formats between JPEG, PNG, WebP, and BMP.
  - Compress image size with custom quality parameters.
  - Resize dimensions to custom pixel resolutions.
- **📄 Document Converter**:
  - Convert plain text files (.txt, .md) to Word-compatible DOCX documents.
  - Extract text contents from DOCX files.
- **🌐 8 Locales**:
  - Native UI translation support for English, Japanese, Tamil, Spanish, Polish, Chinese, Korean, and Tagalog.

---

## 🛠️ Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable channel)
- Android Studio / VS Code with Dart & Flutter plugins
- Android SDK (API 34+ recommended)

### Build & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/meigamingofficial-design/mei_convertor.git
   cd mei_convertor
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app in debug mode:
   ```bash
   flutter run
   ```

---

## 💻 Useful Terminal Commands

Here is a list of useful terminal commands for development, testing, and preparing release builds:

### Development & Code Quality
- **Run static analysis**:
  ```bash
  flutter analyze
  ```
- **Run automated tests**:
  ```bash
  flutter test
  ```
- **Rebuild generated files (if modifying assets/icons)**:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```

### Release Build Setup

To release the app to the Google Play Store, you must generate a secure upload key.

1. **Generate a release keystore** (run this in your home directory or a secure location):
   ```bash
   keytool -genkey -v -keystore ~/mei-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mei
   ```

2. **Build the production package (AAB)**:
   ```bash
   flutter build appbundle --release
   ```

3. **Build the production APK** (for direct testing/distribution):
   ```bash
   flutter build apk --release
   ```

---

## 🔒 Privacy & License

- **Privacy Policy**: Hosted live at [meigamingofficial-design.github.io/mei_convertor/privacy-policy.html](https://meigamingofficial-design.github.io/mei_convertor/privacy-policy.html)
- **Terms of Conditions**: Hosted live at [meigamingofficial-design.github.io/mei_convertor/terms.html](https://meigamingofficial-design.github.io/mei_convertor/terms.html)
- **License**: Distributed under the MIT License. See `LICENSE` for details.
