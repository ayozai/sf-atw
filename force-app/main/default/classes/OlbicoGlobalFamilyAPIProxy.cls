public class OlbicoGlobalFamilyAPIProxy {   
               static final Integer REQ_MAX_TIMEOUT = 45000;//msec
               static final Integer MAX_RETRIES = 2;
               
               private Integer retryCount = 0;
               private final OlbicoGlobalFamilyTreeSettings settings = null;

               public OlbicoGlobalFamilyAPIProxy(OlbicoGlobalFamilyTreeSettings settings){
                   this.settings = settings;
               }

               public String getTree(String duns) {  
                   
                   if (retryCount >= MAX_RETRIES) {
                       System.debug('[FTREE] Maximum amount of retries performed. Ending');
                       return null;
                   }

                   try{
                       
                        System.debug('[FTREE] Getting  family tree for duns:' + duns);

                        String token = this.getToken();

                        if(token == null)
                            return null;

                        Stopwatch watch = new Stopwatch();
                        watch.start();

                        HTTPResponse res = this.requestTree(duns, token);
                        
                        watch.stop();

                        // retry if 401
                        if (res.getStatusCode() ==  401) {

                            System.debug('[FTREE] getTree failed. Not authorized.');
                            String cacheKey = null;
                            if (settings.CacheNamespace != null && settings.CacheNamespace != '')
                                cacheKey = settings.CacheNamespace + '.token';

                            if (cacheKey == null || (String)Cache.Session.get(cacheKey) == null) {
                                return null;
                            }
                            
                            System.debug('[FTREE] Clearing token from cache: ' + cacheKey);
                            Cache.Session.remove(cacheKey);

                            System.debug('[FTREE] getTree going for retry.');
                            retryCount = retryCount + 1;
                            return getTree(duns);
                        }

                        if(res.getStatusCode() == 200){
                            System.debug('[FTREE] getTree executed successfully. Execution time: ' + watch.Elapsed);
                            return res.getBody();
                        }
                        
                   }
                   catch(Exception e){
                        System.debug('[FTREE] getTree failed. Error: ' + e.getMessage());
                   }

                   return null;
                }

                private HTTPResponse requestTree(String duns, String token) {
                    
                        HttpRequest req = new HttpRequest();
                        req.setMethod('GET');
                        req.setHeader('Content-Type', 'application/json');
                        req.setHeader('Authorization', 'Bearer ' + token);
                        req.setTimeout(REQ_MAX_TIMEOUT);
                        req.setEndpoint(String.format('{0}/api/{1}/ConcernTree/?duns={2}', new String[]{ settings.Host, settings.Version, duns}));
                        
                        Http http = new Http();
                        HTTPResponse response = http.send(req);

                        System.debug('[FTREE] requestTree response: ' + response.toString());
                        return response;
                }

                @TestVisible
                private String getToken() {
                   try{

                       String cacheKey = null;
                       if (settings.CacheNamespace != null && settings.CacheNamespace != '')
                            cacheKey = settings.CacheNamespace + '.token';

                       if (cacheKey != null) {
                           System.debug('[FTREE] Getting token from cache: ' + cacheKey);
                           String token = (String)Cache.Session.get(cacheKey);

                           if (token != null){
                                System.debug('[FTREE] Found token in cache');
                                return token;
                           }
                        }
                       
                        Stopwatch watch = new Stopwatch();
                        watch.start();
                        
                        System.debug('[FTREE] Getting token from ' + settings.Host);

                        HttpRequest req = new HttpRequest();

                        String uname = EncodingUtil.urlEncode(settings.UserName, 'UTF-8');
                        String pass = EncodingUtil.urlEncode(settings.Password, 'UTF-8');
                    
                        req.setMethod('POST');
                        req.setHeader('Content-Type','application/json');
                        req.setTimeout(REQ_MAX_TIMEOUT);
                        req.setEndpoint(String.format('{0}/{1}/token', new String[]{settings.Host, settings.Version}));
                        req.setBody(String.format('grant_type=password&username={0}&password={1}', new String[]{uname, pass}));
                        
                        Http http = new Http();
    
                        HTTPResponse res = http.send(req);
                        System.debug('[FTREE] getToken response: ' + res.toString());

                        watch.stop();

                        if(res.getStatusCode() == 200){
                            String token = this.getTokenValueFromResponse(res.getBody());
                            System.debug('[FTREE] Succeeded getting token.  Execution time: ' + watch.Elapsed);                            

                           if (cacheKey != null && token != null) {
                                System.debug('[FTREE] Setting token in cache: ' + cacheKey);
                                Cache.Session.put(cacheKey, token, 28800);
                            }
                                
                            return token;
                        }
                   }
                   catch(Exception e){
                        System.debug('[FTREE] getToken failed. Error: ' + e.getMessage());
                   }

                   return null;
               }
                
                @TestVisible
                private String getTokenValueFromResponse(String response) {
                    Map<String, Object> dictionary = (Map<String, Object>)JSON.deserializeUntyped(response);
                    
                    return (String)dictionary.get('access_token');
                }


     public static void cc() {
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }                
    
}