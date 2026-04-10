'use client'

import React, { useState } from 'react'

interface QueryInputProps {
  onSubmit: (query: string) => void
  disabled?: boolean
  selectedQuery?: string
}

export default function QueryInput({ onSubmit, disabled = false, selectedQuery }: QueryInputProps) {
  const [input, setInput] = useState('')

  // Update input when selectedQuery changes
  React.useEffect(() => {
    if (selectedQuery) {
      setInput(selectedQuery)
    }
  }, [selectedQuery])

  const handleSubmit = () => {
    if (input.trim()) {
      onSubmit(input)
      setInput('')
    }
  }

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey && !disabled) {
      e.preventDefault()
      handleSubmit()
    }
  }

  const suggestedQueries = [
    'Show top trending topics in last 30 days',
    'Compare article engagement by topic',
    'Plot daily views trend',
  ]

  return (
    <div className="space-y-3">
      <div className="flex gap-2">
        <textarea
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyPress={handleKeyPress}
          placeholder="Ask me anything about your analytics... (Press Enter to send)"
          disabled={disabled}
          className="flex-1 p-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none"
          rows={3}
        />
        <button
          onClick={handleSubmit}
          disabled={disabled || !input.trim()}
          className="btn btn-primary self-end h-12"
        >
          Send
        </button>
      </div>

      <div className="text-sm text-gray-600">
        <p className="font-semibold mb-2">💡 Try asking:</p>
        <div className="flex flex-wrap gap-2">
          {suggestedQueries.map((q, idx) => (
            <button
              key={idx}
              onClick={() => {
                setInput(q)
              }}
              className="text-xs bg-gray-100 hover:bg-gray-200 px-3 py-1 rounded-full transition"
            >
              {q}
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}
