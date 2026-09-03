/**
 * Auto Generated and Deployed by the Declarative Lookup Rollup Summaries Tool package (dlrs)
 **/
@IsTest
private class dlrs_InspectionTest
{
    @IsTest
    private static void testTrigger()
    {
        // Force the dlrs_InspectionTrigger to be invoked, fails the test if org config or other Apex code prevents this.
        dlrs.RollupService.testHandler(new Inspection__c());
    }
}