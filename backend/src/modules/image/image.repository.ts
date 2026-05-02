import { ImageRecord, CreateImageDTO } from './image.interface';
import { prisma } from '../../lib/prisma';

export class ImageRepository {
  async create(data: CreateImageDTO): Promise<ImageRecord> {
    const { metadata, label, ...imageFields } = data;

    // Using Prisma nested write to insert into Image and ImageMetadata tables simultaneously
    const record = await prisma.image.create({
      data: {
        ...imageFields,
        label: label || null,
        status: 'onhold',
        metadata: {
          create: metadata
        }
      },
      include: {
        metadata: true
      }
    });

    return record as unknown as ImageRecord;
  }

  async findById(imageId: number): Promise<ImageRecord | null> {
    const record = await prisma.image.findUnique({
      where: { id: imageId },
      include: { metadata: true }
    });
    return record as unknown as ImageRecord | null;
  }

  async findByHash(hash: string): Promise<ImageRecord | null> {
    const record = await prisma.image.findUnique({
      where: { image_hash: hash },
      include: { metadata: true }
    });
    return record as unknown as ImageRecord | null;
  }

  async findByTeam(teamId: number, status?: string, page: number = 1): Promise<{ images: ImageRecord[], total: number }> {
    const limit = 10;

    const whereCondition = {
      team_id: teamId,
      ...(status && { status })
    };

    const [total, images] = await Promise.all([
      prisma.image.count({ where: whereCondition }),
      prisma.image.findMany({
        where: whereCondition,
        skip: (page - 1) * limit,
        take: limit,
        include: { metadata: true }
      })
    ]);

    return {
      images: images as unknown as ImageRecord[],
      total
    };
  }

  async findByCompetition(compId: number, status?: string): Promise<{ images: ImageRecord[], total: number }> {
    // team -> match competition constraint in schema
    const whereCondition = {
      team: { comp_id: compId },
      ...(status && { status })
    };

    const [total, images] = await Promise.all([
      prisma.image.count({ where: whereCondition }),
      prisma.image.findMany({
        where: whereCondition,
        include: { metadata: true }
      })
    ]);

    return { images: images as unknown as ImageRecord[], total };
  }

  async findByStatus(status: string): Promise<ImageRecord[]> {
    const images = await prisma.image.findMany({
      where: { status },
      include: { metadata: true }
    });
    return images as unknown as ImageRecord[];
  }

  async updateStatus(imageId: number, status: 'onhold' | 'verified'): Promise<ImageRecord | null> {
    try {
      const updated = await prisma.image.update({
        where: { id: imageId },
        data: { status },
        include: { metadata: true }
      });
      return updated as unknown as ImageRecord;
    } catch {
      return null;
    }
  }

  async delete(imageId: number): Promise<boolean> {
    try {
      // Must delete metadata manually first if cascading is not fully set
      await prisma.imageMetadata.deleteMany({
        where: { image_id: imageId }
      });
      await prisma.image.delete({
        where: { id: imageId }
      });
      return true;
    } catch {
      return false;
    }
  }

  async countByTeam(teamId: number): Promise<number> {
    return await prisma.image.count({
      where: { team_id: teamId }
    });
  }

  async countByStatus(status: string): Promise<number> {
    return await prisma.image.count({
      where: { status }
    });
  }

  async getStats(compId: number) {
    const whereComp = { team: { comp_id: compId } };

    const total = await prisma.image.count({ where: whereComp });
    const verified = await prisma.image.count({ where: { ...whereComp, status: 'verified' } });
    const onhold = total - verified;

    // Using group by for labels
    const labelsGroups = await prisma.image.groupBy({
      by: ['label'],
      where: whereComp,
      _count: { label: true }
    });

    // Group by Teams
    const teamGroups = await prisma.image.groupBy({
      by: ['team_id'],
      where: whereComp,
      _count: { team_id: true }
    });

    const by_label = labelsGroups.filter(g => g.label).map(g => ({ label: g.label!, count: g._count.label }));
    const by_team = teamGroups.map(g => ({ team_id: g.team_id, count: g._count.team_id }));

    return {
      total,
      by_status: { onhold, verified },
      by_team,
      by_label
    };
  }
}
