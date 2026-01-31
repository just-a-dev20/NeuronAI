import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isUser;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.messageType == MessageType.code)
              _buildCodeBlock(context)
            else if (message.messageType == MessageType.image)
              _buildImage(context)
            else
              _buildText(context),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isUser)
                  Icon(
                    _getAgentIcon(),
                    size: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                const SizedBox(width: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildText(BuildContext context) {
    return MarkdownBody(
      data: message.content,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          color: isUser
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildCodeBlock(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        message.content,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final imageUrl = message.content;
    
    if (imageUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 250,
          height: 200,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 250,
            height: 200,
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 250,
            height: 200,
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.error, color: Colors.red),
            ),
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                imageUrl,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
  }

  IconData _getAgentIcon() {
    switch (message.agentType) {
      case AgentType.code:
        return Icons.code;
      case AgentType.image:
        return Icons.image;
      case AgentType.video:
        return Icons.video_library;
      case AgentType.researcher:
        return Icons.search;
      case AgentType.writer:
        return Icons.edit;
      default:
        return Icons.smart_toy;
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
