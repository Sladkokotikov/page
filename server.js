const express = require('express');
const path = require('path');
const app = express();
const PORT = process.env.PORT || 3000;

// Set the required CORS headers
app.use((req, res, next) => {
  res.header('Cross-Origin-Opener-Policy', 'same-origin');
  res.header('Cross-Origin-Embedder-Policy', 'require-corp');
  next();
});

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});