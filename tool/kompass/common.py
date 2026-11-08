"""Small, deterministic authoring helpers for the original bilingual course.

These helpers do not infer answers from prose. Authors provide explicit answer
rules; validate_content.py and independent content tests check their semantics.
"""
from __future__ import annotations

from typing import Any


def L(de: str, en: str) -> dict[str, str]:
    return {"de": de, "en": en}


def figure(kind: str, data: dict[str, Any], de: str, en: str) -> dict[str, Any]:
    return {"kind": kind, "data": data, "alt": L(de, en)}


def error(value: str | int | float, code: str, de: str, en: str) -> dict[str, Any]:
    return {"value": str(value), "code": code, "feedback": L(de, en)}


def number(id: str, de: str, en: str, value: int | float, skill: str,
           *, unit: str | None = None, points: float = 1, tolerance: float = 0,
           errors: list | None = None, carry: tuple[str, float] | None = None,
           fig: dict | None = None) -> dict:
    part = {"id": id, "kind": "number", "prompt": L(de, en),
            "competencyIds": [skill], "maxPoints": points,
            "answer": {"type": "number", "value": value}}
    if tolerance:
        part["answer"]["tolerance"] = tolerance
    if unit:
        part["unit"] = unit
    if errors:
        part["errors"] = errors
    if carry:
        part.update(carryFrom=carry[0], carryOffset=carry[1])
    if fig:
        part["figure"] = fig
    return part


def choice(id: str, de: str, en: str, options: list[tuple[str, str, str]],
           correct: str, skill: str, *, errors: list | None = None,
           fig: dict | None = None, points: float = 1) -> dict:
    part = {"id": id, "kind": "choice", "prompt": L(de, en),
            "competencyIds": [skill], "maxPoints": points,
            "options": [{"id": key, "label": L(german, english)}
                        for key, german, english in options],
            "answer": {"type": "choice", "value": correct}}
    if errors:
        part["errors"] = errors
    if fig:
        part["figure"] = fig
    return part


def multi(id: str, de: str, en: str, options: list[tuple[str, str, str]],
          correct: list[str], skill: str, *, fig: dict | None = None,
          points: float = 1) -> dict:
    part = choice(id, de, en, options, "", skill, fig=fig, points=points)
    part["kind"] = "multiChoice"
    part["answer"] = {"type": "set", "values": correct}
    return part


def order(id: str, de: str, en: str, options: list[tuple[str, str, str]],
          correct: list[str], skill: str, *, points: float = 1) -> dict:
    part = choice(id, de, en, options, "", skill, points=points)
    part["kind"] = "order"
    part["answer"] = {"type": "sequence", "values": correct}
    return part


def manual(id: str, de: str, en: str, criteria_de: str, criteria_en: str,
           skill: str, *, points: float = 1, rubric: list[dict] | None = None,
           fig: dict | None = None) -> dict:
    part = {"id": id, "kind": "text", "prompt": L(de, en),
            "competencyIds": [skill], "maxPoints": points,
            "answer": {"type": "manual", "criteria": L(criteria_de, criteria_en)},
            "rubric": rubric or [L(criteria_de, criteria_en)]}
    if fig:
        part["figure"] = fig
    return part


def cells(id: str, de: str, en: str, correct: list[str], skill: str,
          fig: dict, *, points: float = 1) -> dict:
    return {"id": id, "kind": "cells", "prompt": L(de, en),
            "competencyIds": [skill], "maxPoints": points,
            "answer": {"type": "set", "values": correct}, "figure": fig}


def task(skill: str, slug: str, domain: str, title_de: str, title_en: str,
         prompt_de: str, prompt_en: str, parts: list[dict], *, use: str,
         level: int = 2, hints: list[tuple[str, str]],
         solution: tuple[str, str], fig: dict | None = None,
         seconds: int = 90, family: str | None = None) -> dict:
    item = {"id": f"{skill.lower().replace('-', '')}_{slug}",
            "familyId": family or f"{skill.lower().replace('-', '')}_{slug}",
            "domain": domain, "title": L(title_de, title_en),
            "prompt": L(prompt_de, prompt_en), "level": level, "use": use,
            "parts": parts, "hints": [L(*hint) for hint in hints],
            "solution": L(*solution), "estimatedSeconds": seconds,
            "source": {"kind": "original", "license": "AGPL-3.0-only",
                       "referenceCompetencies": [skill]}}
    if fig:
        item["figure"] = fig
    return item
