import os
import logging
from collections import defaultdict
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager
from dotenv import load_dotenv

load_dotenv()

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
    "supachat_requests_total", "Total API requests",
    ["method", "endpoint", "status"]
)
query_duration = Histogram(
    "supachat_query_duration_seconds", "Query execution time",
    ["query_type"], buckets=[0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
)
nl_query_count = Counter("supachat_nl_queries_total", "NL queries processed")

# ============================================================================
# SUPABASE — initialised once, used on every request (real-time)
# ============================================================================
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_KEY", "")

_supabase: Optional[Client] = None

def get_supabase() -> Client:
    global _supabase
    if _supabase is None:
        if not SUPABASE_URL or not SUPABASE_KEY:
            raise HTTPException(
                status_code=503,
                detail="Supabase credentials missing. Set SUPABASE_URL and SUPABASE_KEY in .env"
            )
        _supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
    return _supabase

def fetch_articles(filters: dict = None) -> List[Dict[str, Any]]:
    """Fetch fresh rows from Supabase on every call — no caching."""
    q = get_supabase().table("articles").select("*")
    if filters:
        for col, val in filters.items():
            q = q.eq(col, val)
    result = q.execute()
    return result.data or []

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
    try:
        rows = fetch_articles()
        logger.info(f"✅ Supabase connected — {len(rows)} articles in database")
    except Exception as e:
        logger.error(f"❌ Supabase connection failed: {e}")
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

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    request_count.labels(
        method=request.method,
        endpoint=request.url.path,
        status=str(response.status_code)
    ).inc()
    query_duration.labels(query_type="http").observe(time.time() - start)
    return response

# ============================================================================
# NL → SQL TRANSLATION
# ============================================================================
def translate_nl_to_sql(query: str) -> tuple[str, str]:
    q = query.lower()

    if "trending" in q or "top topics" in q:
        return (
            """SELECT topic,
       COUNT(*)                                  AS article_count,
       SUM(views)                                AS total_views,
       ROUND(AVG(engagement_rate)::numeric, 2)   AS avg_engagement
FROM   articles
GROUP  BY topic
ORDER  BY total_views DESC
LIMIT  10;""",
            "trending"
        )

    if "compare" in q and ("engagement" in q or "topic" in q):
        return (
            """SELECT topic,
       COUNT(*)                                  AS article_count,
       ROUND(AVG(views)::numeric, 0)             AS avg_views,
       ROUND(AVG(engagement_rate)::numeric, 2)   AS avg_engagement,
       ROUND(AVG(shares)::numeric, 1)            AS avg_shares
FROM   articles
GROUP  BY topic
ORDER  BY avg_engagement DESC;""",
            "compare"
        )

    if ("daily" in q or "plot" in q or "trend" in q) and ("view" in q or "article" in q):
        topic_clause = "WHERE topic = 'AI'\n" if "ai" in q else ""
        return (
            f"""SELECT DATE(published_date) AS date,
       SUM(views)                AS daily_views,
       COUNT(*)                  AS article_count
FROM   articles
{topic_clause}GROUP  BY DATE(published_date)
ORDER  BY date DESC
LIMIT  30;""",
            "daily_trend"
        )

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

    return (
        "SELECT id, title, topic, views, engagement_rate FROM articles ORDER BY views DESC LIMIT 10;",
        "list"
    )

# ============================================================================
# REAL-TIME QUERY EXECUTION — fetches fresh Supabase data every time
# ============================================================================
def execute_query(query_type: str, user_query: str) -> List[Dict[str, Any]]:
    # Apply topic filter for daily_trend if AI mentioned
    topic_filter = {}
    if query_type == "daily_trend" and "ai" in user_query.lower():
        topic_filter = {"topic": "AI"}

    rows = fetch_articles(topic_filter if topic_filter else None)

    if not rows:
        return []

    if query_type == "trending":
        groups: Dict[str, Any] = defaultdict(
            lambda: {"article_count": 0, "total_views": 0, "eng_sum": 0.0}
        )
        for r in rows:
            t = r["topic"]
            groups[t]["article_count"] += 1
            groups[t]["total_views"]   += r.get("views", 0)
            groups[t]["eng_sum"]       += r.get("engagement_rate", 0.0)
        return sorted(
            [{"topic": t,
              "article_count": v["article_count"],
              "total_views": v["total_views"],
              "avg_engagement": round(v["eng_sum"] / v["article_count"], 2)}
             for t, v in groups.items()],
            key=lambda x: x["total_views"], reverse=True
        )[:10]

    if query_type == "compare":
        groups = defaultdict(
            lambda: {"article_count": 0, "views_sum": 0, "eng_sum": 0.0, "shares_sum": 0}
        )
        for r in rows:
            t = r["topic"]
            groups[t]["article_count"] += 1
            groups[t]["views_sum"]     += r.get("views", 0)
            groups[t]["eng_sum"]       += r.get("engagement_rate", 0.0)
            groups[t]["shares_sum"]    += r.get("shares", 0)
        return sorted(
            [{"topic": t,
              "article_count": v["article_count"],
              "avg_views": int(round(v["views_sum"] / v["article_count"])),
              "avg_engagement": round(v["eng_sum"] / v["article_count"], 2),
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
            [{"date": d,
              "daily_views": v["daily_views"],
              "article_count": v["article_count"]}
             for d, v in groups.items()],
            key=lambda x: x["date"], reverse=True
        )[:30]

    if query_type == "performance":
        return sorted(
            [{"title": r["title"],
              "topic": r["topic"],
              "views": r.get("views", 0),
              "engagement_rate": round(r.get("engagement_rate", 0.0), 2),
              "shares": r.get("shares", 0),
              "published_date": str(r.get("published_date", ""))[:10]}
             for r in rows],
            key=lambda x: x["views"], reverse=True
        )[:20]

    # list / fallback
    return [{"id": r.get("id"),
             "title": r["title"],
             "topic": r["topic"],
             "views": r.get("views", 0),
             "engagement_rate": round(r.get("engagement_rate", 0.0), 2)}
            for r in sorted(rows, key=lambda x: x.get("views", 0), reverse=True)[:10]]

# ============================================================================
# ENDPOINTS
# ============================================================================
@app.get("/health", response_model=HealthResponse)
async def health_check():
    try:
        rows = fetch_articles()
        db_status = f"supabase-connected ({len(rows)} articles)"
    except Exception as e:
        db_status = f"error: {e}"
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

        # Fetch fresh real-time data from Supabase
        results = execute_query(query_type, request.query)
        execution_time = time.time() - start_time
        query_duration.labels(query_type=query_type).observe(execution_time)

        query_history.insert(0, {
            "id": query_history_id_counter,
            "query": request.query,
            "timestamp": datetime.utcnow().isoformat(),
            "execution_time": execution_time,
            "row_count": len(results),
            "success": True
        })
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
            message=f"Live data from Supabase — {len(results)} results"
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Query error: {e}")
        execution_time = time.time() - start_time
        query_history.insert(0, {
            "id": query_history_id_counter,
            "query": request.query,
            "timestamp": datetime.utcnow().isoformat(),
            "execution_time": execution_time,
            "row_count": 0,
            "success": False
        })
        query_history_id_counter += 1
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/queries/history")
async def get_query_history(limit: int = 20):
    return {"queries": query_history[:limit], "total": len(query_history)}


@app.get("/metrics")
async def prometheus_metrics():
    return PlainTextResponse(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/")
async def root():
    try:
        rows = fetch_articles()
        db_info = f"connected ({len(rows)} articles)"
    except Exception:
        db_info = "not connected"
    return {
        "service": "SupaChat Backend",
        "version": "1.0.0",
        "database": db_info,
        "endpoints": {
            "health":  "GET  /health",
            "query":   "POST /query",
            "history": "GET  /queries/history",
            "metrics": "GET  /metrics",
            "docs":    "GET  /docs"
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
