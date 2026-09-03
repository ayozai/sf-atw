public class OlbicoAccountRepository {

    private static Integer criteriaBatchSize = 450;
    
    private OlbicoGlobalFamilyTreeSettings settings = null;

    public OlbicoAccountRepository(OlbicoGlobalFamilyTreeSettings settings){
        this.settings = settings;
    }

    public Map<String,List<Account>> getAccountsByDunsNumbers(List<String> dunsNumbers) {
        
        System.debug('[FTREE] getAccountsByDunsNumbers(): Getting account matching tree duns numbers');
        List<sObject> accounts = new List<sObject>();
        Stopwatch watch = new Stopwatch();
        watch.start();

        if (dunsNumbers == null)
            return null;
                        
        Integer totalDuns = dunsNumbers.size();
        Integer batches = (totalDuns / criteriaBatchSize) + Math.mod(totalDuns,criteriaBatchSize) > 0 ? 1 : 0;

        System.debug(String.format('[FTREE] Requesting in {0} batches.', new String[]{ String.valueOf(batches) }));
        for (Integer i = 0; i < batches; i++)
        {
            List<String> dunsBatch = slice(dunsNumbers, i * criteriaBatchSize, criteriaBatchSize);
            List<sObject> batch = getBatchOfAccounts(settings.DunsFieldName, dunsBatch);
            accounts.addAll(batch);
        }
                    
        watch.stop();
        System.debug('[FTREE] getAccountsByDunsNumbers(): Getting matching tree accounts exec time:' + watch.Elapsed);

        Map<String,List<Account>> mapping = new Map<String,List<Account>>();

        for(sObject a : accounts){
            Account acc = (Account)a;
            String dunsNumber = (String)acc.get(settings.DunsFieldName);
            
            if (!mapping.containsKey(dunsNumber)) {
                mapping.put(dunsNumber, new List<Account>());
            }
            
            mapping.get(dunsNumber).add(acc);
        }

        return mapping;
    }

    public Map<String,List<Account>> getAccountsByGlobalUltimate(String globalUltimateDuns){
        
        System.debug('[FTREE] Getting account matching guduns');
        Stopwatch watch = new Stopwatch();
        watch.start();
        
        String query = String.format('SELECT Id,Name,{0},{1} FROM Account WHERE {0} != NULL AND {1} = :globalUltimateDuns', new String[]{ 
                                                                                            settings.DunsFieldName, 
                                                                                            settings.GlobalUltimateDunsFieldName});
        System.debug('[FTREE] Executing query:' + query);
        List<sObject> accounts = Database.query(query);
        watch.stop();

        System.debug('[FTREE] Getting accounts by global ultimate duns exec time:' + watch.Elapsed);

        Map<String,List<Account>> mapping = new Map<String,List<Account>>();

        for(sObject a : accounts){
            Account acc = (Account)a;
            String dunsNumber = (String)acc.get(settings.DunsFieldName);
            
            if (!mapping.containsKey(dunsNumber)) {
                mapping.put(dunsNumber, new List<Account>());
            }
            
            mapping.get(dunsNumber).add(acc);
        }

        return mapping;
    }
    
    public static List<String> slice(List<String> input, Integer startRange, Integer amount)
    {
        List<String> output = new List<String>();

        Integer endRange = startRange + amount;
        if (endRange > input.size()+1) {
            endRange = input.size();
        }

        for (Integer i = startRange; i<endRange; i++) {
            
            output.add(input.get(i));
        }
            
        return output;
    }

    private List<sObject> getBatchOfAccounts(String dunsFieldName, List<String> dunsNumbers){
        
        String dunsCollection = String.join(dunsNumbers, '\',\'');
        dunsCollection = '\'' + dunsCollection +'\'' ;

        String query = String.format('SELECT Id, Name, {0} FROM Account WHERE {0} IN ({1})', new String[]{dunsFieldName, dunsCollection});        
        System.debug('[FTREE] Executing query:' + query);
        
        List<sObject> accounts = Database.query(query);
        return accounts;
    }

    public Account getById(String id){
        if(id == null)
            return null;

        List<String> fields = settings.getQueryableFields();
        String queryParams = ''; 
        if (!fields.isEmpty()) {
            queryParams = ',' + String.join(fields,',');
        }

        String query = String.format('SELECT Id,Name {0} FROM Account WHERE Id = :id', new String[]{ queryParams });    
        List<sObject> accounts = Database.query(query);

        if(accounts.size() > 0)            
            return (Account)accounts[0];

        return null;
    }
}