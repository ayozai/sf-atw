/* Class that is used to schedule the batch job to sync PS111 proposals.
 * Test coverage is contained within BATCH_Sync_Opp_Proposals_Test
 *
 * Author:  Simon Kaya
 * Date:    04/05/2022
 */
public with sharing class SCHEDULE_Sync_Opp_Proposals implements Schedulable
{
    public void execute(SchedulableContext SC)
    {
        Database.executeBatch(new BATCH_Sync_Opp_Proposals());
    }
}