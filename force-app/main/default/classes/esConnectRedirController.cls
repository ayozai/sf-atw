/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-30-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class esConnectRedirController {
private final Account account;
public esConnectRedirController(ApexPages.StandardController stdController) {
this.account= (Account)stdController.getRecord();
}
public PageReference redirectToConnectSearch(){
//Write your logic here and redirect
PageReference retURL = new
PageReference('/lightning/n/ESCONNECT__Moteur_de_recherche');
retURL.setRedirect(true); return retURL;
 }
}