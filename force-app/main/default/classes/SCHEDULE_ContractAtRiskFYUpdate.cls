public without sharing class SCHEDULE_ContractAtRiskFYUpdate implements Schedulable
{
    public void execute(SchedulableContext SC)
    {
        BATCH_ContractAtRiskFYUpdate batchProcess = new BATCH_ContractAtRiskFYUpdate();
        Database.executeBatch(batchProcess, 50);
    }
}