import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_model.freezed.dart';
part 'message_model.g.dart';

enum MessageType { text, image, video, code, toolCall, toolResult }

enum AgentType { orchestrator, researcher, writer, code, image, video }

enum TaskStatus { pending, inProgress, completed, failed, cancelled }

@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    required String sessionId,
    required String userId,
    required String content,
    @Default(MessageType.text) MessageType messageType,
    @Default(AgentType.orchestrator) AgentType agentType,
    @Default(TaskStatus.completed) TaskStatus status,
    DateTime? timestamp,
    @Default(false) bool isFinal,
    List<Attachment>? attachments,
    List<ToolCall>? toolCalls,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}

@freezed
class Attachment with _$Attachment {
  const factory Attachment({
    required String id,
    required String filename,
    required String mimeType,
    String? url,
    List<int>? data,
  }) = _Attachment;

  factory Attachment.fromJson(Map<String, dynamic> json) =>
      _$AttachmentFromJson(json);
}

@freezed
class ToolCall with _$ToolCall {
  const factory ToolCall({
    required String id,
    required String name,
    required String arguments,
    String? result,
  }) = _ToolCall;

  factory ToolCall.fromJson(Map<String, dynamic> json) =>
      _$ToolCallFromJson(json);
}

@freezed
class ChatSession with _$ChatSession {
  const factory ChatSession({
    required String id,
    required String userId,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    @Default([]) List<Message> messages,
  }) = _ChatSession;

  factory ChatSession.fromJson(Map<String, dynamic> json) =>
      _$ChatSessionFromJson(json);
}

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
