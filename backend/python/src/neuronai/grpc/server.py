"""NeuronAI gRPC server implementation."""

import asyncio
import uuid
from collections.abc import AsyncIterator
from concurrent import futures

import grpc
import structlog
from grpc import aio

from neuronai.agents.orchestrator import SwarmOrchestrator
from neuronai.config.settings import get_settings
from neuronai.grpc import neuronai_pb2, neuronai_pb2_grpc

logger = structlog.get_logger()


class AIServiceServicer(neuronai_pb2_grpc.AIServiceServicer):
    """gRPC service implementation for AI processing."""

    def __init__(self) -> None:
        self.orchestrator = SwarmOrchestrator()
        self.logger = logger.bind(service="AIService")

    async def ProcessChat(
        self,
        request: neuronai_pb2.ChatRequest,
        context: grpc.ServicerContext,
    ) -> neuronai_pb2.ChatResponse:
        """Process a single chat message."""
        self.logger.info(
            "Processing chat request",
            session_id=request.session_id,
            user_id=request.user_id,
        )

        try:
            # Route to appropriate agent
            result = await self.orchestrator.process_message(
                session_id=request.session_id,
                user_id=request.user_id,
                content=request.content,
                message_type=request.message_type,
            )

            return neuronai_pb2.ChatResponse(
                message_id=str(uuid.uuid4()),
                session_id=request.session_id,
                content=result["content"],
                message_type=result.get("message_type", neuronai_pb2.MESSAGE_TYPE_TEXT),
                agent_type=result.get("agent_type", neuronai_pb2.AGENT_TYPE_ORCHESTRATOR),
                status=neuronai_pb2.TASK_STATUS_COMPLETED,
                timestamp=self._get_timestamp(),
                is_final=True,
            )
        except Exception as e:
            self.logger.error("Error processing chat", error=str(e))
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return neuronai_pb2.ChatResponse(
                message_id=str(uuid.uuid4()),
                session_id=request.session_id,
                content=f"Error: {str(e)}",
                status=neuronai_pb2.TASK_STATUS_FAILED,
                timestamp=self._get_timestamp(),
                is_final=True,
            )

    async def ProcessStream(
        self,
        request_iterator: AsyncIterator[neuronai_pb2.StreamRequest],
        context: grpc.ServicerContext,
    ) -> AsyncIterator[neuronai_pb2.StreamResponse]:
        """Process streaming chat messages."""
        async for request in request_iterator:
            self.logger.info(
                "Processing stream request",
                session_id=request.session_id,
                user_id=request.user_id,
            )

            try:
                if request.HasField("chat"):
                    chat_req = request.chat

                    # Stream responses from agent
                    async for chunk in self.orchestrator.process_stream(
                        session_id=chat_req.session_id,
                        user_id=chat_req.user_id,
                        content=chat_req.content,
                        message_type=chat_req.message_type,
                    ):
                        yield neuronai_pb2.StreamResponse(
                            session_id=request.session_id,
                            chat=neuronai_pb2.ChatResponse(
                                message_id=str(uuid.uuid4()),
                                session_id=request.session_id,
                                content=chunk["content"],
                                message_type=chunk.get(
                                    "message_type", neuronai_pb2.MESSAGE_TYPE_TEXT
                                ),
                                agent_type=chunk.get(
                                    "agent_type", neuronai_pb2.AGENT_TYPE_ORCHESTRATOR
                                ),
                                status=neuronai_pb2.TASK_STATUS_IN_PROGRESS,
                                timestamp=self._get_timestamp(),
                                is_final=chunk.get("is_final", False),
                            ),
                        )

            except Exception as e:
                self.logger.error("Error in stream processing", error=str(e))
                yield neuronai_pb2.StreamResponse(
                    session_id=request.session_id,
                    chat=neuronai_pb2.ChatResponse(
                        message_id=str(uuid.uuid4()),
                        session_id=request.session_id,
                        content=f"Error: {str(e)}",
                        status=neuronai_pb2.TASK_STATUS_FAILED,
                        timestamp=self._get_timestamp(),
                        is_final=True,
                    ),
                )

    def _get_timestamp(self):
        """Get current timestamp in protobuf format."""
        from google.protobuf.timestamp_pb2 import Timestamp

        timestamp = Timestamp()
        timestamp.GetCurrentTime()
        return timestamp


async def serve() -> None:
    """Start the gRPC server."""
    settings = get_settings()

    server = aio.server(futures.ThreadPoolExecutor(max_workers=10))
    neuronai_pb2_grpc.add_AIServiceServicer_to_server(AIServiceServicer(), server)

    listen_addr = f"[::]:{settings.service_port}"
    server.add_insecure_port(listen_addr)

    await server.start()
    logger.info("gRPC server started", address=listen_addr)

    try:
        await server.wait_for_termination()
    except asyncio.CancelledError:
        logger.info("Server shutdown requested")
    finally:
        await server.stop(5)
        logger.info("Server stopped")


if __name__ == "__main__":
    asyncio.run(serve())
