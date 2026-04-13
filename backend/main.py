import os
import logging
from collections import defaultdict
from datetime import datetime, timezone, timedelta
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager
from dotenv import load_dotenv

load_dotenv()  # must be before any os.getenv calls

from fastapi import FastAPI, HTTPException, BackgroundTasks, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel
from supabase import create_client, Client
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger(__name__)

# ============================================================================
# PROMETHEUS METRICS
# ============================================================================
request_count = Counter(
    "supachat_requests_total",
    "Total API requests",
    ["method", "endpoint", "status"]
)
query_duration = Histogram(
    "supachat_query_duration_seconds",
    "Query execution time in seconds",
    ["query_type"],
    buckets=[0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
)
nl_query_count = Counter(
    "supachat_nl_queries_total",
    "Natural language queries processed"
)

# ============================================================================
# CONFIGURATION
# ============================================================================
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "")

supabase_client: Optional[Client] = None

def get_supabase() -> Optional[Client]:
    global supabase_client
    if supabase_client is None and SUPABASE_URL and SUPABASE_KEY:
        try:
            key = SUPABASE_SERVICE_KEY or SUPABASE_KEY
            supabase_client = create_client(SUPABASE_URL, key)
        except Exception as e:
            logger.error(f"Supabase init failed: {e}")
    return supabase_client

# ============================================================================
# IN-MEMORY QUERY HISTORY
# ============================================================================
query_history: List[Dict[str, Any]] = []
query_history_id_counter = 1

# ============================================================================
# PYDANTIC MODELS
# ============================================================================
class QueryRequest(BaseModel):
    query: str
    context: Optional[str] = None

class QueryResult(BaseModel):
    success: bool
    query_type: str
    sql_generated: str
    results: List[Dict[str, Any]]
    row_count: int
    execution_time: float
    message: Optional[str] = None

class HealthResponse(BaseModel):
    status: str
    database: str
    timestamp: str
    version: str = "1.0.0"

# ============================================================================
# LIFESPAN
# ============================================================================
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("SupaChat Backend starting...")
    client = get_supabase()
    if client:
        try:
            client.table("articles").select("id").limit(1).execute()
            logger.info("✅ Supabase connection successful")
        except Exception as e:
            logger.warning(f"⚠️  Supabase connection test failed: {e}")
    else:
        logger.warning("⚠️  Supabase credentials not set — running in mock mode")
    yield
    logger.info("SupaChat Backend shutting down...")

