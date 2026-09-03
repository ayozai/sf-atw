/**
 * SCHEDULE_ContractSnapshot
 * 
 * Scheduled job to run the batch for contract snapshot creation
 * 
 * Author : Bernard Price (Brightgen)
 * Created: 2022-06-15
 * 
 * Changes:
 */
public without sharing class SCHEDULE_ContractSnapshot implements Schedulable
{
    public void execute(SchedulableContext SC)
    {
        // Get the batch size from the custom setting
        Contract_Snapshot_Settings__c settings = Contract_Snapshot_Settings__c.getInstance();
        Integer batchSize = Integer.valueOf(settings.Batch_Size__c);
        // Run the job
        BATCH_ContractSnapshot batchProcess = new BATCH_ContractSnapshot();
        Database.executeBatch(batchProcess, batchSize);
    }
}