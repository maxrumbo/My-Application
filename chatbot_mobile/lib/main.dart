import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ChatbotApp());
}

// Global Toast / Pop-up Notification (1 Style, 1 Location, 3 Seconds, Swipeable)
void showAppToast(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.horizontal,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor:
          isError ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
      content: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// Localizations / Dictionary Map (100% Functional ID / EN - Pure Single Language)
class AppStrings {
  final String lang;
  AppStrings(this.lang);

  bool get isEn => lang == 'en';

  String get appTitle => isEn ? 'Courier AI Assistant' : 'Asisten AI Kurir';
  String get newChat => isEn ? '+ New Chat' : '+ Chat Baru';
  String get searchHistory =>
      isEn ? 'Search history...' : 'Cari riwayat chat...';
  String get chatHistory => isEn ? 'Chat History' : 'Riwayat Percakapan';
  String get guestName => isEn ? 'Guest User' : 'Pengguna Tamu';
  String get guestMode => isEn ? 'Guest Mode' : 'Mode Tamu';
  String get guestSub =>
      isEn ? 'Temporary Session' : 'Sesi Sementara';
  String get guestNote => isEn
      ? 'Chat history is saved after sign in.'
      : 'Riwayat chat akan disimpan setelah Anda masuk.';
  String get noHistory =>
      isEn ? 'No chat history found' : 'Tidak ada riwayat ditemukan';
  String get login => isEn ? 'Sign In' : 'Masuk';
  String get logout => isEn ? 'Logout' : 'Keluar';
  String get shareChat => isEn ? 'Share conversation' : 'Bagikan percakapan';
  String get pinChat => isEn ? 'Pin conversation' : 'Sematkan';
  String get unpinChat => isEn ? 'Unpin conversation' : 'Lepas sematan';
  String get renameChat => isEn ? 'Rename' : 'Ganti nama';
  String get deleteChat => isEn ? 'Delete' : 'Hapus';
  String get pinLimitError => isEn
      ? '⚠️ Maximum 5 pinned chats allowed.'
      : '⚠️ Batas maksimal 5 sematan telah tercapai.';
  String get chatRenamed =>
      isEn ? 'Chat renamed' : 'Nama chat berhasil diubah';
  String get chatShared =>
      isEn ? 'Chat link copied' : 'Tautan percakapan berhasil disalin';
  String get typeMessage =>
      isEn ? 'Type a message...' : 'Tulis pesan Anda...';
  String get voiceInput => isEn ? 'Voice Input' : 'Input Suara';
  String get listening =>
      isEn ? 'Listening... Speak now' : 'Mendengarkan... Bicara sekarang';
  String get speakHint =>
      isEn ? 'Tap microphone to speak' : 'Ketuk mikrofon untuk bicara';
  String get send => isEn ? 'Send' : 'Kirim';
  String get cancel => isEn ? 'Cancel' : 'Batal';
  String get stop => isEn ? 'Stop' : 'Hentikan';
  String get welcomeTitle =>
      isEn ? 'How can I help you today?' : 'Ada yang bisa dibantu hari ini?';
  String get welcomeSub => isEn
      ? 'Select a quick topic or type your question:'
      : 'Pilih saran cepat atau tulis pertanyaan Anda:';
  String get modelFast => isEn ? '⚡ Fast Response' : '⚡ Respon Cepat';
  String get modelBalanced => isEn ? '⚖️ Standard' : '⚖️ Standar';
  String get modelAccurate => isEn ? '🎯 Detailed' : '🎯 Akurat & Detail';
  String get profileTitle => isEn ? 'User Profile' : 'Profil Pengguna';
  String get darkMode => isEn ? 'Dark Mode' : 'Mode Gelap';
  String get appLanguage => isEn ? 'Language' : 'Bahasa UI';
  String get loginWelcome => isEn ? 'Welcome Back' : 'Selamat Datang';
  String get loginSub => isEn
      ? 'Sign in to save chat history & unlock full access'
      : 'Masuk untuk menyimpan riwayat & akses penuh';
  String get continueAsGuest =>
      isEn ? 'Continue as Guest ➔' : 'Lanjutkan sebagai Tamu ➔';
  String get emailLabel => isEn ? 'Email Address' : 'Alamat Email';
  String get passwordLabel => isEn ? 'Password' : 'Kata Sandi';
  String get processing =>
      isEn ? 'Processing response...' : 'Memproses jawaban...';
  String get typing => isEn ? 'AI is typing...' : 'AI sedang mengetik...';
}

class ChatbotApp extends StatefulWidget {
  const ChatbotApp({super.key});

  @override
  State<ChatbotApp> createState() => _ChatbotAppState();
}

class _ChatbotAppState extends State<ChatbotApp> {
  bool _isDarkMode = false;

  void _toggleDarkMode(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asisten AI Kurir',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,
          primary: const Color(0xFF4F46E5),
          surface: Colors.white,
          background: const Color(0xFFF8FAFC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 0.5,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          primary: const Color(0xFF6366F1),
          surface: const Color(0xFF1E293B),
          background: const Color(0xFF0F172A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: MainNavigationWrapper(
        isDarkMode: _isDarkMode,
        onToggleDarkMode: _toggleDarkMode,
      ),
    );
  }
}

// User Profile Model
class UserProfile {
  String name;
  String email;
  bool isGuest;

  UserProfile({
    required this.name,
    required this.email,
    this.isGuest = false,
  });

  factory UserProfile.guest(String lang) {
    return UserProfile(
      name: lang == 'en' ? 'Guest User' : 'Pengguna Tamu',
      email: lang == 'en' ? 'Temporary Session' : 'Sesi Sementara',
      isGuest: true,
    );
  }
}

// Message Model
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String status;
  final String? modelUsed;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.status = 'done',
    this.modelUsed,
  });

  ChatMessage copyWith({
    String? text,
    String? status,
  }) {
    return ChatMessage(
      id: id,
      text: text ?? this.text,
      isUser: isUser,
      timestamp: timestamp,
      status: status ?? this.status,
      modelUsed: modelUsed,
    );
  }
}

