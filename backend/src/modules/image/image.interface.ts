export interface ImageMetadata {
  id?: number;
  image_id?: number;
  GPSInfo?: string;
  ImageWidth?: number;
  ImageLength?: number;
  ResolutionUnit?: string;
  ExifOffset?: number;
  Make?: string;
  Model?: string;
  Software?: string;
  Orientation?: number;
  DateTime?: Date;
  YCbCrPositioning?: string;
  XResolution?: number;
  YResolution?: number;
  New_width?: number;
  New_height?: number;
  New_size_mb?: number;
  Extra_subfolder?: string;
  original_resolution?: string;
  new_resolution?: string;
  resizing_method?: string;
  format_change?: string;
  label?: string;
  english_name?: string;
  scientific_name?: string;
}

export interface ImageRecord {
  id: number;
  team_id: number;
  author_id: number;
  time: Date;
  label?: string;
  filepath: string;
  status: 'onhold' | 'verified';
  original_filename?: string;
  old_extension?: string;
  image_hash: string;
  old_size_mb?: number;
  old_width?: number;
  old_height?: number;
  device?: string;
  metadata: ImageMetadata;
}

export interface CreateImageDTO {
  team_id: number;
  author_id: number;
  filepath: string;
  image_hash: string;
  label?: string;
  original_filename?: string;
  old_extension?: string;
  old_size_mb?: number;
  old_width?: number;
  old_height?: number;
  device?: string;
  metadata: ImageMetadata;
}
