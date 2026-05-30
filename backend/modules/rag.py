import io
import json
import math
import uuid
from datetime import datetime

from openai import OpenAI

from config import OPENAI_API_KEY
from modules.mongodb import get_rag_chunks, save_rag_chunks


EMBEDDING_MODEL = "text-embedding-3-small"
_client = OpenAI(api_key=OPENAI_API_KEY)
JSON_TEXT_FIELDS = (
    "title",
    "source",
    "section",
    "text",
    "content",
    "body",
    "summary",
    "symptoms",
    "causes",
    "treatment",
    "prevention",
)


def get_embedding(text):
    cleaned = (text or "").strip()
    if not cleaned:
        return []
    response = _client.embeddings.create(
        model=EMBEDDING_MODEL,
        input=cleaned,
        timeout=30,
    )
    return response.data[0].embedding


def chunk_text(text, chunk_size=1000, overlap=150):
    cleaned = (text or "").strip()
    if not cleaned:
        return []

    chunk_size = max(int(chunk_size or 1000), 1)
    overlap = max(int(overlap or 0), 0)
    if overlap >= chunk_size:
        overlap = max(chunk_size - 1, 0)

    chunks = []
    start = 0
    while start < len(cleaned):
        end = min(start + chunk_size, len(cleaned))
        chunk = cleaned[start:end].strip()
        if chunk:
            chunks.append(chunk)
        if end >= len(cleaned):
            break
        start = end - overlap
    return chunks


def add_rag_document(text, title="", source="", section="", metadata=None):
    document_id = str(uuid.uuid4())
    chunks = chunk_text(text)
    metadata = metadata or {}
    created_at = datetime.utcnow().isoformat()

    docs = []
    for index, chunk in enumerate(chunks):
        docs.append({
            "document_id": document_id,
            "title": title or "",
            "source": source or "",
            "section": section or "",
            "text": chunk,
            "embedding": get_embedding(chunk),
            "metadata": metadata,
            "chunk_index": index,
            "created_at": created_at,
        })

    save_rag_chunks(docs)
    return {
        "document_id": document_id,
        "chunks_count": len(docs),
    }


def cosine_similarity(vec1, vec2):
    if not isinstance(vec1, list) or not isinstance(vec2, list):
        return 0.0
    if not vec1 or not vec2 or len(vec1) != len(vec2):
        return 0.0

    try:
        dot = sum(float(a) * float(b) for a, b in zip(vec1, vec2))
        norm1 = math.sqrt(sum(float(a) * float(a) for a in vec1))
        norm2 = math.sqrt(sum(float(b) * float(b) for b in vec2))
    except (TypeError, ValueError):
        return 0.0

    if norm1 == 0.0 or norm2 == 0.0:
        return 0.0
    return dot / (norm1 * norm2)


def retrieve_rag_chunks(query, top_k=5, min_score=0.25):
    query_embedding = get_embedding(query)
    if not query_embedding:
        return []

    try:
        top_k = max(int(top_k or 5), 1)
    except (TypeError, ValueError):
        top_k = 5

    scored = []
    for chunk in get_rag_chunks():
        item = dict(chunk)
        item.pop("_id", None)
        score = cosine_similarity(query_embedding, item.get("embedding"))
        if score >= min_score:
            item["score"] = score
            item.pop("embedding", None)
            scored.append(item)

    scored.sort(key=lambda item: item.get("score", 0.0), reverse=True)
    return scored[:top_k]


def build_rag_context(chunks):
    if not chunks:
        return ""

    parts = ["Knowledge base context:"]
    for index, chunk in enumerate(chunks, start=1):
        parts.append(
            "\n".join([
                f"[{index}]",
                f"Title: {chunk.get('title', '')}",
                f"Source: {chunk.get('source', '')}",
                f"Section: {chunk.get('section', '')}",
                f"Text: {chunk.get('text', '')}",
            ])
        )
    return "\n\n".join(parts)


def extract_text_from_pdf(file_bytes):
    try:
        from pypdf import PdfReader
    except ImportError as exc:
        raise ValueError("PDF support requires pypdf to be installed") from exc

    reader = PdfReader(io.BytesIO(file_bytes))
    text = "\n".join(page.extract_text() or "" for page in reader.pages)
    return text.strip()


def extract_text_from_txt(file_bytes):
    return file_bytes.decode("utf-8", errors="ignore").strip()


def extract_text_from_json(file_bytes):
    try:
        data = json.loads(file_bytes.decode("utf-8", errors="ignore"))
    except json.JSONDecodeError as exc:
        raise ValueError("invalid JSON file") from exc
    return _json_to_readable_text(data).strip()


def extract_text_from_uploaded_file(uploaded_file):
    filename = (uploaded_file.filename or "").lower()
    content_type = (uploaded_file.content_type or "").lower()
    file_bytes = uploaded_file.read()

    if filename.endswith(".pdf") or content_type == "application/pdf":
        return extract_text_from_pdf(file_bytes)
    if filename.endswith(".txt") or content_type.startswith("text/plain"):
        return extract_text_from_txt(file_bytes)
    if filename.endswith(".json") or "json" in content_type:
        return extract_text_from_json(file_bytes)

    raise ValueError("unsupported file type; upload PDF, TXT, or JSON")


def _json_to_readable_text(value, label=None):
    if isinstance(value, dict):
        lines = []
        ordered_keys = [key for key in JSON_TEXT_FIELDS if key in value]
        ordered_keys.extend(key for key in value.keys() if key not in ordered_keys)

        if label:
            lines.append(f"{label}:")
        for key in ordered_keys:
            child = value.get(key)
            if child is None:
                continue
            lines.append(_json_to_readable_text(child, label=str(key)))
        return "\n".join(line for line in lines if line)

    if isinstance(value, list):
        lines = []
        if label:
            lines.append(f"{label}:")
        for index, item in enumerate(value, start=1):
            lines.append(_json_to_readable_text(item, label=f"Item {index}"))
        return "\n".join(line for line in lines if line)

    if label:
        return f"{label}: {value}"
    return str(value)
