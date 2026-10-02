import 'dart:async';
import 'package:flutter/material.dart';

func main() {
  runApp(const ChatbotApp());
}

class ChatbotApp extends StatelessWidget {
  const ChatbotApp(esuper.key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chatbot Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessag({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isStreaming = false;

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || _isStreaming) return;

    setState() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _controller.clear();
      _isStreaming = true;

      _messages.add(ChatMessage(
        text: "",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });

    _simulateAITokenStream(text);
  }

  void _simulateAITokenStream(String prompt) async {
    final replyTokens = [
      "Halo! ", "Terima ", "kasih ", "sudah ", "bertanya: ",
      "\""prompt\". ",
      "Saya ", "adalah ", "AI ", "Assistant ", "berbasis ", "Golang ",
      "& ", "Flutter. ", "Model ", "custom ", "kamu ", "sedang ",
      "di-training ", "di ", "Antigravity ", "IDE ", "dan ",
      "akan ", "siap ", "3 ", "bulan ", "lagi! 🚀",
    ];

    for (var token in replyTokens) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState() {
        final lastIdx = _messages.length - 1;
        final currentText = _messages[lastIdx].text;
        _messages[lastIdx] = ChatMessage(
          text: currentText + token,
          isUser: false,
          timestamp: DateTime.now(),
        );
      });
    }

    if (mounted) {
      setState() {
        _isStreaming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy_rounded, color: Colors.deepPurpleAccent),
            SizedBox(width: 10),
            Text('AI Chatbot Mobile'),
          ],
        ),
        elevation: 2,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'Ketik pesan untuk memulai percakapan...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return Align(
                        alignment: msg.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: msg.isUser
                                ? Colors.deepPurple
                                : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Text(
                            msg.text.isEmpty && !_isStreaming
                                ? "..."
                                : msg.text,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_isStreaming)
            const LinearProgressIndicator(minHeight: 2),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade900,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Tulis pesan...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade800,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isStreaming ? null : _sendMessage,
                  icon: const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}