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

export default function ResultsDisplay({ data }: ResultsDisplayProps) {
  if (!data.results || data.results.length === 0) {
    return (
      <div className="card">
        <p className="text-gray-500">No results to display</p>
      </div>
    )
  }

  const columns = Object.keys(data.results[0])

  return (
    <div className="card">
      <h3 className="text-lg font-semibold mb-4">📊 Results Table</h3>
      
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b-2 border-gray-300">
              {columns.map((col) => (
                <th key={col} className="text-left py-2 px-3 font-semibold text-gray-700">
                  {col}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.results.map((row, idx) => (
              <tr key={idx} className="border-b border-gray-200 hover:bg-gray-50">
                {columns.map((col) => (
                  <td key={col} className="py-2 px-3 text-gray-700">
                    {typeof row[col] === 'number' ? row[col].toFixed(2) : String(row[col])}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="mt-4 pt-4 border-t border-gray-200 text-xs text-gray-600">
        <p>📈 {data.row_count} rows | ⏱️ {data.execution_time.toFixed(2)}s</p>
        <details className="mt-2">
          <summary className="cursor-pointer font-semibold">View SQL</summary>
          <pre className="mt-2 bg-gray-100 p-2 rounded text-xs overflow-auto max-h-32">
            {data.sql_generated}
          </pre>
        </details>
      </div>
    </div>
  )
}