// Session Model
class ChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  List<ChatMessage> messages;
  bool isPinned;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
    this.isPinned = false,
  });
}

// Navigation Wrapper
class MainNavigationWrapper extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;

  const MainNavigationWrapper({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  bool _showLoginScreen = false;
  String _language = 'id';
  late UserProfile _user;

  @override
  void initState() {
    super.initState();
    _user = UserProfile.guest(_language);
  }

  void _changeLanguage(String newLang) {
    setState(() {
      _language = newLang;
      if (_user.isGuest) {
        _user = UserProfile.guest(_language);
      }
    });
  }

  void _login(String email, String password) {
    setState(() {
      _showLoginScreen = false;
      _user = UserProfile(
        name: email.contains('@') ? email.split('@').first : email,
        email: email,
        isGuest: false,
      );
    });
  }

  void _continueAsGuest() {
    setState(() {
      _showLoginScreen = false;
      _user = UserProfile.guest(_language);
    });
  }

  void _openLogin() {
    setState(() {
      _showLoginScreen = true;
    });
  }

  void _logout() {
    setState(() {
      _user = UserProfile.guest(_language);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(_language);

    if (_showLoginScreen) {
      return LoginScreen(
        strings: s,
        onLogin: _login,
        onContinueAsGuest: _continueAsGuest,
      );
    }
    return ChatScreen(
      user: _user,
      strings: s,
      language: _language,
      isDarkMode: widget.isDarkMode,
      onToggleDarkMode: widget.onToggleDarkMode,
      onChangeLanguage: _changeLanguage,
      onLogout: _logout,
      onOpenLogin: _openLogin,
    );
  }
}

// ==================== LOGIN SCREEN ====================
class LoginScreen extends StatefulWidget {
  final AppStrings strings;
  final Function(String email, String password) onLogin;
  final VoidCallback onContinueAsGuest;

  const LoginScreen({
    super.key,
    required this.strings,
    required this.onLogin,
    required this.onContinueAsGuest,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  size: 40,
                  color: Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.strings.loginWelcome,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.strings.loginSub,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 28),

              // Form Box
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.strings.emailLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: 'nama@kurir.com',
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.strings.passwordLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        side: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final email = _emailController.text.trim();
                        final pwd = _passwordController.text.trim();
                        if (email.isNotEmpty && pwd.isNotEmpty) {
                          widget.onLogin(email, pwd);
                        } else {
                          widget.onLogin('kurir@myproject.ai', '123456');
                        }
                      },
                      icon: const Icon(Icons.login_rounded, size: 20),
                      label: Text(
                        widget.strings.login,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: widget.onContinueAsGuest,
                icon: const Icon(Icons.person_outline_rounded, size: 18),
                label: Text(widget.strings.continueAsGuest),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== PROFILE SCREEN ====================
class ProfileScreen extends StatefulWidget {
  final UserProfile user;
  final AppStrings strings;
  final VoidCallback onLogout;
  final VoidCallback? onOpenLogin;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.strings,
    required this.onLogout,
    this.onOpenLogin,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _routeAlerts = true;
  bool _soundAlerts = true;
  bool _emailDigest = false;

  void _showBlurredModalDialog(
    BuildContext context, {
    required String title,
    required Widget content,
    List<Widget>? actions,
    IconData? icon,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Modal',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            elevation: 12,
            backgroundColor: isDark
                ? const Color(0xFF1E293B).withOpacity(0.9)
                : Colors.white.withOpacity(0.92),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEF2FF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: const Color(0xFF4F46E5), size: 28),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Flexible(child: SingleChildScrollView(child: content)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions ?? [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(widget.strings.cancel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  void _showAccountInfo(BuildContext context) {
    _showBlurredModalDialog(
      context,
      title: widget.strings.isEn ? 'Account Information' : 'Informasi Akun',
      icon: Icons.person_outline_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInfoRow(widget.strings.isEn ? 'Full Name' : 'Nama Lengkap', widget.user.name),
          const Divider(height: 20),
          _buildInfoRow(widget.strings.isEn ? 'Email' : 'Alamat Email', widget.user.email),
          const Divider(height: 20),
          _buildInfoRow(widget.strings.isEn ? 'Role' : 'Peran/Jabatan',
              widget.strings.isEn ? 'Courier Staff' : 'Staf Kurir & Pengiriman'),
          const Divider(height: 20),
          _buildInfoRow(widget.strings.isEn ? 'Status' : 'Status Akun',
              widget.strings.isEn ? 'Active & Verified' : 'Aktif & Terverifikasi'),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    _showBlurredModalDialog(
      context,
      title: widget.strings.isEn ? 'Delivery Notifications' : 'Notifikasi Pengiriman',
      icon: Icons.notifications_none_rounded,
      content: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF4F46E5),
                title: Text(
                  widget.strings.isEn ? 'Route Alerts' : 'Peringatan Rute & Lalu Lintas',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  widget.strings.isEn ? 'Get real-time traffic updates' : 'Dapatkan pembaruan rute & macet real-time',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                value: _routeAlerts,
                onChanged: (val) {
                  setState(() => _routeAlerts = val);
                  setModalState(() {});
                },
              ),
              const Divider(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF4F46E5),
                title: Text(
                  widget.strings.isEn ? 'Sound Alerts' : 'Suara Peringatan',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  widget.strings.isEn ? 'Play sound on new task/message' : 'Bunyikan nada saat ada tugas/pesan baru',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                value: _soundAlerts,
                onChanged: (val) {
                  setState(() => _soundAlerts = val);
                  setModalState(() {});
                },
              ),
              const Divider(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF4F46E5),
                title: Text(
                  widget.strings.isEn ? 'Daily Email Summary' : 'Ringkasan Email Harian',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  widget.strings.isEn ? 'Receive daily delivery logs' : 'Kirim ringkasan laporan ke email',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                value: _emailDigest,
                onChanged: (val) {
                  setState(() => _emailDigest = val);
                  setModalState(() {});
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSecurity(BuildContext context) {
    _showBlurredModalDialog(
      context,
      title: widget.strings.isEn ? 'Security & Password' : 'Keamanan & Kata Sandi',
      icon: Icons.security_outlined,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF4F46E5), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.strings.isEn
                        ? 'Your account is protected with SSL/TLS encryption.'
                        : 'Akun Anda dilindungi dengan enkripsi aman SSL/TLS.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Theme.of(context).cardColor,
            leading: const Icon(Icons.lock_reset_rounded, color: Color(0xFF4F46E5)),
            title: Text(
              widget.strings.isEn ? 'Change Password' : 'Ubah Kata Sandi',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              widget.strings.isEn ? 'Send reset link to your email' : 'Kirim tautan atur ulang ke email',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              Navigator.pop(context);
              showAppToast(
                context,
                widget.strings.isEn ? 'Password reset link sent to email' : 'Tautan atur ulang sandi dikirim ke email',
              );
            },
          ),
        ],
      ),
    );
  }

  void _showHelpCenter(BuildContext context) {
    _showBlurredModalDialog(
      context,
      title: widget.strings.isEn ? 'Help Center & Support' : 'Pusat Bantuan & Support',
      icon: Icons.help_outline_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.strings.isEn ? 'Need assistance with Courier AI?' : 'Butuh bantuan penggunaan Asisten AI Kurir?',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.strings.isEn
                ? 'Contact our 24/7 support team or email us at support@courier.ai for immediate help.'
                : 'Hubungi tim dukungan 24/7 kami atau email ke support@courier.ai untuk bantuan langsung.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              showAppToast(context, widget.strings.isEn ? 'Support ticket created' : 'Tiket bantuan telah dibuat');
            },
            icon: const Icon(Icons.support_agent_rounded, size: 18),
            label: Text(widget.strings.isEn ? 'Contact Customer Support' : 'Hubungi Tim Support'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.strings.profileTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // User Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: widget.user.isGuest
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFFEEF2FF),
                    child: widget.user.isGuest
                        ? const Icon(Icons.person_outline_rounded,
                            size: 40, color: Colors.grey)
                        : Text(
                            widget.user.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.user.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.user.email,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  if (!widget.user.isGuest) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFC7D2FE),
                        ),
                      ),
                      child: Text(
                        widget.strings.isEn ? 'Verified Staff' : 'Staf Terverifikasi',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Mode Tamu vs Akun Terdaftar
            if (widget.user.isGuest) ...[
              // Tampilan Khusus Akun Guest
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.lock_person_outlined,
                        size: 44, color: Color(0xFF4F46E5)),
                    const SizedBox(height: 12),
                    Text(
                      widget.strings.isEn ? 'Guest Mode Active' : 'Mode Tamu Aktif',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.strings.isEn
                          ? 'You are browsing in Guest Mode. Sign in to access full profile settings, chat history, and account features.'
                          : 'Anda sedang menggunakan Mode Tamu. Silakan masuk ke akun Anda untuk mengakses fitur profil, riwayat chat, dan pengaturan akun.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          if (widget.onOpenLogin != null) {
                            widget.onOpenLogin!();
                          }
                        },
                        icon: const Icon(Icons.login_rounded, size: 20),
                        label: Text(
                          widget.strings.login,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Tampilan Akun Sudah Login
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline_rounded,
                          color: Color(0xFF4F46E5)),
                      title: Text(widget.strings.isEn
                          ? 'Account Information'
                          : 'Informasi Akun'),
                      trailing:
                          const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => _showAccountInfo(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.notifications_none_rounded,
                          color: Color(0xFF4F46E5)),
                      title: Text(widget.strings.isEn
                          ? 'Delivery Notifications'
                          : 'Notifikasi Pengiriman'),
                      trailing:
                          const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => _showNotifications(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.security_outlined,
                          color: Color(0xFF4F46E5)),
                      title: Text(widget.strings.isEn
                          ? 'Security & Password'
                          : 'Keamanan & Kata Sandi'),
                      trailing:
                          const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => _showSecurity(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.help_outline_rounded,
                          color: Color(0xFF4F46E5)),
                      title: Text(widget.strings.isEn
                          ? 'Help Center & Support'
                          : 'Pusat Bantuan & Support'),
                      trailing:
                          const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => _showHelpCenter(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onLogout();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: Text(
                    widget.strings.logout,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== CHAT SCREEN ====================
class ChatScreen extends StatefulWidget {
  final UserProfile user;
  final AppStrings strings;
  final String language;
  final bool isDarkMode;
  final ValueChanged<bool> onToggleDarkMode;
  final ValueChanged<String> onChangeLanguage;
  final VoidCallback onLogout;
  final VoidCallback? onOpenLogin;

  const ChatScreen({
    super.key,
    required this.user,
    required this.strings,
    required this.language,
    required this.isDarkMode,
    required this.onToggleDarkMode,
    required this.onChangeLanguage,
    required this.onLogout,
    this.onOpenLogin,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';
  String _backendUrl = 'http://localhost:8080';
  final List<ChatSession> _sessions = [];
  String _activeSessionId = '';

  String _selectedModelId = 'balanced';
  bool _isStreaming = false;
  StreamSubscription? _streamSubscription;
  http.Client? _activeHttpClient;

  List<Map<String, String>> get _availableModels => [
        {'id': 'fast', 'name': widget.strings.modelFast},
        {'id': 'balanced', 'name': widget.strings.modelBalanced},
        {'id': 'accurate', 'name': widget.strings.modelAccurate},
      ];

  @override
  void initState() {
    super.initState();
    _backendUrl = _getDefaultBackendUrl();
    _createNewSession();
    _loadSessionsFromBackend();
  }

  @override
  void dispose() {
    _textController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _streamSubscription?.cancel();
    _activeHttpClient?.close();
    super.dispose();
  }

  String _getDefaultBackendUrl() {
    if (kIsWeb) return 'http://localhost:8080';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  ChatSession get _activeSession {
    return _sessions.firstWhere(
      (s) => s.id == _activeSessionId,
      orElse: () => _sessions.first,
    );
  }

  void _createNewSession() {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newSession = ChatSession(
      id: newId,
      title: widget.strings.newChat.replaceAll('+ ', ''),
      createdAt: DateTime.now(),
      messages: [],
    );
    setState(() {
      _sessions.insert(0, newSession);
      _activeSessionId = newId;
    });
  }

  Future<void> _loadSessionsFromBackend() async {
    if (widget.user.isGuest) return;
    try {
      final res = await http
          .get(Uri.parse('$_backendUrl/api/sessions'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          setState(() {
            _sessions.clear();
            for (var item in data) {
              _sessions.add(ChatSession(
                id: item['id'] ?? '',
                title: item['title'] ?? 'Chat',
                createdAt: DateTime.tryParse(item['created_at'] ?? '') ??
                    DateTime.now(),
                messages: [],
              ));
            }
            if (_sessions.isNotEmpty) {
              _activeSessionId = _sessions.first.id;
              _loadMessagesForActiveSession();
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadMessagesForActiveSession() async {
    if (_activeSessionId.isEmpty || widget.user.isGuest) return;
    try {
      final res = await http.get(Uri.parse(
          '$_backendUrl/api/sessions/$_activeSessionId/messages'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _activeSession.messages = data.map((m) {
            return ChatMessage(
              id: m['id'] ?? '',
              text: m['text'] ?? '',
              isUser: m['sender'] == 'user',
              timestamp: DateTime.tryParse(m['created_at'] ?? '') ??
                  DateTime.now(),
              status: 'done',
            );
          }).toList();
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _deleteSession(String id) async {
    setState(() {
      _sessions.removeWhere((s) => s.id == id);
      if (_sessions.isEmpty) {
        _createNewSession();
      } else if (_activeSessionId == id) {
        _activeSessionId = _sessions.first.id;
        _loadMessagesForActiveSession();
      }
    });

    try {
      await http.delete(Uri.parse('$_backendUrl/api/sessions/$id'));
    } catch (_) {}
  }

  void _togglePinSession(ChatSession session) {
    if (!session.isPinned) {
      final pinnedCount = _sessions.where((s) => s.isPinned).length;
      if (pinnedCount >= 5) {
        showAppToast(context, widget.strings.pinLimitError, isError: true);
        return;
      }
    }

    setState(() {
      session.isPinned = !session.isPinned;
    });
  }

  void _showRenameDialog(ChatSession session) {
    final controller = TextEditingController(text: session.title);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(widget.strings.renameChat),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.strings.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
              ),
              onPressed: () {
                final newTitle = controller.text.trim();
                if (newTitle.isNotEmpty) {
                  setState(() {
                    session.title = newTitle;
                  });
                }
                Navigator.pop(context);
                showAppToast(context, widget.strings.chatRenamed);
              },
              child: Text(widget.strings.send),
            ),
          ],
        );
      },
    );
  }

  void _shareSession(ChatSession session) {
    Clipboard.setData(
        ClipboardData(text: 'https://asisten-kurir.ai/chat/${session.id}'));
    showAppToast(context, widget.strings.chatShared);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _stopStreaming() {
    _streamSubscription?.cancel();
    _activeHttpClient?.close();
    setState(() {
      _isStreaming = false;
      if (_activeSession.messages.isNotEmpty &&
          !_activeSession.messages.last.isUser) {
        final lastMsg = _activeSession.messages.last;
        _activeSession.messages[_activeSession.messages.length - 1] =
            lastMsg.copyWith(
          status: 'done',
          text: lastMsg.text.isEmpty ? '[Stop]' : lastMsg.text,
        );
      }
    });
  }

  void _sendMessage({String? customPrompt}) async {
    final text = customPrompt ?? _textController.text.trim();
    if (text.isEmpty || _isStreaming) return;

    if (customPrompt == null) {
      _textController.clear();
    }

    final selectedModelName = _availableModels
        .firstWhere((m) => m['id'] == _selectedModelId)['name']!;

    final userMsgId = DateTime.now().millisecondsSinceEpoch.toString();
    final aiMsgId = (DateTime.now().millisecondsSinceEpoch + 1).toString();

    setState(() {
      if (_activeSession.messages.isEmpty) {
        _activeSession.title =
            text.length > 25 ? '${text.substring(0, 25)}...' : text;
      }

      _activeSession.messages.add(ChatMessage(
        id: userMsgId,
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));

      _activeSession.messages.add(ChatMessage(
        id: aiMsgId,
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
        status: 'processing',
        modelUsed: selectedModelName,
      ));

      _isStreaming = true;
    });

    _scrollToBottom();

    try {
      final uri = Uri.parse(
        '$_backendUrl/api/chat/stream?'
        'prompt=${Uri.encodeComponent(text)}&'
        'session_id=${Uri.encodeComponent(_activeSession.id)}&'
        'model_id=$_selectedModelId',
      );

      _activeHttpClient = http.Client();
      final request = http.Request('GET', uri);
      final response = await _activeHttpClient!.send(request);

      _streamSubscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.startsWith('data: ')) {
            final token = line.substring(6);
            if (mounted) {
              setState(() {
                final lastIdx = _activeSession.messages.length - 1;
                if (lastIdx >= 0 && !_activeSession.messages[lastIdx].isUser) {
                  final currentMsg = _activeSession.messages[lastIdx];
                  _activeSession.messages[lastIdx] = currentMsg.copyWith(
                    text: currentMsg.text + token,
                    status: 'typing',
                  );
                }
              });
              _scrollToBottom();
            }
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              final lastIdx = _activeSession.messages.length - 1;
              if (lastIdx >= 0 && !_activeSession.messages[lastIdx].isUser) {
                _activeSession.messages[lastIdx] =
                    _activeSession.messages[lastIdx].copyWith(status: 'done');
              }
              _isStreaming = false;
            });
            _scrollToBottom();
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              final lastIdx = _activeSession.messages.length - 1;
              if (lastIdx >= 0 && !_activeSession.messages[lastIdx].isUser) {
                _activeSession.messages[lastIdx] =
                    _activeSession.messages[lastIdx].copyWith(
                  text: '⚠️ Koneksi gagal. Coba lagi.',
                  status: 'error',
                );
              }
              _isStreaming = false;
            });
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          final lastIdx = _activeSession.messages.length - 1;
          if (lastIdx >= 0 && !_activeSession.messages[lastIdx].isUser) {
            _activeSession.messages[lastIdx] =
                _activeSession.messages[lastIdx].copyWith(
              text: '⚠️ Koneksi gagal. Coba lagi.',
              status: 'error',
            );
          }
          _isStreaming = false;
        });
      }
    }
  }

  // Voice Input Sheet
  void _showVoiceInputDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.strings.voiceInput,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  size: 40,
                  color: Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(height: 12),
              Text(widget.strings.listening,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(widget.strings.cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _sendMessage(
                          customPrompt: widget.language == 'en'
                              ? 'Find the fastest delivery route'
                              : 'Bantu cari rute pengiriman tercepat',
                        );
                      },
                      child: Text(widget.strings.send),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.strings.appTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: widget.strings.newChat,
            onPressed: _createNewSession,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // Content Area (Padded to avoid overlap with floating elements)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(top: 48, bottom: 84),
              child: _activeSession.messages.isEmpty
                  ? _buildWelcomeScreen()
                  : _buildMessageList(),
            ),
          ),

          // Floating Model Selector Pill at Top
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: _buildFloatingModelSelector(),
          ),

          // Floating Invisible Glass Input Bar at Bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildInputBar(),
          ),
        ],
      ),
    );
  }

  // Floating Model Selector Pill at Top
  Widget _buildFloatingModelSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentModel = _availableModels.firstWhere(
      (m) => m['id'] == _selectedModelId,
      orElse: () => _availableModels.first,
    );

    return Center(
      child: PopupMenuButton<String>(
        onSelected: (modelId) {
          setState(() {
            _selectedModelId = modelId;
          });
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        itemBuilder: (context) {
          return _availableModels.map((m) {
            final isSelected = m['id'] == _selectedModelId;
            return PopupMenuItem<String>(
              value: m['id'],
              child: Text(
                m['name']!,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF4F46E5) : null,
                ),
              ),
            );
          }).toList();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withOpacity(0.88)
                : Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : const Color(0xFFC7D2FE).withOpacity(0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentModel['name']!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: Color(0xFF4F46E5)),
            ],
          ),
        ),
      ),
    );
  }

  // Sidebar Drawer
  Widget _buildDrawer() {
    final isDark = widget.isDarkMode;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // User Header
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      user: widget.user,
                      strings: widget.strings,
                      onLogout: widget.onLogout,
                      onOpenLogin: widget.onOpenLogin,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF8FAFC),
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFEEF2FF),
                      child: Text(
                        widget.user.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.user.email,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),

            // Button New Chat
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _createNewSession();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(widget.strings.newChat),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.strings.chatHistory,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),

            // History Content
            Expanded(
              child: widget.user.isGuest
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          widget.strings.guestNote,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim().toLowerCase();
                              });
                            },
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: widget.strings.searchHistory,
                              prefixIcon: const Icon(Icons.search_rounded,
                                  size: 16, color: Colors.grey),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final filtered = _sessions.where((s) {
                                if (_searchQuery.isEmpty) return true;
                                return s.title
                                    .toLowerCase()
                                    .contains(_searchQuery);
                              }).toList();

                              // Sort pinned chats first
                              filtered.sort((a, b) {
                                if (a.isPinned && !b.isPinned) return -1;
                                if (!a.isPinned && b.isPinned) return 1;
                                return b.createdAt.compareTo(a.createdAt);
                              });

                              if (filtered.isEmpty) {
                                return Center(
                                  child: Text(
                                    widget.strings.noHistory,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                );
                              }

                              return ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final session = filtered[index];
                                  final isSelected =
                                      session.id == _activeSessionId;

                                  return ListTile(
                                    dense: true,
                                    selected: isSelected,
                                    leading: Icon(
                                      session.isPinned
                                          ? Icons.push_pin_rounded
                                          : Icons.chat_bubble_outline_rounded,
                                      size: 18,
                                      color: session.isPinned
                                          ? const Color(0xFF4F46E5)
                                          : Colors.grey,
                                    ),
                                    title: Text(
                                      session.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected || session.isPinned
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert_rounded,
                                          size: 18, color: Colors.grey),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                      onSelected: (action) {
                                        if (action == 'share') {
                                          _shareSession(session);
                                        } else if (action == 'pin') {
                                          _togglePinSession(session);
                                        } else if (action == 'rename') {
                                          _showRenameDialog(session);
                                        } else if (action == 'delete') {
                                          _deleteSession(session.id);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'share',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.share_outlined,
                                                  size: 18,
                                                  color: Color(0xFF64748B)),
                                              const SizedBox(width: 10),
                                              Text(widget.strings.shareChat,
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'pin',
                                          child: Row(
                                            children: [
                                              Icon(
                                                session.isPinned
                                                    ? Icons.push_pin_rounded
                                                    : Icons.push_pin_outlined,
                                                size: 18,
                                                color: const Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                session.isPinned
                                                    ? widget.strings.unpinChat
                                                    : widget.strings.pinChat,
                                                style: const TextStyle(
                                                    fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'rename',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.edit_outlined,
                                                  size: 18,
                                                  color: Color(0xFF64748B)),
                                              const SizedBox(width: 10),
                                              Text(widget.strings.renameChat,
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuDivider(),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              const Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 18,
                                                  color: Colors.redAccent),
                                              const SizedBox(width: 10),
                                              Text(widget.strings.deleteChat,
                                                  style: const TextStyle(
                                                      color: Colors.redAccent,
                                                      fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _activeSessionId = session.id;
                                        _loadMessagesForActiveSession();
                                      });
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),

            // Bottom Section: Theme & Language & Login/Logout
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  // Dark Mode Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isDark
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                            size: 18,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.strings.darkMode,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      Switch(
                        value: widget.isDarkMode,
                        onChanged: widget.onToggleDarkMode,
                        activeColor: const Color(0xFF4F46E5),
                      ),
                    ],
                  ),

                  // Language Segmented Switcher
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.language_rounded,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            widget.strings.appLanguage,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'id',
                            label: Text('🇮🇩 ID',
                                style: TextStyle(fontSize: 11)),
                          ),
                          ButtonSegment(
                            value: 'en',
                            label: Text('🇬🇧 EN',
                                style: TextStyle(fontSize: 11)),
                          ),
                        ],
                        selected: {widget.language},
                        onSelectionChanged: (selection) {
                          widget.onChangeLanguage(selection.first);
                        },
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Login vs Logout Button
                  if (widget.user.isGuest)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.login_rounded,
                          color: Color(0xFF4F46E5)),
                      title: Text(
                        widget.strings.login,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        if (widget.onOpenLogin != null) {
                          widget.onOpenLogin!();
                        }
                      },
                    )
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.logout_rounded,
                          color: Colors.redAccent),
                      title: Text(
                        widget.strings.logout,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onLogout();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Welcome Screen
  Widget _buildWelcomeScreen() {
    final prompts = widget.language == 'en'
        ? [
            {'icon': '📍', 'text': 'Find the fastest delivery route'},
            {'icon': '📝', 'text': 'Draft a delivery confirmation message'},
            {'icon': '📦', 'text': 'How to reschedule a package delivery'},
            {'icon': '❓', 'text': 'Help answer customer questions'},
          ]
        : [
            {'icon': '📍', 'text': 'Bantu cari rute pengiriman tercepat'},
            {
              'icon': '📝',
              'text': 'Buat draf pesan konfirmasi ke penerima paket'
            },
            {'icon': '📦', 'text': 'Cara atur jadwal ulang pengiriman paket'},
            {'icon': '❓', 'text': 'Bantu jawab pertanyaan umum pelanggan'},
          ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                size: 40,
                color: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.strings.welcomeTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.strings.welcomeSub,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: prompts.map((p) {
                return InkWell(
                  onTap: () => _sendMessage(customPrompt: p['text']),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: MediaQuery.of(context).size.width > 600 ? 240 : 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['icon']!, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 6),
                        Text(
                          p['text']!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Message List
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      itemCount: _activeSession.messages.length,
      itemBuilder: (context, index) {
        final msg = _activeSession.messages[index];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: msg.isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: msg.isUser
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!msg.isUser) ...[
                    Container(
                      margin: const EdgeInsets.only(right: 8, top: 2),
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEF2FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.smart_toy_rounded,
                        color: Color(0xFF4F46E5),
                        size: 16,
                      ),
                    ),
                  ],
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: msg.isUser
                            ? const Color(0xFF4F46E5)
                            : (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF1E293B)
                                : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: msg.isUser
                            ? null
                            : Border.all(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                              ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (msg.isUser)
                            Text(
                              msg.text,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            )
                          else ...[
                            if (msg.status == 'processing')
                              Text(
                                widget.strings.processing,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            else
                              MarkdownBody(
                                data: msg.text,
                                selectable: true,
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Attachment Sheet
  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.language == 'en'
                    ? 'Attach File / Photo'
                    : 'Lampirkan Berkas / Foto',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachOption(
                    icon: Icons.camera_alt_outlined,
                    label: widget.language == 'en' ? 'Camera' : 'Kamera',
                    onTap: () {
                      Navigator.pop(context);
                      showAppToast(context, widget.language == 'en'
                          ? 'Photo attached'
                          : 'Foto berhasil dilampirkan');
                    },
                  ),
                  _buildAttachOption(
                    icon: Icons.image_outlined,
                    label: widget.language == 'en' ? 'Gallery' : 'Galeri',
                    onTap: () {
                      Navigator.pop(context);
                      showAppToast(context, widget.language == 'en'
                          ? 'Image selected'
                          : 'Gambar berhasil dipilih');
                    },
                  ),
                  _buildAttachOption(
                    icon: Icons.location_on_outlined,
                    label: widget.language == 'en' ? 'Location' : 'Lokasi Paket',
                    onTap: () {
                      Navigator.pop(context);
                      showAppToast(context, widget.language == 'en'
                          ? 'Location attached'
                          : 'Lokasi berhasil dilampirkan');
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF4F46E5), size: 24),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // Floating Invisible Glass Input Bar
  Widget _buildInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withOpacity(0.88)
            : Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.12)
              : const Color(0xFFE2E8F0).withOpacity(0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isStreaming) ...[
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Color(0xFFEEF2FF),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              IconButton(
                onPressed: _showAttachmentSheet,
                icon: const Icon(Icons.attach_file_rounded),
                color: const Color(0xFF4F46E5),
                tooltip: widget.language == 'en'
                    ? 'Attach File'
                    : 'Lampirkan Berkas',
              ),
              IconButton(
                onPressed: _showVoiceInputDialog,
                icon: const Icon(Icons.mic_none_rounded),
                color: const Color(0xFF4F46E5),
                tooltip: widget.strings.voiceInput,
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: widget.strings.typeMessage,
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (_isStreaming)
                IconButton.filled(
                  onPressed: _stopStreaming,
                  icon: const Icon(Icons.stop_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                  tooltip: widget.strings.stop,
                )
              else
                IconButton.filled(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                  ),
                  tooltip: widget.strings.send,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
