import { PrismaClient } from '@prisma/client';

export const prisma = new PrismaClient({ adapter: undefined, datasourceUrl: "file:./dev.db" });

