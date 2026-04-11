'use client'

import React from 'react'
import {
  BarChart, Bar, LineChart, Line, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer
} from 'recharts'

interface ChartsPanelProps {
  data: {
    results: Array<Record<string, any>>
    sql_generated?: string
  }
}

const COLORS = ['#3B82F6', '#8B5CF6', '#EC4899', '#F59E0B', '#10B981', '#EF4444']

function detectChartType(results: Array<Record<string, any>>, sql: string): 'line' | 'pie' | 'bar' {
  const sqlLower = (sql || '').toLowerCase()
  const keys = Object.keys(results[0] || {})

  // Time-series data → line chart
  if (keys.some(k => k === 'date' || k === 'day' || k.includes('daily'))) return 'line'
  if (sqlLower.includes('date(') || sqlLower.includes('group by date')) return 'line'

  // Topic distribution → pie chart (few categories, one numeric)
  const numericKeys = keys.filter(k => typeof results[0][k] === 'number')
  const stringKeys = keys.filter(k => typeof results[0][k] === 'string')
  if (stringKeys.length === 1 && numericKeys.length === 1 && results.length <= 8) return 'pie'

  // Default: bar chart
  return 'bar'
}

export default function ChartsPanel({ data }: ChartsPanelProps) {
  if (!data.results || data.results.length === 0) return null

  const firstRow = data.results[0]
  const numericKeys = Object.keys(firstRow).filter(k => typeof firstRow[k] === 'number')
  const labelKey = Object.keys(firstRow).find(k => typeof firstRow[k] === 'string') || Object.keys(firstRow)[0]

  if (numericKeys.length === 0) return null

  const chartType = detectChartType(data.results, data.sql_generated || '')

  const renderChart = () => {
    if (chartType === 'line') {
      return (
        <ResponsiveContainer width="100%" height={280}>
          <LineChart data={data.results} margin={{ top: 5, right: 20, bottom: 60, left: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey={labelKey} angle={-35} textAnchor="end" tick={{ fontSize: 11 }} />
            <YAxis tick={{ fontSize: 11 }} />
            <Tooltip />
            <Legend />
            {numericKeys.map((key, idx) => (
              <Line
                key={key}
                type="monotone"
                dataKey={key}
                stroke={COLORS[idx % COLORS.length]}
                strokeWidth={2}
                dot={{ r: 4 }}
              />
            ))}
          </LineChart>
        </ResponsiveContainer>
      )
    }

    if (chartType === 'pie') {
      return (
        <ResponsiveContainer width="100%" height={280}>
          <PieChart>
            <Pie
              data={data.results}
              dataKey={numericKeys[0]}
              nameKey={labelKey}
              cx="50%"
              cy="50%"
              outerRadius={100}
              label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
              labelLine={true}
            >
              {data.results.map((_, idx) => (
                <Cell key={`cell-${idx}`} fill={COLORS[idx % COLORS.length]} />
              ))}
            </Pie>
            <Tooltip formatter={(val: any) => typeof val === 'number' ? val.toLocaleString() : val} />
          </PieChart>
        </ResponsiveContainer>
      )
    }

    // Bar chart (default)
    return (
      <ResponsiveContainer width="100%" height={280}>
        <BarChart data={data.results} margin={{ top: 5, right: 20, bottom: 60, left: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey={labelKey} angle={-35} textAnchor="end" tick={{ fontSize: 11 }} />
          <YAxis tick={{ fontSize: 11 }} />
          <Tooltip formatter={(val: any) => typeof val === 'number' ? val.toLocaleString() : val} />
          <Legend />
          {numericKeys.map((key, idx) => (
            <Bar key={key} dataKey={key} fill={COLORS[idx % COLORS.length]} radius={[3, 3, 0, 0]} />
          ))}
        </BarChart>
      </ResponsiveContainer>
    )
  }

  const chartLabel = chartType === 'line' ? '📈 Trend Chart' : chartType === 'pie' ? '🥧 Distribution Chart' : '📊 Bar Chart'

  return (
    <div className="card">
      <h3 className="text-lg font-semibold mb-4">{chartLabel}</h3>
      {renderChart()}
    </div>
  )
}
