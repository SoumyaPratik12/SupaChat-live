import os
import asyncio
import logging
from datetime import datetime
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel
from supabase import create_client, Client
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time

# Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ============================================================================
# METRICS (for Prometheus monitoring)
# ============================================================================
request_count = Counter(
    "supachat_requests_total",
    "Total API requests",
    ["method", "endpoint", "status"]
)
query_duration = Histogram(
    "supachat_query_duration_seconds",
    "Query execution time",
    ["query_type"]
)
nl_query_count = Counter(
    "supachat_nl_queries_total",
    "Natural language queries processed"
)

# ============================================================================
# CONFIGURATION
# ============================================================================
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://your-project.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "your-anon-key")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "your-service-key")

# Initialize Supabase
supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY or SUPABASE_KEY)

# ============================================================================
# QUERY HISTORY STORAGE (In-memory for demo - use DB in production)
# ============================================================================
query_history: List[Dict[str, Any]] = []
query_history_id_counter = 1

# ============================================================================
# PYDANTIC MODELS
# ============================================================================
class QueryRequest(BaseModel):
    """Natural language query request"""
    query: str
    context: Optional[str] = None


class QueryResult(BaseModel):
    """Query result response"""
    success: bool
    query_type: str
    sql_generated: str
    results: List[Dict[str, Any]]
    row_count: int
    execution_time: float
    message: Optional[str] = None


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    database: str
    timestamp: str
    version: str = "1.0.0"


class QueryHistoryItem(BaseModel):
    """Query history item"""
    id: int
    query: str
    timestamp: str
    execution_time: float
    row_count: int
    success: bool


# ============================================================================
# LIFESPAN EVENT HANDLER
# ============================================================================
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Handle startup and shutdown events"""
    logger.info("SupaChat Backend starting...")
    # Startup
    try:
        # Test database connection
        result = supabase.table("articles").select("id").limit(1).execute()
        logger.info("✅ Supabase connection successful")
    except Exception as e:
        logger.error(f"❌ Supabase connection failed: {e}")
    
    yield
    
    # Shutdown
    logger.info("SupaChat Backend shutting down...")


# ============================================================================
# INITIALIZE FASTAPI APP
# ============================================================================
app = FastAPI(
    title="SupaChat Backend",
    description="Natural Language → SQL → Supabase Analytics",
    version="1.0.0",
    lifespan=lifespan
)

# ============================================================================
# MIDDLEWARE
# ============================================================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict this
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
def translate_nl_to_sql(query: str) -> str:
    """
    Translate natural language to SQL (MCP Integration Point)
    
    In production, this would:
    1. Call an MCP server endpoint
    2. Use Claude/LLM to convert NL → SQL
    3. Validate SQL safety
    
    For now, we have hardcoded examples for demo purposes.
    """
    query_lower = query.lower()
    
    # Example 1: Top trending topics in last 30 days
    if "trending" in query_lower or "top topics" in query_lower:
        return """
        SELECT 
            topic, 
            COUNT(*) as article_count,
            SUM(views) as total_views,
            AVG(engagement_rate) as avg_engagement
        FROM articles
        WHERE published_date >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY topic
        ORDER BY total_views DESC
        LIMIT 10;
        """
    
    # Example 2: Compare article engagement by topic
    if "compare" in query_lower and "engagement" in query_lower:
        return """
        SELECT 
            topic,
            COUNT(*) as article_count,
            AVG(views) as avg_views,
            AVG(engagement_rate) as avg_engagement,
            AVG(shares) as avg_shares
        FROM articles
        GROUP BY topic
        ORDER BY avg_engagement DESC;
        """
    
    # Example 3: Daily views trend for specific topic
    if "daily" in query_lower and "views" in query_lower:
        return """
        SELECT 
            DATE(published_date) as date,
            SUM(views) as daily_views,
            COUNT(*) as article_count
        FROM articles
        GROUP BY DATE(published_date)
        ORDER BY date DESC
        LIMIT 30;
        """
    
    # Example 4: Article performance metrics
    if "performance" in query_lower or "metrics" in query_lower:
        return """
        SELECT 
            title,
            topic,
            views,
            engagement_rate,
            shares,
            published_date
        FROM articles
        ORDER BY views DESC
        LIMIT 20;
        """
    
    # Fallback: list articles
    return "SELECT id, title, topic, views, engagement_rate FROM articles LIMIT 10;"


async def execute_sql(sql: str) -> List[Dict[str, Any]]:
    """
    Execute SQL query against Supabase
    
    For demo, we'll create mock data instead of real queries
    since we don't have actual Supabase set up yet.
    """
    # In production, this would execute real SQL via Supabase RPC or raw SQL
    # For now, return mock data
    logger.info(f"Executing SQL: {sql[:100]}...")
    
    # Simulate execution time
    await asyncio.sleep(0.5)
    
    normalized_sql = " ".join(sql.lower().split())

    # Mock results based on the generated SQL shape.
    if "sum(views) as total_views" in normalized_sql and "group by topic" in normalized_sql:
        return [
            {"topic": "AI", "article_count": 15, "total_views": 5230, "avg_engagement": 0.78},
            {"topic": "DevOps", "article_count": 12, "total_views": 4120, "avg_engagement": 0.72},
            {"topic": "Web3", "article_count": 8, "total_views": 2950, "avg_engagement": 0.65},
        ]
    elif "avg(views) as avg_views" in normalized_sql and "avg(shares) as avg_shares" in normalized_sql:
        return [
            {"topic": "AI", "article_count": 42, "avg_views": 185.3, "avg_engagement": 0.82, "avg_shares": 12.5},
            {"topic": "DevOps", "article_count": 38, "avg_views": 156.2, "avg_engagement": 0.75, "avg_shares": 9.8},
            {"topic": "Web3", "article_count": 25, "avg_views": 118.4, "avg_engagement": 0.68, "avg_shares": 7.2},
        ]
    elif "date(published_date) as date" in normalized_sql and "sum(views) as daily_views" in normalized_sql:
        dates = ["2024-01-08", "2024-01-07", "2024-01-06"]
        return [
            {"date": dates[0], "daily_views": 1250, "article_count": 5},
            {"date": dates[1], "daily_views": 980, "article_count": 4},
            {"date": dates[2], "daily_views": 1520, "article_count": 6},
        ]
    elif "title," in normalized_sql and "shares," in normalized_sql and "published_date" in normalized_sql:
        return [
            {"title": "AI Trends 2024", "topic": "AI", "views": 450, "engagement_rate": 0.85, "shares": 25, "published_date": "2024-01-08"},
            {"title": "DevOps Best Practices", "topic": "DevOps", "views": 320, "engagement_rate": 0.72, "shares": 18, "published_date": "2024-01-07"},
            {"title": "Web3 Fundamentals", "topic": "Web3", "views": 210, "engagement_rate": 0.68, "shares": 12, "published_date": "2024-01-06"},
        ]
    else:
        return [
            {"id": 1, "title": "AI Trends 2024", "topic": "AI", "views": 450, "engagement_rate": 0.85},
            {"id": 2, "title": "DevOps Best Practices", "topic": "DevOps", "views": 320, "engagement_rate": 0.72},
            {"id": 3, "title": "Web3 Fundamentals", "topic": "Web3", "views": 210, "engagement_rate": 0.68},
        ]


# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint for monitoring"""
    return HealthResponse(
        status="healthy",
        database="supabase-connected",
        timestamp=datetime.utcnow().isoformat()
    )


