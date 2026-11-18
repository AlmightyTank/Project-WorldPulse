-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "SimulationStatus" AS ENUM ('not_started');

-- CreateEnum
CREATE TYPE "SystemEventType" AS ENUM ('world_initialized');

-- CreateTable
CREATE TABLE "World" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "status" "SimulationStatus" NOT NULL DEFAULT 'not_started',

    CONSTRAINT "World_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WorldSettings" (
    "id" UUID NOT NULL,
    "worldId" TEXT NOT NULL,
    "settings" JSONB NOT NULL DEFAULT '{}',
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WorldSettings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SystemEvent" (
    "id" UUID NOT NULL,
    "worldId" TEXT NOT NULL,
    "eventType" "SystemEventType" NOT NULL,
    "payload" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SystemEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "WorldSettings_worldId_key" ON "WorldSettings"("worldId");

-- CreateIndex
CREATE INDEX "SystemEvent_worldId_createdAt_idx" ON "SystemEvent"("worldId", "createdAt");

-- AddForeignKey
ALTER TABLE "WorldSettings" ADD CONSTRAINT "WorldSettings_worldId_fkey" FOREIGN KEY ("worldId") REFERENCES "World"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SystemEvent" ADD CONSTRAINT "SystemEvent_worldId_fkey" FOREIGN KEY ("worldId") REFERENCES "World"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
