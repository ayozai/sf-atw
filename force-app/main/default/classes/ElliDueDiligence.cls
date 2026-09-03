/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 07-23-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class ElliDueDiligence {
 
    @InvocableMethod(label='Ellisphere Check Due Diligence' description='Check companie due diligence with identifier')
    public static List <ElliDueDiligenceResult> process(List<Request> requestList) {

        List<ElliDueDiligenceResult> responseWrapper = new List<ElliDueDiligenceResult>();

        for (Request curRequest : requestList) {
            if (curRequest.batchEventsGetFolderIds) {
                responseWrapper=getFolderIdsFromEvents(curRequest.contract,curRequest.user,curRequest.password);
            }else{
                if (curRequest.dueDiligenceId == '') {
                    responseWrapper=createDueDiligence(curRequest.contract,curRequest.user,curRequest.password, curRequest.companyId, curRequest.companyCountryCode, curRequest.businessUnit, curRequest.buContact, curRequest.relationshipType, curRequest.GTRrefId, curRequest.GTRid, curRequest.publicEntity, curRequest.keyEntity, curRequest.reference);
                }else{
                    responseWrapper=getDueDiligence(curRequest.contract,curRequest.user,curRequest.password, curRequest.dueDiligenceId);
                }
            }
        }
        return responseWrapper;
    }

    public class Request {
        @InvocableVariable(required=false label='Récupération des évènements' description='Permet la récupération des dossiers concernés par une mise à jour')
        public Boolean batchEventsGetFolderIds=false;
        @InvocableVariable(required=true label='Contrat technique')
        public String contract;
        @InvocableVariable(required=true label='Code utilisateur technique')
        public String user;
        @InvocableVariable(required=true label='Mot de passe de l\'utilisateur')
        public String password;
        @InvocableVariable(required=false label='Identifiant technique de l\'entreprise')
        public String companyId = '';
        @InvocableVariable(required=false label='Code pays' description='Format ISO-2 ou ISO-3')
        public String companyCountryCode = '';
        @InvocableVariable(required=false label='Identifiant du dossier')
        public String folderId = '';        
        @InvocableVariable(required=false label='Identifiant de la demande')
        public String dueDiligenceId = '';        
        @InvocableVariable(required=false label='Code de la BU du demandeur' description='Voir configuration CFB')
        public String businessUnit = '';        
        @InvocableVariable(required=false label='Adresse e-mail pour contact')
        public String buContact = '';        
        @InvocableVariable(required=false label='Type de relation' description='CLIENT, FOURNISSEUR ... voir configuration CFB')
        public String relationshipType = '';        
        @InvocableVariable(required=false label='Référence de la demande')
        public String reference = '';        
        @InvocableVariable(required=false label='Code de référence du GTR' description='Voir configuration CFB')
        public String GTRrefId = '';        
        @InvocableVariable(required=false label='Code du GTR')
        public String GTRid = '';        
        @InvocableVariable(required=false label='Top entité publique')
        public Boolean publicEntity = false;        
        @InvocableVariable(required=false label='Top grand compte')
        public Boolean keyEntity = false;        
    }

    private static List <ElliDueDiligenceResult> createDueDiligence(String contract, String user, String password, String companyId, String companyCountryCode, String businessUnit, String buContact, String relationshipType, String GTRrefId, String GTRid, Boolean publicEntity, Boolean keyEntity, String reference) {
        ElliDueDiligenceResult callResponse = new ElliDueDiligenceResult();
        List<ElliDueDiligenceResult> callResponseList = new List<ElliDueDiligenceResult>();
        String resultCode;
        String xml;
        String requestBody;
        String strPublicEntity;
        String strKeyEntity;
        //2020-11-30T08:23:35.785Z
        datetime currentDateTime = datetime.now();
        String txtCurrentDateTime = currentDateTime.format('yyyy-MM-dd')+'T'+currentDateTime.format('HH:mm')+':00.000Z';
        if (companyCountryCode.length()==2) {
            companyCountryCode = convertToIso3Country(companyCountryCode);
        }
        if (companyCountryCode == '') {
            companyCountryCode = 'FRA';
        }
        if (companyCountryCode == 'FRA' & companyId.length()==14) {
            companyId = companyId.left(9);
        }
        if (publicEntity){
            strPublicEntity = 'true';
        }else{
            strPublicEntity = 'false';
        }
        if (keyEntity){
            strKeyEntity = 'true';
        }else{
            strKeyEntity = 'false';
        }
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://services-cfb.data-access-gateway.com/cfb/rest/svcCreateDueDiligence');
        req.setHeader('Content-Type','application/xml');
        req.setTimeout(90000);
         
        if (companyCountryCode == 'FRA') {
            requestBody = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><svcCreateDueDiligenceRequest lang="FR" version="2.2"><admin><client><contractId>'+contract+'</contractId><userPrefix>GEOCOM</userPrefix><userId>'+user+'</userId><password>'+password+'</password></client><context><appId version="1">WSCFB</appId><date>'+txtCurrentDateTime+'</date></context></admin><request><entity><company><id type="register">'+companyId+'</id><country code="'+companyCountryCode+'"/></company></entity><relationshipType code="'+relationshipType+'"/><risk><field name="ID" value="'+GTRrefId+'"/><field name="GTR" value="'+GTRid+'"/></risk><businessUnit><name ref="ACP" code="'+businessUnit+'"/><communication type="mail">'+buContact+'</communication></businessUnit><reference name="ID INTERNE" value="'+reference+'"/><characteristic name="SOE" value="'+strPublicEntity+'"/><characteristic name="KEYACCOUNT" value="'+strKeyEntity+'"/></request></svcCreateDueDiligenceRequest>';        
        
        }else{
            requestBody = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><svcCreateDueDiligenceRequest lang="FR" version="2.2"><admin><client><contractId>'+contract+'</contractId><userPrefix>GEOCOM</userPrefix><userId>'+user+'</userId><password>'+password+'</password></client><context><appId version="1">WSCFB</appId><date>'+txtCurrentDateTime+'</date></context></admin><request><entity><company><id type="src">'+companyId+'</id><country code="'+companyCountryCode+'"/></company></entity><relationshipType code="'+relationshipType+'"/><risk><field name="ID" value="'+GTRrefId+'"/><field name="GTR" value="'+GTRid+'"/></risk><businessUnit><name ref="ACP" code="'+businessUnit+'"/><communication type="mail">'+buContact+'</communication></businessUnit><reference name="ID INTERNE" value="'+reference+'"/><characteristic name="SOE" value="'+strPublicEntity+'"/><characteristic name="KEYACCOUNT" value="'+strKeyEntity+'"/></request></svcCreateDueDiligenceRequest>';        
        }                    
         
        req.setBody(requestBody);
         
        req.setMethod('POST');

        system.debug('Ellisphere API Call');

        Http http = new Http();
        
        try {
            HTTPResponse res = http.send(req);
            xml = res.getBody();
            System.debug(xml);
            
            
            
            System.debug('load document');
            DOM.Document document = res.getBodyDocument();
            System.debug('get root element');
            DOM.XMLNode rootElement = document.getRootElement();
            System.debug('get code');
            resultCode = rootElement.getChildElement('result', null)
                .getAttribute('code', null);
            system.debug(resultCode);
            if (resultCode  == 'OK') {
                callResponse.error = false;
                for (DOM.XmlNode node : rootElement.getChildElement('response', null).getChildren()){
                
                    if(node.getName() == 'folderId'){
                        callResponse.dueDiligenceFolderId = node.getText();
                    }
                    
                    if(node.getName() == 'dueDiligenceId'){
                        callResponse.dueDiligenceId = node.getText();
                    }
                    
                }
           } else  {
                    callResponse.error = true;
                    callResponse.comment = 'Erreur de traitement:'+rootElement.getChildElement('result', null)
                    .getChildElement('additionalInfo', null)
                    .getText();
            }
    
         } catch(Exception e) {
            callResponse.error = true;
            callResponse.comment = e.getMessage();
            System.debug('An exception occurred: ' + e.getMessage());
        } finally {
            callResponseList.add(callResponse);
            return callResponseList;
        }
        callResponseList.add(callResponse);
        return callResponseList;
    }
    private static List <ElliDueDiligenceResult> getDueDiligence(String contract, String user, String password, String dueDiligenceId) {
        ElliDueDiligenceResult callResponse = new ElliDueDiligenceResult();
        List<ElliDueDiligenceResult> callResponseList = new List<ElliDueDiligenceResult>();
        String resultCode;
        String xml;
        String requestBody;
        //2020-11-30T08:23:35.785Z
        datetime currentDateTime = datetime.now();
        String txtCurrentDateTime = currentDateTime.format('yyyy-MM-dd')+'T'+currentDateTime.format('HH:mm')+':00.000Z';
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://services-cfb.data-access-gateway.com/cfb/rest/svcGetDueDiligenceIndicators');
        req.setHeader('Content-Type','application/xml');
        req.setTimeout(90000);
         
        requestBody = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><svcGetDueDiligenceIndicatorsRequest lang="FR" version="2.2"><admin><client><contractId>'+contract+'</contractId><userPrefix>GEOCOM</userPrefix><userId>'+user+'</userId><password>'+password+'</password></client><context><appId version="1">WSCFB</appId><date>'+txtCurrentDateTime+'</date></context></admin><request><criteria><dueDiligenceId>'+dueDiligenceId+'</dueDiligenceId></criteria></request></svcGetDueDiligenceIndicatorsRequest>';        
         
        req.setBody(requestBody);
         
        req.setMethod('POST');

        system.debug('Ellisphere API Call');

        Http http = new Http();
        
        try {
            HTTPResponse res = http.send(req);
            xml = res.getBody();
            System.debug(xml);
            
            
            
            System.debug('load document');
            DOM.Document document = res.getBodyDocument();
            System.debug('get root element');
            DOM.XMLNode rootElement = document.getRootElement();
            System.debug('get code');
            resultCode = rootElement.getChildElement('result', null)
                .getAttribute('code', null);
            system.debug(resultCode);
            if (resultCode  == 'OK') {
                callResponse.error = false;
                for (DOM.XmlNode node : rootElement.getChildElement('response', null).getChildren()){
                    if(node.getName() == 'folder'){
                        for(Dom.XmlNode folderNode: node.getChildElements()) {
                            system.debug('folderNode/'+folderNode.getName()+': '+folderNode.getText());
                            if(folderNode.getName() == 'dueDiligence'){
                                for(Dom.XmlNode dueDiligenceNode: folderNode.getChildElements()) {
                                    system.debug('dueDiligence/'+dueDiligenceNode.getName()+': '+dueDiligenceNode.getText());
                                    if(dueDiligenceNode.getName() == 'status'){
                                        callResponse.dueDiligenceStatus = dueDiligenceNode.getAttribute('code', null);
                                    }
                                    if(dueDiligenceNode.getName() == 'decision'){
                                        for(Dom.XmlNode decisionNode: dueDiligenceNode.getChildElements()) {
                                            system.debug('decisionNode/'+decisionNode.getName()+': '+decisionNode.getText());
                                            if(decisionNode.getName() == 'decisionStatus'){
                                                callResponse.dueDiligenceDecision = decisionNode.getAttribute('code', null);
                                            }
                                            if(decisionNode.getName() == 'comment'){
                                                callResponse.dueDiligenceComment = decisionNode.getText();
                                            }
                                        }
                                    }
                                    if(dueDiligenceNode.getName() == 'indicator'){
                                        for(Dom.XmlNode indicatorNode: dueDiligenceNode.getChildElements()) {
                                            system.debug('indicatorNode/'+indicatorNode.getName()+': '+indicatorNode.getText());
                                            if(indicatorNode.getName() == 'color'){
                                                callResponse.dueDiligenceRisk = indicatorNode.getAttribute('code', null);
                                            }
                                        }
                                    }
                                    if(dueDiligenceNode.getName() == 'statistics' && dueDiligenceNode.getAttribute('code', null) == 'PENDINGMIT'){
                                        for(Dom.XmlNode statisticsNode: dueDiligenceNode.getChildElements()) {
                                            system.debug('statisticsNode/'+statisticsNode.getName()+': '+statisticsNode.getText());
                                            if(statisticsNode.getName() == 'value'){
                                                callResponse.dueDiligenceMitigations = statisticsNode.getText();
                                            }
                                        }
                                    }
                                    if(dueDiligenceNode.getName() == 'date' && dueDiligenceNode.getAttribute('ref', null) == 'LASTUPDATE'){
                                        system.debug('Date:'+dueDiligenceNode.getText().split('\\+')[0].replace('T', ' ')+'//');
                                        callResponse.dueDiligenceLastUpdate = Datetime.valueOfGmt(dueDiligenceNode.getText().split('\\+')[0].replace('T', ' '));
                                        system.debug('Date calculee:'+callResponse.dueDiligenceLastUpdate);
                                    }
                                }
                            }
                        }
                    }
                }
           } else  {
                    callResponse.error = true;
                    callResponse.comment = 'Erreur de traitement:'+rootElement.getChildElement('result', null)
                    .getChildElement('additionalInfo', null)
                    .getText();
            }
    
         } catch(Exception e) {
            callResponse.error = true;
            callResponse.comment = e.getMessage();
            System.debug('An exception occurred: ' + e.getMessage());
        } finally {
            callResponseList.add(callResponse);
            return callResponseList;
        }
        callResponseList.add(callResponse);
        return callResponseList;
    }
    private static List <ElliDueDiligenceResult> getFolderIdsFromEvents(String contract, String user, String password) {
        ElliDueDiligenceResult callResponse = new ElliDueDiligenceResult();
        List<ElliDueDiligenceResult> callResponseList = new List<ElliDueDiligenceResult>();
        String resultCode;
        String xml;
        String requestBody;
        //2020-11-30T08:23:35.785Z
        datetime currentDateTime = datetime.now();
        datetime yesterdayDateTime = currentDateTime.addDays(-1);
        String txtCurrentDateTime = currentDateTime.format('yyyy-MM-dd')+'T'+currentDateTime.format('HH:mm')+':00.000Z';
        String txtyesterdayDateTime = yesterdayDateTime.format('yyyy-MM-dd')+'T00:00:00.000Z';
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://services-cfb.data-access-gateway.com/cfb/rest/svcGetEvents');
        req.setHeader('Content-Type','application/xml');
        req.setTimeout(90000);
         
        requestBody = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><svcGetEventsRequest lang="FR" version="2.2"><admin><client><contractId>'+contract+'</contractId><userPrefix>GEOCOM</userPrefix><userId>'+user+'</userId><password>'+password+'</password></client><context><appId version="1">WSCFB</appId><date>'+txtCurrentDateTime+'</date></context></admin><request><eventsFilters><type>EVALUATION_EXECUTION_START</type></eventsFilters><period after="'+txtyesterdayDateTime+'" before="'+txtCurrentDateTime+'"/><page number="1" size="999"/></request></svcGetEventsRequest>';        
         
        req.setBody(requestBody);
         
        req.setMethod('POST');

        system.debug('Ellisphere API Call');

        Http http = new Http();
        
        try {
            HTTPResponse res = http.send(req);
            xml = res.getBody();
            System.debug(xml);
            
            
            
            System.debug('load document');
            DOM.Document document = res.getBodyDocument();
            System.debug('get root element');
            DOM.XMLNode rootElement = document.getRootElement();
            System.debug('get code');
            resultCode = rootElement.getChildElement('result', null)
                .getAttribute('code', null);
            system.debug(resultCode);
            if (resultCode  == 'OK') {
                callResponse.error = false;
                callResponse.dueDiligenceFolderIds = new List<String>();
                for (DOM.XmlNode node : rootElement.getChildElement('response', null).getChildren()){
                    if(node.getName() == 'folder'){
                        for(Dom.XmlNode folderNode: node.getChildElements()) {
                            system.debug('folderNode/'+folderNode.getName()+': '+folderNode.getText());
                            if(folderNode.getName() == 'id'){
                                callResponse.dueDiligenceFolderIds.add(folderNode.getText());
                            }
                        }
                    }
                }
           } else  {
                    callResponse.error = true;
                    callResponse.comment = 'Erreur de traitement:'+rootElement.getChildElement('result', null)
                    .getChildElement('additionalInfo', null)
                    .getText();
            }
    
         } catch(Exception e) {
            callResponse.error = true;
            callResponse.comment = e.getMessage();
            System.debug('An exception occurred: ' + e.getMessage());
        } finally {
            callResponseList.add(callResponse);
            return callResponseList;
        }
        callResponseList.add(callResponse);
        return callResponseList;
    }
    private static String convertToIso3Country(String countryIso2){
        String tmpReturnValue;
        switch on countryIso2 {
            when 'AF' { tmpReturnValue='AFG'; }
            when 'AX' { tmpReturnValue='ALA'; }
            when 'AL' { tmpReturnValue='ALB'; }
            when 'DZ' { tmpReturnValue='DZA'; }
            when 'AS' { tmpReturnValue='ASM'; }
            when 'AD' { tmpReturnValue='AND'; }
            when 'AO' { tmpReturnValue='AGO'; }
            when 'AI' { tmpReturnValue='AIA'; }
            when 'AQ' { tmpReturnValue='ATA'; }
            when 'AG' { tmpReturnValue='ATG'; }
            when 'AR' { tmpReturnValue='ARG'; }
            when 'AM' { tmpReturnValue='ARM'; }
            when 'AW' { tmpReturnValue='ABW'; }
            when 'AU' { tmpReturnValue='AUS'; }
            when 'AT' { tmpReturnValue='AUT'; }
            when 'AZ' { tmpReturnValue='AZE'; }
            when 'BS' { tmpReturnValue='BHS'; }
            when 'BH' { tmpReturnValue='BHR'; }
            when 'BD' { tmpReturnValue='BGD'; }
            when 'BB' { tmpReturnValue='BRB'; }
            when 'BY' { tmpReturnValue='BLR'; }
            when 'BE' { tmpReturnValue='BEL'; }
            when 'BZ' { tmpReturnValue='BLZ'; }
            when 'BJ' { tmpReturnValue='BEN'; }
            when 'BM' { tmpReturnValue='BMU'; }
            when 'BT' { tmpReturnValue='BTN'; }
            when 'BO' { tmpReturnValue='BOL'; }
            when 'BQ' { tmpReturnValue='BES'; }
            when 'BA' { tmpReturnValue='BIH'; }
            when 'BW' { tmpReturnValue='BWA'; }
            when 'BV' { tmpReturnValue='BVT'; }
            when 'BR' { tmpReturnValue='BRA'; }
            when 'IO' { tmpReturnValue='IOT'; }
            when 'BN' { tmpReturnValue='BRN'; }
            when 'BG' { tmpReturnValue='BGR'; }
            when 'BF' { tmpReturnValue='BFA'; }
            when 'BI' { tmpReturnValue='BDI'; }
            when 'CV' { tmpReturnValue='CPV'; }
            when 'KH' { tmpReturnValue='KHM'; }
            when 'CM' { tmpReturnValue='CMR'; }
            when 'CA' { tmpReturnValue='CAN'; }
            when 'KY' { tmpReturnValue='CYM'; }
            when 'CF' { tmpReturnValue='CAF'; }
            when 'TD' { tmpReturnValue='TCD'; }
            when 'CL' { tmpReturnValue='CHL'; }
            when 'CN' { tmpReturnValue='CHN'; }
            when 'CX' { tmpReturnValue='CXR'; }
            when 'CC' { tmpReturnValue='CCK'; }
            when 'CO' { tmpReturnValue='COL'; }
            when 'KM' { tmpReturnValue='COM'; }
            when 'CG' { tmpReturnValue='COG'; }
            when 'CD' { tmpReturnValue='COD'; }
            when 'CK' { tmpReturnValue='COK'; }
            when 'CR' { tmpReturnValue='CRI'; }
            when 'CI' { tmpReturnValue='CIV'; }
            when 'HR' { tmpReturnValue='HRV'; }
            when 'CU' { tmpReturnValue='CUB'; }
            when 'CW' { tmpReturnValue='CUW'; }
            when 'CY' { tmpReturnValue='CYP'; }
            when 'CZ' { tmpReturnValue='CZE'; }
            when 'DK' { tmpReturnValue='DNK'; }
            when 'DJ' { tmpReturnValue='DJI'; }
            when 'DM' { tmpReturnValue='DMA'; }
            when 'DO' { tmpReturnValue='DOM'; }
            when 'EC' { tmpReturnValue='ECU'; }
            when 'EG' { tmpReturnValue='EGY'; }
            when 'SV' { tmpReturnValue='SLV'; }
            when 'GQ' { tmpReturnValue='GNQ'; }
            when 'ER' { tmpReturnValue='ERI'; }
            when 'EE' { tmpReturnValue='EST'; }
            when 'SZ' { tmpReturnValue='SWZ'; }
            when 'ET' { tmpReturnValue='ETH'; }
            when 'FK' { tmpReturnValue='FLK'; }
            when 'FO' { tmpReturnValue='FRO'; }
            when 'FJ' { tmpReturnValue='FJI'; }
            when 'FI' { tmpReturnValue='FIN'; }
            when 'FR' { tmpReturnValue='FRA'; }
            when 'GF' { tmpReturnValue='GUF'; }
            when 'PF' { tmpReturnValue='PYF'; }
            when 'TF' { tmpReturnValue='ATF'; }
            when 'GA' { tmpReturnValue='GAB'; }
            when 'GM' { tmpReturnValue='GMB'; }
            when 'GE' { tmpReturnValue='GEO'; }
            when 'DE' { tmpReturnValue='DEU'; }
            when 'GH' { tmpReturnValue='GHA'; }
            when 'GI' { tmpReturnValue='GIB'; }
            when 'GR' { tmpReturnValue='GRC'; }
            when 'GL' { tmpReturnValue='GRL'; }
            when 'GD' { tmpReturnValue='GRD'; }
            when 'GP' { tmpReturnValue='GLP'; }
            when 'GU' { tmpReturnValue='GUM'; }
            when 'GT' { tmpReturnValue='GTM'; }
            when 'GG' { tmpReturnValue='GGY'; }
            when 'GN' { tmpReturnValue='GIN'; }
            when 'GW' { tmpReturnValue='GNB'; }
            when 'GY' { tmpReturnValue='GUY'; }
            when 'HT' { tmpReturnValue='HTI'; }
            when 'HM' { tmpReturnValue='HMD'; }
            when 'VA' { tmpReturnValue='VAT'; }
            when 'HN' { tmpReturnValue='HND'; }
            when 'HK' { tmpReturnValue='HKG'; }
            when 'HU' { tmpReturnValue='HUN'; }
            when 'IS' { tmpReturnValue='ISL'; }
            when 'IN' { tmpReturnValue='IND'; }
            when 'ID' { tmpReturnValue='IDN'; }
            when 'IR' { tmpReturnValue='IRN'; }
            when 'IQ' { tmpReturnValue='IRQ'; }
            when 'IE' { tmpReturnValue='IRL'; }
            when 'IM' { tmpReturnValue='IMN'; }
            when 'IL' { tmpReturnValue='ISR'; }
            when 'IT' { tmpReturnValue='ITA'; }
            when 'JM' { tmpReturnValue='JAM'; }
            when 'JP' { tmpReturnValue='JPN'; }
            when 'JE' { tmpReturnValue='JEY'; }
            when 'JO' { tmpReturnValue='JOR'; }
            when 'KZ' { tmpReturnValue='KAZ'; }
            when 'KE' { tmpReturnValue='KEN'; }
            when 'KI' { tmpReturnValue='KIR'; }
            when 'KP' { tmpReturnValue='PRK'; }
            when 'KR' { tmpReturnValue='KOR'; }
            when 'KW' { tmpReturnValue='KWT'; }
            when 'KG' { tmpReturnValue='KGZ'; }
            when 'LA' { tmpReturnValue='LAO'; }
            when 'LV' { tmpReturnValue='LVA'; }
            when 'LB' { tmpReturnValue='LBN'; }
            when 'LS' { tmpReturnValue='LSO'; }
            when 'LR' { tmpReturnValue='LBR'; }
            when 'LY' { tmpReturnValue='LBY'; }
            when 'LI' { tmpReturnValue='LIE'; }
            when 'LT' { tmpReturnValue='LTU'; }
            when 'LU' { tmpReturnValue='LUX'; }
            when 'MO' { tmpReturnValue='MAC'; }
            when 'MG' { tmpReturnValue='MDG'; }
            when 'MW' { tmpReturnValue='MWI'; }
            when 'MY' { tmpReturnValue='MYS'; }
            when 'MV' { tmpReturnValue='MDV'; }
            when 'ML' { tmpReturnValue='MLI'; }
            when 'MT' { tmpReturnValue='MLT'; }
            when 'MH' { tmpReturnValue='MHL'; }
            when 'MQ' { tmpReturnValue='MTQ'; }
            when 'MR' { tmpReturnValue='MRT'; }
            when 'MU' { tmpReturnValue='MUS'; }
            when 'YT' { tmpReturnValue='MYT'; }
            when 'MX' { tmpReturnValue='MEX'; }
            when 'FM' { tmpReturnValue='FSM'; }
            when 'MD' { tmpReturnValue='MDA'; }
            when 'MC' { tmpReturnValue='MCO'; }
            when 'MN' { tmpReturnValue='MNG'; }
            when 'ME' { tmpReturnValue='MNE'; }
            when 'MS' { tmpReturnValue='MSR'; }
            when 'MA' { tmpReturnValue='MAR'; }
            when 'MZ' { tmpReturnValue='MOZ'; }
            when 'MM' { tmpReturnValue='MMR'; }
            when 'NA' { tmpReturnValue='NAM'; }
            when 'NR' { tmpReturnValue='NRU'; }
            when 'NP' { tmpReturnValue='NPL'; }
            when 'NL' { tmpReturnValue='NLD'; }
            when 'NC' { tmpReturnValue='NCL'; }
            when 'NZ' { tmpReturnValue='NZL'; }
            when 'NI' { tmpReturnValue='NIC'; }
            when 'NE' { tmpReturnValue='NER'; }
            when 'NG' { tmpReturnValue='NGA'; }
            when 'NU' { tmpReturnValue='NIU'; }
            when 'NF' { tmpReturnValue='NFK'; }
            when 'MK' { tmpReturnValue='MKD'; }
            when 'MP' { tmpReturnValue='MNP'; }
            when 'NO' { tmpReturnValue='NOR'; }
            when 'OM' { tmpReturnValue='OMN'; }
            when 'PK' { tmpReturnValue='PAK'; }
            when 'PW' { tmpReturnValue='PLW'; }
            when 'PS' { tmpReturnValue='PSE'; }
            when 'PA' { tmpReturnValue='PAN'; }
            when 'PG' { tmpReturnValue='PNG'; }
            when 'PY' { tmpReturnValue='PRY'; }
            when 'PE' { tmpReturnValue='PER'; }
            when 'PH' { tmpReturnValue='PHL'; }
            when 'PN' { tmpReturnValue='PCN'; }
            when 'PL' { tmpReturnValue='POL'; }
            when 'PT' { tmpReturnValue='PRT'; }
            when 'PR' { tmpReturnValue='PRI'; }
            when 'QA' { tmpReturnValue='QAT'; }
            when 'RE' { tmpReturnValue='REU'; }
            when 'RO' { tmpReturnValue='ROU'; }
            when 'RU' { tmpReturnValue='RUS'; }
            when 'RW' { tmpReturnValue='RWA'; }
            when 'BL' { tmpReturnValue='BLM'; }
            when 'SH' { tmpReturnValue='SHN'; }
            when 'KN' { tmpReturnValue='KNA'; }
            when 'LC' { tmpReturnValue='LCA'; }
            when 'MF' { tmpReturnValue='MAF'; }
            when 'PM' { tmpReturnValue='SPM'; }
            when 'VC' { tmpReturnValue='VCT'; }
            when 'WS' { tmpReturnValue='WSM'; }
            when 'SM' { tmpReturnValue='SMR'; }
            when 'ST' { tmpReturnValue='STP'; }
            when 'SA' { tmpReturnValue='SAU'; }
            when 'SN' { tmpReturnValue='SEN'; }
            when 'RS' { tmpReturnValue='SRB'; }
            when 'SC' { tmpReturnValue='SYC'; }
            when 'SL' { tmpReturnValue='SLE'; }
            when 'SG' { tmpReturnValue='SGP'; }
            when 'SX' { tmpReturnValue='SXM'; }
            when 'SK' { tmpReturnValue='SVK'; }
            when 'SI' { tmpReturnValue='SVN'; }
            when 'SB' { tmpReturnValue='SLB'; }
            when 'SO' { tmpReturnValue='SOM'; }
            when 'ZA' { tmpReturnValue='ZAF'; }
            when 'GS' { tmpReturnValue='SGS'; }
            when 'SS' { tmpReturnValue='SSD'; }
            when 'ES' { tmpReturnValue='ESP'; }
            when 'LK' { tmpReturnValue='LKA'; }
            when 'SD' { tmpReturnValue='SDN'; }
            when 'SR' { tmpReturnValue='SUR'; }
            when 'SJ' { tmpReturnValue='SJM'; }
            when 'SE' { tmpReturnValue='SWE'; }
            when 'CH' { tmpReturnValue='CHE'; }
            when 'SY' { tmpReturnValue='SYR'; }
            when 'TW' { tmpReturnValue='TWN'; }
            when 'TJ' { tmpReturnValue='TJK'; }
            when 'TZ' { tmpReturnValue='TZA'; }
            when 'TH' { tmpReturnValue='THA'; }
            when 'TL' { tmpReturnValue='TLS'; }
            when 'TG' { tmpReturnValue='TGO'; }
            when 'TK' { tmpReturnValue='TKL'; }
            when 'TO' { tmpReturnValue='TON'; }
            when 'TT' { tmpReturnValue='TTO'; }
            when 'TN' { tmpReturnValue='TUN'; }
            when 'TR' { tmpReturnValue='TUR'; }
            when 'TM' { tmpReturnValue='TKM'; }
            when 'TC' { tmpReturnValue='TCA'; }
            when 'TV' { tmpReturnValue='TUV'; }
            when 'UG' { tmpReturnValue='UGA'; }
            when 'UA' { tmpReturnValue='UKR'; }
            when 'AE' { tmpReturnValue='ARE'; }
            when 'GB' { tmpReturnValue='GBR'; }
            when 'US' { tmpReturnValue='USA'; }
            when 'UM' { tmpReturnValue='UMI'; }
            when 'UY' { tmpReturnValue='URY'; }
            when 'UZ' { tmpReturnValue='UZB'; }
            when 'VU' { tmpReturnValue='VUT'; }
            when 'VE' { tmpReturnValue='VEN'; }
            when 'VN' { tmpReturnValue='VNM'; }
            when 'VG' { tmpReturnValue='VGB'; }
            when 'VI' { tmpReturnValue='VIR'; }
            when 'WF' { tmpReturnValue='WLF'; }
            when 'EH' { tmpReturnValue='ESH'; }
            when 'YE' { tmpReturnValue='YEM'; }
            when 'ZM' { tmpReturnValue='ZMB'; }
            when 'ZW' { tmpReturnValue='ZWE'; }
            when else { tmpReturnValue= ''; }
        }
        return tmpReturnValue;
    }
}