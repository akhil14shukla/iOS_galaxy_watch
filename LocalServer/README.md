# Local Health Data Sync Server

This is a reference implementation of a local server for the Galaxy Watch iOS Hybrid Sync system.

## Overview

The local server acts as the primary data transport layer, providing efficient HTTP-based synchronization between the Galaxy Watch (Wear OS) and iPhone (iOS) when both devices are on the same local network.

## API Specification

### Base URL

```
http://[LOCAL_IP]:8080/api/v1
```

### Endpoints

#### 1. Health Check

**GET** `/health`

Returns server status and version information.

**Response:**

```json
{
  "status": "ok",
  "version": "1.0.0",
  "timestamp": "2025-07-26T10:00:00Z"
}
```

#### 2. Upload Health Data

**POST** `/data`

Upload health data batch from Galaxy Watch.

**Request Body:**

```json
{
  "id": "batch-uuid",
  "timestamp": "2025-07-26T10:00:00Z",
  "heartRateData": [
    {
      "id": "hr-uuid",
      "timestamp": "2025-07-26T10:00:00Z",
      "value": 75.5,
      "confidence": 0.95
    }
  ],
  "stepCountData": [
    {
      "id": "step-uuid",
      "timestamp": "2025-07-26T10:00:00Z",
      "count": 1000,
      "duration": 3600
    }
  ],
  "sleepData": [
    {
      "id": "sleep-uuid",
      "timestamp": "2025-07-26T09:00:00Z",
      "startTime": "2025-07-26T01:00:00Z",
      "endTime": "2025-07-26T09:00:00Z",
      "stages": [
        {
          "stage": "LIGHT",
          "startTime": "2025-07-26T01:00:00Z",
          "endTime": "2025-07-26T02:00:00Z"
        }
      ]
    }
  ],
  "workoutData": [
    {
      "id": "workout-uuid",
      "timestamp": "2025-07-26T10:00:00Z",
      "type": "RUNNING",
      "startTime": "2025-07-26T09:00:00Z",
      "endTime": "2025-07-26T10:00:00Z",
      "duration": 3600,
      "totalDistance": 5000,
      "totalCalories": 400,
      "averageHeartRate": 145,
      "maxHeartRate": 165,
      "route": [
        {
          "latitude": 37.7749,
          "longitude": -122.4194,
          "altitude": 100,
          "timestamp": "2025-07-26T09:00:00Z",
          "speed": 2.5,
          "accuracy": 5.0
        }
      ]
    }
  ]
}
```

**Response:**

```json
{
  "status": "success",
  "message": "Data saved successfully",
  "processedCount": 42,
  "timestamp": "2025-07-26T10:00:05Z"
}
```

**Error Response:**

```json
{
  "status": "error",
  "message": "Invalid data format",
  "details": "Missing required field: timestamp",
  "timestamp": "2025-07-26T10:00:05Z"
}
```

#### 3. Fetch Health Data

**GET** `/data?since={timestamp}`

Fetch health data updates since the specified timestamp.

**Query Parameters:**

- `since`: ISO 8601 timestamp (required)
- `limit`: Maximum number of records to return (optional, default: 1000)
- `types`: Comma-separated list of data types to include (optional)

**Example:**

```
GET /data?since=2025-07-26T09:00:00Z&limit=500&types=heartRate,stepCount
```

**Response:**

```json
{
  "id": "fetch-batch-uuid",
  "timestamp": "2025-07-26T10:00:00Z",
  "heartRateData": [...],
  "stepCountData": [...],
  "sleepData": [...],
  "workoutData": [...],
  "hasMore": false,
  "nextCursor": null
}
```

## Implementation Notes

### Data Storage

- Use in-memory storage for simplicity (Redis recommended for production)
- Implement data deduplication based on ID fields
- Support timestamp-based querying for efficient sync

### Error Handling

- Return appropriate HTTP status codes
- Provide detailed error messages for debugging
- Handle malformed JSON gracefully

### Performance

- Implement request throttling to prevent abuse
- Support compression for large data transfers
- Add request timeout handling

## Sample Node.js Implementation

