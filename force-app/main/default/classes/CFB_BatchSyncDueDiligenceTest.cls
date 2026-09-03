@isTest
public class CFB_BatchSyncDueDiligenceTest {

    private class CfbMock implements HttpCalloutMock {
        private String resultCode;
        private String decisionStatus;
        private String mitigationsValue;
        private String riskColor;

        public CfbMock(String resultCode, String decisionStatus, String mitigationsValue, String riskColor) {
            this.resultCode = resultCode;
            this.decisionStatus = decisionStatus;
            this.mitigationsValue = mitigationsValue;
            this.riskColor = riskColor;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/xml');
            res.setStatus('200 OK');
            res.setStatusCode(200);

            String mockXml;
            if (resultCode == 'OK') {
                mockXml =
                    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
                    '<svcGetDueDiligenceIndicatorsResponse lang="FR" version="2.2">' +
                    '<result code="OK"/>' +
                    '<response>' +
                        '<folder>' +
                            '<dueDiligence>' +
                                '<status code="OK"/>' +
                                '<decision><decisionStatus code="' + decisionStatus + '"/></decision>' +
                                '<indicator><color code="' + riskColor + '"/></indicator>' +
                                '<statistics code="PENDINGMIT"><value>' + mitigationsValue + '</value></statistics>' +
                                '<date ref="LASTUPDATE">2026-07-28T10:00:00+02:00</date>' +
                            '</dueDiligence>' +
                        '</folder>' +
                    '</response>' +
                    '</svcGetDueDiligenceIndicatorsResponse>';
            } else {
                mockXml =
                    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
                    '<svcGetDueDiligenceIndicatorsResponse lang="FR" version="2.2">' +
                    '<result code="KO"><additionalInfo>Erreur simulée</additionalInfo></result>' +
                    '</svcGetDueDiligenceIndicatorsResponse>';
            }

            res.setBody(mockXml);
            return res;
        }
    }

    private static Account newAccount(String name, String folderId, String orderId) {
        return new Account(
            Name = name,
            CFB_Force_Sync__c = true,
            CFB_ESCONNECT_folder_id__c = folderId,
            CFB_ESCONNECT_order_Id__c = orderId
        );
    }

    @isTest
    static void testBatchSuccessWithoutMitigations() {
        insert newAccount('CFB Test Sans Mitigations', 'F001', 'DD-001');
        Test.setMock(HttpCalloutMock.class, new CfbMock('OK', 'CONTINUE', '0', 'GREEN'));

        Test.startTest();
        Database.executeBatch(new CFB_BatchSyncDueDiligence(), 50);
        Test.stopTest();

        Account result = [
            SELECT CFB_ESCONNECT_TCH_result__c, CFB_ESCONNECT_risk__c, CFB_ESCONNECT_update__c, CFB_Force_Sync__c
            FROM Account
            WHERE Name = 'CFB Test Sans Mitigations'
        ];
        System.assertEquals('ACCEPTED', result.CFB_ESCONNECT_TCH_result__c);
        System.assertEquals('GREEN', result.CFB_ESCONNECT_risk__c);
        System.assertNotEquals(null, result.CFB_ESCONNECT_update__c);
        System.assertEquals(false, result.CFB_Force_Sync__c);
    }

    @isTest
    static void testBatchSuccessWithMitigations() {
        insert newAccount('CFB Test Avec Mitigations', 'F002', 'DD-002');
        Test.setMock(HttpCalloutMock.class, new CfbMock('OK', 'CONTINUE_UNDER_CONDITION', '3', 'ORANGE'));

        Test.startTest();
        Database.executeBatch(new CFB_BatchSyncDueDiligence(), 50);
        Test.stopTest();

        Account result = [
            SELECT CFB_ESCONNECT_TCH_result__c, CFB_Force_Sync__c
            FROM Account
            WHERE Name = 'CFB Test Avec Mitigations'
        ];
        System.assertEquals('RESTRICTION_MIT', result.CFB_ESCONNECT_TCH_result__c);
        System.assertEquals(false, result.CFB_Force_Sync__c);
    }

    @isTest
    static void testBatchApiError() {
        insert newAccount('CFB Test Erreur API', 'F003', 'DD-003');
        Test.setMock(HttpCalloutMock.class, new CfbMock('KO', null, null, null));

        Test.startTest();
        Database.executeBatch(new CFB_BatchSyncDueDiligence(), 50);
        Test.stopTest();

        Account result = [
            SELECT CFB_ESCONNECT_TCH_result__c, CFB_Force_Sync__c
            FROM Account
            WHERE Name = 'CFB Test Erreur API'
        ];
        System.assertEquals(null, result.CFB_ESCONNECT_TCH_result__c);
        System.assertEquals(false, result.CFB_Force_Sync__c, 'Le booléen doit être repassé à false même en erreur');
    }

    @isTest
    static void testBatchStopDecision() {
        insert newAccount('CFB Test Refus', 'F004', 'DD-004');
        Test.setMock(HttpCalloutMock.class, new CfbMock('OK', 'STOP', '0', 'RED'));

        Test.startTest();
        Database.executeBatch(new CFB_BatchSyncDueDiligence(), 50);
        Test.stopTest();

        Account result = [
            SELECT CFB_ESCONNECT_TCH_result__c, CFB_Force_Sync__c
            FROM Account
            WHERE Name = 'CFB Test Refus'
        ];
        System.assertEquals('REFUSED', result.CFB_ESCONNECT_TCH_result__c);
        System.assertEquals(false, result.CFB_Force_Sync__c);
    }

    @isTest
    static void testAccountWithoutIdentifiersIsExcluded() {
        insert newAccount('CFB Test Sans Identifiants', null, null);
        // Pas de mock HTTP : un callout déclenché ici ferait échouer le test.

        Test.startTest();
        Database.executeBatch(new CFB_BatchSyncDueDiligence(), 50);
        Test.stopTest();

        Account result = [
            SELECT CFB_Force_Sync__c
            FROM Account
            WHERE Name = 'CFB Test Sans Identifiants'
        ];
        System.assertEquals(true, result.CFB_Force_Sync__c, 'Le compte ne doit pas être traité par le batch');
    }
}