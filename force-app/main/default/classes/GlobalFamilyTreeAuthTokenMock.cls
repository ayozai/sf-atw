@isTest
public class GlobalFamilyTreeAuthTokenMock implements HttpCalloutMock {
        public GlobalFamilyTreeAuthTokenMock() {

        }
        
        public HTTPResponse respond(HTTPRequest req) {
            String authenticationDetailsJson = '{"access_token":"IAMADUMMYTOKEN","token_type":"bearer","expires_in":899}';

            System.assertEquals('https://linkage-test-api.dqbox.com/v1/token', req.getEndpoint());
            System.assertEquals('POST', req.getMethod());

            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(authenticationDetailsJson);
            res.setStatusCode(200);
            return res;
        }
}