"""Prompt templates for LLM interactions."""

from enum import Enum
from typing import Any


class PromptTemplate(Enum):
    """Available prompt templates."""

    SYSTEM_PROMPT = "system_prompt"
    CHAT_PROMPT = "chat_prompt"
    CODE_GENERATION = "code_generation"
    IMAGE_DESCRIPTION = "image_description"
    RESEARCH_SUMMARY = "research_summary"
    TASK_ORCHESTRATION = "task_orchestration"


class PromptTemplates:
    """Manager for LLM prompt templates."""

    _templates: dict[PromptTemplate, str] = {
        PromptTemplate.SYSTEM_PROMPT: (
            "You are NeuronAI, a helpful AI assistant designed to assist users "
            "with a wide range of tasks. You can help with:\n"
            "- Answering questions and providing information\n"
            "- Writing and editing text\n"
            "- Generating code snippets\n"
            "- Analyzing and summarizing content\n"
            "- Collaborating with other specialized agents\n\n"
            "Be clear, concise, and helpful in your responses."
        ),
        PromptTemplate.CHAT_PROMPT: (
            "User: {user_message}\n\nProvide a helpful response to the user's message."
        ),
        PromptTemplate.CODE_GENERATION: (
            "You are an expert programmer. Generate code based on the following request:\n\n"
            "Request: {user_message}\n\n"
            "Provide clear, well-commented code. Include explanations when necessary."
        ),
        PromptTemplate.IMAGE_DESCRIPTION: (
            "Describe the following image in detail:\n\n"
            "{image_context}\n\n"
            "Provide a comprehensive description covering main elements, colors, "
            "composition, and any notable features."
        ),
        PromptTemplate.RESEARCH_SUMMARY: (
            "You are a research assistant. Summarize the following information:\n\n"
            "{content}\n\n"
            "Provide a concise summary highlighting key points, main themes, "
            "and any important details."
        ),
        PromptTemplate.TASK_ORCHESTRATION: (
            "You are a task orchestrator managing multiple AI agents. "
            "Analyze the following task and determine the best approach:\n\n"
            "Task: {task_description}\n\n"
            "Required agents: {required_agents}\n\n"
            "Context: {context}\n\n"
            "Provide a step-by-step plan for completing this task, "
            "specifying which agent should handle each step."
        ),
    }

    @classmethod
    def get_template(cls, template_type: PromptTemplate) -> str:
        """Get a prompt template by type.

        Args:
            template_type: The type of template to retrieve

        Returns:
            The template string
        """
        return cls._templates.get(
            template_type,
            cls._templates[PromptTemplate.SYSTEM_PROMPT],
        )

    @classmethod
    def format_template(
        cls,
        template_type: PromptTemplate,
        **kwargs: Any,
    ) -> str:
        """Format a template with provided variables.

        Args:
            template_type: The type of template to format
            **kwargs: Variables to substitute in the template

        Returns:
            The formatted template string

        Raises:
            KeyError: If required variables are missing
        """
        template = cls.get_template(template_type)
        return template.format(**kwargs)

    @classmethod
    def build_system_prompt(
        cls,
        additional_context: str | None = None,
        capabilities: list[str] | None = None,
    ) -> str:
        """Build a system prompt with optional additions.

        Args:
            additional_context: Optional additional context to include
            capabilities: Optional list of capabilities to emphasize

        Returns:
            The formatted system prompt
        """
        base_prompt = cls.get_template(PromptTemplate.SYSTEM_PROMPT)

        if capabilities:
            capabilities_text = "\n".join(f"- {cap}" for cap in capabilities)
            base_prompt += f"\n\nSpecialized Capabilities:\n{capabilities_text}"

        if additional_context:
            base_prompt += f"\n\nAdditional Context:\n{additional_context}"

        return base_prompt

    @classmethod
    def build_chat_prompt(
        cls,
        user_message: str,
        conversation_history: list[dict[str, str]] | None = None,
    ) -> str:
        """Build a chat prompt with optional conversation history.

        Args:
            user_message: The current user message
            conversation_history: Optional list of previous messages

        Returns:
            The formatted chat prompt
        """
        if conversation_history:
            history_text = "\n".join(
                f"{msg['role']}: {msg['content']}" for msg in conversation_history
            )
            return f"{history_text}\n\nUser: {user_message}"
        else:
            return cls.format_template(PromptTemplate.CHAT_PROMPT, user_message=user_message)

    @classmethod
    def add_few_shot_examples(
        cls,
        template_type: PromptTemplate,
        examples: list[tuple[str, str]],
    ) -> str:
        """Add few-shot examples to a template.

        Args:
            template_type: The type of template to enhance
            examples: List of (input, output) tuples

        Returns:
            Template with few-shot examples appended
        """
        template = cls.get_template(template_type)

        examples_text = "\n\nExamples:\n"
        for i, (input_example, output_example) in enumerate(examples, 1):
            examples_text += f"\n{i}. Input: {input_example}"
            examples_text += f"\n   Output: {output_example}"

        return template + examples_text

    @classmethod
    def register_custom_template(
        cls,
        template_type: PromptTemplate,
        template: str,
    ) -> None:
        """Register a custom template.

        Args:
            template_type: The type of template to register
            template: The template string
        """
        cls._templates[template_type] = template
