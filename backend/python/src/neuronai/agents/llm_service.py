"""LLM service for handling AI model interactions."""

import asyncio
import json
from collections.abc import AsyncIterator
from enum import Enum
from typing import Any

import requests
import structlog

from neuronai.config.settings import get_settings

logger = structlog.get_logger()


class LLMProvider(Enum):
    OPENAI = "openai"
    OPENROUTER = "openrouter"
    OLLAMA = "ollama"


class LLMService:
    def __init__(self) -> None:
        self.settings = get_settings()
        self.logger = logger.bind(component="LLMService")
        self.provider = LLMProvider(self.settings.llm_provider.lower())

        if self.provider == LLMProvider.OPENAI:
            self.api_key = self.settings.openai_api_key
            self.base_url = "https://api.openai.com/v1"
            if self.api_key:
                self.logger.info("Initialized OpenAI client")
            else:
                self.logger.warning("No valid OpenAI credentials found")
        elif self.provider == LLMProvider.OPENROUTER:
            self.api_key = self.settings.openrouter_api_key
            self.base_url = "https://openrouter.ai/api/v1"
            if self.api_key:
                self.logger.info("Initialized OpenRouter client")
            else:
                self.logger.warning("No valid OpenRouter credentials found")
        elif self.provider == LLMProvider.OLLAMA:
            self.api_key = None
            self.base_url = self.settings.ollama_base_url
            self.logger.info("Initialized Ollama client")
        else:
            self.api_key = None
            self.base_url = ""
            self.logger.error(f"Unknown LLM provider: {self.provider}")

    def _build_messages(self, prompt: str, system_prompt: str | None) -> list[dict[str, str]]:
        messages = [{"role": "system", "content": system_prompt}] if system_prompt else []
        messages.append({"role": "user", "content": prompt})
        return messages

    def _build_payload(
        self,
        messages: list[dict[str, str]],
        model: str | None,
        max_tokens: int | None,
        temperature: float | None,
        stream: bool = False,
    ) -> dict[str, Any]:
        return {
            "model": model or self.settings.default_model,
            "messages": messages,
            "max_tokens": max_tokens or self.settings.max_tokens,
            "temperature": temperature or self.settings.temperature,
            "stream": stream,
        }

    def _get_headers(self) -> dict[str, str]:
        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        return headers

    def _error_response(self, message: str, error_code: str) -> dict[str, Any]:
        return {"content": f"Error: {message}", "error": error_code}

    async def generate_response(
        self,
        prompt: str,
        system_prompt: str | None = None,
        model: str | None = None,
        max_tokens: int | None = None,
        temperature: float | None = None,
    ) -> dict[str, Any]:
        if self.provider != LLMProvider.OLLAMA and not self.api_key:
            self.logger.error("LLM client not initialized")
            return self._error_response(
                "LLM service not properly configured", "client_not_initialized"
            )

        try:
            messages = self._build_messages(prompt, system_prompt)
            model_name = model or self.settings.default_model

            if self.provider == LLMProvider.OLLAMA:
                return await self._generate_ollama_response(
                    messages, model_name, max_tokens, temperature
                )
            else:
                return await self._generate_openai_compatible_response(
                    messages, model_name, max_tokens, temperature
                )

        except Exception as e:
            self.logger.error("Error generating LLM response", error=str(e))
            return self._error_response(str(e), "generation_failed")

    async def _generate_openai_compatible_response(
        self,
        messages: list[dict[str, str]],
        model: str,
        max_tokens: int | None,
        temperature: float | None,
    ) -> dict[str, Any]:
        payload = self._build_payload(messages, model, max_tokens, temperature)

        self.logger.info("Generating LLM response", model=model, provider=self.provider.value)

        response = await asyncio.to_thread(
            requests.post,
            f"{self.base_url}/chat/completions",
            headers=self._get_headers(),
            json=payload,
            timeout=60,
        )
        response.raise_for_status()
        data = response.json()

        content = data["choices"][0]["message"]["content"]
        tokens_used = data.get("usage", {}).get("total_tokens", 0)
        model_used = data.get("model", model)

        self.logger.info("Generated LLM response", tokens_used=tokens_used, model=model_used)

        return {
            "content": content,
            "model": model_used,
            "tokens_used": tokens_used,
            "finish_reason": data["choices"][0].get("finish_reason"),
        }

    async def _generate_ollama_response(
        self,
        messages: list[dict[str, str]],
        model: str,
        max_tokens: int | None,
        temperature: float | None,
    ) -> dict[str, Any]:
        payload = {
            "model": model,
            "messages": messages,
            "stream": False,
            "options": {
                "temperature": temperature or self.settings.temperature,
            },
        }
        if max_tokens:
            payload["options"]["num_predict"] = max_tokens

        self.logger.info("Generating Ollama response", model=model)

        response = await asyncio.to_thread(
            requests.post,
            f"{self.base_url}/api/chat",
            headers=self._get_headers(),
            json=payload,
            timeout=60,
        )
        response.raise_for_status()
        data = response.json()

        content = data["message"]["content"]

        self.logger.info("Generated Ollama response", model=model)

        return {
            "content": content,
            "model": model,
            "tokens_used": 0,
            "finish_reason": "stop",
        }

    async def generate_stream(
        self,
        prompt: str,
        system_prompt: str | None = None,
        model: str | None = None,
        max_tokens: int | None = None,
        temperature: float | None = None,
    ) -> AsyncIterator[dict[str, Any]]:
        if self.provider != LLMProvider.OLLAMA and not self.api_key:
            self.logger.error("LLM client not initialized")
            yield {
                "content": "Error: LLM service not properly configured",
                "error": "client_not_initialized",
                "is_final": True,
            }
            return

        try:
            messages = self._build_messages(prompt, system_prompt)
            model_name = model or self.settings.default_model

            if self.provider == LLMProvider.OLLAMA:
                async for chunk in self._generate_ollama_stream(
                    messages, model_name, max_tokens, temperature
                ):
                    yield chunk
            else:
                async for chunk in self._generate_openai_compatible_stream(
                    messages, model_name, max_tokens, temperature
                ):
                    yield chunk

        except Exception as e:
            self.logger.error("Error in LLM stream generation", error=str(e))
            yield {
                "content": f"Error: {str(e)}",
                "error": "stream_generation_failed",
                "is_final": True,
            }

    async def _generate_openai_compatible_stream(
        self,
        messages: list[dict[str, str]],
        model: str,
        max_tokens: int | None,
        temperature: float | None,
    ) -> AsyncIterator[dict[str, Any]]:
        payload = self._build_payload(messages, model, max_tokens, temperature, stream=True)

        self.logger.info(
            "Generating streaming LLM response", model=model, provider=self.provider.value
        )

        full_content = ""
        response = await asyncio.to_thread(
            requests.post,
            f"{self.base_url}/chat/completions",
            headers=self._get_headers(),
            json=payload,
            stream=True,
            timeout=60,
        )
        response.raise_for_status()

        for line in response.iter_lines():
            if not line:
                continue

            line_text = line.decode("utf-8")
            if not line_text.startswith("data: "):
                continue

            data_str = line_text[6:]
            if data_str == "[DONE]":
                self.logger.info(
                    "Completed streaming LLM response",
                    finish_reason="stop",
                    content_length=len(full_content),
                )
                yield {"content": full_content, "is_final": True, "finish_reason": "stop"}
                return

            try:
                chunk = json.loads(data_str)
                delta = chunk["choices"][0].get("delta", {})
                content_delta = delta.get("content", "")

                if content_delta:
                    full_content += content_delta
                    yield {"content": full_content, "delta": content_delta, "is_final": False}

                finish_reason = chunk["choices"][0].get("finish_reason")
                if finish_reason:
                    self.logger.info(
                        "Completed streaming LLM response",
                        finish_reason=finish_reason,
                        content_length=len(full_content),
                    )
                    yield {
                        "content": full_content,
                        "is_final": True,
                        "finish_reason": finish_reason,
                    }
                    return

            except json.JSONDecodeError:
                continue

    async def _generate_ollama_stream(
        self,
        messages: list[dict[str, str]],
        model: str,
        max_tokens: int | None,
        temperature: float | None,
    ) -> AsyncIterator[dict[str, Any]]:
        payload = {
            "model": model,
            "messages": messages,
            "stream": True,
            "options": {
                "temperature": temperature or self.settings.temperature,
            },
        }
        if max_tokens:
            payload["options"]["num_predict"] = max_tokens

        self.logger.info("Generating Ollama streaming response", model=model)

        full_content = ""
        response = await asyncio.to_thread(
            requests.post,
            f"{self.base_url}/api/chat",
            headers=self._get_headers(),
            json=payload,
            stream=True,
            timeout=60,
        )
        response.raise_for_status()

        for line in response.iter_lines():
            if not line:
                continue

            try:
                chunk = json.loads(line.decode("utf-8"))
                content_delta = chunk.get("message", {}).get("content", "")
                done = chunk.get("done", False)

                if content_delta:
                    full_content += content_delta
                    yield {"content": full_content, "delta": content_delta, "is_final": False}

                if done:
                    self.logger.info(
                        "Completed Ollama streaming response",
                        content_length=len(full_content),
                    )
                    yield {"content": full_content, "is_final": True, "finish_reason": "stop"}
                    return

            except json.JSONDecodeError:
                continue

    def get_model_info(self) -> dict[str, Any]:
        client_initialized = True if self.provider == LLMProvider.OLLAMA else bool(self.api_key)

        return {
            "provider": self.provider.value,
            "base_url": self.base_url,
            "default_model": self.settings.default_model,
            "max_tokens": self.settings.max_tokens,
            "temperature": self.settings.temperature,
            "client_initialized": client_initialized,
        }
