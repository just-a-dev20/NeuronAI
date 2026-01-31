from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Service Configuration
    service_name: str = "neuronai-python"
    service_port: int = 50051
    environment: str = "development"
    log_level: str = "INFO"

    # Security
    jwt_secret: str = ""
    jwt_algorithm: str = "HS256"

    # Supabase
    supabase_url: str = ""
    supabase_key: str = ""

    # LLM Configuration
    openai_api_key: str = ""
    default_model: str = "gpt-4"
    max_tokens: int = 4096
    temperature: float = 0.7

    # Agent Configuration
    max_agents: int = 10
    agent_timeout: int = 300

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
