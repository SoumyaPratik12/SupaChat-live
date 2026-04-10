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
  results?: any
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
      content: '👋 Hi! I\'m SupaChat. Ask me questions about your blog analytics using natural language.',
      role: 'assistant',
      timestamp: new Date(),
    }
  ])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const messagesEndRef = useRef<HTMLDivElement>(null)
  const [selectedResults, setSelectedResults] = useState<any>(null)
  const [selectedQueryFromHistory, setSelectedQueryFromHistory] = useState<string>('')

  // Auto-scroll to bottom
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const handleQuery = async (userQuery: string) => {
    setError(null)
    setLoading(true)
    setSelectedQueryFromHistory('')  // Clear selected query from history

    // Add user message
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

      // Add assistant response
      const assistantMessage: Message = {
        id: (Date.now() + 1).toString(),
        content: `Found ${data.row_count} results in ${data.execution_time.toFixed(2)}s`,
        role: 'assistant',
        timestamp: new Date(),
        results: data,
      }
      setMessages(prev => [...prev, assistantMessage])
      setSelectedResults(data)
    } catch (err: any) {
      const errorMsg = err.response?.data?.detail || err.message || 'Failed to process query'
      setError(errorMsg)

      const errorMessage: Message = {
        id: (Date.now() + 1).toString(),
        content: `⚠️ Error: ${errorMsg}`,
        role: 'assistant',
        timestamp: new Date(),
      }
      setMessages(prev => [...prev, errorMessage])
    } finally {
      setLoading(false)
    }
  }

  const handleSelectQueryFromHistory = (query: string) => {
    setSelectedQueryFromHistory(query)
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <Header />
      
      <main className="container mx-auto py-6 grid grid-cols-1 lg:grid-cols-4 gap-6 h-screen overflow-hidden">
        {/* Chat Panel */}
        <div className="lg:col-span-2 card flex flex-col overflow-hidden">
          <div className="flex-1 overflow-y-auto mb-4 space-y-4">
            {messages.map((msg) => (
              <ChatMessage key={msg.id} message={msg} />
            ))}
            {loading && (
              <div className="flex items-center space-x-2 text-gray-500">
                <div className="spinner" style={{ width: '20px', height: '20px' }}></div>
                <span>Processing your query...</span>
              </div>
            )}
            <div ref={messagesEndRef} />
          </div>

          {error && (
            <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
              {error}
            </div>
          )}

          <QueryInput 
            onSubmit={handleQuery} 
            disabled={loading} 
            selectedQuery={selectedQueryFromHistory}
          />
        </div>

        {/* Query History Panel */}
        <div className="lg:col-span-1 overflow-y-auto">
          <QueryHistory onSelectQuery={handleSelectQueryFromHistory} />
        </div>

        {/* Results & Charts Panel */}
        <div className="lg:col-span-1 space-y-6 overflow-y-auto">
          {selectedResults && (
            <>
              <ResultsDisplay data={selectedResults} />
              <ChartsPanel data={selectedResults} />
            </>
          )}
        </div>
      </main>
    </div>
  )
}