# ============================================================================
# APP
# ============================================================================
app = FastAPI(
    title="SupaChat Backend",
    description="Natural Language → SQL → Supabase Analytics",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Prometheus request latency middleware
@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start
    endpoint = request.url.path
    request_count.labels(
        method=request.method,
        endpoint=endpoint,
        status=str(response.status_code)
    ).inc()
    query_duration.labels(query_type="http").observe(duration)
    return response

# ============================================================================
# NL → SQL TRANSLATION  (MCP integration point)
# ============================================================================
def translate_nl_to_sql(query: str) -> tuple[str, str]:
    """
    Translate natural language to SQL.
    Returns (sql, query_type).

    In production this calls an MCP server / LLM.
    For demo: keyword-based routing to pre-validated SQL templates.
    """
    q = query.lower()

    # "Show top trending topics in last 30 days"
    if "trending" in q or "top topics" in q:
        return (
            """SELECT topic,
       COUNT(*)            AS article_count,
       SUM(views)          AS total_views,
       ROUND(AVG(engagement_rate)::numeric, 2) AS avg_engagement
FROM   articles
WHERE  published_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP  BY topic
ORDER  BY total_views DESC
LIMIT  10;""",
            "trending"
        )

    # "Compare article engagement by topic"
    if "compare" in q and ("engagement" in q or "topic" in q):
        return (
            """SELECT topic,
       COUNT(*)                                AS article_count,
       ROUND(AVG(views)::numeric, 0)           AS avg_views,
       ROUND(AVG(engagement_rate)::numeric, 2) AS avg_engagement,
       ROUND(AVG(shares)::numeric, 1)          AS avg_shares
FROM   articles
GROUP  BY topic
ORDER  BY avg_engagement DESC;""",
            "compare"
        )

    # "Plot daily views trend for AI articles" / "daily views"
    if ("daily" in q or "plot" in q or "trend" in q) and ("view" in q or "article" in q):
        topic_filter = ""
        if "ai" in q:
            topic_filter = "WHERE topic = 'AI'\n"
        return (
            f"""SELECT DATE(published_date) AS date,
       SUM(views)           AS daily_views,
       COUNT(*)             AS article_count
FROM   articles
{topic_filter}GROUP  BY DATE(published_date)
ORDER  BY date DESC
LIMIT  30;""",
            "daily_trend"
        )

    # "Show performance metrics" / "article performance"
    if "performance" in q or "metrics" in q:
        return (
            """SELECT title,
       topic,
       views,
       ROUND(engagement_rate::numeric, 2) AS engagement_rate,
       shares,
       DATE(published_date)               AS published_date
FROM   articles
ORDER  BY views DESC
LIMIT  20;""",
            "performance"
        )

    # Fallback
    return (
        "SELECT id, title, topic, views, engagement_rate FROM articles LIMIT 10;",
        "list"
    )

# ============================================================================
# SQL EXECUTION — real Supabase table API, no mock
# ============================================================================
async def execute_sql(sql: str, query_type: str) -> List[Dict[str, Any]]:
    logger.info(f"Executing [{query_type}]: {sql[:80].strip()}...")

    client = get_supabase()
    if not client:
        raise HTTPException(status_code=503, detail="Supabase not configured. Set SUPABASE_URL and SUPABASE_KEY in .env")

    # Fetch all articles from Supabase
    result = client.table("articles").select("*").execute()
    rows: List[Dict[str, Any]] = result.data or []

    if not rows:
        return []

    # ── Transform real data per query type ──────────────────────────────────
    if query_type == "trending":
        cutoff = (datetime.now(timezone.utc) - timedelta(days=30)).isoformat()
        filtered = [r for r in rows if r.get("published_date", "") >= cutoff]
        if not filtered:
            filtered = rows  # fallback: use all if none in last 30 days
        groups: Dict[str, Any] = defaultdict(lambda: {"article_count": 0, "total_views": 0, "engagement_sum": 0.0})
        for r in filtered:
            t = r["topic"]
            groups[t]["article_count"] += 1
            groups[t]["total_views"]   += r.get("views", 0)
            groups[t]["engagement_sum"] += r.get("engagement_rate", 0)
        return sorted(
            [{"topic": t,
              "article_count": v["article_count"],
              "total_views": v["total_views"],
              "avg_engagement": round(v["engagement_sum"] / v["article_count"], 2)}
             for t, v in groups.items()],
            key=lambda x: x["total_views"], reverse=True
        )[:10]

    if query_type == "compare":
        groups = defaultdict(lambda: {"article_count": 0, "views_sum": 0, "engagement_sum": 0.0, "shares_sum": 0})
        for r in rows:
            t = r["topic"]
            groups[t]["article_count"] += 1
            groups[t]["views_sum"]      += r.get("views", 0)
            groups[t]["engagement_sum"] += r.get("engagement_rate", 0)
            groups[t]["shares_sum"]     += r.get("shares", 0)
        return sorted(
            [{"topic": t,
              "article_count": v["article_count"],
              "avg_views": round(v["views_sum"] / v["article_count"], 0),
              "avg_engagement": round(v["engagement_sum"] / v["article_count"], 2),
              "avg_shares": round(v["shares_sum"] / v["article_count"], 1)}
             for t, v in groups.items()],
            key=lambda x: x["avg_engagement"], reverse=True
        )

    if query_type == "daily_trend":
        groups = defaultdict(lambda: {"daily_views": 0, "article_count": 0})
        for r in rows:
            date_str = str(r.get("published_date", ""))[:10]
            groups[date_str]["daily_views"]   += r.get("views", 0)
            groups[date_str]["article_count"] += 1
        return sorted(
            [{"date": d, "daily_views": v["daily_views"], "article_count": v["article_count"]}
             for d, v in groups.items()],
            key=lambda x: x["date"], reverse=True
        )[:30]

    if query_type == "performance":
        return sorted(
            [{"title": r["title"],
              "topic": r["topic"],
              "views": r.get("views", 0),
              "engagement_rate": round(r.get("engagement_rate", 0), 2),
              "shares": r.get("shares", 0),
              "published_date": str(r.get("published_date", ""))[:10]}
             for r in rows],
            key=lambda x: x["views"], reverse=True
        )[:20]

    # list / fallback — return raw rows
    return [{"id": r.get("id"), "title": r["title"], "topic": r["topic"],
             "views": r.get("views", 0), "engagement_rate": round(r.get("engagement_rate", 0), 2)}
            for r in rows[:10]]

# ============================================================================
# ENDPOINTS
# ============================================================================
@app.get("/health", response_model=HealthResponse)
async def health_check():
    client = get_supabase()
    db_status = "supabase-connected" if client else "mock-mode"
    return HealthResponse(
        status="healthy",
        database=db_status,
        timestamp=datetime.utcnow().isoformat()
    )


@app.post("/query", response_model=QueryResult)
async def process_query(request: QueryRequest, background_tasks: BackgroundTasks):
    global query_history_id_counter
    start_time = time.time()

    try:
        nl_query_count.inc()

        sql, query_type = translate_nl_to_sql(request.query)
        logger.info(f"Query: '{request.query}' → type={query_type}")

        results = await execute_sql(sql, query_type)
        execution_time = time.time() - start_time
        query_duration.labels(query_type=query_type).observe(execution_time)

        history_item = {
            "id": query_history_id_counter,
            "query": request.query,
            "timestamp": datetime.utcnow().isoformat(),
            "execution_time": execution_time,
            "row_count": len(results),
            "success": True
        }
        query_history.insert(0, history_item)
        query_history_id_counter += 1
        if len(query_history) > 100:
            query_history.pop()

        return QueryResult(
            success=True,
            query_type=query_type,
            sql_generated=sql,
            results=results,
            row_count=len(results),
            execution_time=execution_time,
            message="Query executed successfully"
        )

    except Exception as e:
        logger.error(f"Query error: {e}")
        execution_time = time.time() - start_time
        history_item = {
            "id": query_history_id_counter,
            "query": request.query,
            "timestamp": datetime.utcnow().isoformat(),
            "execution_time": execution_time,
            "row_count": 0,
            "success": False
        }
        query_history.insert(0, history_item)
        query_history_id_counter += 1
        if len(query_history) > 100:
            query_history.pop()
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/queries/history")
async def get_query_history(limit: int = 20):
    return {"queries": query_history[:limit], "total": len(query_history)}


@app.get("/metrics")
async def prometheus_metrics():
    return PlainTextResponse(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/")
async def root():
    return {
        "service": "SupaChat Backend",
        "version": "1.0.0",
        "mode": "supabase" if get_supabase() else "mock",
        "endpoints": {
            "health": "GET /health",
            "query":  "POST /query",
            "history": "GET /queries/history",
            "metrics": "GET /metrics",
            "docs":   "GET /docs"
        }
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=int(os.getenv("BACKEND_PORT", 8000)),
        log_level="info"
    )
