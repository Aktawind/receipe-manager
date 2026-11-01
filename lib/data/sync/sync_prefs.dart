/// Les clés des préférences de synchronisation, partagées entre l'application
/// et la tâche d'arrière-plan.
abstract final class SyncPrefs {
  static const enabled = 'sync_enabled';
  static const email = 'sync_email';
  static const name = 'sync_name';
  static const photo = 'sync_photo';
  static const backupFrequency = 'backup_frequency';
  static const lastBackup = 'backup_last';
}
