@isTest
public class GlobalFamilyTreeJsonMock implements HttpCalloutMock {
        
        public GlobalFamilyTreeJsonMock() {
        
        }

        public HTTPResponse respond(HTTPRequest req) {

            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');

            if('POST' == req.getMethod())
                res.setBody('{"access_token":"IAMADUMMYTOKEN","token_type":"bearer","expires_in":899}');
            else
                res.setBody('{"Duns":"417833209","Name":"Almarach International Handelsmaatschappij B.V.","Location":"Netherlands","CrmId":null,"Children":[{"Duns":"490167581","Name":"Almarach Shipping B.V.","Location":"Netherlands","CrmId":null,"Children":[{"Duns":"402606441","Name":"Blue Line Logistics Nederland B.V.","Location":"Netherlands","CrmId":null,"Children":[]},{"Duns":"415645530","Name":"Tesco (The European Shipment Company) B.V.","Location":"Netherlands","CrmId":null,"Children":[]}]},{"Duns":"489248027","Name":"Almarach Europe B.V.","Location":"Netherlands","CrmId":null,"Children":[]}]}');
            
            res.setStatusCode(200);
            return res;
        }
}