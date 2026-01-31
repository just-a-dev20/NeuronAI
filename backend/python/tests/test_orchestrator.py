"""Tests for the swarm orchestrator."""

import asyncio
import pytest

from neuronai.agents.orchestrator import (
    SwarmOrchestrator,
    AgentState,
    SwarmTask,
    AgentType,
)


@pytest.fixture
def orchestrator():
    """Create a swarm orchestrator instance."""
    return SwarmOrchestrator()


@pytest.fixture
def sample_task():
    """Create a sample swarm task."""
    return SwarmTask(
        task_id="task-123",
        session_id="session-456",
        description="Test task",
        required_agents=["researcher", "writer"],
    )


class TestSwarmOrchestrator:
    """Test cases for SwarmOrchestrator class."""

    def test_initialization(self, orchestrator):
        """Test that orchestrator initializes correctly."""
        assert orchestrator.agents == {}
        assert orchestrator.active_tasks == {}
        assert orchestrator.logger is not None

    @pytest.mark.asyncio
    async def test_process_message(self, orchestrator):
        """Test processing a single message."""
        result = await orchestrator.process_message(
            session_id="session-123",
            user_id="user-456",
            content="Hello, world!",
            message_type=1,
        )

        assert "content" in result
        assert result["content"] == "I received your message: Hello, world!..."
        assert result["message_type"] == 1
        assert result["agent_type"] == 1

    @pytest.mark.asyncio
    async def test_process_message_long_content(self, orchestrator):
        """Test processing a long message."""
        long_content = "This is a very long message that should be truncated. " * 10

        result = await orchestrator.process_message(
            session_id="session-123",
            user_id="user-456",
            content=long_content,
            message_type=1,
        )

        assert len(result["content"]) <= 200  # Should be truncated

    @pytest.mark.asyncio
    async def test_process_stream(self, orchestrator):
        """Test streaming response."""
        content = "Test streaming message with multiple words here"

        chunks = []
        async for chunk in orchestrator.process_stream(
            session_id="session-123",
            user_id="user-456",
            content=content,
            message_type=1,
        ):
            chunks.append(chunk)

        assert len(chunks) > 0
        assert chunks[-1]["is_final"] is True
        assert any(not chunk["is_final"] for chunk in chunks[:-1])

    @pytest.mark.asyncio
    async def test_process_stream_content_progressive(self, orchestrator):
        """Test that stream content builds progressively."""
        content = "one two three four five"

        async for chunk in orchestrator.process_stream(
            session_id="session-123",
            user_id="user-456",
            content=content,
            message_type=1,
        ):
            if not chunk["is_final"]:
                assert " " in chunk["content"] or len(chunk["content"]) > 0

    @pytest.mark.asyncio
    async def test_execute_swarm_task(self, orchestrator, sample_task):
        """Test executing a swarm task."""
        results = []
        async for result in orchestrator.execute_swarm_task(sample_task):
            results.append(result)

        assert len(results) > 0
        assert results[-1]["status"] == "completed"
        assert sample_task.status == "completed"
        assert sample_task.task_id in orchestrator.active_tasks

    @pytest.mark.asyncio
    async def test_execute_swarm_task_progress(self, orchestrator, sample_task):
        """Test that swarm task shows progress for each agent."""
        results = []
        async for result in orchestrator.execute_swarm_task(sample_task):
            results.append(result)

        working_results = [r for r in results if r.get("status") == "working"]
        assert len(working_results) == len(sample_task.required_agents)


class TestAgentState:
    """Test cases for AgentState class."""

    def test_agent_state_creation(self):
        """Test creating an agent state."""
        state = AgentState(
            agent_id="agent-123",
            agent_type=AgentType.RESEARCHER,
        )

        assert state.agent_id == "agent-123"
        assert state.agent_type == AgentType.RESEARCHER
        assert state.status == "idle"
        assert state.current_task == ""
        assert state.memory == {}

    def test_agent_state_with_all_fields(self):
        """Test creating an agent state with all fields."""
        state = AgentState(
            agent_id="agent-123",
            agent_type=AgentType.WRITER,
            status="working",
            current_task="Write a summary",
            memory={"key": "value"},
        )

        assert state.status == "working"
        assert state.current_task == "Write a summary"
        assert state.memory == {"key": "value"}


class TestSwarmTask:
    """Test cases for SwarmTask class."""

    def test_swarm_task_creation(self):
        """Test creating a swarm task."""
        task = SwarmTask(
            task_id="task-123",
            session_id="session-456",
            description="Test description",
            required_agents=["researcher"],
        )

        assert task.task_id == "task-123"
        assert task.session_id == "session-456"
        assert task.description == "Test description"
        assert task.required_agents == ["researcher"]
        assert task.status == "pending"
        assert task.context == {}

    def test_swarm_task_with_context(self):
        """Test creating a swarm task with context."""
        task = SwarmTask(
            task_id="task-123",
            session_id="session-456",
            description="Test description",
            required_agents=["researcher", "writer"],
            context={"additional_info": "important"},
        )

        assert task.context == {"additional_info": "important"}
        assert task.status == "pending"

    def test_swarm_task_status_update(self):
        """Test updating swarm task status."""
        task = SwarmTask(
            task_id="task-123",
            session_id="session-456",
            description="Test",
            required_agents=["researcher"],
        )

        assert task.status == "pending"
        task.status = "in_progress"
        assert task.status == "in_progress"
        task.status = "completed"
        assert task.status == "completed"


class TestAgentType:
    """Test cases for AgentType enum."""

    def test_agent_type_values(self):
        """Test that all agent types are defined."""
        assert AgentType.ORCHESTRATOR.value == "orchestrator"
        assert AgentType.RESEARCHER.value == "researcher"
        assert AgentType.WRITER.value == "writer"
        assert AgentType.CODE.value == "code"
        assert AgentType.IMAGE.value == "image"
        assert AgentType.VIDEO.value == "video"

    def test_agent_type_comparison(self):
        """Test agent type comparison."""
        assert AgentType.RESEARCHER == AgentType.RESEARCHER
        assert AgentType.RESEARCHER != AgentType.WRITER

    def test_agent_type_string_conversion(self):
        """Test converting agent type to string."""
        assert str(AgentType.ORCHESTRATOR) == "AgentType.ORCHESTRATOR"
