"""LLM service for handling AI model interactions."""

from collections.abc import AsyncIterator
from enum import Enum
from typing import Any

import structlog
from openai import AsyncOpenAI
from openai.types.chat import ChatCompletionMessageParam

from neuronai.config.settings import get_settings

logger = structlog.get_logger()


class LLMProvider(Enum):
    """Supported LLM providers."""

    OPENAI = "openai"
    CLAUDE = "claude"


class LLMService:
    """Service for interacting with LLM APIs."""

    def __init__(self) -> None:
        """Initialize the LLM service with settings."""
        self.settings = get_settings()
        self.logger = logger.bind(component="LLMService")

        self.client: AsyncOpenAI | None = None
        self.provider = LLMProvider.OPENAI

        self._initialize_client()

    def _initialize_client(self) -> None:
        """Initialize the LLM client based on provider."""
        if self.provider == LLMProvider.OPENAI and self.settings.openai_api_key:
            self.client = AsyncOpenAI(api_key=self.settings.openai_api_key)
            self.logger.info("Initialized OpenAI client")
        else:
            self.logger.warning("No valid LLM credentials found")

    async def generate_response(
        self,
        prompt: str,
        system_prompt: str | None = None,
        model: str | None = None,
        max_tokens: int | None = None,
        temperature: float | None = None,
    ) -> dict[str, Any]:
        """Generate a response from the LLM.

        Args:
            prompt: The user's prompt
            system_prompt: Optional system prompt for context
            model: Model to use (defaults to settings.default_model)
            max_tokens: Maximum tokens to generate
            temperature: Temperature for generation (0.0-2.0)

        Returns:
            Dictionary containing the response and metadata
        """
        if self.client is None:
            self.logger.error("LLM client not initialized")
            return {
                "content": "Error: LLM service not properly configured",
                "error": "client_not_initialized",
            }

        try:
            messages: list[ChatCompletionMessageParam] = []

            if system_prompt:
                messages.append({"role": "system", "content": system_prompt})

            messages.append({"role": "user", "content": prompt})

            self.logger.info(
                "Generating LLM response",
                model=model or self.settings.default_model,
                prompt_length=len(prompt),
            )

            response = await self.client.chat.completions.create(
                model=model or self.settings.default_model,
                messages=messages,
                max_tokens=max_tokens if max_tokens is not None else self.settings.max_tokens,
                temperature=temperature if temperature is not None else self.settings.temperature,
            )

            content = response.choices[0].message.content
            tokens_used = response.usage.total_tokens if response.usage else 0

            self.logger.info(
                "Generated LLM response",
                tokens_used=tokens_used,
                model=response.model,
            )

            return {
                "content": content,
                "model": response.model,
                "tokens_used": tokens_used,
                "finish_reason": response.choices[0].finish_reason,
            }

        except Exception as e:
            self.logger.error("Error generating LLM response", error=str(e))
            return {
                "content": f"Error: {str(e)}",
                "error": "generation_failed",
            }

    async def generate_stream(
        self,
        prompt: str,
        system_prompt: str | None = None,
        model: str | None = None,
        max_tokens: int | None = None,
        temperature: float | None = None,
    ) -> AsyncIterator[dict[str, Any]]:
        """Generate a streaming response from the LLM.

        Args:
            prompt: The user's prompt
            system_prompt: Optional system prompt for context
            model: Model to use (defaults to settings.default_model)
            max_tokens: Maximum tokens to generate
            temperature: Temperature for generation (0.0-2.0)

        Yields:
            Dictionaries containing chunks of the response
        """
        if self.client is None:
            self.logger.error("LLM client not initialized")
            yield {
                "content": "Error: LLM service not properly configured",
                "error": "client_not_initialized",
                "is_final": True,
            }
            return

        try:
            messages: list[ChatCompletionMessageParam] = []

            if system_prompt:
                messages.append({"role": "system", "content": system_prompt})

            messages.append({"role": "user", "content": prompt})

            self.logger.info(
                "Generating streaming LLM response",
                model=model or self.settings.default_model,
                prompt_length=len(prompt),
            )

            stream = await self.client.chat.completions.create(
                model=model or self.settings.default_model,
                messages=messages,
                max_tokens=max_tokens if max_tokens is not None else self.settings.max_tokens,
                temperature=temperature if temperature is not None else self.settings.temperature,
                stream=True,
            )

            full_content = ""

            async for chunk in stream:
                delta = chunk.choices[0].delta

                if delta.content:
                    full_content += delta.content
                    yield {
                        "content": full_content,
                        "delta": delta.content,
                        "is_final": False,
                    }

                if chunk.choices[0].finish_reason:
                    self.logger.info(
                        "Completed streaming LLM response",
                        finish_reason=chunk.choices[0].finish_reason,
                        content_length=len(full_content),
                    )
                    yield {
                        "content": full_content,
                        "is_final": True,
                        "finish_reason": chunk.choices[0].finish_reason,
                    }

        except Exception as e:
            self.logger.error("Error in LLM stream generation", error=str(e))
            yield {
                "content": f"Error: {str(e)}",
                "error": "stream_generation_failed",
                "is_final": True,
            }

    def get_model_info(self) -> dict[str, Any]:
        """Get information about available models."""
        return {
            "provider": self.provider.value,
            "default_model": self.settings.default_model,
            "max_tokens": self.settings.max_tokens,
            "temperature": self.settings.temperature,
            "client_initialized": self.client is not None,
        }
