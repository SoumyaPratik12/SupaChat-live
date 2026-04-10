# 🧪 SupaChat - Complete Testing Guide

**Created**: April 10, 2026  
**Status**: Ready for Testing  
**Services**: Backend ✅ (http://localhost:8000), Frontend ✅ (http://localhost:3000)

---

## 🎯 TESTING OVERVIEW

This guide provides comprehensive test queries and procedures to validate all SupaChat functionality.

---

## 🔍 ENDPOINT TEST REFERENCE

### Available Test Endpoints

| Endpoint | Method | Purpose | Status |
|----------|--------|---------|--------|
| `/health` | GET | Health check | ✅ Live |
| `/query` | POST | Process NL queries | ✅ Live |
| `/queries/history` | GET | Get query history | ✅ Live |
| `/metrics` | GET | Prometheus metrics | ✅ Live |
| `/docs` | GET | Swagger UI | ✅ Live |
| `/redoc` | GET | ReDoc | ✅ Live |

---

## 📋 TEST QUERIES (Ready to Use)

### Query Category 1: Trending Topics

#### Query 1️⃣
```
"Show top trending topics in last 30 days"
```

**cURL Command**:
```bash
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Show top trending topics in last 30 days"}'
```

**Expected Response**:
```json
{
  "success": true,
  "query_type": "analytics",
  "sql_generated": "SELECT topic, COUNT(*) as article_count, SUM(views) as total_views, AVG(engagement_rate) as avg_engagement FROM articles WHERE published_date >= CURRENT_DATE - INTERVAL '30 days' GROUP BY topic ORDER BY total_views DESC LIMIT 10;",
  "results": [
    {"topic": "AI", "article_count": 15, "total_views": 5230, "avg_engagement": 0.78},
    {"topic": "DevOps", "article_count": 12, "total_views": 4120, "avg_engagement": 0.72},
    {"topic": "Web3", "article_count": 8, "total_views": 2950, "avg_engagement": 0.65}
  ],
  "row_count": 3,
  "execution_time": 0.52,
  "message": "Query executed successfully"
}
```

---

#### Query 2️⃣
```
"What are the trending topics"
```

**cURL Command**:
```bash
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"What are the trending topics"}'
```

**Expected Response**: Same as Query 1 (matches "trending" keyword)

---

#### Query 3️⃣
```
"List top topics"
```

**cURL Command**:
```bash
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"List top topics"}'
```

**Expected Response**: Same as Query 1 (matches "top topics" keyword)

---

### Query Category 2: Engagement Comparison

#### Query 4️⃣
```
"Compare article engagement by topic"
```

**cURL Command**:
```bash
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Compare article engagement by topic"}'
```

**Expected Response**:
```json
{
  "success": true,
  "query_type": "analytics",
  "sql_generated": "SELECT topic, COUNT(*) as article_count, AVG(views) as avg_views, AVG(engagement_rate) as avg_engagement, AVG(shares) as avg_shares FROM articles GROUP BY topic ORDER BY avg_engagement DESC;",
  "results": [
    {"topic": "AI", "article_count": 42, "avg_views": 185.3, "avg_engagement": 0.82, "avg_shares": 12.5},
    {"topic": "DevOps", "article_count": 38, "avg_views": 156.2, "avg_engagement": 0.75, "avg_shares": 9.8},
    {"topic": "Web3", "article_count": 25, "avg_views": 118.4, "avg_engagement": 0.68, "avg_shares": 7.2}
  ],
  "row_count": 3,
  "execution_time": 0.48,
  "message": "Query executed successfully"
}
```

---

#### Query 5️⃣
```
"Which topic has best engagement"
```

**cURL Command**:
```bash
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Which topic has best engagement"}'
```

**Expected Response**: Same as Query 4 (matches "compare" + "engagement")

---

#### Query 6️⃣
```
"Show engagement metrics by topic"
```

**cURL Command**:
```bash
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Show engagement metrics by topic"}'
```

**Expected Response**: Same as Query 4

---

### Query Category 3: Daily Views Trend

#### Query 7️⃣
```
"Plot daily views trend"
```

**cURL Command**:
```bash
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Plot daily views trend"}'
```

**Expected Response**:
```json
{
  "success": true,
  "query_type": "analytics",
  "sql_generated": "SELECT DATE(published_date) as date, SUM(views) as daily_views, COUNT(*) as article_count FROM articles GROUP BY DATE(published_date) ORDER BY date DESC LIMIT 30;",
  "results": [
    {"date": "2024-01-08", "daily_views": 1250, "article_count": 5},
    {"date": "2024-01-07", "daily_views": 980, "article_count": 4},
    {"date": "2024-01-06", "daily_views": 1520, "article_count": 6}
  ],
  "row_count": 3,
  "execution_time": 0.45,
  "message": "Query executed successfully"
}
```

---

#### Query 8️⃣
```
"Show daily views for last 30 days"
```

**cURL Command**:
```bash
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Show daily views for last 30 days"}'
```

**Expected Response**: Same as Query 7 (matches "daily" + "views")

---

#### Query 9️⃣
```
"What is the daily trend"
```

**cURL Command**:
```bash
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"What is the daily trend"}'
```

**Expected Response**: Same as Query 7

---

### Query Category 4: Performance Metrics

#### Query 🔟
```
"Show article performance metrics"
```

**cURL Command**:
```bash
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Show article performance metrics"}'
```

**Expected Response**:
```json
{
  "success": true,
  "query_type": "analytics",
  "sql_generated": "SELECT title, topic, views, engagement_rate, shares, published_date FROM articles ORDER BY views DESC LIMIT 20;",
  "results": [
    {"title": "AI Trends 2024", "topic": "AI", "views": 450, "engagement_rate": 0.85, "shares": 25, "published_date": "2024-01-08"},
    {"title": "DevOps Best Practices", "topic": "DevOps", "views": 320, "engagement_rate": 0.72, "shares": 18, "published_date": "2024-01-07"},
    {"title": "Web3 Fundamentals", "topic": "Web3", "views": 210, "engagement_rate": 0.68, "shares": 12, "published_date": "2024-01-06"}
  ],
  "row_count": 3,
  "execution_time": 0.51,
  "message": "Query executed successfully"
}
```

---

#### Query 1️⃣1️⃣
```
"What are the best performing articles"
```

**cURL Command**:
```bash
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"What are the best performing articles"}'
```

**Expected Response**: Same as Query 10 (matches "performance" or "metrics")

---

#### Query 1️⃣2️⃣
```
"List article metrics"
```

**cURL Command**:
```bash
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"List article metrics"}'
```

**Expected Response**: Same as Query 10

---

### Query Category 5: Fallback/Default

#### Query 1️⃣3️⃣
```
"Show me all articles"
```

**cURL Command**:
```bash
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Show me all articles"}'
```

**Expected Response** (Default fallback):
```json
{
  "success": true,
  "query_type": "analytics",
  "sql_generated": "SELECT id, title, topic, views, engagement_rate FROM articles LIMIT 10;",
  "results": [
    {"id": 1, "title": "AI Trends 2024", "topic": "AI", "views": 450, "engagement_rate": 0.85},
    {"id": 2, "title": "DevOps Best Practices", "topic": "DevOps", "views": 320, "engagement_rate": 0.72},
    {"id": 3, "title": "Web3 Fundamentals", "topic": "Web3", "views": 210, "engagement_rate": 0.68}
  ],
  "row_count": 3,
  "execution_time": 0.50,
  "message": "Query executed successfully"
}
```

---

#### Query 1️⃣4️⃣
```
"Random query that doesn't match any pattern"
```

**cURL Command**:
```bash
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Random query that doesn'"'"'t match any pattern"}'
```

**Expected Response**: Default fallback (same as Query 13)

---

## 🏥 HEALTH & SYSTEM ENDPOINTS

### Health Check
```bash
curl http://localhost:8000/health
```

**Expected Response**:
```json
{
  "status": "healthy",
  "database": "supabase-connected",
  "timestamp": "2026-04-10T08:30:45.123456",
  "version": "1.0.0"
}
```

---

### Query History
```bash
curl http://localhost:8000/queries/history?limit=10
```

**Expected Response**:
```json
{
  "queries": [
    {
      "id": 1,
      "query": "Show top trending topics in last 30 days",
      "timestamp": "2026-04-10T08:25:12.456789",
      "execution_time": 0.52,
      "row_count": 3,
      "success": true
    },
    {
      "id": 2,
      "query": "Compare article engagement by topic",
      "timestamp": "2026-04-10T08:24:45.123456",
      "execution_time": 0.48,
      "row_count": 3,
      "success": true
    }
  ],
  "total": 2
}
```

---

### Prometheus Metrics
```bash
curl http://localhost:8000/metrics
```

**Expected Response**: Prometheus format metrics
```
# HELP supachat_requests_total Total API requests
# TYPE supachat_requests_total counter
supachat_requests_total{endpoint="/query",method="POST",status="200"} 5.0

# HELP supachat_query_duration_seconds Query execution time
# TYPE supachat_query_duration_seconds histogram
supachat_query_duration_seconds_bucket{query_type="nl_to_sql",le="0.005"} 0.0
```

---

### API Documentation
```bash
# Swagger UI
curl http://localhost:8000/docs

# ReDoc
curl http://localhost:8000/redoc
```

---

## 🌐 WEB UI TESTING

### Access Frontend
```
URL: http://localhost:3000
```

### Testing Steps:

1. **Open Application**
   - Navigate to http://localhost:3000
   - See the chat interface with greeting message

2. **Use Query Suggestions**
   - Click on suggested queries at the bottom
   - Examples:
     - "Show top trending topics in last 30 days"
     - "Compare article engagement by topic"
     - "Plot daily views trend"

3. **Type Custom Query**
   - Click in the textarea at the bottom
   - Type any of the test queries above
   - Press Enter or click "Send" button

4. **View Results**
   - Results appear as:
     - Chat message with summary
     - Data table in results panel
     - Interactive chart in visualization panel

5. **Use Query History**
   - Click on any previous query in the Query History panel (left side)
   - Query is populated in the input field
   - Execute to re-run

6. **Test Error Handling**
   - Try malformed queries
   - Observe error messages in red banner

---

## 🔧 TESTING METHOD OPTIONS

### Option 1: Using cURL (Command Line)

**Best for**: Quick API testing, CI/CD, automation

**Setup**:
```bash
# No additional setup needed
# Just copy-paste cURL commands
```

**Example**:
```bash
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Show trending topics"}'
```

---

### Option 2: Using Swagger UI

**Best for**: Interactive API exploration

**Access**:
```
http://localhost:8000/docs
```

**Steps**:
1. Navigate to http://localhost:8000/docs
2. Find "POST /query" endpoint
3. Click "Try it out"
4. Enter query in request body:
   ```json
   {
     "query": "Show trending topics"
   }
   ```
5. Click "Execute"
6. View response below

---

### Option 3: Using Postman

**Best for**: Complete REST API testing, collections

**Setup**:
1. Download Postman from postman.com
2. Create new request
3. Set method to POST
4. URL: `http://localhost:8000/query`
5. Set header: `Content-Type: application/json`
6. Set body (raw JSON):
   ```json
   {
     "query": "Show trending topics"
   }
   ```
7. Click Send

---

### Option 4: Using VS Code REST Client

**Best for**: Quick testing with IDE integration

**Install**: 
- Install "REST Client" extension

**Create file**: `test.http`
```http
### Health Check
GET http://localhost:8000/health

### Query 1: Trending Topics
POST http://localhost:8000/query
Content-Type: application/json

{
  "query": "Show top trending topics in last 30 days"
}

### Query 2: Engagement Comparison
POST http://localhost:8000/query
Content-Type: application/json

{
  "query": "Compare article engagement by topic"
}
```

**Run**: Click "Send Request" above each request

---

### Option 5: Using Frontend UI

**Best for**: End-to-end testing, user experience

**Access**: http://localhost:3000

**Features**:
- Type or click suggested queries
- View results in real-time
- Browse query history
- Interactive charts

---

## 📊 TEST SCENARIOS

### Scenario 1: Basic Query Execution
```bash
# Test 1
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Show trending topics"}'

# Verify:
# ✅ Response status 200
# ✅ success: true
# ✅ results array not empty
# ✅ execution_time > 0
```

---

### Scenario 2: Query History
```bash
# Run a query first
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Show trending topics"}'

# Then check history
curl http://localhost:8000/queries/history?limit=5

# Verify:
# ✅ Most recent query appears first
# ✅ Includes timestamp
# ✅ Includes execution_time
# ✅ success field is true
```

---

### Scenario 3: Multiple Queries
```bash
# Run Query 1
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Show trending topics"}'

# Run Query 2
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Compare article engagement by topic"}'

# Run Query 3
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Plot daily views trend"}'

# Check history
curl http://localhost:8000/queries/history?limit=10

# Verify:
# ✅ All 3 queries in history
# ✅ Listed in reverse order (newest first)
# ✅ Each has unique ID
```

---

### Scenario 4: Error Handling
```bash
# Test missing query field
curl -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{}'

# Verify:
# ✅ Response status 422 (validation error)
# ✅ Error message about missing field
```

---

### Scenario 5: Metrics & Monitoring
```bash
# Get metrics
curl http://localhost:8000/metrics

# Verify:
# ✅ Contains supachat_requests_total metric
# ✅ Contains supachat_query_duration_seconds metric
# ✅ Contains supachat_nl_queries_total metric
```

---

## 📋 TEST CHECKLIST

### Backend API Tests
- [ ] Health endpoint responds (GET /health)
- [ ] Query endpoint accepts query (POST /query)
- [ ] Query results returned
- [ ] Trending topics query works
- [ ] Engagement comparison works
- [ ] Daily views trend works
- [ ] Performance metrics work
- [ ] Fallback query works
- [ ] Query history tracked (GET /queries/history)
- [ ] Metrics available (GET /metrics)
- [ ] API docs available (GET /docs)
- [ ] ReDoc available (GET /redoc)

### Frontend UI Tests
- [ ] Frontend accessible (http://localhost:3000)
- [ ] Chat interface renders
- [ ] Query suggestions visible
- [ ] Can type custom query
- [ ] Query sends on Enter key
- [ ] Query sends on Send button
- [ ] Results display in chat
- [ ] Results table appears
- [ ] Charts render correctly
- [ ] Query history panel visible
- [ ] Can click history to reuse query
- [ ] Error messages display properly
- [ ] Loading state shows

### Performance Tests
- [ ] Response time < 1 second
- [ ] Charts render smoothly
- [ ] No console errors
- [ ] Memory usage stable
- [ ] CPU usage normal

### Data Tests
- [ ] Results have correct structure
- [ ] Timestamps are valid
- [ ] Metrics are numbers
- [ ] Row counts accurate
- [ ] Engagement rates between 0-1

---

## 🚀 QUICK TEST BASH SCRIPT

**Create file**: `test_queries.sh`

```bash
#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== SupaChat API Test Suite ===${NC}\n"

# Test 1: Health Check
echo -e "${YELLOW}Test 1: Health Check${NC}"
curl -s http://localhost:8000/health | jq . && echo -e "${GREEN}✅ PASS${NC}\n" || echo -e "${RED}❌ FAIL${NC}\n"

# Test 2: Trending Topics
echo -e "${YELLOW}Test 2: Trending Topics Query${NC}"
curl -s -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Show trending topics"}' | jq . && echo -e "${GREEN}✅ PASS${NC}\n" || echo -e "${RED}❌ FAIL${NC}\n"

# Test 3: Engagement Comparison
echo -e "${YELLOW}Test 3: Engagement Comparison${NC}"
curl -s -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Compare engagement by topic"}' | jq . && echo -e "${GREEN}✅ PASS${NC}\n" || echo -e "${RED}❌ FAIL${NC}\n"

# Test 4: Daily Views
echo -e "${YELLOW}Test 4: Daily Views Trend${NC}"
curl -s -X POST http://localhost:8000/query \
  -H "Content-Type: application/json" \
  -d '{"query":"Plot daily views"}' | jq . && echo -e "${GREEN}✅ PASS${NC}\n" || echo -e "${RED}❌ FAIL${NC}\n"

# Test 5: Query History
echo -e "${YELLOW}Test 5: Query History${NC}"
curl -s http://localhost:8000/queries/history?limit=5 | jq . && echo -e "${GREEN}✅ PASS${NC}\n" || echo -e "${RED}❌ FAIL${NC}\n"

# Test 6: Metrics
echo -e "${YELLOW}Test 6: Prometheus Metrics${NC}"
curl -s http://localhost:8000/metrics | head -20 && echo -e "${GREEN}✅ PASS${NC}\n" || echo -e "${RED}❌ FAIL${NC}\n"

echo -e "${GREEN}=== Test Suite Complete ===${NC}"
```

**Run it**:
```bash
bash test_queries.sh
```

---

## 📈 EXPECTED RESULTS SUMMARY

| Query | Type | Expected Rows | Chart Type |
|-------|------|---------------|-----------|
| Trending Topics | Object | 3+ | Bar Chart |
| Engagement Comparison | Object | 3+ | Bar Chart |
| Daily Views | Time Series | 3+ | Line Chart |
| Performance Metrics | List | 3+ | Table |
| Default Fallback | List | 3+ | Table |

---

## ✅ SUCCESS CRITERIA

✅ **All tests PASS if**:
1. Health endpoint responds with 200 OK
2. Query endpoint accepts POST requests
3. Responses include success: true
4. Results array contains data
5. Execution time is measured
6. Query history tracks queries
7. Metrics are exported
8. Frontend UI is accessible
9. Charts render without errors
10. No console errors

---

## 📞 TROUBLESHOOTING TESTS

### If tests fail, check:

**Backend not running?**
```bash
ps aux | grep python
# Should show: python main.py

# Start if needed:
cd backend && python main.py
```

**Frontend not running?**
```bash
ps aux | grep "next dev"
# Should show: npm run dev

# Start if needed:
cd frontend && npm run dev
```

**Port in use?**
```bash
# Check port 8000
lsof -i :8000

# Check port 3000
lsof -i :3000
```

**Connection refused?**
```bash
# Test connectivity
curl -v http://localhost:8000/health
# Should see "Connected to localhost"
```

---

**Test Suite Created**: April 10, 2026  
**Status**: Ready for Testing  
**Services**: Online and Responding ✅

