'use client'

import React, { useState, useEffect } from 'react'
import axios from 'axios'
import { getApiBaseUrl } from '../lib/api'

interface QueryHistoryItem {
  id: number
  query: string
  timestamp: string
  execution_time: number
  row_count: number
  success: boolean
}

interface QueryHistoryResponse {
  queries: QueryHistoryItem[]
  total: number
}

interface QueryHistoryProps {
  onSelectQuery: (query: string) => void
}

export default function QueryHistory({ onSelectQuery }: QueryHistoryProps) {
  const [history, setHistory] = useState<QueryHistoryItem[]>([])
  const [loading, setLoading] = useState(false)
  const [expanded, setExpanded] = useState(false)

  const fetchHistory = async () => {
    setLoading(true)
    try {
      const apiUrl = getApiBaseUrl()
      const response = await axios.get<QueryHistoryResponse>(`${apiUrl}/queries/history?limit=20`)
      setHistory(response.data.queries)
    } catch (error) {
      console.error('Failed to fetch query history:', error)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchHistory()
  }, [])

  const formatTimestamp = (timestamp: string) => {
    return new Date(timestamp).toLocaleString()
  }

  const handleQueryClick = (query: string) => {
    onSelectQuery(query)
  }

  return (
    <div className="card">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-semibold">📚 Query History</h3>
        <button
          onClick={fetchHistory}
          disabled={loading}
          className="text-sm text-blue-600 hover:text-blue-800 disabled:opacity-50"
        >
          {loading ? '🔄' : '↻'} Refresh
        </button>
      </div>

      {history.length === 0 ? (
        <p className="text-gray-500 text-sm">No queries yet. Start asking questions!</p>
      ) : (
        <div className="space-y-2">
          {history.slice(0, expanded ? history.length : 5).map((item) => (
            <div
              key={item.id}
              className={`p-3 rounded-lg border cursor-pointer transition-colors ${
                item.success
                  ? 'border-gray-200 hover:border-blue-300 hover:bg-blue-50'
                  : 'border-red-200 hover:border-red-300 hover:bg-red-50'
              }`}
              onClick={() => handleQueryClick(item.query)}
            >
              <div className="flex items-start justify-between">
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-900 truncate">
                    {item.query}
                  </p>
                  <div className="flex items-center space-x-2 mt-1 text-xs text-gray-500">
                    <span>{formatTimestamp(item.timestamp)}</span>
                    <span>•</span>
                    <span>{item.execution_time.toFixed(2)}s</span>
                    <span>•</span>
                    <span>{item.row_count} rows</span>
                    {!item.success && (
                      <>
                        <span>•</span>
                        <span className="text-red-500">Failed</span>
                      </>
                    )}
                  </div>
                </div>
                <div className="ml-2">
                  {item.success ? (
                    <span className="text-green-500 text-sm">✓</span>
                  ) : (
                    <span className="text-red-500 text-sm">✗</span>
                  )}
                </div>
              </div>
            </div>
          ))}

          {history.length > 5 && (
            <button
              onClick={() => setExpanded(!expanded)}
              className="w-full text-sm text-blue-600 hover:text-blue-800 py-2"
            >
              {expanded ? 'Show Less' : `Show ${history.length - 5} More`}
            </button>
          )}
        </div>
      )}
    </div>
  )
}
