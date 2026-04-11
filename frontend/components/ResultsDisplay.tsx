'use client'

import React from 'react'

interface ResultsDisplayProps {
  data: {
    success: boolean
    sql_generated: string
    results: Array<Record<string, any>>
    row_count: number
    execution_time: number
  }
}

function formatCell(value: any): string {
  if (value === null || value === undefined) return '—'
  if (typeof value === 'number') {
    // Integer: no decimals. Float: up to 2 decimals, strip trailing zeros
    return Number.isInteger(value) ? value.toLocaleString() : parseFloat(value.toFixed(2)).toString()
  }
  return String(value)
}

export default function ResultsDisplay({ data }: ResultsDisplayProps) {
  if (!data.results || data.results.length === 0) {
    return (
      <div className="card">
        <h3 className="text-lg font-semibold mb-2">📋 Results</h3>
        <p className="text-gray-500 text-sm">No results returned.</p>
      </div>
    )
  }

  const columns = Object.keys(data.results[0])

  return (
    <div className="card">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-semibold">📋 Results Table</h3>
        <span className="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded">
          {data.row_count} rows · {data.execution_time.toFixed(2)}s
        </span>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="bg-gray-50 border-b-2 border-gray-200">
              {columns.map((col) => (
                <th key={col} className="text-left py-2 px-3 font-semibold text-gray-700 whitespace-nowrap">
                  {col.replace(/_/g, ' ')}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.results.map((row, idx) => (
              <tr key={idx} className={`border-b border-gray-100 hover:bg-blue-50 transition-colors ${idx % 2 === 0 ? '' : 'bg-gray-50/50'}`}>
                {columns.map((col) => (
                  <td key={col} className="py-2 px-3 text-gray-700">
                    {formatCell(row[col])}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <details className="mt-4 pt-3 border-t border-gray-100">
        <summary className="cursor-pointer text-xs font-semibold text-gray-500 hover:text-gray-700">
          🔍 View Generated SQL
        </summary>
        <pre className="mt-2 bg-gray-900 text-green-400 p-3 rounded text-xs overflow-auto max-h-40 leading-relaxed">
          {data.sql_generated.trim()}
        </pre>
      </details>
    </div>
  )
}
