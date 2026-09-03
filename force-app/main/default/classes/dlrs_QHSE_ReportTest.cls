/**
 * Auto Generated and Deployed by the Declarative Lookup Rollup Summaries Tool package (dlrs)
 **/
@IsTest
private class dlrs_QHSE_ReportTest
{
    @IsTest
    private static void testTrigger()
    {
        // Force the dlrs_QHSE_ReportTrigger to be invoked, fails the test if org config or other Apex code prevents this.
        dlrs.RollupService.testHandler(new QHSE_Report__c());
    }
}