public class OlbicoGlobalFamilyTreeSettings {

    @TestVisible
    private OnBoardSettings__c apiSettings;

    public OlbicoGlobalFamilyTreeSettings(){
        this.apiSettings = OnBoardSettings__c.getOrgDefaults();
    }

    public OlbicoGlobalFamilyTreeSettings(OnBoardSettings__c apiSettings) {
        this.apiSettings = apiSettings;
    }

    public String Host{
        get{
            return this.apiSettings.Host__c;
        }
    }

    public String Version{
        get{
            return this.apiSettings.Version__c;
        }
    }

    public String UserName{
        get{
            return this.apiSettings.Username__c;
        }
    }

    public String Password{
        get{
            return this.apiSettings.Password__c;
        }
    }

    public String DunsFieldName{
        get{
            return this.apiSettings.DunsFieldName__c;
        }
    }

    public String GlobalUltimateDunsFieldName{
        get{
            return this.apiSettings.GlobalUltimateDunsFieldName__c;
        }
    }

    public String SearchMappingDunsField{
        get{
            return this.apiSettings.SearchMappingDunsField__c;
        }
    }

    public String SearchMappingNameField{
        get{
            return this.apiSettings.SearchMappingNameField__c;
        }
    }

    public String SearchMappingCountryNameField{
        get{
            return this.apiSettings.SearchMappingCountryNameField__c;
        }
    }

    public String SearchMappingCountryIsoCodeField{
        get{
            return this.apiSettings.SearchMappingCountryIsoCodeField__c;
        }
    }

    public String CacheNamespace {
        get {
            return this.apiSettings.CacheNamespace__c;
        }
    }

    public String SearchPageUrl{
        get{
            return this.apiSettings.SearchPageUrl__c;
        }
    }

    public String SearchPageUrlLightning{
        get{
            return this.apiSettings.SearchPageUrlLightning__c;
        }
    }

    public Boolean GlobalFamTreeImmediate {
        get{
            return this.apiSettings.GlobalFamTreeImmediate__c;
        }
    }


    public List<String> getQueryableFields() {

        List<String> fields = new List<String>();

        if (!String.isBlank(this.DunsFieldName)) {
            fields.add(this.DunsFieldName);
        }

        if (!String.isBlank(this.GlobalUltimateDunsFieldName)) {
            fields.add(this.GlobalUltimateDunsFieldName);
        }

        return fields;
    }

    public static OlbicoGlobalFamilyTreeSettings getInstance(){

        OlbicoGlobalFamilyTreeSettings instance = new OlbicoGlobalFamilyTreeSettings();
        if(instance.apiSettings.id == null){
            return null;
        }

        return instance;
    }
}