@isTest
public class ElliDueDiligence_Test {

    // -------------------------------------------------------
    //  MOCK HTTP RESPONSE
    // -------------------------------------------------------
    private class ElliMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/xml');
            res.setStatus('200 OK');
            res.setStatusCode(200);

            // Exemple de réponse XML renvoyée par l’API (à adapter si besoin)
            String mockXml = 
                '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'+
                '<svcTest lang="FR" version="2.2">'+
                '<result code="OK"/>'+
                '<response>' +
                '<folder>'+
                    '<dueDiligence>' +
                        '<id>DD-12345</id>' +
                        '<status>OK</status>' +
                        '<decision><decisionStatus>OK</decisionStatus></decision>' +
                        '<indicator><color>RED</color></indicator>' +
                        '<statistics code="PENDINGMIT"><value>0</value></statistics>' +
                    '</dueDiligence>' +
                '</folder>'+
                '</response>'+
                '</svcTest>';

            res.setBody(mockXml);
            return res;
        }
    }

    // -------------------------------------------------------
    //  MOCK HTTP RESPONSE
    // -------------------------------------------------------
    private class ElliEventsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/xml');
            res.setStatus('200 OK');
            res.setStatusCode(200);

            // Exemple de réponse XML renvoyée par l’API (à adapter si besoin)
            String mockXml = 
                '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'+
                '<svcTest lang="FR" version="2.2">'+
                '<result code="OK"/>'+
                '<response>'+
                    '<total>7</total>'+
                    '<folder>'+
                        '<id>12345</id>'+
                        '<eventList total="1">'+
                            '<event type="EVALUATION_EXECUTION_START">'+
                                '<date>2026-01-21 11:55:42.803</date>'+
                                '<dueDiligence reference="456789"/>'+
                            '</event>'+
                        '</eventList>'+
                    '</folder>'+
                '</response>'+
                '</svcTest>';
            res.setBody(mockXml);
            return res;
        }
    }

    // -------------------------------------------------------
    //  TEST : création d’une due diligence (dueDiligenceId vide)
    // -------------------------------------------------------
    @isTest
    static void testCreateDueDiligence() {
        Test.setMock(HttpCalloutMock.class, new ElliMock());

        ElliDueDiligence.Request req = new ElliDueDiligence.Request();
        req.user = 'testuser';
        req.password = 'pwd';
        req.companyId = '123456789';
        req.companyCountryCode = 'ZW';
        req.folderId = 'F001';
        req.dueDiligenceId = '';      // ➜ déclenche createDueDiligence
        req.businessUnit = 'BU1';
        req.relationshipType = 'SUPPLIER';
        req.reference = 'TESTREF';

        List<ElliDueDiligence.Request> listReq = new List<ElliDueDiligence.Request>{ req };

        Test.startTest();
        List<ElliDueDiligenceResult> result = 
            ElliDueDiligence.process(listReq);
        Test.stopTest();

        System.assertNotEquals(0, result.size(), 'Le résultat ne doit pas être vide');
        System.assertNotEquals(null, result[0], 'L’élément retourné doit être défini');
    }

    // -------------------------------------------------------
    //  TEST : récupération d’une due diligence existante (dueDiligenceId renseigné)
    // -------------------------------------------------------
    @isTest
    static void testGetDueDiligence() {
        Test.setMock(HttpCalloutMock.class, new ElliMock());

        ElliDueDiligence.Request req = new ElliDueDiligence.Request();
        req.user = 'testuser';
        req.password = 'pwd';
        req.companyId = '987654321';
        req.companyCountryCode = 'FR';
        req.folderId = 'F002';
        req.dueDiligenceId = 'DD-EXISTING';   // ➜ déclenche getDueDiligence
        req.businessUnit = 'BU1';
        req.relationshipType = 'CLIENT';
        req.reference = 'REF2';

        List<ElliDueDiligence.Request> listReq = new List<ElliDueDiligence.Request>{ req };

        Test.startTest();
        List<ElliDueDiligenceResult> result = 
            ElliDueDiligence.process(listReq);
        Test.stopTest();

        System.assert(result.size() > 0, 'Une liste doit être retournée');
        System.assertNotEquals(null, result[0], 'Un objet résultat doit être retourné');
    }
    // -------------------------------------------------------
    //  TEST : récupération d’une due diligence existante (dueDiligenceId renseigné)
    // -------------------------------------------------------
    @isTest
    static void testGetDueDiligenceEvents() {
        Test.setMock(HttpCalloutMock.class, new ElliEventsMock());

        ElliDueDiligence.Request req = new ElliDueDiligence.Request();
        req.user = 'testuser';
        req.password = 'pwd';
        req.batchEventsGetFolderIds = true;

        List<ElliDueDiligence.Request> listReq = new List<ElliDueDiligence.Request>{ req };

        Test.startTest();
        List<ElliDueDiligenceResult> result = 
            ElliDueDiligence.process(listReq);
        Test.stopTest();

        System.assert(result.size() > 0, 'Une liste doit être retournée');
        System.assertNotEquals(null, result[0], 'Un objet résultat doit être retourné');
    }
}