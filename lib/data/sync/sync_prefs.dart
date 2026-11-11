/// Les clés des préférences de synchronisation, partagées entre l'application
/// et la tâche d'arrière-plan.
abstract final class SyncPrefs {
  static const enabled = 'sync_enabled';
  static const email = 'sync_email';
  static const name = 'sync_name';
  static const photo = 'sync_photo';

  /// Le compte dont l'appareil connaît le dossier Drive. Gardé à la
  /// déconnexion : se reconnecter au même compte reprend où on en était.
  static const account = 'sync_account';
  static const backupFrequency = 'backup_frequency';
  static const lastBackup = 'backup_last';

  /// La dernière synchro réussie (application ou arrière-plan).
  static const lastSync = 'sync_last';
}
