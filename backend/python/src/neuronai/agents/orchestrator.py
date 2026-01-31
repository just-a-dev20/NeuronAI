"""Swarm orchestrator for managing multiple AI agents."""

import asyncio
from collections.abc import AsyncIterator
from dataclasses import dataclass, field
from enum import Enum
from typing import Any

import structlog

from neuronai.agents.llm_service import LLMService
from neuronai.agents.prompt_templates import PromptTemplates

logger = structlog.get_logger()


class AgentType(Enum):
    """Types of agents in the swarm."""

    ORCHESTRATOR = "orchestrator"
    RESEARCHER = "researcher"
    WRITER = "writer"
    CODE = "code"
    IMAGE = "image"
    VIDEO = "video"


@dataclass
class AgentState:
    """State of an individual agent."""

    agent_id: str
    agent_type: AgentType
    status: str = "idle"
    current_task: str = ""
    memory: dict[str, Any] = field(default_factory=dict)


@dataclass
class SwarmTask:
    """Task to be executed by the swarm."""

    task_id: str
    session_id: str
    description: str
    required_agents: list
    context: dict[str, Any] = field(default_factory=dict)
    status: str = "pending"


class SwarmOrchestrator:
    """Orchestrates multiple AI agents to complete complex tasks."""

    def __init__(self) -> None:
        self.agents: dict[str, AgentState] = {}
        self.active_tasks: dict[str, SwarmTask] = {}
        self.llm_service = LLMService()
        self.logger = logger.bind(component="SwarmOrchestrator")

    async def process_message(
        self,
        session_id: str,
        user_id: str,
        content: str,
        message_type: int = 1,  # TEXT
    ) -> dict[str, Any]:
        """Process a single message and return result."""
        self.logger.info(
            "Processing message",
            session_id=session_id,
            user_id=user_id,
            content_length=len(content),
        )

        # Use LLM service with prompt templates for response
        system_prompt = PromptTemplates.build_system_prompt()
        result = await self.llm_service.generate_response(
            prompt=PromptTemplates.build_chat_prompt(content),
            system_prompt=system_prompt,
        )

        return {
            "content": result.get("content", "I apologize, but I couldn't process your message."),
            "message_type": message_type,
            "agent_type": 1,  # ORCHESTRATOR
        }

    async def process_stream(
        self,
        session_id: str,
        user_id: str,
        content: str,
        message_type: int = 1,  # TEXT
    ) -> AsyncIterator[dict[str, Any]]:
        """Process a message and stream response."""
        self.logger.info(
            "Processing stream",
            session_id=session_id,
            user_id=user_id,
        )

        # Use LLM service for streaming response with prompt templates
        system_prompt = PromptTemplates.build_system_prompt()

        async for chunk in self.llm_service.generate_stream(
            prompt=PromptTemplates.build_chat_prompt(content),
            system_prompt=system_prompt,
        ):
            yield {
                "content": chunk.get("content", ""),
                "message_type": message_type,
                "agent_type": 1,  # ORCHESTRATOR
                "is_final": chunk.get("is_final", False),
            }

    async def execute_swarm_task(self, task: SwarmTask) -> AsyncIterator[dict[str, Any]]:
        """Execute a complex task using multiple agents."""
        self.logger.info(
            "Executing swarm task",
            task_id=task.task_id,
            session_id=task.session_id,
        )

        task.status = "in_progress"
        self.active_tasks[task.task_id] = task

        # Simulate multi-agent coordination
        for agent_type in task.required_agents:
            yield {
                "agent_type": agent_type,
                "status": "working",
                "message": f"Agent {agent_type} is processing...",
            }
            await asyncio.sleep(0.5)

        task.status = "completed"
        yield {
            "status": "completed",
            "result": "Task completed by swarm",
        }
