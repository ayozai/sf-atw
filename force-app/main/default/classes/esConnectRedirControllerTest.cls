/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-30-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
public class esConnectRedirControllerTest {
 @isTest
 static void testRedirectToConnectSearch() {
 // Création de données de test pour un Account
 Account testAccount = new Account(
 Name = 'Test Account' // Le champ obligatoire pour Account
 );
 insert testAccount;
 // Initialisation du contrôleur standard avec l'enregistrement de test
 ApexPages.StandardController stdController = new ApexPages.StandardController(testAccount);
 esConnectRedirController testController = new esConnectRedirController(stdController);
 // Appel de la méthode à tester
 PageReference result = testController.redirectToConnectSearch();

 // Assertions pour vérifier le comportement attendu
 System.assertNotEquals(result, null, 'La PageReference ne doit pas être nulle.');
 System.assertEquals('/lightning/n/ESCONNECT__Moteur_de_recherche', result.getUrl(), 'L\'URL retournée est incorrecte.');
 System.assert(result.getRedirect(), 'La redirection doit être activée.');
 }
}