export interface ImageMetadata {
  width: number;
  height: number;
  size: number;
  format: string;
}

export interface ImageRecord {
  id: number;
  team_id: number;
  author_id: number;
  filepath: string;
  image_hash: string;
  label?: string;
  status: 'onhold' | 'verified';
  metadata: ImageMetadata;
}

export interface CreateImageDTO {
  team_id: number;
  author_id: number;
  filepath: string;
  image_hash: string;
  label?: string;
  metadata: ImageMetadata;
}

