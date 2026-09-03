/**
 * CFB_ScheduledSyncDueDiligence
 *
 * Déclenche quotidiennement CFB_BatchSyncDueDiligence, pour que les admins
 * n'aient qu'à cocher CFB_Force_Sync__c sur les comptes défaillants (via le
 * Page Layout) sans avoir à lancer de code (IACRM-336).
 *
 * Planification (Apex anonyme, à exécuter une seule fois) :
 *   System.schedule('CFB Rattrapage quotidien', '0 0 22 * * ?', new CFB_ScheduledSyncDueDiligence());
 */
public class CFB_ScheduledSyncDueDiligence implements Schedulable
{
    public void execute(SchedulableContext sc)
    {
        Database.executeBatch(new CFB_BatchSyncDueDiligence(), 50);
    }
}