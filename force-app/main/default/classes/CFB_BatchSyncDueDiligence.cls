/**
 * CFB_BatchSyncDueDiligence
 *
 * Batch Apex de rattrapage de la synchronisation CFB ↔ Salesforce (IACRM-336).
 * Traite les comptes tagués via CFB_Force_Sync__c : appelle l'API CFB
 * (svcGetDueDiligenceIndicators, via ElliDueDiligence.process) pour récupérer
 * le statut compliance de chaque compte et met à jour les champs Account.
 *
 * Le calcul du statut réplique strictement la formule "calculatedStatus" du
 * scheduled flow CFB_ESCONNECT_update_accounts, pour rester cohérent avec le
 * flux nominal.
 *
 * Relançable à la demande, lot par lot, au fur et à mesure du croisement des
 * ~911 dossiers CFB orphelins avec les comptes Salesforce.
 *
 * Lancement (Apex anonyme) :
 *   // Taguer au préalable les comptes à traiter (CFB_Force_Sync__c = true),
 *   // puis :
 *   Database.executeBatch(new CFB_BatchSyncDueDiligence(), 50);
 */
public with sharing class CFB_BatchSyncDueDiligence
    implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful
{
    private static final String TCH_CONTRACT = '57104';
    private static final String TCH_USER = 'api_cfb-sf_atalian@nomail.dns';
    private static final String TCH_PWD = 'Ellisphe26!';

    // État cumulé sur tous les lots
    private Integer countSuccess = 0;
    private Integer countError = 0;
    private List<String> errors = new List<String>();

    public Database.QueryLocator start(Database.BatchableContext bc)
    {
        return Database.getQueryLocator([
            SELECT Id, CFB_ESCONNECT_order_Id__c, CFB_ESCONNECT_folder_id__c
            FROM Account
            WHERE CFB_Force_Sync__c = true
            AND CFB_ESCONNECT_folder_id__c != null
            AND CFB_ESCONNECT_order_Id__c != null
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Account> scope)
    {
        List<Account> toUpdate = new List<Account>();

        for (Account acc : scope)
        {
            acc.CFB_Force_Sync__c = false;

            try
            {
                ElliDueDiligence.Request req = new ElliDueDiligence.Request();
                req.contract = TCH_CONTRACT;
                req.user = TCH_USER;
                req.password = TCH_PWD;
                req.dueDiligenceId = acc.CFB_ESCONNECT_order_Id__c;

                List<ElliDueDiligenceResult> results =
                    ElliDueDiligence.process(new List<ElliDueDiligence.Request>{ req });
                ElliDueDiligenceResult result = results.isEmpty() ? null : results[0];

                if (result == null || result.error)
                {
                    countError++;
                    errors.add(acc.Id + ' : ' + (result != null ? result.comment : 'Aucune réponse API'));
                }
                else
                {
                    acc.CFB_ESCONNECT_TCH_result__c = calculatedStatus(
                        result.dueDiligenceMitigations, result.dueDiligenceDecision, result.dueDiligenceStatus);
                    acc.CFB_ESCONNECT_risk__c = result.dueDiligenceRisk;
                    acc.CFB_ESCONNECT_update__c = result.dueDiligenceLastUpdate;
                    countSuccess++;
                }
            }
            catch (Exception e)
            {
                countError++;
                errors.add(acc.Id + ' : ' + e.getMessage());
            }

            toUpdate.add(acc);
        }

        List<Database.SaveResult> saveResults = Database.update(toUpdate, false);
        for (Integer i = 0; i < saveResults.size(); i++)
        {
            if (!saveResults[i].isSuccess())
            {
                errors.add(toUpdate[i].Id + ' : ' + saveResults[i].getErrors()[0].getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc)
    {
        String body =
            'Rattrapage synchronisation CFB terminé.\n\n'
            + 'Comptes mis à jour : ' + countSuccess + '\n'
            + 'Comptes en erreur  : ' + countError + '\n';
        if (!errors.isEmpty())
        {
            body += '\n--- Erreurs ---\n - ' + String.join(errors, '\n - ');
        }

        System.debug(body);
        sendSummaryEmail(body);
    }

    /** Envoi best-effort du récapitulatif au lanceur (silencieux si l'email est indisponible). */
    private void sendSummaryEmail(String body)
    {
        try
        {
            String toAddress = UserInfo.getUserEmail();
            if (String.isBlank(toAddress)) { return; }
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ toAddress });
            mail.setSubject('Rattrapage CFB — récapitulatif');
            mail.setPlainTextBody(body);
            mail.setSaveAsActivity(false);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        }
        catch (Exception e)
        {
            System.debug('Récapitulatif email non envoyé : ' + e.getMessage());
        }
    }

    /** Réplique la formule "calculatedStatus" du flow CFB_ESCONNECT_update_accounts. */
    private static String calculatedStatus(String mitigations, String decision, String status)
    {
        Boolean hasMitigations = String.isNotBlank(mitigations) && mitigations != '0';

        if (decision == 'INPROGRESS') { return 'IN_PROGRESS'; }
        if (decision == 'CONTINUE') { return hasMitigations ? 'ACCEPTED_MIT' : 'ACCEPTED'; }
        if (decision == 'CONTINUE_UNDER_CONDITION') { return hasMitigations ? 'RESTRICTION_MIT' : 'RESTRICTION'; }
        if (decision == 'STOP') { return 'REFUSED'; }

        return (status == 'INPROGRESS') ? 'IN_PROGRESS' : '';
    }
}