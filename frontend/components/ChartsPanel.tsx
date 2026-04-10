'use client'

import React, { useMemo } from 'react'
import { BarChart, Bar, LineChart, Line, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts'

interface ChartsPanelProps {
  data: {
    results: Array<Record<string, any>>
  }
}

export default function ChartsPanel({ data }: ChartsPanelProps) {
  if (!data.results || data.results.length === 0) {
    return null
  }

  const COLORS = ['#3B82F6', '#8B5CF6', '#EC4899', '#F59E0B', '#10B981']

  // Detect chart type based on data
  const chartType = useMemo(() => {
    const firstRow = data.results[0]
    const keys = Object.keys(firstRow)

    // Count columns
    if (keys.length === 2) {
      const hasNumeric = keys.some(k => typeof firstRow[k] === 'number')
      if (hasNumeric) return 'bar'
    }

    if (keys.some(k => k.toLowerCase().includes('views') || k.toLowerCase().includes('engagement'))) {
      return 'line'
    }

    if (keys.some(k => k.toLowerCase().includes('topic'))) {
      return 'pie'
    }

    return 'bar'
  }, [data.results])

  const renderChart = () => {
    const firstRow = data.results[0]
    const dataKeys = Object.keys(firstRow).filter(k => typeof firstRow[k] === 'number')
    const labelKey = Object.keys(firstRow).find(k => typeof firstRow[k] === 'string') || Object.keys(firstRow)[0]

    if (chartType === 'line' && dataKeys.length > 0) {
      return (
        <ResponsiveContainer width="100%" height={250}>
          <LineChart data={data.results}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey={labelKey} angle={-45} textAnchor="end" height={80} />
            <YAxis />
            <Tooltip />
            <Legend />
            {dataKeys.map((key, idx) => (
              <Line key={key} type="monotone" dataKey={key} stroke={COLORS[idx]} />
            ))}
          </LineChart>
        </ResponsiveContainer>
      )
    }

    if (chartType === 'pie' && dataKeys.length > 0) {
      return (
        <ResponsiveContainer width="100%" height={250}>
          <PieChart>
            <Pie
              data={data.results}
              dataKey={dataKeys[0]}
              nameKey={labelKey}
              cx="50%"
              cy="50%"
              outerRadius={80}
              label
            >
              {data.results.map((_, idx) => (
                <Cell key={`cell-${idx}`} fill={COLORS[idx % COLORS.length]} />
              ))}
            </Pie>
            <Tooltip />
          </PieChart>
        </ResponsiveContainer>
      )
    }

    // Default: Bar chart
    if (dataKeys.length > 0) {
      return (
        <ResponsiveContainer width="100%" height={250}>
          <BarChart data={data.results}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey={labelKey} angle={-45} textAnchor="end" height={80} />
            <YAxis />
            <Tooltip />
            <Legend />
            {dataKeys.map((key, idx) => (
              <Bar key={key} dataKey={key} fill={COLORS[idx % COLORS.length]} />
            ))}
          </BarChart>
        </ResponsiveContainer>
      )
    }

    return <p className="text-gray-500 text-sm">No numeric data to display</p>
  }

  return (
    <div className="card">
      <h3 className="text-lg font-semibold mb-4">📈 Visualization</h3>
      {renderChart()}
    </div>
  )
}
