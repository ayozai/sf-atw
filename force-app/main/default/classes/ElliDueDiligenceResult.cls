public class ElliDueDiligenceResult {
  @AuraEnabled @InvocableVariable public Boolean error;
  @AuraEnabled @InvocableVariable public String comment;
  @AuraEnabled @InvocableVariable public String dueDiligenceFolderId;
  @AuraEnabled @InvocableVariable public String dueDiligenceId;
  @AuraEnabled @InvocableVariable public String dueDiligenceStatus;
  @AuraEnabled @InvocableVariable public String dueDiligenceRisk;
  @AuraEnabled @InvocableVariable public String dueDiligenceDecision;
  @AuraEnabled @InvocableVariable public String dueDiligenceComment;
  @AuraEnabled @InvocableVariable public String dueDiligenceMitigations;
  @AuraEnabled @InvocableVariable public List<String> dueDiligenceFolderIds;
  @AuraEnabled @InvocableVariable public Datetime dueDiligenceLastUpdate;
}