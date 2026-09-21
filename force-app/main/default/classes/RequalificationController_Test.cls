@isTest
private class RequalificationController_Test {

    @isTest
    static void test_nullOpportunityId_throwsException() {
        try {
            RequalificationController.startRequalification(null, 2);
            System.assert(false, 'Expected AuraHandledException.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'Exception should be thrown.');
        }
    }

    @isTest
    static void test_zeroNumberOfOpps_throwsException() {
        Id fakeId = '006000000000001AAA';
        try {
            RequalificationController.startRequalification(fakeId, 0);
            System.assert(false, 'Expected AuraHandledException.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'Exception should be thrown.');
        }
    }

    @isTest
    static void test_nullNumberOfOpps_throwsException() {
        Id fakeId = '006000000000001AAA';
        try {
            RequalificationController.startRequalification(fakeId, null);
            System.assert(false, 'Expected AuraHandledException.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'Exception should be thrown.');
        }
    }
}
