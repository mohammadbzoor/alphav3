import mysql from 'mysql2/promise';
import { env } from './env';

export const db = mysql.createPool({
  host: env.dbHost,
  port: env.dbPort,
  user: env.dbUser,
  password: env.dbPass,
  database: env.dbName,

  waitForConnections: true,
  connectionLimit: env.dbConnectionLimit,
  queueLimit: 0,

  charset: 'utf8mb4',
});