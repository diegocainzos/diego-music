from __future__ import annotations

import json
from typing import Final

import httpx


_OPENROUTER_URL: Final[str] = "https://openrouter.ai/api/v1/chat/completions"
_MAX_RECOMMENDATIONS: Final[int] = 10


class RecommendationError(RuntimeError):
    """Fallo del LLM; nunca se devuelve al cliente tal cual."""


async def recommend_queries(
    client: httpx.AsyncClient,
    api_key: str,
    model: str,
    seeds: list[str],
) -> list[str]:
    """Pide al LLM canciones parecidas a `seeds` y devuelve búsquedas «artista - título»."""
    prompt = (
        "Canciones escuchadas recientemente:\n"
        + "\n".join(f"- {seed}" for seed in seeds)
        + f"\n\nRecomienda {_MAX_RECOMMENDATIONS} canciones distintas que no estén en la lista y que "
        "probablemente le gusten a quien las escucha, mezclando artistas conocidos y descubrimientos. "
        'Responde solo con JSON: {"recommendations": [{"artist": "...", "title": "..."}]}'
    )
    try:
        response = await client.post(
            _OPENROUTER_URL,
            headers={"Authorization": f"Bearer {api_key}"},
            json={"model": model, "messages": [{"role": "user", "content": prompt}]},
        )
        response.raise_for_status()
        content = response.json()["choices"][0]["message"]["content"]
    except (httpx.HTTPError, ValueError, KeyError, IndexError, TypeError) as error:
        raise RecommendationError from error
    return parse_queries(content)


def parse_queries(content: object) -> list[str]:
    """Extrae el JSON aunque el modelo lo envuelva en texto o en ```json."""
    if not isinstance(content, str):
        raise RecommendationError
    start, end = content.find("{"), content.rfind("}")
    try:
        items = json.loads(content[start : end + 1])["recommendations"]
    except (ValueError, KeyError, TypeError) as error:
        raise RecommendationError from error
    queries: list[str] = []
    for item in items if isinstance(items, list) else []:
        if not isinstance(item, dict):
            continue
        artist, title = str(item.get("artist", "")).strip(), str(item.get("title", "")).strip()
        if title:
            queries.append(f"{artist} - {title}"[:200] if artist else title[:200])
    return queries[:_MAX_RECOMMENDATIONS]
