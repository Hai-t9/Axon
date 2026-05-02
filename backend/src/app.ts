import express from 'express';
import cors from 'cors';
import imageRoutes from './modules/image/image.routes';
import cleanerRoutes from './modules/cleaner/cleaner.routes';

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Register routes
app.use('/api', imageRoutes);
app.use('/api', cleanerRoutes);

// Healthcheck
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK' });
});

export default app;

