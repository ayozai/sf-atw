/**
Author : Vibhor Goel (www.accidentalcodersf.com) - Accidental Coder - A Salesforce Blog 
**/

@isTest
public class MultiSelectFlowValuesTestClass{
    
    @isTest
    static void MultiSelectFlowValuesTest(){
    
        List<string> tempLst = new list<string>();
        tempLst.add('AccidentalCoder');
        tempLst.add('Salesforce');
        MultiselectFlowvalues.CheckValues(tempLst);

    }
}