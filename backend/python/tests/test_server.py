"""Tests for gRPC server."""

import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

import grpc
import grpc.aio
import pytest
from google.protobuf.timestamp_pb2 import Timestamp

from neuronai.grpc.server import AIServiceServicer, serve


@pytest.fixture
def servicer():
    """Create an AI service servicer instance."""
    return AIServiceServicer()


@pytest.fixture
def mock_chat_request():
    """Create a mock chat request."""
    from neuronai.grpc import neuronai_pb2

    return neuronai_pb2.ChatRequest(
        session_id="session-123",
        user_id="user-456",
        content="Hello, world!",
        message_type=1,
        metadata={"key": "value"},
    )


@pytest.fixture
def mock_stream_request(mock_chat_request):
    """Create a mock stream request."""
    from neuronai.grpc import neuronai_pb2

    return neuronai_pb2.StreamRequest(
        session_id="session-123",
        user_id="user-456",
        chat=mock_chat_request,
    )


class TestAIServiceServicer:
    """Test cases for AIServiceServicer class."""

    def test_initialization(self, servicer):
        """Test that servicer initializes correctly."""
        assert servicer.orchestrator is not None
        assert servicer.logger is not None

    @pytest.mark.asyncio
    async def test_process_chat_basic(self, servicer, mock_chat_request):
        """Test basic chat processing."""
        context = MagicMock(spec=grpc.aio.ServicerContext)

        response = await servicer.ProcessChat(mock_chat_request, context)

        assert response is not None
        assert response.session_id == "session-123"
        assert "I received your message" in response.content
        assert response.message_id is not None
        assert response.status is not None
        assert response.is_final is True

    @pytest.mark.asyncio
    async def test_process_chat_with_long_content(self, servicer):
        """Test processing chat with long content."""
        from neuronai.grpc import neuronai_pb2

        long_content = "This is a very long message that will be processed. " * 100
        request = neuronai_pb2.ChatRequest(
            session_id="session-123",
            user_id="user-456",
            content=long_content,
            message_type=1,
        )
        context = MagicMock(spec=grpc.aio.ServicerContext)

        response = await servicer.ProcessChat(request, context)

        assert response is not None
        assert response.content is not None

    @pytest.mark.asyncio
    async def test_process_chat_error_handling(self, servicer, mock_chat_request):
        """Test error handling in chat processing."""
        context = MagicMock(spec=grpc.aio.ServicerContext)

        with patch.object(
            servicer.orchestrator, "process_message", side_effect=Exception("Test error")
        ):
            response = await servicer.ProcessChat(mock_chat_request, context)

            assert response is not None
            assert "Error" in response.content
            assert response.is_final is True

        context.set_code.assert_called()
        context.set_details.assert_called()

    @pytest.mark.asyncio
    async def test_process_stream_basic(self, servicer, mock_stream_request):
        """Test basic stream processing."""
        context = MagicMock(spec=grpc.aio.ServicerContext)

        responses = []
        async for response in servicer.ProcessStream(iter([mock_stream_request]), context):
            responses.append(response)

        assert len(responses) > 0
        assert all(r.session_id == "session-123" for r in responses)

    @pytest.mark.asyncio
    async def test_process_stream_with_multiple_requests(self, servicer):
        """Test processing multiple stream requests."""
        from neuronai.grpc import neuronai_pb2

        context = MagicMock(spec=grpc.aio.ServicerContext)

        requests = []
        for i in range(3):
            chat_req = neuronai_pb2.ChatRequest(
                session_id=f"session-{i}",
                user_id="user-456",
                content=f"Message {i}",
                message_type=1,
            )
            stream_req = neuronai_pb2.StreamRequest(
                session_id=f"session-{i}",
                user_id="user-456",
                chat=chat_req,
            )
            requests.append(stream_req)

        responses = []
        async for response in servicer.ProcessStream(iter(requests), context):
            responses.append(response)

        assert len(responses) > 0

    @pytest.mark.asyncio
    async def test_process_stream_error_handling(self, servicer, mock_stream_request):
        """Test error handling in stream processing."""
        context = MagicMock(spec=grpc.aio.ServicerContext)

        with patch.object(
            servicer.orchestrator, "process_stream", side_effect=Exception("Test error")
        ):
            responses = []
            async for response in servicer.ProcessStream(iter([mock_stream_request]), context):
                responses.append(response)

            assert len(responses) > 0
            assert "Error" in responses[-1].chat.content

    def test_get_timestamp(self, servicer):
        """Test timestamp generation."""
        timestamp = servicer._get_timestamp()

        assert isinstance(timestamp, Timestamp)
        assert timestamp.seconds > 0 or timestamp.nanos > 0


class TestServe:
    """Test cases for the serve function."""

    @pytest.mark.asyncio
    async def test_serve_initialization(self):
        """Test that serve can be initialized."""
        with patch("neuronai.grpc.server.get_settings") as mock_settings:
            mock_settings.return_value = MagicMock(service_port=50051)

            server_mock = MagicMock(spec=grpc.aio.Server)
            server_mock.start = AsyncMock()
            server_mock.wait_for_termination = AsyncMock(side_effect=asyncio.CancelledError())
            server_mock.stop = AsyncMock()

            with (
                patch("grpc.aio.server", return_value=server_mock),
                patch("neuronai.grpc.server.neuronai_pb2_grpc.add_AIServiceServicer_to_server"),
                pytest.raises(asyncio.CancelledError),
            ):
                await serve()

    @pytest.mark.asyncio
    async def test_serve_graceful_shutdown(self):
        """Test graceful shutdown of server."""
        with patch("neuronai.grpc.server.get_settings") as mock_settings:
            mock_settings.return_value = MagicMock(service_port=50051)

            server_mock = MagicMock(spec=grpc.aio.Server)
            server_mock.start = AsyncMock()
            server_mock.wait_for_termination = AsyncMock(side_effect=asyncio.CancelledError())
            server_mock.stop = AsyncMock()

            with (
                patch("grpc.aio.server", return_value=server_mock),
                patch("neuronai.grpc.server.neuronai_pb2_grpc.add_AIServiceServicer_to_server"),
            ):
                with pytest.raises(asyncio.CancelledError):
                    await serve()

                server_mock.stop.assert_called_once_with(5)


class TestIntegration:
    """Integration tests for the gRPC service."""

    @pytest.mark.asyncio
    async def test_full_chat_flow(self, servicer, mock_chat_request):
        """Test complete chat flow from request to response."""
        context = MagicMock(spec=grpc.aio.ServicerContext)

        response = await servicer.ProcessChat(mock_chat_request, context)

        assert response.message_id is not None
        assert response.session_id == mock_chat_request.session_id
        assert response.content is not None
        assert response.is_final is True

    @pytest.mark.asyncio
    async def test_full_stream_flow(self, servicer, mock_stream_request):
        """Test complete stream flow from request to responses."""
        context = MagicMock(spec=grpc.aio.ServicerContext)

        responses = []
        async for response in servicer.ProcessStream(iter([mock_stream_request]), context):
            responses.append(response)

        assert len(responses) > 0
        final_response = responses[-1]
        assert final_response.chat.is_final is True
