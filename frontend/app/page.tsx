'use client'

import React, { useState, useRef, useEffect } from 'react'
import ChatMessage from '../components/ChatMessage'
import QueryInput from '../components/QueryInput'
import ResultsDisplay from '../components/ResultsDisplay'
import ChartsPanel from '../components/ChartsPanel'
import QueryHistory from '../components/QueryHistory'
import Header from '../components/Header'
import axios from 'axios'
import { getApiBaseUrl } from '../lib/api'

interface Message {
  id: string
  content: string
  role: 'user' | 'assistant'
  timestamp: Date
  results?: QueryResponse
}

interface QueryResponse {
  success: boolean
  query_type: string
  sql_generated: string
  results: Array<Record<string, any>>
  row_count: number
  execution_time: number
  message?: string
}

export default function Home() {
  const [messages, setMessages] = useState<Message[]>([
    {
      id: '0',
      content: "👋 Hi! I'm SupaChat. Ask me questions about your blog analytics in natural language.\n\nTry: \"Show top trending topics\" or \"Compare article engagement by topic\"",
      role: 'assistant',
      timestamp: new Date(),
    }
  ])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const messagesEndRef = useRef<HTMLDivElement>(null)
  const [selectedResults, setSelectedResults] = useState<QueryResponse | null>(null)
  const [selectedQueryFromHistory, setSelectedQueryFromHistory] = useState<string>('')

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const handleQuery = async (userQuery: string) => {
    setError(null)
    setLoading(true)
    setSelectedQueryFromHistory('')

    const userMessage: Message = {
      id: Date.now().toString(),
      content: userQuery,
      role: 'user',
      timestamp: new Date(),
    }
    setMessages(prev => [...prev, userMessage])

    try {
      const apiUrl = getApiBaseUrl()
      const response = await axios.post<QueryResponse>(
        `${apiUrl}/query`,
        { query: userQuery },
        { timeout: 30000 }
      )
      const data = response.data
      const assistantMessage: Message = {
        id: (Date.now() + 1).toString(),
        content: `✅ Found **${data.row_count} results** in ${data.execution_time.toFixed(2)}s. Results and chart updated below.`,
        role: 'assistant',
        timestamp: new Date(),
        results: data,
      }
      setMessages(prev => [...prev, assistantMessage])
      setSelectedResults(data)
    } catch (err: any) {
      const errorMsg = err.response?.data?.detail || err.message || 'Failed to process query'
      setError(errorMsg)
      setMessages(prev => [...prev, {
        id: (Date.now() + 1).toString(),
        content: `⚠️ Error: ${errorMsg}`,
        role: 'assistant',
        timestamp: new Date(),
      }])
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-blue-950 to-indigo-900">
      <Header />

      <main className="container mx-auto px-4 py-6 space-y-6">
        {/* Top row: Chat + History */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Chat Panel */}
          <div className="lg:col-span-2 card flex flex-col" style={{ height: '520px' }}>
            <h2 className="text-lg font-bold text-gray-800 mb-3">💬 Chat</h2>
            <div className="flex-1 overflow-y-auto space-y-3 mb-4 pr-1">
              {messages.map((msg) => (
                <ChatMessage key={msg.id} message={msg} />
              ))}
              {loading && (
                <div className="flex items-center space-x-2 text-gray-500 text-sm">
                  <div className="spinner" style={{ width: '18px', height: '18px' }} />
                  <span>Translating to SQL and querying...</span>
                </div>
              )}
              <div ref={messagesEndRef} />
            </div>

            {error && (
              <div className="bg-red-50 border border-red-300 text-red-700 px-3 py-2 rounded text-sm mb-3">
                {error}
              </div>
            )}
            <QueryInput
              onSubmit={handleQuery}
              disabled={loading}
              selectedQuery={selectedQueryFromHistory}
            />
          </div>

          {/* Query History */}
          <div className="lg:col-span-1 overflow-y-auto" style={{ maxHeight: '520px' }}>
            <QueryHistory onSelectQuery={setSelectedQueryFromHistory} />
          </div>
        </div>

        {/* Bottom row: Results Table + Chart — full width, always visible */}
        {selectedResults && (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <ResultsDisplay data={selectedResults} />
            <ChartsPanel data={selectedResults} />
          </div>
        )}

        {!selectedResults && (
          <div className="card text-center py-12 text-gray-500">
            <p className="text-4xl mb-3">📊</p>
            <p className="text-lg font-medium">Results and charts will appear here</p>
            <p className="text-sm mt-1">Ask a question above to get started</p>
          </div>
        )}
      </main>
    </div>
  )
}
