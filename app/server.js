const express = require('express');
const mysql = require('mysql2/promise');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 80;

const dbConfig = {
  host: process.env.DB_HOST,
  user: process.env.DB_USER || 'admin',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'appdb',
  connectTimeout: 5000,
};

let pool;
if (dbConfig.host) {
  pool = mysql.createPool(dbConfig);
}

app.use(express.json());

// Used by the ALB target group health check. Must respond fast and
// must NOT depend on the database, otherwise a slow DB takes down
// otherwise-healthy instances.
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', instance: os.hostname() });
});

app.get('/', (req, res) => {
  res.status(200).json({
    message: 'Scalable web app is running',
    instance: os.hostname(),
    timestamp: new Date().toISOString(),
  });
});

// Example API route that proves the app tier can reach the database.
app.get('/api/db-check', async (req, res) => {
  if (!pool) {
    return res.status(503).json({ status: 'error', message: 'DB_HOST not configured' });
  }
  try {
    const [rows] = await pool.query('SELECT 1 AS result');
    res.status(200).json({ status: 'ok', db_result: rows[0].result, instance: os.hostname() });
  } catch (err) {
    res.status(500).json({ status: 'error', message: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
