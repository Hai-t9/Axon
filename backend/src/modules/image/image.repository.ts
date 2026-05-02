import { ImageRecord, CreateImageDTO } from './image.interface';

// Mock in-memory database for now
const db: ImageRecord[] = [];
let currentId = 1;

export class ImageRepository {
  async create(data: CreateImageDTO): Promise<ImageRecord> {
    const newImage: ImageRecord = {
      id: currentId++,
      time: new Date(),
      ...data,
      status: 'onhold', // default status
    };
    db.push(newImage);
    return newImage;
  }

  async findById(imageId: number): Promise<ImageRecord | null> {
    return db.find(img => img.id === imageId) || null;
  }

  async findByHash(hash: string): Promise<ImageRecord | null> {
    return db.find(img => img.image_hash === hash) || null;
  }

  async findByTeam(teamId: number, status?: string, page: number = 1): Promise<{ images: ImageRecord[], total: number }> {
    let images = db.filter(img => img.team_id === teamId);
    if (status) {
      images = images.filter(img => img.status === status);
    }
    const limit = 10;
    const total = images.length;
    const paginated = images.slice((page - 1) * limit, page * limit);
    return { images: paginated, total };
  }

  async findByCompetition(compId: number, status?: string): Promise<{ images: ImageRecord[], total: number }> {
    // Note: Assuming team_id is linked to compId indirectly, mock returns all for now unless schema refines it
    let images = db;
    if (status) {
      images = images.filter(img => img.status === status);
    }
    return { images, total: images.length };
  }

  async findByStatus(status: string): Promise<ImageRecord[]> {
    return db.filter(img => img.status === status);
  }

  async updateStatus(imageId: number, status: 'onhold' | 'verified'): Promise<ImageRecord | null> {
    const image = await this.findById(imageId);
    if (image) {
      image.status = status;
      return image;
    }
    return null;
  }

  async delete(imageId: number): Promise<boolean> {
    const index = db.findIndex(img => img.id === imageId);
    if (index !== -1) {
      db.splice(index, 1);
      return true;
    }
    return false;
  }

  async countByTeam(teamId: number): Promise<number> {
    return db.filter(img => img.team_id === teamId).length;
  }

  async countByStatus(status: string): Promise<number> {
    return db.filter(img => img.status === status).length;
  }

  async getStats(compId: number) {
    const total = db.length;
    const verified = db.filter(i => i.status === 'verified').length;
    const onhold = total - verified;
    return {
      total,
      by_status: { onhold, verified },
      // Mocked aggregation
      by_team: [],
      by_label: []
    };
  }
}
