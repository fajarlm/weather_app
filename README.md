# AeroWeather 🌤️

AeroWeather adalah aplikasi pemantauan cuaca dan kualitas udara (AQI) berbasis Flutter yang modern, interaktif, dan dilengkapi dengan layanan latar belakang cerdas (Background Service). Aplikasi ini memadukan desain antarmuka glassmorphism yang responsif dengan pelacakan lokasi real-time.

---

## 🌟 Fitur Utama

- **Pemantauan Cuaca Real-Time**: Menampilkan informasi temperatur, kondisi cuaca, kelembapan, angin, dan tekanan udara berdasarkan GPS/koordinat pengguna secara otomatis.
- **Prakiraan Cuaca Terintegrasi**: Menyediakan informasi perkiraan cuaca per jam (hourly) maupun harian (daily).
- **Indeks Kualitas Udara (AQI)**: Melacak parameter kualitas udara di sekitar Anda beserta label status kesehatan udara (Sangat Baik, Baik, Sedang, Buruk, Sangat Buruk).
- **Pencarian Kota Pintar**: Autocomplete saran pencarian kota berdasarkan kecocokan nama kota di seluruh dunia.
- **Background Service & Notifikasi Cerdas**:
  - **Notifikasi Persisten**: Menampilkan ringkasan cuaca dan kualitas udara terkini secara langsung pada panel notifikasi handphone secara real-time.
  - **Laporan Terjadwal**: Mengirimkan pop-up pemberitahuan laporan cuaca otomatis pada pagi hari (06.00-08.00), siang hari (12.00-14.00), dan malam hari (18.00-20.00).
  - **Pelacak Jarak Latar Belakang**: Secara cerdas mengirimkan update cuaca baru apabila Anda bepergian/berpindah lokasi lebih dari 2 km.
- **UI Estetik & Premium**:
  - **Splash Screen Interaktif**: Intro dengan animasi transisi masuk (scale & fade).
  - **Visualisasi Adaptif**: Animasi widget cuaca (matahari bersinar, pergerakan awan, gerimis/hujan) serta perubahan warna latar belakang gradien yang dinamis menyesuaikan cuaca dan siang/malam.

---

## 🛠️ Teknologi & Paket yang Digunakan

Aplikasi ini dibangun menggunakan framework **Flutter** dan memanfaatkan library berikut:

| Library | Kegunaan |
| :--- | :--- |
| `flutter_background_service` | Mengaktifkan service pemantau lokasi/cuaca di latar belakang (Background Mode) |
| `flutter_local_notifications` | Menampilkan pemberitahuan/notifikasi sistem (pop-up & status bar) |
| `geolocator` | Melacak koordinat GPS perangkat |
| `shared_preferences` | Menyimpan status pengiriman notifikasi harian dan lokasi terakhir perangkat |
| `http` | Melakukan request data ke OpenWeatherMap API |

---

## ⚙️ Konfigurasi & Persiapan Android

Layanan latar belakang pada Android memerlukan beberapa perizinan khusus agar dapat berjalan secara optimal di Android 12 (API 31) ke atas:

### 1. Perizinan AndroidManifest.xml
Pastikan perizinan berikut diatur pada `android/app/src/main/AndroidManifest.xml`:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.google.com/tools">
    
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application ...>
        ...
        <!-- Konfigurasi Service untuk Background Service -->
        <service
            android:name="id.flutter.flutter_background_service.BackgroundService"
            android:foregroundServiceType="location"
            android:exported="true"
            tools:replace="android:exported" />
    </application>
</manifest>
```

### 2. Core Library Desugaring (`build.gradle.kts`)
Untuk mendukung fitur API Java 8 pada versi Android lama, desugaring diaktifkan pada `android/app/build.gradle.kts`:
```kotlin
android {
    ...
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

---

## 🚀 Cara Menjalankan Project

### Langkah 1: Kloning Repositori
```bash
git clone https://github.com/fajarlm/weather_app.git
cd weather_app
```

### Langkah 2: Ambil Dependencies
```bash
flutter pub get
```

### Langkah 3: Konfigurasi API Key (Opsional)
Aplikasi ini sudah dikonfigurasi dengan API Key bawaan di file `lib/service/weather_service.dart` dan `lib/service/notification_service.dart`. Jika ingin menggunakan API Key pribadi Anda, buat akun di [OpenWeatherMap](https://openweathermap.org/) dan ganti nilai berikut:
```dart
static const String _apiKey = 'API_KEY_ANDA_DI_SINI';
```

### Langkah 4: Jalankan Aplikasi
Jalankan di emulator atau perangkat fisik Anda:
```bash
flutter run
```
*(Catatan: Izinkan izin lokasi perangkat menjadi **"Izinkan sepanjang waktu" / "Allow all the time"** agar fitur tracking di latar belakang dapat berjalan dengan lancar).*

---

## 📄 Lisensi
Hak Cipta © 2026 AeroWeather. Dibuat untuk tujuan pengembangan aplikasi cuaca personal.
