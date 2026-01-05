const JWT = require('jsonwebtoken');
const SECRET = process.env.JWT_SECRET || 'replace-me-in-prod';

function auth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader) return res.status(401).json({ error: 'Missing token' });

  const [, token] = authHeader.split(' ');
  try {
    const payload = JWT.verify(token, SECRET);
    req.user = payload;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}
module.exports = { auth };
