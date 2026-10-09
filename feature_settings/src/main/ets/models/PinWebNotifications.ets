export interface NotificationChannel { label: string; value: boolean; }
export interface NotificationCategory { key: string; label: string; description: string; summary: string; channels: NotificationChannel[]; }
export interface NotificationGroup { key: string; label: string; categories: NotificationCategory[]; }
export interface NotificationResult { groups: NotificationGroup[]; error: string; }