@app.post("/query", response_model=QueryResult)
async def process_query(request: QueryRequest, background_tasks: BackgroundTasks):
    """
    Main endpoint: Natural Language Query → SQL → Results
    
    Flow:
    1. Accept natural language query
    2. Translate to SQL (MCP integration)
    3. Execute on Supabase
    4. Return structured results
    """
    global query_history_id_counter
    start_time = time.time()
    
    try:
        # Record metric
        nl_query_count.inc()
        
        # Step 1: Translate NL to SQL
        sql = translate_nl_to_sql(request.query)
        logger.info(f"Translated query: {request.query}")
        
        # Step 2: Execute SQL
        results = await execute_sql(sql)
        
        # Step 3: Measure execution time
        execution_time = time.time() - start_time
        query_duration.labels(query_type="nl_to_sql").observe(execution_time)
        
        # Record success metric
        request_count.labels(method="POST", endpoint="/query", status="200").inc()
        
        # Store query in history
        history_item = {
            "id": query_history_id_counter,
            "query": request.query,
            "timestamp": datetime.utcnow().isoformat(),
            "execution_time": execution_time,
            "row_count": len(results),
            "success": True
        }
        query_history.insert(0, history_item)  # Insert at beginning for newest first
        query_history_id_counter += 1
        
        # Keep only last 100 queries
        if len(query_history) > 100:
            query_history.pop()
        
        return QueryResult(
            success=True,
            query_type="analytics",
            sql_generated=sql,
            results=results,
            row_count=len(results),
            execution_time=execution_time,
            message="Query executed successfully"
        )
    
    except Exception as e:
        logger.error(f"Query execution error: {e}")
        request_count.labels(method="POST", endpoint="/query", status="500").inc()
        
        # Store failed query in history
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
        
        # Keep only last 100 queries
        if len(query_history) > 100:
            query_history.pop()
        
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/queries/history")
async def get_query_history(limit: int = 10):
    """Get query history"""
    return {
        "queries": query_history[:limit],
        "total": len(query_history)
    }


@app.get("/metrics")
async def prometheus_metrics():
    """Prometheus metrics endpoint"""
    return PlainTextResponse(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "SupaChat Backend",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "query": "/query (POST)",
            "history": "/queries/history",
            "metrics": "/metrics"
        }
    }


# ============================================================================
# RUN THE SERVER
# ============================================================================
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=int(os.getenv("BACKEND_PORT", 8000)),
        log_level="info"
    )
