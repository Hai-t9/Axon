import { PrismaClient } from '@prisma/client';
import { PrismaLibSql } from '@prisma/adapter-libsql';

const adapter = new PrismaLibSql({ url: 'file:./prisma/dev.db' });
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('Seeding database...');

  const user = await prisma.user.upsert({
    where: { email: 'abderrahman@axon.dz' },
    update: {},
    create: {
      fullname: 'Abderrahman',
      email: 'abderrahman@axon.dz',
      password: 'hashed_password_here',
      phone: '0555000001',
    },
  });
  console.log('User created:', user.id);

  const competition = await prisma.competition.upsert({
    where: { id: 1 },
    update: {},
    create: {
      id: 1,
      name: 'AgrI Challenge 2024',
      description: 'Tree species classification competition',
    },
  });
  console.log('Competition created:', competition.id);

  await prisma.role.upsert({
    where: { user_id_competition_id: { user_id: user.id, competition_id: competition.id } },
    update: {},
    create: {
      user_id: user.id,
      competition_id: competition.id,
      role: 'participant',
    },
  });

  const team = await prisma.team.upsert({
    where: { name_comp_id: { name: 'Team Axon', comp_id: competition.id } },
    update: {},
    create: {
      name: 'Team Axon',
      comp_id: competition.id,
      user_ids: JSON.stringify([user.id]),
    },
  });
  console.log('Team created:', team.id);

  await prisma.phaseLog.create({
    data: {
      competition_id: competition.id,
      current_phase: 'data_collection',
    },
  });

  await prisma.config.upsert({
    where: { competition_id: competition.id },
    update: {},
    create: {
      competition_id: competition.id,
      labels: JSON.stringify(['Carob', 'Oak', 'Pepper', 'Ash', 'Pistachio', 'Tipuana']),
      duplicate_threshhold: 0.95,
    },
  });

  console.log('Done. Summary:');
  console.log('  User ID:', user.id);
  console.log('  Competition ID:', competition.id);
  console.log('  Team ID:', team.id);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());