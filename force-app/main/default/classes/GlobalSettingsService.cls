/**
 * Created by BCH on 25/01/2020.
 */

public with sharing class GlobalSettingsService {

    private static Map<String, String> globalSettingsMapping;
    public static void loadMappingService() {
        globalSettingsMapping = geGlobalSettingsMapping();
    }

    private static  Map<String, String> geGlobalSettingsMapping() {
        String previousFieldName;
        Map<String, String> globalSettingsMappings = new  Map<String, String>();

        for (Global_Settings__c globalSetting:[SELECT key__c,value__c
                                                FROM global_settings__c
                                                ORDER BY key__c]) {
            globalSettingsMappings.put(globalSetting.key__c.toLowerCase(), globalSetting.value__c.toLowerCase());
            System.debug(' ============================================= globalSetting <key__c : value__c > : <'+ globalSetting.key__c +' : '+globalSetting.key__c+'>');
        }
        System.debug(' ============================================= globalSettingsMappings  : ' + globalSettingsMappings);

        return globalSettingsMappings;
    }


    public static String getValueSetting(String key) {
        String returnValue;
        try {
            returnValue = globalSettingsMapping.get(key.toLowerCase());
            returnValue = (returnValue == null) ? 'No Mapping' : returnValue;

        } catch (Exception e){
            returnValue =  'No Mapping';
        }
        System.debug(' ============================================= GlobalSetting key : '+ key + ' returnValue :' + returnValue);
        return returnValue;
    }
}