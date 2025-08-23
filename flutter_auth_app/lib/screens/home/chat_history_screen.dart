import 'package:flutter/material.dart';
import 'package:flutter_auth_app/models/chat_message.dart';
import 'package:flutter_auth_app/services/chat_history_service.dart';
import 'package:flutter_auth_app/screens/home/disease_info_screen.dart';
import 'package:intl/intl.dart';

class ChatHistoryScreen extends StatefulWidget {
  final String token;
  const ChatHistoryScreen({super.key, required this.token});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final ChatHistoryService _chatHistoryService = ChatHistoryService();
  late Future<List<Map<String, dynamic>>> _conversations;
  bool _isDeleteMode = false;
  final Set<String> _selectedConversations = {};

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  void _loadConversations() {
    setState(() {
      _conversations = _chatHistoryService.getConversations(widget.token);
    });
  }

  void _toggleDeleteMode() {
    setState(() {
      _isDeleteMode = !_isDeleteMode;
      if (!_isDeleteMode) {
        _selectedConversations.clear();
      }
    });
  }

  void _deleteSelectedConversations() async {
    if (_selectedConversations.isEmpty) {
      _toggleDeleteMode();
      return;
    }

    try {
      await _chatHistoryService.deleteConversations(
          widget.token, _selectedConversations.toList());
      _selectedConversations.clear();
      _isDeleteMode = false;
      _loadConversations(); // Refresh the list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete chats: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isDeleteMode ? 'Select Chats' : 'Chat History'),
        leading: _isDeleteMode
            ? IconButton(
                icon: const Icon(Icons.cancel),
                onPressed: _toggleDeleteMode,
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(_isDeleteMode ? Icons.delete : Icons.delete_outline),
            onPressed: _isDeleteMode
                ? _deleteSelectedConversations
                : _toggleDeleteMode,
            tooltip: _isDeleteMode ? 'Delete Selected' : 'Delete History',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _conversations,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No chat history found.'));
          }

          final conversations = snapshot.data!;
          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final conversationId = conversation['id'] as String;
              final isSelected = _selectedConversations.contains(conversationId);
              final timestamp = DateTime.parse(conversation['timestamp']);
              final formattedDate =
                  DateFormat.yMMMd().add_jm().format(timestamp);

              return ListTile(
                leading: _isDeleteMode
                    ? Checkbox(
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedConversations.add(conversationId);
                            } else {
                              _selectedConversations.remove(conversationId);
                            }
                          });
                        },
                      )
                    : null,
                title: Text(conversation['title'] ?? 'Untitled Chat'),
                subtitle: Text(formattedDate),
                onTap: () async {
                  if (_isDeleteMode) {
                    setState(() {
                      if (isSelected) {
                        _selectedConversations.remove(conversationId);
                      } else {
                        _selectedConversations.add(conversationId);
                      }
                    });
                  } else {
                    try {
                      final conversationDetails = await _chatHistoryService
                          .getConversationDetails(
                              widget.token, conversation['id']);

                      final messages =
                          (conversationDetails['messages'] as List)
                              .map((m) => ChatMessage.fromJson(
                                  m as Map<String, dynamic>))
                              .toList();

                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DiseaseInfoScreen(
                              initialMessages: messages,
                              token: widget.token,
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Failed to load chat: ${e.toString()}')),
                        );
                      }
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
