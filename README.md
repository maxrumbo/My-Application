# Dokumentasi Proyek: AI Chatbot Mobile & Backend

Proyek ini menggunakan arsitektur modern berpisah antara Frontend Mobile dan Backend API.

---

## 1. Spesifikasi Stack Teknologi

- Frontend Mobile: Flutter (Dart) - Folder: `chatbot_mobile/`
- Backend API: Go Fiber (Golang) - Folder: `backend/`
- Database: MongoDB (Port 27017) & Redis (Port 6379) via Docker Compose

---

## 2. Cara Menjalankan Proyek

### Langkah 1: Jalankan Database (Docker)
Buka terminal di root proyek, lalu jalankan:
```bash
docker-compose up -d
```

### Langkah 2: Jalankan Server Backend (Go Fiber)
Buka tab terminal pertama, masuk ke folder backend dan jalankan server:
```bash
cd backend
go mod tidy
go run main.go
```
Server backend akan aktif di `http://localhost:8080`.

### Langkah 3: Jalankan Aplikasi Mobile (Flutter)
Buka tab terminal kedua, masuk ke folder Flutter dan jalankan aplikasi:
```bash
cd chatbot_mobile
$env:Path += ";C:\flutter\bin"
flutter run
```

---

## 3. Alur Komunikasi Sistem & API Endpoint

1. **Flutter Mobile Client (Clean Light Mode UI):**
   - **Sidebar Drawer:** Mengelola riwayat percakapan/sesi chat (`/api/sessions`).
   - **Settings Modal:** Mengatur URL Backend, *Temperature*, *Max Tokens*, dan *System Prompt*.
   - **Quick Prompt Chips:** Menyediakan rekomendasi pertanyaan di *Welcome Screen*.
   - **Streaming & Markdown:** Mendukung render Markdown, *code block syntax*, status indikator bertahap, serta tombol *Stop Streaming* & *Jawab Ulang (Regenerate)*.

2. **Go Fiber Backend Endpoints:**
   - `GET /api/health` — Status koneksi MongoDB & Redis.
   - `GET /api/sessions` — Mengambil daftar riwayat sesi percakapan dari MongoDB.
   - `GET /api/sessions/:id/messages` — Mengambil riwayat pesan dalam sesi tertentu.
   - `DELETE /api/sessions/:id` — Menghapus sesi percakapan dan seluruh pesannya.
   - `GET /api/chat/stream?prompt=...&session_id=...&temperature=...&max_tokens=...&system_prompt=...` — Request HTTP SSE Stream ke Backend Go Fiber.

3. **Database Storage (MongoDB & Redis):**
   - Go Fiber memproses request, menyimpan/meng-upsert dokumen sesi (`sessions`) dan pesan (`messages`) ke MongoDB (`chatbot_db`), serta melakukan caching di Redis. Token balasan dikirimkan secara streaming ke Flutter real-time.

---

## 4. Panduan Fungsi Tombol & Ikon di Android Studio

### Navigasi Panel Utama
1. Device Manager (Ikon Smartphone di pojok kanan atas)
   Digunakan untuk membuat, mengelola, dan menyalakan Emulator Android.

2. Play / Run (Ikon Segitiga Hijau di toolbar atas)
   Digunakan untuk menjalankan modul atau aplikasi utama yang dikonfigurasi di IDE.

3. Stop (Ikon Kotak Merah)
   Digunakan untuk menghentikan proses aplikasi atau server yang sedang berjalan.

4. Terminal Tab (Panel bawah IDE)
   Tempat mengeksekusi perintah CLI seperti `go run`, `flutter run`, dan `docker-compose`. Anda dapat menambah tab baru dengan menekan tombol plus (+).

5. Project View (Panel kiri IDE)
   Menampilkan struktur folder dan file proyek. Folder utama pengerjaan adalah `backend` dan `chatbot_mobile`.

### Ikon Action Toolbar
1. Make / Build Project (Ikon Palu dengan Tombol Play)
   Merakit dan memeriksa kompilasi kode proyek tanpa menjalankannya ke emulator.

2. Apply Code Changes (Ikon Panah Melengkung Huruf A)
   Mengirimkan perubahan kode langsung ke aplikasi yang berjalan tanpa merestart aplikasi.

3. Apply Changes and Restart Activity (Ikon Garis dengan Panah Putar)
   Mengirimkan perubahan kode sekaligus merestart layar (Activity) yang sedang dibuka di emulator.

4. Attach Debugger to Process (Ikon Serangga dengan Panah)
   Menghubungkan debugger ke proses aplikasi yang sedang berjalan untuk analisis error baris demi baris.

5. Sync Project with Gradle Files (Ikon Gajah dengan Panah Bawah)
   Menyinkronkan konfigurasi Gradle saat ada perubahan dependensi atau file build.