```javascript
const express = require("express");
const cors = require("cors");
const { v4: uuidv4 } = require("uuid");

const app = express();
const PORT = 8080;

// Middleware
app.use(cors());
app.use(express.json({ limit: "10mb" }));

// In-memory data store
let healthDataStore = {
  heartRateData: [],
  stepCountData: [],
  sleepData: [],
  workoutData: [],
};

// Health check endpoint
app.get("/api/v1/health", (req, res) => {
  res.json({
    status: "ok",
    version: "1.0.0",
    timestamp: new Date().toISOString(),
  });
});

// Upload health data
app.post("/api/v1/data", (req, res) => {
  try {
    const batch = req.body;

    // Validate required fields
    if (!batch.id || !batch.timestamp) {
      return res.status(400).json({
        status: "error",
        message: "Missing required fields",
        timestamp: new Date().toISOString(),
      });
    }

    let processedCount = 0;

    // Process each data type
    if (batch.heartRateData) {
      healthDataStore.heartRateData.push(...batch.heartRateData);
      processedCount += batch.heartRateData.length;
    }

    if (batch.stepCountData) {
      healthDataStore.stepCountData.push(...batch.stepCountData);
      processedCount += batch.stepCountData.length;
    }

    if (batch.sleepData) {
      healthDataStore.sleepData.push(...batch.sleepData);
      processedCount += batch.sleepData.length;
    }

    if (batch.workoutData) {
      healthDataStore.workoutData.push(...batch.workoutData);
      processedCount += batch.workoutData.length;
    }

    // Sort all arrays by timestamp for efficient querying
    Object.keys(healthDataStore).forEach((key) => {
      healthDataStore[key].sort(
        (a, b) => new Date(a.timestamp) - new Date(b.timestamp)
      );
    });

    res.json({
      status: "success",
      message: "Data saved successfully",
      processedCount,
      timestamp: new Date().toISOString(),
    });

    console.log(`Saved ${processedCount} health data points`);
  } catch (error) {
    console.error("Error saving data:", error);
    res.status(500).json({
      status: "error",
      message: "Internal server error",
      timestamp: new Date().toISOString(),
    });
  }
});

// Fetch health data
app.get("/api/v1/data", (req, res) => {
  try {
    const { since, limit = 1000, types } = req.query;

    if (!since) {
      return res.status(400).json({
        status: "error",
        message: "Missing required parameter: since",
        timestamp: new Date().toISOString(),
      });
    }

    const sinceDate = new Date(since);
    const requestedTypes = types
      ? types.split(",")
      : ["heartRate", "stepCount", "sleep", "workout"];

    const result = {
      id: uuidv4(),
      timestamp: new Date().toISOString(),
      heartRateData: [],
      stepCountData: [],
      sleepData: [],
      workoutData: [],
    };

    // Filter data by timestamp and type
    if (requestedTypes.includes("heartRate")) {
      result.heartRateData = healthDataStore.heartRateData
        .filter((item) => new Date(item.timestamp) > sinceDate)
        .slice(0, limit);
    }

    if (requestedTypes.includes("stepCount")) {
      result.stepCountData = healthDataStore.stepCountData
        .filter((item) => new Date(item.timestamp) > sinceDate)
        .slice(0, limit);
    }

    if (requestedTypes.includes("sleep")) {
      result.sleepData = healthDataStore.sleepData
        .filter((item) => new Date(item.timestamp) > sinceDate)
        .slice(0, limit);
    }

    if (requestedTypes.includes("workout")) {
      result.workoutData = healthDataStore.workoutData
        .filter((item) => new Date(item.timestamp) > sinceDate)
        .slice(0, limit);
    }

    result.hasMore = false; // Simplified for this implementation
    result.nextCursor = null;

    res.json(result);

    const totalItems =
      result.heartRateData.length +
      result.stepCountData.length +
      result.sleepData.length +
      result.workoutData.length;
    console.log(`Fetched ${totalItems} health data points since ${since}`);
  } catch (error) {
    console.error("Error fetching data:", error);
    res.status(500).json({
      status: "error",
      message: "Internal server error",
      timestamp: new Date().toISOString(),
    });
  }
});

// Start server
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Health data sync server running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/api/v1/health`);
});

module.exports = app;
```

## Setup Instructions

### Prerequisites

- Node.js 16+ installed
- Network connectivity between devices

### Installation

```bash
npm init -y
npm install express cors uuid
```

### Running the Server

```bash
node server.js
```

### Configuration

1. **Find Local IP Address:**

   ```bash
   # On macOS/Linux
   ifconfig | grep "inet 192"

   # On Windows
   ipconfig | findstr "IPv4"
   ```

2. **Update iOS App:**
   Configure the server address in the iOS app settings to match your local IP.

3. **Firewall Configuration:**
   Ensure port 8080 is open on the server machine.

## Testing

### Manual Testing

```bash
# Health check
curl http://192.168.1.100:8080/api/v1/health

# Upload test data
curl -X POST http://192.168.1.100:8080/api/v1/data \
  -H "Content-Type: application/json" \
  -d '{"id":"test","timestamp":"2025-07-26T10:00:00Z","heartRateData":[{"id":"hr1","timestamp":"2025-07-26T10:00:00Z","value":75}]}'

# Fetch data
curl "http://192.168.1.100:8080/api/v1/data?since=2025-07-26T09:00:00Z"
```

### Automated Testing

The iOS app includes comprehensive tests for the hybrid sync system. Run the tests in Xcode to verify the integration.

## Security Considerations

- **Local Network Only:** Server should only accept connections from local network
- **No Authentication:** Suitable for trusted local networks only
- **Data Validation:** Always validate incoming data structure
- **Rate Limiting:** Implement request throttling for production use

## Production Enhancements

- Add persistent storage (SQLite/PostgreSQL)
- Implement data encryption
- Add user authentication
- Support multiple device pairing
- Add data compression
- Implement automatic backup/restore
